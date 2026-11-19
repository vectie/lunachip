///|
test "health and unowned DDR responses poison idle until physical reset" {
  let b = bench()
  b.unsolicited = true
  b.step()
  b.unsolicited = false
  b.step()
  assert_eq(value(b.sim, "observe_fault"), 1UL)
  assert_eq(b.read(12UL), 4UL)
  assert_eq(b.write(16UL, 1UL), 2UL)
  b.set("reset", 1, 1UL)
  b.step()
  b.set("reset", 1, 0UL)
  b.step()
  configure(b, 1, 1, 1)
  b.environment(stalled=true)
  assert_eq(b.write(16UL, 1UL), 0UL)
  b.environment(healthy=false)
  b.step()
  assert_eq(value(b.sim, "observe_fault"), 1UL)
  assert_eq(b.read(12UL), 2UL)
  assert_eq(b.read(0x34UL), 0UL)
}

///|
test "malformed stream LAST faults and drains captured ownership" {
  let b = bench()
  configure(b, 1, 1, 1)
  b.malformed_last = true
  assert_eq(b.write(16UL, 1UL), 0UL)
  for _ in 0..<30 {
    if value(b.sim, "observe_fault") == 1UL {
      break
    }
    b.step()
  }
  assert_eq(value(b.sim, "observe_fault"), 1UL)
  assert_eq(value(b.sim, "observe_owner"), 3UL)
  assert_eq(value(b.sim, "observe_issued"), 1UL)
  b.malformed_last = false
  for _ in 0..<150 {
    b.step()
  }
  assert_eq(value(b.sim, "observe_owner"), 0UL)
  assert_eq(value(b.sim, "ddr_request_valid"), 0UL)
  assert_eq(b.read(12UL), 4UL)
  assert_eq(b.read(0x34UL), 0UL)
  assert_eq(b.write(16UL, 2UL), 2UL)
}
