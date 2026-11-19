///|
/// AXI-Lite program/scratch/DDR portal and one-owner DDR transport around the
/// MoonBit layer machine. Host tensor/program writes are rejected while busy.
pub fn controller() -> @ir.Module raise {
  make_controller(false)
}

///|
/// Opt-in four-word DDR response transport; host portals retain 32-bit words.
pub fn wide_controller() -> @ir.Module raise {
  make_controller(true)
}

///|
/// Native-width transport with four strided rows per marked read owner.
pub fn batched_controller() -> @ir.Module raise {
  make_controller(true, batch=true)
}

///|
/// Eight-row target transport; must be paired with its core and bridge.
pub fn eight_row_controller() -> @ir.Module raise {
  make_controller(true, batch=true, eight_row=true)
}

///|

///|
/// Sixteen-row transport; pair only with its matched core and bridge.
/// Example: `let design = @prx100_layer.sixteen_row_controller()`.
pub fn sixteen_row_controller() -> @ir.Module raise {
  make_controller(true, batch=true, eight_row=true, sixteen_row=true)
}

///|
/// Sixteen-row transport with eight-word responses; use the matched delivery bridge.
pub fn delivery_controller() -> @ir.Module raise {
  make_controller(
    true,
    batch=true,
    eight_row=true,
    sixteen_row=true,
    delivery=true,
  )
}

