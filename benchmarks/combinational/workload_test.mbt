///|
test "representative prepared workload agrees with independent oracle" {
  let workload = @combinational.representative_workload(12)
  let simulator = @sim.Simulator::prepare(workload.hardware_module())
  simulator.set_input("lhs", workload.lhs())
  simulator.set_input("rhs", workload.rhs())
  simulator.settle()
  assert_eq(simulator.output("result").to_uint64(), workload.expected())
  assert_eq(workload.nodes(), 184)
}

///|
test "repeated settlement is deterministic" {
  let workload = @combinational.representative_workload(4)
  let simulator = @sim.Simulator::prepare(workload.hardware_module())
  simulator.set_input("lhs", workload.lhs())
  simulator.set_input("rhs", workload.rhs())
  simulator.settle()
  let expected = simulator.output("result")
  for _ in 0..<100 {
    simulator.settle()
    assert_eq(simulator.output("result"), expected)
  }
}
