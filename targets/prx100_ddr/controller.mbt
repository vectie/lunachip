///|
/// Standalone native128-bit DDR tester and AXI4-Lite diagnostics. No core import.
pub fn controller() -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("Prx100DdrDiagnostic")
  let clock = b.input("clock", @wire.clock())
  let d = b.rising_edge(clock)
  let reset_input = b.input("reset", @wire.reset())
  b.input_timing(reset_input, SampledIn(d.id()))
  let reset = b.synchronous_reset(reset_input, 0UL)
  let active = b.bit_not(b.reset_asserted(reset_input))
  let calibrated = input(b, d, "calibrated", 1)
  let app_ready = input(b, d, "app_rdy", 1)
  let data_ready = input(b, d, "app_wdf_rdy", 1)
  let read_valid = input(b, d, "app_rd_data_valid", 1)
  let read_end = input(b, d, "app_rd_data_end", 1)
  let read_data : Array[@wire.Signal] = []
  for i in 0..<4 {
    read_data.push(input(b, d, "app_rd_word" + i.to_string(), 32))
  }
  let a = axi_begin(b, d, reset)
  let state = b.register_state_in(d, @wire.uint(3), reset~)
  let seed_cfg = b.register_state_in(d, @wire.uint(32), reset~)
  let count_cfg = b.register_state_in(d, @wire.uint(25), reset~)
  let mode_cfg = b.register_state_in(d, @wire.uint(3), reset~)
  let seed = b.register_state_in(d, @wire.uint(32), reset~)
  let count = b.register_state_in(d, @wire.uint(25), reset~)
  let mode = b.register_state_in(d, @wire.uint(3), reset~)
  let reverse = b.register_state_in(d, @wire.bits(1), reset~)
  let write_only = b.register_state_in(d, @wire.bits(1), reset~)
  let commands = b.register_state_in(d, @wire.uint(25), reset~)
  let data_beats = b.register_state_in(d, @wire.uint(25), reset~)
  let reads = b.register_state_in(d, @wire.uint(25), reset~)
  let checked = b.register_state_in(d, @wire.uint(25), reset~)
  let mismatches = b.register_state_in(d, @wire.uint(25), reset~)
  let error = b.register_state_in(d, @wire.uint(2), reset~)
  let first_address = b.register_state_in(d, @wire.uint(32), reset~)
  let first_expected : Array[@wire.RegisterHandle] = []
  let first_actual : Array[@wire.RegisterHandle] = []
  for _ in 0..<4 {
    first_expected.push(b.register_state_in(d, @wire.uint(32), reset~))
    first_actual.push(b.register_state_in(d, @wire.uint(32), reset~))
  }
  let write_cycles = b.register_state_in(d, @wire.uint(64), reset~)
  let read_cycles = b.register_state_in(d, @wire.uint(64), reset~)
  let command_sent = b.register_state_in(d, @wire.bits(1), reset~)
  let data_sent = b.register_state_in(d, @wire.bits(1), reset~)
  let write_index = b.register_state_in(d, @wire.uint(24), reset~)
  let writing = eq(b, state.value(), 1UL)
  let reading = eq(b, state.value(), 2UL)
  let busy = b.bit_or(writing, reading)
  let writable = both(b, [active, b.bit_not(busy), eq(b, a.strobe, 15UL)])
  let cmd_address = eq(b, a.address, 16UL)
  let seed_address = eq(b, a.address, 20UL)
  let count_address = eq(b, a.address, 24UL)
  let mode_address = eq(b, a.address, 28UL)
  let ro = eq(b, u(b, b.slice(a.data, 1, 1)), 1UL)
  let wo = eq(b, u(b, b.slice(a.data, 2, 2)), 1UL)
  let command_valid = both(b, [
    calibrated,
    b.not_equal(count_cfg.value(), n(b, 25, 0UL)),
    b.less_equal(count_cfg.value(), n(b, 25, 16777216UL)),
    eq(b, u(b, b.slice(a.data, 31, 4)), 0UL),
    eq(b, u(b, b.slice(a.data, 0, 0)), 1UL),
    b.bit_not(b.bit_and(ro, wo)),
  ])
  let write_ok = both(b, [
    writable,
    any(b, [
      seed_address,
      b.bit_and(
        count_address,
        both(b, [
          b.not_equal(a.data, n(b, 32, 0UL)),
          b.less_equal(a.data, n(b, 32, 16777216UL)),
        ]),
      ),
      b.bit_and(mode_address, b.less_equal(a.data, n(b, 32, 7UL))),
      b.bit_and(cmd_address, command_valid),
    ]),
  ])
  let commit = b.bit_and(a.write, write_ok)
  let start = b.bit_and(commit, cmd_address)
  let bad_start = both(b, [
    a.write,
    writable,
    cmd_address,
    b.bit_not(command_valid),
  ])
  update(b, seed_cfg, b.bit_and(commit, seed_address), a.data)
  update(
    b,
    count_cfg,
    b.bit_and(commit, count_address),
    u(b, b.slice(a.data, 24, 0)),
  )
  update(
    b,
    mode_cfg,
    b.bit_and(commit, mode_address),
    u(b, b.slice(a.data, 2, 0)),
  )
  update(b, seed, start, seed_cfg.value())
  update(b, count, start, count_cfg.value())
  update(b, mode, start, mode_cfg.value())
  update(b, reverse, start, eq(b, u(b, b.slice(a.data, 3, 3)), 1UL))
  update(b, write_only, start, wo)
  let write_enable = both(b, [active, writing, calibrated])
  let command_valid = both(b, [write_enable, b.bit_not(command_sent.value())])
  let data_valid = both(b, [write_enable, b.bit_not(data_sent.value())])
  let command_fire = b.bit_and(command_valid, app_ready)
  let data_fire = b.bit_and(data_valid, data_ready)
  let write_beat = both(b, [
    write_enable,
    b.bit_or(command_sent.value(), command_fire),
    b.bit_or(data_sent.value(), data_fire),
  ])
  let last_write = b.bit_and(
    write_beat,
    b.equal(
      b.add(b.zero_extend(write_index.value(), 25), n(b, 25, 1UL)),
      count.value(),
    ),
  )
  let pending = b.sub(reads.value(), checked.value())
  let read_enable = both(b, [
    active,
    reading,
    calibrated,
    b.less_than(reads.value(), count.value()),
    b.less_than(pending, n(b, 25, 16UL)),
  ])
  let read_fire = b.bit_and(read_enable, app_ready)
  let response = both(b, [active, reading, read_valid])
  let response_owned = b.less_than(checked.value(), reads.value())
  let response_ok = both(b, [response, response_owned, read_end])
  let protocol_fault = both(b, [
    active,
    read_valid,
    b.bit_not(both(b, [reading, response_owned, read_end])),
  ])
  let calibration_lost = both(b, [active, busy, b.bit_not(calibrated)])
  let last_read = both(b, [
    response_ok,
    b.equal(b.add(checked.value(), n(b, 25, 1UL)), count.value()),
  ])
  let issue_index = u(
    b,
    b.truncate(
      b.mux(
        reverse.value(),
        b.sub(b.sub(count.value(), n(b, 25, 1UL)), reads.value()),
        reads.value(),
      ),
      24,
    ),
  )
  let check_index = u(
    b,
    b.truncate(
      b.mux(
        reverse.value(),
        b.sub(b.sub(count.value(), n(b, 25, 1UL)), checked.value()),
        checked.value(),
      ),
      24,
    ),
  )
  let expected = pattern(b, check_index, seed.value(), mode.value(), true)
  let word_errors : Array[@wire.Signal] = []
  for i in 0..<4 {
    word_errors.push(b.not_equal(read_data[i], expected[i]))
  }
  let mismatch = both(b, [response_ok, any(b, word_errors)])
  let first_mismatch = b.bit_and(mismatch, eq(b, mismatches.value(), 0UL))
  let failed = any(b, [calibration_lost, protocol_fault])
  b.connect_next(
    state,
    b.mux(
      start,
      b.mux(ro, n(b, 3, 2UL), n(b, 3, 1UL)),
      b.mux(
        bad_start,
        n(b, 3, 4UL),
        b.mux(
          failed,
          n(b, 3, 4UL),
          b.mux(
            last_write,
            b.mux(write_only.value(), n(b, 3, 3UL), n(b, 3, 2UL)),
            b.mux(last_read, n(b, 3, 3UL), state.value()),
          ),
        ),
      ),
    ),
  )
  b.connect_next(
    command_sent,
    b.mux(
      b.bit_or(start, write_beat),
      n(b, 1, 0UL),
      b.bit_or(command_sent.value(), command_fire),
    ),
  )
  b.connect_next(
    data_sent,
    b.mux(
      b.bit_or(start, write_beat),
      n(b, 1, 0UL),
      b.bit_or(data_sent.value(), data_fire),
    ),
  )
  b.connect_next(
    write_index,
    b.mux(
      start,
      n(b, 24, 0UL),
      b.mux(
        write_beat,
        b.add(write_index.value(), n(b, 24, 1UL)),
        write_index.value(),
      ),
    ),
  )
  for
    (r, enable) in [
      (commands, command_fire),
      (data_beats, data_fire),
      (reads, read_fire),
      (checked, response_ok),
      (mismatches, mismatch),
    ] {
    b.connect_next(
      r,
      b.mux(
        start,
        n(b, 25, 0UL),
        b.mux(enable, b.add(r.value(), n(b, 25, 1UL)), r.value()),
      ),
    )
  }
  for (r, enable) in [(write_cycles, writing), (read_cycles, reading)] {
    b.connect_next(
      r,
      b.mux(
        start,
        n(b, 64, 0UL),
        b.mux(enable, b.add(r.value(), n(b, 64, 1UL)), r.value()),
      ),
    )
  }
  b.connect_next(
    error,
    b.mux(
      start,
      n(b, 2, 0UL),
      b.mux(
        bad_start,
        n(b, 2, 1UL),
        b.mux(
          calibration_lost,
          n(b, 2, 2UL),
          b.mux(protocol_fault, n(b, 2, 3UL), error.value()),
        ),
      ),
    ),
  )
  let check_byte_address = b.zero_extend(
    u(b, b.concat(check_index, n(b, 4, 0UL))),
    32,
  )
  let first_values : Array[(@wire.RegisterHandle, @wire.Signal)] = [
    (first_address, check_byte_address),
  ]
  for i in 0..<4 {
    first_values.push((first_expected[i], expected[i]))
    first_values.push((first_actual[i], read_data[i]))
  }
  for (r, value) in first_values {
    b.connect_next(
      r,
      b.mux(
        start,
        n(b, r.value().signal_type().width().bits(), 0UL),
        b.mux(first_mismatch, value, r.value()),
      ),
    )
  }
  let native_index = b.mux(writing, write_index.value(), issue_index)
  out(
    b,
    "app_addr",
    b.zero_extend(u(b, b.concat(native_index, n(b, 3, 0UL))), 28),
  )
  out(b, "app_cmd", b.mux(writing, n(b, 3, 0UL), n(b, 3, 1UL)))
  out(b, "app_en", b.bit_or(command_valid, read_enable))
  let write_words = pattern(
    b,
    write_index.value(),
    seed.value(),
    mode.value(),
    false,
  )
  for i in 0..<4 {
    out(b, "app_wdf_word" + i.to_string(), write_words[i])
  }
  out(b, "app_wdf_wren", data_valid)
  out(b, "app_wdf_end", data_valid)
  out(
    b,
    "app_wdf_mask",
    b.mux(
      eq(b, mode.value(), 6UL),
      n(b, 16, 0xaaaaUL),
      b.mux(eq(b, mode.value(), 7UL), n(b, 16, 0x5555UL), n(b, 16, 0UL)),
    ),
  )
  let done = any(b, [eq(b, state.value(), 3UL), eq(b, state.value(), 4UL)])
  let has_error = any(b, [
    b.not_equal(error.value(), n(b, 2, 0UL)),
    b.not_equal(mismatches.value(), n(b, 25, 0UL)),
  ])
  let flags = u(
    b,
    b.concat(b.concat(has_error, done), b.concat(busy, calibrated)),
  )
  let registers : Array[(UInt64, @wire.Signal)] = [
    (0UL, n(b, 32, 0x44445233UL)),
    (4UL, n(b, 32, 0x00010000UL)),
    (8UL, flags),
    (12UL, error.value()),
    (16UL, n(b, 32, 0UL)),
    (20UL, seed_cfg.value()),
    (24UL, count_cfg.value()),
    (28UL, mode_cfg.value()),
    (32UL, commands.value()),
    (36UL, reads.value()),
    (40UL, checked.value()),
    (44UL, mismatches.value()),
    (48UL, u(b, b.slice(write_cycles.value(), 31, 0))),
    (52UL, u(b, b.slice(write_cycles.value(), 63, 32))),
    (56UL, u(b, b.slice(read_cycles.value(), 31, 0))),
    (60UL, u(b, b.slice(read_cycles.value(), 63, 32))),
    (64UL, first_address.value()),
    (100UL, n(b, 32, 100000000UL)),
    (104UL, n(b, 32, 16UL)),
    (108UL, data_beats.value()),
  ]
  for i in 0..<4 {
    registers.push(((68 + i * 4).to_uint64(), first_expected[i].value()))
    registers.push(((84 + i * 4).to_uint64(), first_actual[i].value()))
  }
  axi_finish(b, a, write_ok, registers)
  out(b, "test_state", state.value())
  out(b, "test_writes", commands.value())
  out(b, "test_data_beats", data_beats.value())
  out(b, "test_reads", reads.value())
  out(b, "test_checked", checked.value())
  out(b, "test_mismatches", mismatches.value())
  out(b, "test_write_cycles", write_cycles.value())
  out(b, "test_read_cycles", read_cycles.value())
  out(b, "test_error", error.value())
  b.finish()
}
