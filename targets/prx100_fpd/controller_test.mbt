///|
test "FP DDR controller resets to healthy idle and has separate cache memories" {
  let h = @prx100_fpd.controller()
  assert_eq(h.memories().length(), 2)
  let s = @sim.Simulator::prepare(h)
  for n in h.nodes() {
    if n.kind() is Input(name) {
      s.set_input(
        name,
        @wave.LogicValue::from_uint64(
          width=n.signal_type().width().bits(),
          value=0UL,
        ),
      )
    }
  }
  s.set_input("reset", @wave.LogicValue::from_uint64(width=1, value=1UL))
  s.rising_edge("clock")
  s.set_input("reset", @wave.LogicValue::from_uint64(width=1, value=0UL))
  s.set_input(
    "memory_healthy",
    @wave.LogicValue::from_uint64(width=1, value=1UL),
  )
  s.settle()
  for
    name in [
      "observe_busy", "observe_fault", "observe_cache", "ddr_request_valid", "load",
      "start",
    ] {
    assert_eq(s.output(name).value_bits(), 0UL)
  }
}
