///|
test "held DDR result survives next computation and overlapping health fault suppresses publication" {
  let b = bench()
  configure(b, 1024, 4, 3)
  assert_eq(b.write(16UL, 1UL), 0UL)
  for _ in 0..<100000 {
    if value(b.sim, "observe_pending") == 1UL &&
      value(b.sim, "observe_started") == 2UL {
      break
    }
    assert_eq(value(b.sim, "observe_fault"), 0UL)
    b.step()
  }
  assert_eq(value(b.sim, "observe_started"), 2UL)
  b.environment(stalled=true)
  for _ in 0..<5000 {
    b.step()
  }
  assert_eq(value(b.sim, "observe_fault"), 0UL)
  assert_eq(value(b.sim, "observe_pending"), 1UL)
  assert_eq(value(b.sim, "observe_retired"), 1UL)
  assert_eq(b.core.output("done").value_bits(), 1UL)
  assert_eq(b.core.output("busy").value_bits(), 0UL)
  b.environment()
  finish(b, 4, 1024, true, Array::makei(3, _ => Array::make(8, 0U)))
  assert_eq(b.read(0x30UL), 3UL)
  assert_eq(b.read(0x60UL), 0UL)
  assert_eq(b.write(16UL, 1UL), 0UL)
  for _ in 0..<50000 {
    if value(b.sim, "observe_executing") == 1UL &&
      value(b.sim, "observe_pack") == 1UL {
      break
    }
    b.step()
  }
  assert_eq(value(b.sim, "observe_executing"), 1UL)
  assert_eq(value(b.sim, "observe_pack"), 1UL)
  b.environment(healthy=false)
  for _ in 0..<100 {
    b.step()
  }
  assert_eq(value(b.sim, "observe_fault"), 1UL)
  assert_eq(b.read(12UL), 2UL)
  assert_eq(b.read(0x34UL), 0UL)
  for name in ["start", "load", "ddr_request_valid"] {
    assert_eq(value(b.sim, name), 0UL)
  }
  assert_eq(b.core.output("busy").value_bits(), 0UL)
}