///|
fn make_controller(
  wide : Bool,
  batch~ : Bool = false,
  eight_row~ : Bool = false,
  sixteen_row~ : Bool = false,
  delivery~ : Bool = false,
) -> @ir.Module raise {
  assert_true(!delivery || sixteen_row)
  assert_true(!sixteen_row || eight_row)
  let beat_width = if sixteen_row { 7 } else { 6 }
  let b = @wire.ModuleBuilder::new("Prx100QwenLayerControl")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  b.input_timing(rs, SampledIn(d.id()))
  let reset = b.synchronous_reset(rs, 0UL)
  let a = axi_begin(b, d, reset)
  let healthy = input(b, d, "memory_healthy", 1)
  let ready = input(b, d, "ddr_request_ready", 1)
  let response = input(b, d, "ddr_response_valid", 1)
  let response_data = input(b, d, "ddr_response_data", 32)
  let response_fault = input(b, d, "ddr_response_fault", 2)
  let response_last = input(b, d, "ddr_response_last", 1)
  let c : Map[String, @wire.Signal] = Map([])
  for
    p in (if batch {
      @fp.batched_layer_machine()
    } else if wide {
      @fp.wide_layer_machine()
    } else {
      @fp.layer_machine()
    }).outputs() {
    let x = b.input("c_" + p.name(), p.signal_type())
    b.input_timing(x, SampledIn(d.id()))
    c[p.name()] = x
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
            n(b, beat_width, if delivery { 3UL } else { 7UL }),
            if eight_row {
              b.mux(
                batch_line.unwrap().value(),
                n(
                  b,
                  beat_width,
                  if delivery {
                    63UL
                  } else if sixteen_row {
                    127UL
                  } else {
                    63UL
                  },
                ),
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
  let bad = both(b, [
    response,
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
      b.bit_and(c["ddr_request_write"], c["ddr_request_line"]),
    ]),
  ])
  update(b, poisoned, b.bit_or(bad, malformed_core), n(b, 1, 1UL))
  let protocol = any(b, [poisoned.value(), bad, malformed_core])
  let terminated = both(b, [response, issued.value(), expected_last])
  let idle = both(b, [
    b.bit_not(c["busy"]),
    b.bit_not(c["fault"]),
    b.bit_not(protocol),
  ])
  let configurable = both(b, [idle, vacant])
  let count = b.register_state_in(d, @wire.uint(12), reset~)
  let shape = eq(b, a.strobe, 15UL)
  let aligned = eq(b, b.slice(a.address, 1, 0), 0UL)
  let read_aligned = eq(b, b.slice(a.ar_address, 1, 0), 0UL)
  let write_ddr = eq(b, b.slice(a.address, 31, 28), 1UL)
  let read_ddr = eq(b, b.slice(a.ar_address, 31, 28), 1UL)
  let write_program = eq(b, b.slice(a.address, 31, 17), 0x1000UL)
  let read_program = eq(b, b.slice(a.ar_address, 31, 17), 0x1000UL)
  let write_scratch = eq(b, b.slice(a.address, 31, 17), 0x1800UL)
  let read_scratch = eq(b, b.slice(a.ar_address, 31, 17), 0x1800UL)
  let writable = both(b, [a.write, configurable, shape, aligned])
  let start = both(b, [
    writable,
    healthy,
    eq(b, a.address, 16UL),
    eq(b, a.data, 1UL),
    b.greater_equal(count.value(), n(b, 12, 1UL)),
    b.less_equal(count.value(), n(b, 12, 2048UL)),
  ])
  let count_write = both(b, [
    writable,
    eq(b, a.address, 20UL),
    b.greater_equal(a.data, n(b, 32, 1UL)),
    b.less_equal(a.data, n(b, 32, 2048UL)),
  ])
  update(b, count, count_write, b.truncate(a.data, 12))
  out(b, "start", start)
  out(b, "program_count", count.value())
  out(b, "core_reset", b.reset_asserted(rs))
  out(b, "program_write", b.bit_and(writable, write_program))
  out(b, "program_address", u(b, b.slice(a.address, 16, 2)))
  out(b, "program_data", a.data)
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
  let take_read = both(b, [
    a.read,
    read_ddr,
    configurable,
    healthy,
    read_aligned,
    b.bit_not(take_write),
  ])
  let take_job = both(b, [
    c["ddr_request_valid"],
    vacant,
    healthy,
    b.bit_not(protocol),
  ])
  let job_address = b.register_state_in(d, @wire.uint(28), reset~)
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
    out(b, "ddr_request_wide", b.bit_and(job_owner, job_wide.unwrap().value()))
    for i in 1..<(if delivery { 8 } else { 4 }) {
      let name = "ddr_response_data" + i.to_string()
      let x = input(b, d, name, 32)
      out(b, name + "_to_core", x)
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
  out(b, "ddr_request_line", b.bit_and(job_owner, job_line.value()))
  out(b, "ddr_request_burst", b.bit_and(job_owner, job_line.value()))
  out(b, "ddr_request_write", b.mux(job_owner, job_write.value(), write_owner))
  out(
    b,
    "ddr_request_address",
    b.mux(
      job_owner,
      job_address.value(),
      b.truncate(b.mux(write_owner, a.address, a.ar_address), 28),
    ),
  )
  // Read requests carry a stable zero payload. An unrelated AXI write may
  // update a.data while a DDR read is stalled; it must not change that request.
  out(
    b,
    "ddr_request_data",
    b.mux(
      job_owner,
      job_data.value(),
      b.mux(write_owner, a.data, n(b, 32, 0UL)),
    ),
  )
  for i in 1..<4 {
    out_static(b, "ddr_request_data" + i.to_string(), 32, 0UL)
  }
  out_static(b, "ddr_response_ready", 1, 1UL)
  out(b, "memory_healthy_to_core", b.bit_and(healthy, b.bit_not(protocol)))
  out(
    b,
    "ddr_request_ready_to_core",
    both(b, [vacant, healthy, b.bit_not(protocol)]),
  )
  out(
    b,
    "ddr_response_valid_to_core",
    both(b, [response, issued.value(), job_owner]),
  )
  out(b, "ddr_response_data_to_core", response_data)
  out(b, "ddr_response_fault_to_core", response_fault)
  out(b, "ddr_response_last_to_core", response_last)
  let registers : Array[(UInt64, @wire.Signal)] = [
    (0UL, n(b, 32, 0x514c5930UL)),
    (4UL, n(b, 32, 0x10000UL)),
    (
      8UL,
      u(
        b,
        b.concat(
          b.concat(b.bit_or(c["fault"], protocol), c["done"]),
          b.concat(c["busy"], healthy),
        ),
      ),
    ),
    (12UL, b.mux(protocol, n(b, 32, 256UL), c["error"])),
    (20UL, count.value()),
  ]
  for
    i, name in [
      "pc", "state", "opcode", "cycles_low", "cycles_high", "instructions", "products",
      "ddr_beats",
    ] {
    registers.push((24UL + i.to_uint64() * 4UL, c[name]))
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
  let read_done = b.bit_and(terminated, read_owner)
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
      start,
      count_write,
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
    ] {
    out(b, "observe_" + name, x)
  }
  b.finish()
}
