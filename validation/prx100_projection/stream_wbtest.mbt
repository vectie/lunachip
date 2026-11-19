///|
test "eight-line stream holds all32 beats, latches request, rejects shape and resets" {
  stream_bridge_replay(bridge_bench())
}

///|
test "stream poison drains its owner without issuing later native reads" {
  for calibration in [false, true] {
    let b = bridge_bench()
    b.begin_line(0UL, burst=true)
    for _ in 0..<5 {
      ignore(b.line_beat(1))
    }
    if calibration {
      set(b.sim, "calibrated", 1, 0UL)
    } else {
      b.environment(bad_end=true)
    }
    let mut fault_seen = false
    for beat in 5..<32 {
      let (_, fault, last) = b.line_beat(3)
      assert_eq(last, if beat == 31 { 1UL } else { 0UL })
      if fault != 0UL {
        fault_seen = true
      }
      if fault_seen {
        assert_true(fault != 0UL)
      }
    }
    assert_true(fault_seen)
    assert_eq(value(b.sim, "memory_healthy"), 0UL)
    let reads = b.reads.length()
    for _ in 0..<30 {
      b.step()
    }
    assert_eq(b.reads.length(), reads)
    b.environment()
    b.reset()
    assert_eq(b.transaction(0UL), (0UL, 0UL))
  }
}

///|
test "descriptor patching progresses during a stalled operand prefetch but publication waits" {
  let b = bench()
  let (a, w, p, sums) = fixture(2, 127)
  store_codes(b, 0x100000U, w)
  store_codes(b, 0x200000U, a)
  b.configure(2)
  assert_eq(b.write(16UL, 1UL), 0UL)
  for _ in 0..<2000 {
    if b.observe("state") == 7UL {
      break
    }
    b.step()
  }
  assert_eq(b.observe("state"), 7UL)
  b.environment(stalled=true)
  for _ in 0..<1200 {
    b.step()
  }
  assert_eq(b.observe("ahead"), 2UL)
  assert_true(b.observe("prefetch") != 2UL)
  assert_eq(value(b.core, "producer_count"), 4UL)
  assert_eq(b.descriptor_writes.length(), 44)
  b.environment()
  b.finish_job(2, p, sums)
}
