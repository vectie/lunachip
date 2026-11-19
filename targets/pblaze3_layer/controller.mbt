///|
/// PBlaze3 ABI 1.1 AXI-Lite controller with a 2 GiB compute-memory aperture.
/// AXI-Lite addresses are local BAR offsets; bulk DDR access belongs to XDMA.
/// Program/scratch writes are rejected while the engine is busy.
pub fn controller(
  profile~ : Bool = false,
  wide512~ : Bool = false,
  wide1024~ : Bool = false,
  scalar_lines~ : Bool = false,
  store_bursts~ : Bool = false,
  chain~ : Bool = false,
  program_bursts~ : Bool = false,
  stream_unary~ : Bool = false,
  indirect_bf16~ : Bool = false,
  deep_batch~ : Bool = false,
  strided_rows~ : Bool = false,
  group64_rows~ : Bool = false,
  stripe512~ : Bool = false,
  prefetch_row_blocks~ : Bool = false,
) -> @ir.Module raise {
  assert_true(!stream_unary || program_bursts)
  assert_true(!strided_rows || deep_batch)
  assert_true(!group64_rows || deep_batch)
  assert_true(!stripe512 || group64_rows)
  assert_true(!prefetch_row_blocks || stripe512)
  assert_true(!deep_batch || wide1024)
  assert_true(!indirect_bf16 || stream_unary)
  assert_true(!program_bursts || (wide1024 && chain))
  assert_true(!wide1024 || wide512)
  assert_true(!store_bursts || (wide1024 && scalar_lines))
  let wide = true
  let batch = true
  let eight_row = true
  let sixteen_row = true
  let delivery = true
  assert_true(!delivery || sixteen_row)
  assert_true(!sixteen_row || eight_row)
  let beat_width = if prefetch_row_blocks {
    12
  } else if deep_batch {
    8
  } else if sixteen_row {
    7
  } else {
    6
  }
  let b = @wire.ModuleBuilder::new("Pblaze3QwenLayerControl")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  b.input_timing(rs, SampledIn(d.id()))
  let reset = b.synchronous_reset(rs, 0UL)
  let loader = resident_loader(b, d, reset)
  let a = axi_begin(b, d, reset)
  let healthy = input(b, d, "memory_healthy", 1)
  let ready = input(b, d, "ddr_request_ready", 1)
  let response = input(b, d, "ddr_response_valid", 1)
  let response_data = input(b, d, "ddr_response_data", 32)
  let response_fault = input(b, d, "ddr_response_fault", 2)
  let response_last = input(b, d, "ddr_response_last", 1)
  let c : Map[String, @wire.Signal] = Map([])
  for p in @fp.feedback_layer_machine(delivery=true, memory=GiB2).outputs() {
    let x = b.input("c_" + p.name(), p.signal_type())
    b.input_timing(x, SampledIn(d.id()))
    c[p.name()] = x
  }
  if store_bursts {
    for
      (name, width) in [
        ("store_fill_valid", 1),
        ("store_fill_index", 6),
        ("store_word", 32),
        ("store_commit_valid", 1),
        ("store_commit_address", 32),
      ] {
      c[name] = input(b, d, "c_" + name, width)
    }
    out(b, "ddr_request_fill_valid", c["store_fill_valid"])
    out(b, "ddr_request_fill_index", c["store_fill_index"])
    out(b, "ddr_request_fill_data", c["store_word"])
  }
  let owner = b.register_state_in(d, @wire.uint(2), reset~)
  let issued = b.register_state_in(d, @wire.bits(1), reset~)
  let beat = b.register_state_in(d, @wire.uint(beat_width), reset~)
  let line = b.register_state_in(d, @wire.bits(1), reset~)
  let wide_line = if wide {
    Some(b.register_state_in(d, @wire.bits(1), reset~))
  } else {
    None
  }
  let poisoned = b.register_state_in(d, @wire.bits(1), reset~)
  let batch_line = if batch {
    Some(b.register_state_in(d, @wire.bits(1), reset~))
  } else {
    None
  }
  let vacant = eq(b, owner.value(), 0UL)
  let write_owner = eq(b, owner.value(), 1UL)
  let read_owner = eq(b, owner.value(), 2UL)
  let job_owner = eq(b, owner.value(), 3UL)
  let long_batch = if wide1024 {
    Some(b.register_state_in(d, @wire.bits(1), reset~))
  } else {
    None
  }
  let group32 = if deep_batch {
    Some(b.register_state_in(d, @wire.bits(1), reset~))
  } else {
    None
  }
  let prefetch = if prefetch_row_blocks {
    Some(b.register_state_in(d, @wire.bits(1), reset~))
  } else {
    None
  }
  let burst = if program_bursts {
    Some(program_burst(b, d, reset, read_owner))
  } else {
    None
  }
  let wire_valid = response
  let stream_ready = if burst is Some(p) {
    Some(
      any(b, [
        p.ready,
        b.bit_not(healthy),
        b.bit_not(eq(b, response_fault, 0UL)),
        eq(b, loader.state.value(), 4UL),
      ]),
    )
  } else {
    None
  }
  let response = if stream_ready is Some(rdy) {
    b.bit_and(response, rdy)
  } else {
    response
  }
  let expected_last = b.bit_or(
    b.bit_not(line.value()),
    if wide {
      b.equal(
        beat.value(),
        if batch {
          b.mux(
            b.bit_and(
              wide_line.unwrap().value(),
              b.bit_not(batch_line.unwrap().value()),
            ),
            n(
              b,
              beat_width,
              if wide1024 {
                0UL
              } else if wide512 {
                1UL
              } else if delivery {
                3UL
              } else {
                7UL
              },
            ),
            if eight_row {
              b.mux(
                batch_line.unwrap().value(),
                if long_batch is Some(flag) {
                  b.mux(
                    flag.value(),
                    if group32 is Some(g) {
                      b.mux(
                        g.value(),
                        if prefetch is Some(early) {
                          b.mux(
                            early.value(),
                            n(b, beat_width, 4095UL),
                            n(b, beat_width, 255UL),
                          )
                        } else {
                          n(b, beat_width, 255UL)
                        },
                        n(b, beat_width, 63UL),
                      )
                    } else {
                      n(b, beat_width, 63UL)
                    },
                    n(b, beat_width, 15UL),
                  )
                } else {
                  n(
                    b,
                    beat_width,
                    if wide512 {
                      31UL
                    } else if delivery {
                      63UL
                    } else if sixteen_row {
                      127UL
                    } else {
                      63UL
                    },
                  )
                },
                n(b, beat_width, 31UL),
              )
            } else {
              n(b, beat_width, 31UL)
            },
          )
        } else {
          b.mux(
            wide_line.unwrap().value(),
            n(b, beat_width, 7UL),
            n(b, beat_width, 31UL),
          )
        },
      )
    } else {
      eq(b, beat.value(), 31UL)
    },
  )
  let expected_last = if burst is Some(p) {
    b.mux(
      read_owner,
      b.bit_or(b.bit_not(p.batch.value()), eq(b, beat.value(), 63UL)),
      expected_last,
    )
  } else {
    expected_last
  }
  let bad = both(b, [
    if program_bursts {
      wire_valid
    } else {
      response
    },
    any(b, [
      vacant,
      b.bit_not(issued.value()),
      b.bit_xor(expected_last, response_last),
    ]),
  ])
  let malformed_core = both(b, [
    c["ddr_request_valid"],
    any(b, [
      b.bit_xor(c["ddr_request_line"], c["ddr_request_burst"]),
      if store_bursts {
        both(b, [
          c["ddr_request_write"],
          c["ddr_request_line"],
          c["ddr_request_wide"],
        ])
      } else {
        b.bit_and(c["ddr_request_write"], c["ddr_request_line"])
      },
    ]),
  ])
  update(b, poisoned, b.bit_or(bad, malformed_core), n(b, 1, 1UL))
  let loader_result = both(b, [response, issued.value(), read_owner])
  let loader_word = if program_bursts {
    both(b, [wire_valid, issued.value(), read_owner])
  } else {
    loader_result
  }
  let loader_fault = both(b, [
    loader.busy,
    any(b, [
      b.bit_not(healthy),
      bad,
      b.bit_and(loader_word, b.bit_not(eq(b, response_fault, 0UL))),
      eq(b, loader.state.value(), 4UL),
      b.greater_equal(loader.cycles.value(), n(b, 32, 250000000UL)),
    ]),
  ])
  let active = if chain {
    Some(b.register_state_in(d, @wire.bits(1), reset~))
  } else {
    None
  }
  let protocol = any(b, [poisoned.value(), bad, malformed_core, loader_fault])
  let protocol = if active is Some(flag) {
    let failed = b.register_state_in(d, @wire.bits(1), reset~)
    update(b, failed, b.bit_and(flag.value(), b.bit_not(healthy)), n(b, 1, 1UL))
    b.bit_or(protocol, failed.value())
  } else {
    protocol
  }
  let terminated = both(b, [response, issued.value(), expected_last])
  let idle = both(b, [
    b.bit_not(c["busy"]),
    b.bit_not(c["fault"]),
    b.bit_not(protocol),
    b.bit_not(loader.busy),
  ])
  let idle = if active is Some(flag) {
    b.bit_and(idle, b.bit_not(flag.value()))
  } else {
    idle
  }
  let configurable = both(b, [idle, vacant])
  let count = b.register_state_in(d, @wire.uint(12), reset~)
  let shape = eq(b, a.strobe, 15UL)
  let aligned = eq(b, b.slice(a.address, 1, 0), 0UL)
  let read_aligned = eq(b, b.slice(a.ar_address, 1, 0), 0UL)
  // DDR is a separate XDMA address space. No AXI-Lite alias may reach it.
  let write_ddr = n(b, 1, 0UL)
  let read_ddr = n(b, 1, 0UL)
  let write_program = eq(b, b.slice(a.address, 31, 17), 1UL)
  let read_program = eq(b, b.slice(a.ar_address, 31, 17), 1UL)
  let write_scratch = eq(b, b.slice(a.address, 31, 17), 2UL)
  let read_scratch = eq(b, b.slice(a.ar_address, 31, 17), 2UL)
  let writable = both(b, [a.write, configurable, shape, aligned])
  let start = both(b, [
    writable,
    healthy,
    eq(b, a.address, 16UL),
    eq(b, a.data, 1UL),
    b.greater_equal(count.value(), n(b, 12, 1UL)),
    b.less_equal(count.value(), n(b, 12, 2048UL)),
    b.less_equal(
      b.add(
        b.zero_extend(loader.base.value(), 33),
        b.shift_left(b.zero_extend(count.value(), 33), n(b, 33, 6UL)),
      ),
      n(b, 33, 0x80000000UL),
    ),
  ])
  let base_write = both(b, [
    writable,
    eq(b, a.address, 0x3cUL),
    eq(b, b.slice(a.data, 5, 0), 0UL),
    b.less_than(a.data, n(b, 32, 0x80000000UL)),
  ])
  let scheduler = if active is Some(flag) {
    Some(
      token_chain(b, d, reset, a, writable, healthy, protocol, flag, loader, c),
    )
  } else {
    None
  }
  let accepted = if scheduler is Some(s) {
    b.bit_or(start, s.accept)
  } else {
    start
  }
  let segment_count = match (scheduler, active) {
    (Some(s), Some(flag)) => b.mux(flag.value(), s.count, count.value())
    _ => count.value()
  }
  if scheduler is Some(s) {
    update(
      b,
      loader.base,
      b.bit_or(base_write, s.advance),
      b.mux(s.advance, b.add(loader.base.value(), n(b, 32, 131072UL)), a.data),
    )
  } else {
    update(b, loader.base, base_write, a.data)
  }
  let count_write = both(b, [
    writable,
    eq(b, a.address, 20UL),
    b.greater_equal(a.data, n(b, 32, 1UL)),
    b.less_equal(a.data, n(b, 32, 2048UL)),
  ])
  // A posted host MMIO write is not an acknowledgement that START was
  // accepted. Expose a generation that advances only on the accepted start,
  // so a previous job's DONE cannot be mistaken for a new completion.
  let launch_sequence = b.register_state_in(d, @wire.uint(32), reset~)
  update(
    b,
    launch_sequence,
    accepted,
    b.add(launch_sequence.value(), n(b, 32, 1UL)),
  )
  update(b, count, count_write, b.truncate(a.data, 12))
  out(
    b,
    "start",
    both(b, [
      b.bit_not(protocol),
      healthy,
      any(b, [b.bit_and(start, eq(b, loader.base.value(), 0UL)), loader.launch]),
    ]),
  )
  out(b, "program_count", segment_count)
  out(b, "core_reset", b.reset_asserted(rs))
  let load_word = b.bit_and(loader_word, b.bit_not(protocol))
  out(
    b,
    "program_write",
    b.bit_or(b.bit_and(writable, write_program), load_word),
  )
  out(
    b,
    "program_address",
    b.mux(load_word, loader.index.value(), u(b, b.slice(a.address, 16, 2))),
  )
  if !program_bursts {
    out(b, "program_data", b.mux(load_word, response_data, a.data))
  }
  out(b, "scratch_write", b.bit_and(writable, write_scratch))
  out(b, "scratch_address", u(b, b.slice(a.address, 16, 2)))
  out(b, "scratch_data", a.data)
  let local_pending = b.register_state_in(d, @wire.bits(1), reset~)
  let local_read = both(b, [
    a.read,
    configurable,
    read_aligned,
    b.bit_not(local_pending.value()),
  ])
  let take_local = both(b, [local_read, b.bit_or(read_program, read_scratch)])
  let program_pending = b.register_state_in(d, @wire.bits(1), reset~)
  update(b, program_pending, take_local, read_program)
  out(b, "program_read", b.bit_and(local_read, read_program))
  out(b, "program_read_address", u(b, b.slice(a.ar_address, 16, 2)))
  out(b, "scratch_read", b.bit_and(local_read, read_scratch))
  out(b, "scratch_read_address", u(b, b.slice(a.ar_address, 16, 2)))
  let local_done = both(b, [
    local_pending.value(),
    b.mux(
      program_pending.value(),
      c["program_read_valid"],
      c["scratch_read_valid"],
    ),
  ])
  b.connect_next(
    local_pending,
    b.mux(
      local_done,
      n(b, 1, 0UL),
      b.mux(take_local, n(b, 1, 1UL), local_pending.value()),
    ),
  )
  let take_write = both(b, [
    a.write,
    write_ddr,
    configurable,
    healthy,
    shape,
    aligned,
  ])
  let take_read = both(b, [loader.request, vacant, healthy, b.bit_not(protocol)])
  let stage = if scheduler is Some(s) {
    b.bit_or(accepted, s.advance)
  } else {
    start
  }
  let finish_request = if burst is Some(p) {
    p.bind(b, loader, segment_count, take_read, load_word)
    Some(b.bit_and(loader_result, expected_last))
  } else {
    None
  }
  loader.commit(
    b,
    stage,
    take_read,
    load_word,
    loader_fault,
    segment_count,
    finish_request~,
  )
  let take_job = both(b, [
    c["ddr_request_valid"],
    vacant,
    healthy,
    b.bit_not(protocol),
    b.bit_not(loader.busy),
  ])
  let job_address = b.register_state_in(d, @wire.uint(32), reset~)
  let job_data = b.register_state_in(d, @wire.uint(32), reset~)
  let job_write = b.register_state_in(d, @wire.bits(1), reset~)
  let job_line = b.register_state_in(d, @wire.bits(1), reset~)
  let job_wide = if wide {
    Some(b.register_state_in(d, @wire.bits(1), reset~))
  } else {
    None
  }
  if job_wide is Some(r) {
    update(b, r, take_job, c["ddr_request_wide"])
  }
  update(b, job_address, take_job, c["ddr_request_address"])
  update(b, job_data, take_job, c["ddr_request_data"])
  update(b, job_write, take_job, c["ddr_request_write"])
  update(b, job_line, take_job, c["ddr_request_burst"])
  let allocate = any(b, [take_job, take_write, take_read])
  b.connect_next(
    owner,
    b.mux(
      terminated,
      n(b, 2, 0UL),
      b.mux(
        allocate,
        b.mux(
          take_job,
          n(b, 2, 3UL),
          b.mux(take_write, n(b, 2, 1UL), n(b, 2, 2UL)),
        ),
        owner.value(),
      ),
    ),
  )
  let request = both(b, [
    b.bit_not(vacant),
    b.bit_not(issued.value()),
    healthy,
    b.bit_not(protocol),
  ])
  let fire = b.bit_and(request, ready)
  if group32 is Some(g) {
    let header = job_data.value()
    let contiguous = eq(b, header, 0xe0000200UL)
    let contiguous = if group64_rows {
      any(b, [
        contiguous,
        eq(b, header, 0xf0000800UL),
        eq(b, header, 0xf0001000UL),
        eq(b, header, 0xf0001800UL),
      ])
    } else {
      contiguous
    }
    let contiguous = if stripe512 {
      any(b, [
        contiguous,
        eq(b, header, 0xf8000800UL),
        eq(b, header, 0xf8001000UL),
        eq(b, header, 0xf8001800UL),
      ])
    } else {
      contiguous
    }
    let contiguous = if prefetch is Some(early) {
      let full = any(
        b,
        [0xfc000800UL, 0xfc001000UL, 0xfc001800UL].map(tag => eq(b, header, tag)),
      )
      update(b, early, fire, full)
      b.bit_or(contiguous, full)
    } else {
      contiguous
    }
    update(
      b,
      g,
      fire,
      if strided_rows {
        any(b, [
          contiguous,
          eq(b, header, 0xe0001000UL),
          eq(b, header, 0xe0001800UL),
        ])
      } else {
        contiguous
      },
    )
  }
  if long_batch is Some(flag) {
    update(b, flag, fire, b.slice(job_data.value(), 30, 30))
  }
  if batch_line is Some(r) {
    update(
      b,
      r,
      fire,
      both(b, [
        job_owner,
        job_wide.unwrap().value(),
        job_line.value(),
        b.bit_not(job_write.value()),
        b.slice(job_data.value(), 31, 31),
      ]),
    )
  }
  b.connect_next(
    issued,
    b.mux(terminated, n(b, 1, 0UL), b.mux(fire, n(b, 1, 1UL), issued.value())),
  )
  update(
    b,
    line,
    fire,
    both(b, [job_owner, job_line.value(), b.bit_not(job_write.value())]),
  )
  if wide_line is Some(r) {
    update(
      b,
      r,
      fire,
      both(b, [
        job_owner,
        job_wide.unwrap().value(),
        job_line.value(),
        b.bit_not(job_write.value()),
      ]),
    )
    let core_wide = b.bit_and(job_owner, job_wide.unwrap().value())
    out(
      b,
      "ddr_request_wide",
      if burst is Some(p) {
        p.request_flag(b, read_owner, core_wide)
      } else {
        core_wide
      },
    )
    let words = [response_data]
    for
      i in 1..<(if wide1024 {
        32
      } else if wide512 {
        16
      } else if delivery {
        8
      } else {
        4
      }) {
      let name = "ddr_response_data" + i.to_string()
      let x = input(b, d, name, 32)
      out(b, name + "_to_core", x)
      words.push(x)
    }
    if burst is Some(p) {
      out(b, "program_data", b.mux(load_word, p.word(b, words), a.data))
    }
  }
  b.connect_next(
    beat,
    b.mux(
      b.bit_or(allocate, terminated),
      n(b, beat_width, 0UL),
      b.mux(
        b.bit_and(response, issued.value()),
        b.add(beat.value(), n(b, beat_width, 1UL)),
        beat.value(),
      ),
    ),
  )
  out(b, "ddr_request_valid", request)
  if burst is Some(p) {
    let flag = p.request_flag(
      b,
      read_owner,
      b.bit_and(job_owner, job_line.value()),
    )
    out(b, "ddr_request_line", flag)
    out(b, "ddr_request_burst", flag)
  } else {
    out(b, "ddr_request_line", b.bit_and(job_owner, job_line.value()))
    out(b, "ddr_request_burst", b.bit_and(job_owner, job_line.value()))
  }
  out(b, "ddr_request_write", b.mux(job_owner, job_write.value(), write_owner))
  out(
    b,
    "ddr_request_address",
    b.mux(job_owner, job_address.value(), loader.address),
  )
  // Read requests carry a stable zero payload. An unrelated AXI write may
  // update a.data while a DDR read is stalled; it must not change that request.
  out(
    b,
    "ddr_request_data",
    b.mux(
      job_owner,
      job_data.value(),
      b.mux(
        write_owner,
        a.data,
        if burst is Some(p) {
          b.mux(
            b.bit_and(read_owner, p.batch.value()),
            n(b, 32, 0xc0000200UL),
            n(b, 32, 0UL),
          )
        } else {
          n(b, 32, 0UL)
        },
      ),
    ),
  )
  for i in 1..<4 {
    out_static(b, "ddr_request_data" + i.to_string(), 32, 0UL)
  }
  if stream_ready is Some(rdy) {
    out(b, "ddr_response_ready", rdy)
  } else {
    out_static(b, "ddr_response_ready", 1, 1UL)
  }
  out(b, "memory_healthy_to_core", b.bit_and(healthy, b.bit_not(protocol)))
  out(
    b,
    "ddr_request_ready_to_core",
    both(b, [vacant, healthy, b.bit_not(protocol), b.bit_not(loader.busy)]),
  )
  out(
    b,
    "ddr_response_valid_to_core",
    both(b, [response, issued.value(), job_owner]),
  )
  out(b, "ddr_response_data_to_core", response_data)
  out(b, "ddr_response_fault_to_core", response_fault)
  out(b, "ddr_response_last_to_core", response_last)
  let staging = if active is Some(flag) {
    b.bit_or(loader.busy, flag.value())
  } else {
    loader.busy
  }
  let registers : Array[(UInt64, @wire.Signal)] = [
    (0UL, n(b, 32, 0x50423330UL)),
    (4UL, n(b, 32, 0x10001UL)),
    (
      8UL,
      u(
        b,
        b.concat(
          b.concat(
            b.bit_or(c["fault"], protocol),
            b.bit_and(c["done"], b.bit_not(staging)),
          ),
          b.concat(b.bit_or(c["busy"], staging), healthy),
        ),
      ),
    ),
    (12UL, b.mux(protocol, n(b, 32, 256UL), c["error"])),
    (20UL, count.value()),
    (0x38UL, launch_sequence.value()),
    (0x3cUL, loader.base.value()),
    (0x40UL, loader.cycles.value()),
    (0x90UL, n(b, 32, 1UL)),
    (0x80UL, n(b, 32, 0x80000000UL)),
    (0x84UL, n(b, 32, 0UL)),
    (0x88UL, n(b, 32, 31UL)),
    (0x8cUL, n(b, 32, 1UL)),
  ]
  let loader_mode_write = if burst is Some(p) {
    let cfg = both(b, [
      writable,
      eq(b, a.address, 0x244UL),
      b.less_equal(a.data, n(b, 32, 1UL)),
    ])
    update(b, p.scalar_mode, cfg, b.truncate(a.data, 1))
    for
      reg in p.counters(
        b,
        d,
        reset,
        b.bit_and(fire, read_owner),
        load_word,
        loader_result,
      ) {
      registers.push(reg)
    }
    Some(cfg)
  } else {
    None
  }
  let loader_mode_write = if stream_unary {
    let valid = both(b, [
      writable,
      eq(b, a.address, 0x264UL),
      b.less_equal(a.data, n(b, 32, 1UL)),
    ])
    let legacy = b.register_state_in(d, @wire.uint(1), reset~)
    update(b, legacy, valid, b.truncate(a.data, 1))
    registers.push((0x260UL, n(b, 32, 0x53465531UL)))
    registers.push((0x264UL, legacy.value()))
    out(b, "unary_legacy", legacy.value())
    for pair in core_detail_counters(b, d, reset, c) {
      registers.push(pair)
    }
    // Cleared by configuration, reset or loss of DDR health. Commit only after
    // the host has completed the upload and written the identity record in DDR.
    let publish = both(b, [
      writable,
      healthy,
      eq(b, a.address, 0x29cUL),
      b.less_equal(a.data, n(b, 32, 1UL)),
    ])
    let resident = b.register_state_in(d, @wire.uint(1), reset~)
    update(
      b,
      resident,
      b.bit_or(publish, b.bit_not(healthy)),
      b.mux(healthy, b.truncate(a.data, 1), b.constant(@wire.uint(1), 0UL)),
    )
    registers.push((0x29cUL, resident.value()))
    if indirect_bf16 {
      registers.push((0x2a0UL, n(b, 32, 0x42463136UL)))
    }
    Some(any(b, [loader_mode_write.unwrap(), valid, publish]))
  } else {
    loader_mode_write
  }
  let write_ok = both(b, [
    terminated,
    job_owner,
    job_write.value(),
    healthy,
    b.bit_not(protocol),
    eq(b, response_fault, 0UL),
  ])
  let (commit, commit_address, commit_data) = if store_bursts {
    let replay = c["store_commit_valid"]
    (
      b.bit_or(b.bit_and(write_ok, b.bit_not(job_line.value())), replay),
      b.mux(replay, c["store_commit_address"], job_address.value()),
      b.mux(replay, c["store_word"], job_data.value()),
    )
  } else {
    (write_ok, job_address.value(), job_data.value())
  }
  let (argmax_write, argmax_registers) = streaming_argmax(
    b, d, reset, writable, a, commit, commit_address, commit_data,
  )
  for register in argmax_registers {
    registers.push(register)
  }
  let mut profile_scope : (@wire.Output, @wire.Signal)? = None
  if profile {
    let weight_owned = if scalar_lines {
      both(b, [
        job_owner,
        issued.value(),
        wide_line.unwrap().value(),
        eq(b, c["opcode"], 4UL),
      ])
    } else {
      both(b, [job_owner, issued.value(), wide_line.unwrap().value()])
    }
    let port = b.output("observe_weight_owned", weight_owned.signal_type())
    b.output_timing(port, ProducedIn(d.id()))
    profile_scope = Some((port, weight_owned))
    for
      register in cycle_profile(
        b,
        d,
        reset,
        c,
        loader,
        weight_owned,
        response,
        beat.value(),
        launch_sequence.value(),
      ) {
      registers.push(register)
    }
  }
  for
    i, name in [
      "pc", "state", "opcode", "cycles_low", "cycles_high", "instructions", "products",
      "ddr_beats",
    ] {
    registers.push((24UL + i.to_uint64() * 4UL, c[name]))
  }
  // One contiguous AXI burst, with sequence brackets for stable completion.
  let csr = Map::from_iter(registers.iter())
  for
    i, offset in [
      0x38UL, 8UL, 12UL, 20UL, 24UL, 28UL, 32UL, 36UL, 40UL, 44UL, 48UL, 52UL, 0x40UL,
      0x38UL,
    ] {
    registers.push((0xa0UL + i.to_uint64() * 4UL, csr[offset]))
  }
  if scheduler is Some(s) {
    for r in s.registers {
      registers.push(r)
    }
    // Token snapshot retains the legacy word layout, with sequence guards.
    for
      (offset, source) in [
        (0x200UL, 0x38UL),
        (0x204UL, 8UL),
        (0x208UL, 12UL),
        (0x210UL, 24UL),
        (0x214UL, 28UL),
        (0x218UL, 32UL),
        (0x234UL, 0x38UL),
      ] {
      registers.push((offset, csr[source]))
    }
    registers.push((0x20cUL, s.registers[0].1))
  }
  let mut data = n(b, 32, 0UL)
  let mut known = n(b, 1, 0UL)
  for (address, x) in registers {
    let selected = eq(b, a.ar_address, address)
    let x = u(b, x)
    data = b.mux(
      selected,
      if x.signal_type().width().bits() < 32 {
        b.zero_extend(x, 32)
      } else {
        x
      },
      data,
    )
    known = b.bit_or(known, selected)
  }
  let write_done = b.bit_and(terminated, write_owner)
  let read_done = n(b, 1, 0UL)
  let ok = both(b, [
    issued.value(),
    b.bit_not(protocol),
    eq(b, response_fault, 0UL),
  ])
  let immediate_write = b.bit_and(a.write, b.bit_not(write_ddr))
  let rejected_write = both(b, [
    a.write,
    write_ddr,
    b.bit_not(both(b, [configurable, healthy, shape, aligned])),
    b.bit_not(write_owner),
  ])
  let local_portal = b.bit_or(read_program, read_scratch)
  let immediate_read = both(b, [
    a.read,
    b.bit_not(read_ddr),
    b.bit_not(local_portal),
  ])
  let rejected_read = both(b, [
    a.read,
    b.bit_or(read_ddr, local_portal),
    b.bit_not(
      both(b, [
        configurable,
        read_aligned,
        b.mux(read_ddr, healthy, n(b, 1, 1UL)),
      ]),
    ),
    b.bit_not(b.bit_or(read_owner, local_pending.value())),
  ])
  axi_finish(
    b,
    a,
    any(b, [immediate_write, rejected_write, write_done]),
    any(b, [
      if scheduler is Some(s) {
        b.bit_or(accepted, s.configure)
      } else {
        start
      },
      if loader_mode_write is Some(cfg) {
        b.bit_or(count_write, cfg)
      } else {
        count_write
      },
      argmax_write,
      base_write,
      both(b, [writable, b.bit_or(write_program, write_scratch)]),
      b.bit_and(write_done, ok),
    ]),
    any(b, [immediate_read, rejected_read, read_done, local_done]),
    any(b, [
      b.bit_and(immediate_read, known),
      b.bit_and(read_done, ok),
      local_done,
    ]),
    b.mux(
      read_done,
      response_data,
      b.mux(
        local_done,
        b.mux(
          program_pending.value(),
          c["program_read_data"],
          c["scratch_read_data"],
        ),
        data,
      ),
    ),
  )
  for
    (name, x) in [
      ("owner", owner.value()),
      ("issued", issued.value()),
      ("beat", beat.value()),
      ("protocol", protocol),
      ("loader_result", loader_result),
      ("loader_state", loader.state.value()),
      ("loader_fault", loader_fault),
    ] {
    out(b, "observe_" + name, x)
  }
  if profile_scope is Some((port, scope)) {
    // Register the predicate before it crosses to the MIG UI synchronizer.
    // Keep the existing scheduler's predicate and counters undelayed.
    b.connect(port, b.register_in(d, scope, reset~))
  }
  b.finish()
}
