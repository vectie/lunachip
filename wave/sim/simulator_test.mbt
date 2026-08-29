///|
fn data_type(width : Int) -> @ir.SignalType raise {
  UInt(@ir.Width::new(width))
}

///|
test "settles the supported combinational node subset" {
  let one = data_type(1)
  let four = data_type(4)
  let select = @ir.NodeId::new(0)
  let a = @ir.NodeId::new(1)
  let b = @ir.NodeId::new(2)
  let sum = @ir.NodeId::new(3)
  let inverted = @ir.NodeId::new(4)
  let masked = @ir.NodeId::new(5)
  let ored = @ir.NodeId::new(6)
  let xored = @ir.NodeId::new(7)
  let selected = @ir.NodeId::new(8)
  let nodes = [
    @ir.Node::new(select, one, Input("select")),
    @ir.Node::new(a, four, Input("a")),
    @ir.Node::new(b, four, Input("b")),
    @ir.Node::new(sum, four, Add(a, b)),
    @ir.Node::new(inverted, four, BitNot(sum)),
    @ir.Node::new(masked, four, BitAnd(inverted, a)),
    @ir.Node::new(ored, four, BitOr(masked, b)),
    @ir.Node::new(xored, four, BitXor(ored, a)),
    @ir.Node::new(selected, four, Mux(select~, when_true=xored, when_false=sum)),
  ]
  let hardware_module = @ir.Module::checked("Combinational", nodes, [
    @ir.OutputPort::new("result", four, selected),
  ])
  let simulator = @sim.Simulator::prepare(hardware_module)
  simulator.set_input(
    "select",
    @wave.LogicValue::from_uint64(width=1, value=1UL),
  )
  simulator.set_input("a", @wave.LogicValue::from_uint64(width=4, value=3UL))
  simulator.set_input("b", @wave.LogicValue::from_uint64(width=4, value=5UL))
  simulator.settle()
  inspect(simulator.output("result").to_uint64(), content="4")
}

///|
test "propagates X conservatively and preserves determined bits" {
  let one = data_type(1)
  let four = data_type(4)
  let select = @ir.NodeId::new(0)
  let unknown_input = @ir.NodeId::new(1)
  let zeros = @ir.NodeId::new(2)
  let anded = @ir.NodeId::new(3)
  let muxed = @ir.NodeId::new(4)
  let nodes = [
    @ir.Node::new(select, one, Input("select")),
    @ir.Node::new(unknown_input, four, Input("unknown")),
    @ir.Node::new(zeros, four, Constant(0UL)),
    @ir.Node::new(anded, four, BitAnd(unknown_input, zeros)),
    @ir.Node::new(muxed, four, Mux(select~, when_true=anded, when_false=zeros)),
  ]
  let hardware_module = @ir.Module::checked("Unknowns", nodes, [
    @ir.OutputPort::new("result", four, muxed),
  ])
  let simulator = @sim.Simulator::prepare(hardware_module)
  simulator.set_input("select", @wave.LogicValue::unknown(width=1))
  simulator.set_input("unknown", @wave.LogicValue::unknown(width=4))
  simulator.settle()
  inspect(simulator.output("result").to_bit_string(), content="0000")
}

///|
test "registers observe old state and commit simultaneously" {
  let clock_type = @ir.Clock
  let eight = data_type(8)
  let clock = @ir.NodeId::new(0)
  let input = @ir.NodeId::new(1)
  let first = @ir.NodeId::new(2)
  let second = @ir.NodeId::new(3)
  let nodes = [
    @ir.Node::new(clock, clock_type, Input("clock")),
    @ir.Node::new(input, eight, Input("input")),
    @ir.Node::new(first, eight, Register(clock~, next=input, initial=Some(1UL))),
    @ir.Node::new(
      second,
      eight,
      Register(clock~, next=first, initial=Some(9UL)),
    ),
  ]
  let hardware_module = @ir.Module::checked("Pipeline", nodes, [
    @ir.OutputPort::new("first", eight, first),
    @ir.OutputPort::new("second", eight, second),
  ])
  let simulator = @sim.Simulator::prepare(hardware_module)
  inspect(simulator.output("first").to_uint64(), content="1")
  inspect(simulator.output("second").to_uint64(), content="9")
  simulator.set_input(
    "input",
    @wave.LogicValue::from_uint64(width=8, value=5UL),
  )
  simulator.rising_edge("clock")
  inspect(simulator.output("first").to_uint64(), content="5")
  inspect(simulator.output("second").to_uint64(), content="1")
  simulator.set_input(
    "input",
    @wave.LogicValue::from_uint64(width=8, value=7UL),
  )
  simulator.rising_edge("clock")
  inspect(simulator.output("first").to_uint64(), content="7")
  inspect(simulator.output("second").to_uint64(), content="5")
  inspect(simulator.cycle().value(), content="2")
}

///|
test "register feedback settles next-state logic constructed later" {
  let eight = data_type(8)
  let clock = @ir.NodeId::new(0)
  let state = @ir.NodeId::new(1)
  let one = @ir.NodeId::new(2)
  let next = @ir.NodeId::new(3)
  let nodes = [
    @ir.Node::new(clock, Clock, Input("clock")),
    @ir.Node::new(state, eight, Register(clock~, next~, initial=Some(0UL))),
    @ir.Node::new(one, eight, Constant(1UL)),
    @ir.Node::new(next, eight, Add(state, one)),
  ]
  let hardware_module = @ir.Module::checked("Counter", nodes, [
    @ir.OutputPort::new("count", eight, state),
  ])
  let simulator = @sim.Simulator::prepare(hardware_module)
  simulator.rising_edge("clock")
  inspect(simulator.output("count").to_uint64(), content="1")
  simulator.rising_edge("clock")
  inspect(simulator.output("count").to_uint64(), content="2")
}
