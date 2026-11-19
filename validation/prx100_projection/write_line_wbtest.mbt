///|
test "full line writes preserve four distinct signed words and drain rejected requests" {
  let b = bridge_bench()
  write_line_replay(b)
}

///|
test "calibration loss while gathering a write line issues no native write" {
  let b = bridge_bench()
  b.begin_write_line(16UL, [0x80000000UL, 0x7fffffffUL, 0xffffffffUL, 0UL])
  set(b.sim, "calibrated", 1, 0UL)
  assert_eq(b.line_beat(9), (0UL, 2UL, 1UL))
  assert_eq(b.commands.length(), 0)
  assert_eq(b.data.length(), 0)
  assert_eq(b.memory[1], [0U, 0U, 0U, 0U])
  set(b.sim, "calibrated", 1, 1UL)
  for _ in 0..<16 {
    b.step()
  }
  assert_eq(value(b.sim, "memory_healthy"), 0UL)
  b.write_line(16UL, [1UL, 2UL, 3UL, 4UL], fault=2UL)
  b.reset()
  b.write_line(16UL, [1UL, 2UL, 3UL, 4UL])
}

///|
test "failed partial and final batch ACKs preserve acknowledged prefixes and forbid DONE" {
  for failed in 0..<4 {
    let b = bench()
    let (a, w, _, _) = fixture(1, 127 + failed)
    store_codes(b, 0x100000U, w)
    store_codes(b, 0x200000U, a)
    b.configure(1)
    assert_eq(b.read(4UL), 0x10007UL)
    assert_eq(b.write(16UL, 1UL), 0UL)
    for _ in 0..<3000 {
      if b.pending is Some(_) && b.observe("writes") == (failed + 1).to_uint64() {
        break
      }
      b.step()
    }
    assert_eq(b.observe("writes"), (failed + 1).to_uint64())
    assert_true([12UL, 15UL].contains(b.observe("state")))
    let (due, address, word, _, remaining) = b.pending.unwrap()
    b.pending = Some((due, address, word, 1UL, remaining))
    for _ in 0..<16 {
      b.step()
    }
    assert_eq(b.observe("state"), 17UL)
    assert_eq(b.read(12UL), 3UL)
    assert_eq(
      b.read(52UL),
      (if failed < 2 { failed * 4 } else { 8 }).to_uint64(),
    )
    assert_eq(b.read(44UL), if failed < 2 { 0UL } else { 1UL })
    assert_eq(b.read(8UL) & 4UL, 0UL)
  }
}

///|
test "batch write ACK requires last for partials and final sums" {
  for failed in [0, 3] {
    let b = bench()
    let (a, w, _, _) = fixture(1, 137 + failed)
    store_codes(b, 0x100000U, w)
    store_codes(b, 0x200000U, a)
    b.configure(1)
    assert_eq(b.write(16UL, 1UL), 0UL)
    for _ in 0..<3000 {
      if b.pending is Some(_) && b.observe("writes") == (failed + 1).to_uint64() {
        break
      }
      b.step()
    }
    assert_eq(b.observe("writes"), (failed + 1).to_uint64())
    assert_true([12UL, 15UL].contains(b.observe("state")))
    // Inject one malformed bridge ACK at the actual controller boundary.
    b.set("ddr_response_valid", 1, 1UL)
    b.set("ddr_response_fault", 2, 0UL)
    b.set("ddr_response_last", 1, 0UL)
    b.sim.rising_edge("clock")
    b.pending = None
    assert_eq(b.observe("state"), 17UL)
    assert_eq(b.read(12UL), 7UL)
    assert_eq(b.read(52UL), if failed == 0 { 0UL } else { 8UL })
    assert_eq(b.read(8UL) & 4UL, 0UL)
  }
}
