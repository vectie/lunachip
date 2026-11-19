///|
pub(all) suberror MemtestError {
  InvalidGeometry
}

///|
/// Two finite, complete write-then-read rounds. No wall-clock or host stimulus
/// is involved. The board supplies coordinated synchronous reset and calibration.
pub fn controller(
  beats~ : UInt32 = 134217728U,
  base_address~ : UInt32 = 0U,
) -> @ir.Module raise {
  guard beats > 0U &&
    beats <= 134217728U &&
    base_address % 16U == 0U &&
    base_address.to_uint64() + beats.to_uint64() * 16UL <= 2147483648UL else {
    raise InvalidGeometry
  }
  let b = @wire.ModuleBuilder::new("Pblaze3Memtest")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let reset_input = b.input("reset", @wire.reset())
  b.input_timing(reset_input, SampledIn(d.id()))
  let reset = b.synchronous_reset(reset_input, 0UL)
  let running = b.bit_not(b.reset_asserted(reset_input))
  let calibrated = input(b, d, "calibrated", 1)
  let healthy = input(b, d, "memory_healthy", 1)
  let ready = input(b, d, "request_ready", 1)
  let valid = input(b, d, "response_valid", 1)
  let data = input(b, d, "response_data", 32)
  let fault = input(b, d, "response_fault", 2)
  let last = input(b, d, "response_last", 1)
  let wide = input(b, d, "response_wide", 1)
  let phase = b.register_state_in(d, @wire.uint(3), reset~)
  let round = b.register_state_in(d, @wire.bits(1), reset~)
  let writes = b.register_state_in(d, @wire.uint(28), reset~)
  let reads = b.register_state_in(d, @wire.uint(28), reset~)
  let address = b.register_state_in(d, @wire.uint(32), reset~)
  let lane = b.register_state_in(d, @wire.uint(2), reset~)
  let error = b.register_state_in(d, @wire.uint(3), reset~)
  let first_address = b.register_state_in(d, @wire.uint(32), reset~)
  let first_expected = b.register_state_in(d, @wire.uint(32), reset~)
  let first_actual = b.register_state_in(d, @wire.uint(32), reset~)
  let waiting = eq(b, phase.value(), 0UL)
  let write_issue = eq(b, phase.value(), 1UL)
  let write_wait = eq(b, phase.value(), 2UL)
  let read_issue = eq(b, phase.value(), 3UL)
  let read_wait = eq(b, phase.value(), 4UL)
  let passed = eq(b, phase.value(), 5UL)
  let failed = eq(b, phase.value(), 6UL)
  let busy = any(b, [write_issue, write_wait, read_issue, read_wait])
  let start = all(b, [running, waiting, calibrated, healthy])
  let request_valid = all(b, [running, b.bit_or(write_issue, read_issue)])
  let accepted = b.bit_and(request_valid, ready)
  let response = all(b, [running, valid, busy])
  let final_lane = eq(b, lane.value(), 3UL)
  let write_response = b.bit_and(response, write_wait)
  let read_response = b.bit_and(response, read_wait)
  let shape_bad = any(b, [
    b.bit_not(b.bit_or(write_wait, read_wait)),
    wide,
    b.bit_xor(last, b.bit_or(write_wait, b.bit_and(read_wait, final_lane))),
  ])
  let protocol_bad = all(b, [running, valid, b.bit_not(failed), shape_bad])
  let io_bad = b.bit_and(response, b.bit_not(eq(b, fault, 0UL)))
  let lost = all(b, [running, busy, b.bit_not(b.bit_and(calibrated, healthy))])
  let words : Array[@wire.Signal] = []
  for salt in [0x13579bdfUL, 0x2468ace0UL, 0x9e3779b9UL, 0x5a5aa5a5UL] {
    let value = b.bit_xor(address.value(), n(b, 32, 0x31415926UL ^ salt))
    words.push(b.mux(round.value(), b.bit_not(value), value))
  }
  let mut expected = words[0]
  for i in 1..<4 {
    expected = b.mux(eq(b, lane.value(), i.to_uint64()), words[i], expected)
  }
  let mismatch = all(b, [read_response, b.bit_not(b.equal(data, expected))])
  let failure = any(b, [lost, io_bad, protocol_bad, mismatch])
  let clean = b.bit_not(failure)
  let write_complete = b.bit_and(write_response, clean)
  let line_complete = all(b, [read_response, final_lane, clean])
  let next_writes = b.add(writes.value(), n(b, 28, 1UL))
  let next_reads = b.add(reads.value(), n(b, 28, 1UL))
  let last_write = b.bit_and(
    write_complete,
    eq(b, next_writes, beats.to_uint64()),
  )
  let last_read = b.bit_and(line_complete, eq(b, next_reads, beats.to_uint64()))
  let another_round = b.bit_and(last_read, b.bit_not(round.value()))
  let finish = b.bit_and(last_read, round.value())
  let rewind = any(b, [start, last_write, another_round])
  let advance = b.bit_or(write_complete, line_complete)
  update(
    b,
    address,
    b.bit_or(rewind, advance),
    b.mux(
      rewind,
      n(b, 32, base_address.to_uint64()),
      b.add(address.value(), n(b, 32, 16UL)),
    ),
  )
  update(b, round, another_round, n(b, 1, 1UL))
  b.connect_next(
    writes,
    b.mux(
      another_round,
      n(b, 28, 0UL),
      b.mux(write_complete, next_writes, writes.value()),
    ),
  )
  b.connect_next(
    reads,
    b.mux(
      another_round,
      n(b, 28, 0UL),
      b.mux(line_complete, next_reads, reads.value()),
    ),
  )
  b.connect_next(
    lane,
    b.mux(
      b.bit_or(start, accepted),
      n(b, 2, 0UL),
      b.mux(read_response, b.add(lane.value(), n(b, 2, 1UL)), lane.value()),
    ),
  )
  let mut next_phase = phase.value()
  next_phase = b.mux(start, n(b, 3, 1UL), next_phase)
  next_phase = b.mux(
    accepted,
    b.mux(write_issue, n(b, 3, 2UL), n(b, 3, 4UL)),
    next_phase,
  )
  next_phase = b.mux(
    write_complete,
    b.mux(last_write, n(b, 3, 3UL), n(b, 3, 1UL)),
    next_phase,
  )
  next_phase = b.mux(line_complete, n(b, 3, 3UL), next_phase)
  next_phase = b.mux(another_round, n(b, 3, 1UL), next_phase)
  next_phase = b.mux(finish, n(b, 3, 5UL), next_phase)
  next_phase = b.mux(failure, n(b, 3, 6UL), next_phase)
  b.connect_next(phase, next_phase)
  let first_failure = b.bit_and(failure, b.bit_not(failed))
  let fail_address = b.add(
    address.value(),
    b.mux(
      read_wait,
      b.shift_left(b.zero_extend(lane.value(), 32), n(b, 5, 2UL)),
      n(b, 32, 0UL),
    ),
  )
  update(b, first_address, first_failure, fail_address)
  update(b, first_expected, first_failure, expected)
  update(b, first_actual, first_failure, data)
  update(
    b,
    error,
    first_failure,
    b.mux(
      lost,
      n(b, 3, 2UL),
      b.mux(
        io_bad,
        n(b, 3, 3UL),
        b.mux(protocol_bad, n(b, 3, 4UL), n(b, 3, 1UL)),
      ),
    ),
  )
  let progress = b.mux(
    b.bit_or(write_issue, write_wait),
    writes.value(),
    reads.value(),
  )
  out(
    b,
    d,
    "status0",
    b.concat(b.concat(phase.value(), round.value()), progress),
  )
  out(b, d, "status1", b.mux(failed, first_address.value(), address.value()))
  out(b, d, "request_valid", request_valid)
  out(b, d, "request_write", b.bit_or(write_issue, write_wait))
  out(b, d, "request_address", address.value())
  constant_output(b, "request_line", 1UL)
  constant_output(b, "request_burst", 0UL)
  constant_output(b, "request_wide", 0UL)
  for i in 0..<4 {
    out(
      b,
      d,
      if i == 0 {
        "request_data"
      } else {
        "request_data" + i.to_string()
      },
      words[i],
    )
  }
  constant_output(b, "response_ready", 1UL)
  for
    (name, signal) in [
      ("done", passed),
      ("failed", failed),
      ("phase", phase.value()),
      ("round", round.value()),
      ("completed_writes", writes.value()),
      ("checked_reads", reads.value()),
      ("lane", lane.value()),
      ("first_error_code", error.value()),
      ("first_expected", first_expected.value()),
      ("first_actual", first_actual.value()),
      ("first_error_address", first_address.value()),
    ] {
    out(b, d, name, signal)
  }
  b.finish()
}
