///|
/// One-owner AXI4 adapter for the 2GiB PBlaze3 aperture. The clock is the core
/// clock. The board clock converter connects it to MIG's 200 MHz domain.
/// The wrapper packs little-endian 32-bit lanes into AXI data.
/// Scalar, serial line/burst, sixteen-row strided and eight-word delivery modes
/// retain the Qwen memory protocol. The optional streaming port uses 256-bit
/// AXI and four-beat bursts for wide reads. The 512-bit option delivers
/// sixteen words per response with two beats per row. The 1024-bit option
/// returns 32 words per beat and supports one- or four-beat rows. Its
/// width converter runs on the MIG side. The legacy port uses 128 bits.
/// Faults: 1 malformed request, 2 calibration unavailable/lost, 3 AXI response.
/// AXI faults poison the bridge until coordinated bridge/interconnect reset.
///
/// ```mbt check
/// test {
///   assert_eq(@pblaze3_axi.bridge().name(), "Pblaze3AxiBridge")
/// }
/// ```
pub fn bridge(
  streaming~ : Bool = false,
  wide512~ : Bool = false,
  wide1024~ : Bool = false,
  deep_batch~ : Bool = false,
  strided_rows~ : Bool = false,
  store_bursts~ : Bool = false,
  staged_fill~ : Bool = false,
  group64_rows~ : Bool = false,
  stripe512~ : Bool = false,
  prefetch_row_blocks~ : Bool = false,
  staged_response_last~ : Bool = false,
) -> @ir.Module raise {
  assert_true(!strided_rows || deep_batch)
  assert_true(!deep_batch || wide1024)
  assert_true(!wide1024 || wide512)
  assert_true(!store_bursts || wide1024)
  assert_true(!staged_fill || store_bursts)
  assert_true(!group64_rows || deep_batch)
  assert_true(!stripe512 || group64_rows)
  assert_true(!prefetch_row_blocks || stripe512)
  assert_true(!wide512 || streaming)
  let b = @wire.ModuleBuilder::new("Pblaze3AxiBridge")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let reset = b.input("reset", @wire.reset())
  b.input_timing(reset, SampledIn(d.id()))
  let r = b.synchronous_reset(reset, 0UL)
  let running = b.bit_not(b.reset_asserted(reset))
  let valid = input(b, d, "request_valid", 1)
  let write = input(b, d, "request_write", 1)
  let address = input(b, d, "request_address", 32)
  let line = input(b, d, "request_line", 1)
  let burst = input(b, d, "request_burst", 1)
  let wide = input(b, d, "request_wide", 1)
  let data = Array::makei(4, i => {
    input(
      b,
      d,
      if i == 0 {
        "request_data"
      } else {
        "request_data" + i.to_string()
      },
      32,
    )
  })
  let ready = input(b, d, "response_ready", 1)
  let calibrated = input(b, d, "calibrated", 1)
  let awready = input(b, d, "m_axi_awready", 1)
  let wready = input(b, d, "m_axi_wready", 1)
  let bvalid = input(b, d, "m_axi_bvalid", 1)
  let bresp = input(b, d, "m_axi_bresp", 2)
  let arready = input(b, d, "m_axi_arready", 1)
  let rvalid = input(b, d, "m_axi_rvalid", 1)
  let rresp = input(b, d, "m_axi_rresp", 2)
  let rlast = input(b, d, "m_axi_rlast", 1)
  let lanes = if wide1024 {
    32
  } else if wide512 {
    16
  } else if streaming {
    8
  } else {
    4
  }
  let address_bits = if wide1024 {
    7
  } else if wide512 {
    6
  } else if streaming {
    5
  } else {
    4
  }
  let read_words = Array::makei(lanes, i => {
    input(b, d, "m_axi_rword" + i.to_string(), 32)
  })
  let state = b.register_state_in(d, @wire.uint(3), reset=r)
  let idle = eq(b, state.value(), 0UL)
  let launch = eq(b, state.value(), 1UL)
  let reading = eq(b, state.value(), 2UL)
  let writing = eq(b, state.value(), 3UL)
  let responding_write = eq(b, state.value(), 4UL)
  let replying = eq(b, state.value(), 5UL)
  let address_reg = b.register_state_in(d, @wire.uint(32), reset=r)
  let row_base = b.register_state_in(d, @wire.uint(32), reset=r)
  let stride = b.register_state_in(d, @wire.uint(32), reset=r)
  let batch = b.register_state_in(d, @wire.bits(1), reset=r)
  let wide_reg = b.register_state_in(d, @wire.bits(1), reset=r)
  let write_reg = b.register_state_in(d, @wire.bits(1), reset=r)
  let line_reg = b.register_state_in(d, @wire.bits(1), reset=r)
  let word_lane = b.register_state_in(d, @wire.uint(2), reset=r)
  let line_index = b.register_state_in(d, @wire.uint(3), reset=r)
  let half = b.register_state_in(d, @wire.bits(1), reset=r)
  let sent = b.register_state_in(d, @wire.uint(10), reset=r)
  let limit = b.register_state_in(d, @wire.uint(10), reset=r)
  let fault = b.register_state_in(d, @wire.uint(2), reset=r)
  let poisoned = b.register_state_in(d, @wire.bits(1), reset=r)
  let seen_calibration = b.register_state_in(d, @wire.bits(1), reset=r)
  let awsent = b.register_state_in(d, @wire.bits(1), reset=r)
  let wsent = b.register_state_in(d, @wire.bits(1), reset=r)
  let write_data = Array::makei(4, _ => {
    b.register_state_in(d, @wire.uint(32), reset=r)
  })
  let buffer = Array::makei(8, _ => {
    b.register_state_in(d, @wire.uint(32), reset=r)
  })
  let calibration_lost = both(b, [
    seen_calibration.value(),
    b.bit_not(calibrated),
  ])
  let healthy = both(b, [calibrated, b.bit_not(poisoned.value())])
  let request_ready = b.bit_and(idle, running)
  let accept = b.bit_and(valid, request_ready)
  let valid_line = both(b, [line, b.bit_not(write)])
  let valid_burst = b.bit_and(burst, valid_line)
  let valid_wide = b.bit_and(wide, valid_burst)
  let valid_batch = b.bit_and(valid_wide, b.slice(data[0], 31, 31))
  let group64 = if group64_rows {
    Some(
      any(
        b,
        [0xf0000800UL, 0xf0001000UL, 0xf0001800UL].map(h => eq(b, data[0], h)),
      ),
    )
  } else {
    None
  }
  let slice1k = if stripe512 {
    Some(
      any(
        b,
        [0xf8000800UL, 0xf8001000UL, 0xf8001800UL].map(tag => {
          eq(b, data[0], tag)
        }),
      ),
    )
  } else {
    None
  }
  let prefetch = if prefetch_row_blocks {
    Some(
      any(
        b,
        [0xfc000800UL, 0xfc001000UL, 0xfc001800UL].map(tag => {
          eq(b, data[0], tag)
        }),
      ),
    )
  } else {
    None
  }
  let slice1k = if prefetch is Some(w) {
    Some(b.bit_or(slice1k.unwrap(), w))
  } else {
    slice1k
  }
  let malformed = invalid_request(
    b,
    address,
    data[0],
    write,
    line,
    burst,
    wide,
    wide1024~,
    deep_batch~,
    strided_rows~,
    group64~,
    slice1k~,
    prefetch~,
  )
  let writer = if store_bursts {
    let selected = both(b, [write, line, burst, b.bit_not(wide)])
    Some(
      (
        selected,
        burst_writer(b, d, r, idle, healthy, accept, selected, staged_fill),
      ),
    )
  } else {
    None
  }
  let malformed = if writer is Some((selected, p)) {
    b.mux(
      selected,
      any(b, [
        b.slice(address, 31, 31),
        b.bit_not(eq(b, b.slice(address, 7, 0), 0UL)),
        b.bit_not(p.complete),
      ]),
      malformed,
    )
  } else {
    malformed
  }
  let rejected = b.bit_or(malformed, b.bit_not(healthy))
  let stream = if streaming {
    Some(
      stream_read(
        b,
        d,
        r,
        both(b, [accept, valid_wide, b.bit_not(rejected)]),
        eq(b, state.value(), 6UL),
        running,
        address,
        valid_batch,
        data[0],
        healthy,
        ready,
        arready,
        rvalid,
        rresp,
        rlast,
        read_words,
        deep_batch~,
        strided_rows~,
        group64=if slice1k is Some(w) {
          Some(b.bit_or(group64.unwrap(), w))
        } else {
          group64
        },
        slice1k~,
        prefetch~,
      ),
    )
  } else {
    None
  }
  let arvalid = b.bit_and(launch, running)
  let awvalid = both(b, [writing, b.bit_not(awsent.value()), running])
  let wvalid = both(b, [writing, b.bit_not(wsent.value()), running])
  let arfire = b.bit_and(arvalid, arready)
  let awfire = b.bit_and(awvalid, awready)
  let wfire = b.bit_and(wvalid, wready)
  let last_write = if writer is Some((_, p)) {
    b.connect_next(
      p.second,
      b.mux(
        accept,
        n(b, 1, 0UL),
        b.bit_or(p.second.value(), b.bit_and(wfire, p.active)),
      ),
    )
    Some(b.bit_or(b.bit_not(p.active), p.second.value()))
  } else {
    None
  }
  let final_wfire = if last_write is Some(last) {
    b.bit_and(wfire, last)
  } else {
    wfire
  }
  let write_sent = both(b, [
    writing,
    b.bit_or(awsent.value(), awfire),
    b.bit_or(wsent.value(), final_wfire),
  ])
  let read_fire = both(b, [reading, rvalid, running])
  let write_fire = both(b, [responding_write, bvalid, running])
  let bad_read = both(b, [
    read_fire,
    any(b, [b.bit_not(eq(b, rresp, 0UL)), b.bit_not(rlast)]),
  ])
  let bad_write = both(b, [write_fire, b.bit_not(eq(b, bresp, 0UL))])
  let bad_axi = b.bit_or(bad_read, bad_write)
  let poison_axi = if stream is Some(s) {
    b.bit_or(bad_axi, s.bad_axi)
  } else {
    bad_axi
  }
  let io_fault = b.mux(
    b.bit_not(healthy),
    n(b, 2, 2UL),
    b.mux(bad_axi, n(b, 2, 3UL), n(b, 2, 0UL)),
  )
  let io_failed = b.bit_not(eq(b, io_fault, 0UL))
  let response_valid = b.bit_and(replying, running)
  let response_fire = b.bit_and(response_valid, ready)
  let step = b.mux(wide_reg.value(), n(b, 10, 8UL), n(b, 10, 1UL))
  let next_sent = b.add(sent.value(), step)
  // Predict the next response's terminal flag on the preceding handshake.
  // No response edge is added: this removes the carry/comparison chain from
  // the controller's same-cycle protocol-fault and BRAM-enable paths.
  let last = if staged_response_last {
    let predicted = b.register_state_in(
      d,
      @wire.bits(1),
      reset=b.synchronous_reset(reset, 1UL),
    )
    let accepted_limit = b.mux(
      valid_batch,
      n(b, 10, 512UL),
      b.mux(
        valid_burst,
        n(b, 10, 32UL),
        b.mux(valid_line, n(b, 10, 4UL), n(b, 10, 1UL)),
      ),
    )
    b.connect_next(
      predicted,
      b.mux(
        accept,
        b.greater_equal(
          b.mux(valid_wide, n(b, 10, 8UL), n(b, 10, 1UL)),
          accepted_limit,
        ),
        b.mux(
          response_fire,
          b.greater_equal(b.add(next_sent, step), limit.value()),
          predicted.value(),
        ),
      ),
    )
    predicted.value()
  } else {
    b.greater_equal(next_sent, limit.value())
  }
  let more = both(b, [response_fire, b.bit_not(last)])
  let need_read = both(b, [
    more,
    b.bit_or(wide_reg.value(), eq(b, word_lane.value(), 3UL)),
    eq(b, fault.value(), 0UL),
    healthy,
  ])
  let next_half = both(b, [
    read_fire,
    wide_reg.value(),
    b.bit_not(half.value()),
    b.bit_not(io_failed),
  ])
  let row_end = both(b, [batch.value(), eq(b, line_index.value(), 7UL)])
  let next_row = b.add(row_base.value(), stride.value())
  let increment_address = b.mux(
    row_end,
    next_row,
    b.add(address_reg.value(), n(b, 32, 16UL)),
  )
  let aligned_address = u(b, b.concat(b.slice(address, 31, 4), n(b, 4, 0UL)))
  update(b, seen_calibration, calibrated, n(b, 1, 1UL))
  update(b, poisoned, b.bit_or(calibration_lost, poison_axi), n(b, 1, 1UL))
  update(b, wide_reg, accept, valid_wide)
  update(b, write_reg, accept, write)
  update(b, line_reg, accept, line)
  update(b, batch, accept, valid_batch)
  update(b, stride, accept, b.zero_extend(u(b, b.slice(data[0], 30, 0)), 32))
  b.connect_next(
    row_base,
    b.mux(
      accept,
      aligned_address,
      b.mux(b.bit_and(read_fire, row_end), next_row, row_base.value()),
    ),
  )
  b.connect_next(
    address_reg,
    b.mux(
      accept,
      aligned_address,
      b.mux(read_fire, increment_address, address_reg.value()),
    ),
  )
  b.connect_next(
    line_index,
    b.mux(
      accept,
      n(b, 3, 0UL),
      b.mux(
        read_fire,
        b.add(line_index.value(), n(b, 3, 1UL)),
        line_index.value(),
      ),
    ),
  )
  b.connect_next(
    word_lane,
    b.mux(
      accept,
      b.mux(valid_line, n(b, 2, 0UL), u(b, b.slice(address, 3, 2))),
      b.mux(more, b.add(word_lane.value(), n(b, 2, 1UL)), word_lane.value()),
    ),
  )
  b.connect_next(
    half,
    b.mux(
      b.bit_or(accept, response_fire),
      n(b, 1, 0UL),
      b.mux(read_fire, b.bit_not(half.value()), half.value()),
    ),
  )
  b.connect_next(
    sent,
    b.mux(accept, n(b, 10, 0UL), b.mux(response_fire, next_sent, sent.value())),
  )
  update(
    b,
    limit,
    accept,
    b.mux(
      valid_batch,
      n(b, 10, 512UL),
      b.mux(
        valid_burst,
        n(b, 10, 32UL),
        b.mux(valid_line, n(b, 10, 4UL), n(b, 10, 1UL)),
      ),
    ),
  )
  b.connect_next(
    awsent,
    b.mux(accept, n(b, 1, 0UL), b.bit_or(awsent.value(), awfire)),
  )
  b.connect_next(
    wsent,
    b.mux(accept, n(b, 1, 0UL), b.bit_or(wsent.value(), final_wfire)),
  )
  for i, reg in write_data {
    update(b, reg, accept, data[i])
  }
  for i, reg in buffer {
    update(
      b,
      reg,
      both(b, [
        read_fire,
        if i < 4 {
          b.bit_or(b.bit_not(wide_reg.value()), b.bit_not(half.value()))
        } else {
          b.bit_and(wide_reg.value(), half.value())
        },
      ]),
      if wide512 {
        table(
          b,
          b.slice(address_reg.value(), address_bits - 1, 4),
          Array::makei(lanes / 4, q => read_words[q * 4 + i % 4]),
        )
      } else if streaming {
        b.mux(
          b.slice(address_reg.value(), 4, 4),
          read_words[4 + i % 4],
          read_words[i % 4],
        )
      } else {
        read_words[i % 4]
      },
    )
  }
  b.connect_next(
    fault,
    b.mux(
      accept,
      b.mux(
        malformed,
        n(b, 2, 1UL),
        b.mux(b.bit_not(healthy), n(b, 2, 2UL), n(b, 2, 0UL)),
      ),
      b.mux(
        b.bit_or(read_fire, write_fire),
        io_fault,
        b.mux(
          both(b, [more, eq(b, fault.value(), 0UL), b.bit_not(healthy)]),
          n(b, 2, 2UL),
          fault.value(),
        ),
      ),
    ),
  )
  let mut next_state = state.value()
  next_state = b.mux(
    response_fire,
    b.mux(last, n(b, 3, 0UL), b.mux(need_read, n(b, 3, 1UL), n(b, 3, 5UL))),
    next_state,
  )
  next_state = b.mux(write_fire, n(b, 3, 5UL), next_state)
  next_state = b.mux(
    read_fire,
    b.mux(next_half, n(b, 3, 1UL), n(b, 3, 5UL)),
    next_state,
  )
  next_state = b.mux(write_sent, n(b, 3, 4UL), next_state)
  next_state = b.mux(arfire, n(b, 3, 2UL), next_state)
  next_state = b.mux(
    accept,
    b.mux(
      rejected,
      n(b, 3, 5UL),
      b.mux(
        write,
        n(b, 3, 3UL),
        if streaming {
          b.mux(valid_wide, n(b, 3, 6UL), n(b, 3, 1UL))
        } else {
          n(b, 3, 1UL)
        },
      ),
    ),
    next_state,
  )
  if stream is Some(s) {
    next_state = b.mux(s.done, n(b, 3, 0UL), next_state)
  }
  b.connect_next(state, next_state)
  out(b, d, "request_ready", request_ready)
  out(b, d, "memory_healthy", healthy)
  out(b, d, "bridge_poisoned", poisoned.value())
  out(
    b,
    d,
    "response_valid",
    if stream is Some(s) {
      b.bit_or(s.valid, response_valid)
    } else {
      response_valid
    },
  )
  out(
    b,
    d,
    "response_fault",
    if stream is Some(s) {
      b.mux(s.valid, s.fault, fault.value())
    } else {
      fault.value()
    },
  )
  out(
    b,
    d,
    "response_last",
    if stream is Some(s) {
      b.mux(s.valid, s.last, last)
    } else {
      last
    },
  )
  out(b, d, "response_wide", wide_reg.value())
  let zero_data = b.bit_or(
    write_reg.value(),
    b.bit_not(eq(b, fault.value(), 0UL)),
  )
  for i in 0..<(if wide1024 { 32 } else if wide512 { 16 } else { 8 }) {
    let selected = if i >= 8 {
      n(b, 32, 0UL)
    } else if i == 0 {
      b.mux(
        wide_reg.value(),
        buffer[0].value(),
        table(b, word_lane.value(), buffer[0:4].map(x => x.value())),
      )
    } else {
      b.mux(wide_reg.value(), buffer[i].value(), n(b, 32, 0UL))
    }
    out(
      b,
      d,
      if i == 0 {
        "response_data"
      } else {
        "response_data" + i.to_string()
      },
      if stream is Some(s) {
        b.mux(s.valid, s.words[i], b.mux(zero_data, n(b, 32, 0UL), selected))
      } else {
        b.mux(zero_data, n(b, 32, 0UL), selected)
      },
    )
  }
  for prefix in ["m_axi_aw", "m_axi_ar"] {
    let a = if streaming {
      u(
        b,
        b.concat(
          b.slice(address_reg.value(), 31, address_bits),
          n(b, address_bits, 0UL),
        ),
      )
    } else {
      address_reg.value()
    }
    if prefix == "m_axi_ar" && stream is Some(s) {
      out(b, d, prefix + "addr", b.mux(s.arvalid, s.address, a))
      out(
        b,
        d,
        prefix + "len",
        b.mux(
          s.arvalid,
          match s.burst_length {
            Some(length) => length
            None => n(b, 8, (32 / lanes - 1).to_uint64())
          },
          n(b, 8, 0UL),
        ),
      )
    } else {
      out(b, d, prefix + "addr", a)
      if prefix == "m_axi_aw" && writer is Some((_, p)) {
        out(b, d, prefix + "len", b.mux(p.active, n(b, 8, 1UL), n(b, 8, 0UL)))
      } else {
        constant_output(b, prefix + "len", 8, 0UL)
      }
    }
    constant_output(b, prefix + "size", 3, address_bits.to_uint64())
    constant_output(b, prefix + "burst", 2, 1UL)
  }
  out(b, d, "m_axi_awvalid", awvalid)
  out(
    b,
    d,
    "m_axi_arvalid",
    if stream is Some(s) {
      b.bit_or(s.arvalid, arvalid)
    } else {
      arvalid
    },
  )
  out(b, d, "m_axi_wvalid", wvalid)
  if last_write is Some(last) {
    out(b, d, "m_axi_wlast", last)
  } else {
    constant_output(b, "m_axi_wlast", 1, 1UL)
  }
  out(b, d, "m_axi_bready", b.bit_and(responding_write, running))
  let legacy_ready = b.bit_and(reading, running)
  out(
    b,
    d,
    "m_axi_rready",
    if stream is Some(s) {
      b.bit_or(s.rready, legacy_ready)
    } else {
      legacy_ready
    },
  )
  let mask = b.mux(
    line_reg.value(),
    n(b, 16, 0xffffUL),
    table(b, word_lane.value(), [
      n(b, 16, 0xfUL),
      n(b, 16, 0xf0UL),
      n(b, 16, 0xf00UL),
      n(b, 16, 0xf000UL),
    ]),
  )
  fn strobe_half(first : Int32) -> @wire.Signal raise {
    let select = b.slice(address_reg.value(), 6, 4)
    let mut word = b.mux(eq(b, select, first.to_uint64()), mask, n(b, 16, 0UL))
    for i in 1..<4 {
      word = u(
        b,
        b.concat(
          b.mux(eq(b, select, (first + i).to_uint64()), mask, n(b, 16, 0UL)),
          word,
        ),
      )
    }
    word
  }
  if wide1024 {
    let upper = strobe_half(4)
    out(
      b,
      d,
      "m_axi_wstrb_hi",
      if writer is Some((_, p)) {
        b.mux(p.active, n(b, 64, 0xffffffffffffffffUL), upper)
      } else {
        upper
      },
    )
  }
  out(
    b,
    d,
    "m_axi_wstrb",
    if wide1024 {
      let lower = strobe_half(0)
      if writer is Some((_, p)) {
        b.mux(p.active, n(b, 64, 0xffffffffffffffffUL), lower)
      } else {
        lower
      }
    } else if wide512 {
      let select = b.slice(address_reg.value(), 5, 4)
      let quarters = Array::makei(4, i => {
        b.mux(eq(b, select, i.to_uint64()), mask, n(b, 16, 0UL))
      })
      u(
        b,
        b.concat(
          b.concat(quarters[3], quarters[2]),
          b.concat(quarters[1], quarters[0]),
        ),
      )
    } else if streaming {
      let zero = n(b, 16, 0UL)
      b.mux(
        b.slice(address_reg.value(), 4, 4),
        u(b, b.concat(mask, zero)),
        u(b, b.concat(zero, mask)),
      )
    } else {
      mask
    },
  )
  for i in 0..<lanes {
    out(
      b,
      d,
      "m_axi_wword" + i.to_string(),
      {
        let scalar = b.mux(
          line_reg.value(),
          write_data[i % 4].value(),
          write_data[0].value(),
        )
        if writer is Some((_, p)) {
          b.mux(
            p.active,
            b.mux(p.second.value(), p.words[i + 32], p.words[i]),
            scalar,
          )
        } else {
          scalar
        }
      },
    )
  }
  b.finish()
}
