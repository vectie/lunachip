///|
test "eight-line stream holds all32 beats, latches request, rejects shape and resets" {
  let b = bridge_bench()
  for _ in 0..<3 {
    stream_bridge_replay(b)
  }
}

///|
test "stream poison drains its owner without issuing later native reads" {
  for calibration in [false, true] {
    let b = bridge_bench()
    b.read_delay = 60
    b.begin_line(0UL, burst=true)
    for _ in 0..<300 {
      b.step()
      if b.reads.length() == 8 {
        break
      }
    }
    assert_eq(b.reads.length(), 8)
    if calibration {
      set(b.sim, "calibrated", 1, 0UL)
    } else {
      b.environment(bad_end=true)
    }
    let mut fault_seen = false
    for beat in 0..<32 {
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
