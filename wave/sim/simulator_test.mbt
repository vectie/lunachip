///|
fn data_type(width : Int) -> @ir.SignalType raise {
  UInt(@ir.Width::new(width))
}

///|
fn register(
  clock : @ir.NodeId,
  next : @ir.NodeId,
  initial : UInt64,
) -> @ir.NodeKind {
  Register(
    @ir.RegisterSpec::new(@ir.ClockDomain::rising(clock), next, initial~),
  )
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
    @ir.Node::new(first, eight, register(clock, input, 1UL)),
    @ir.Node::new(second, eight, register(clock, first, 9UL)),
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
    @ir.Node::new(state, eight, register(clock, next, 0UL)),
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

///|
fn controlled_register_module() -> @ir.Module raise {
  let clock = @ir.NodeId::new(0)
  let reset = @ir.NodeId::new(1)
  let enable = @ir.NodeId::new(2)
  let next = @ir.NodeId::new(3)
  let state = @ir.NodeId::new(4)
  let one = @ir.Width::new(1)
  let eight = data_type(8)
  let spec = @ir.RegisterSpec::new(
    @ir.ClockDomain::rising(clock),
    next,
    reset=@ir.ResetSpec::new(reset, 0UL),
    enable~,
    initial=3UL,
  )
  @ir.Module::checked(
    "ControlledRegister",
    [
      @ir.Node::new(clock, Clock, Input("clock")),
      @ir.Node::new(reset, Reset, Input("reset")),
      @ir.Node::new(enable, Bits(one), Input("enable")),
      @ir.Node::new(next, eight, Input("next")),
      @ir.Node::new(state, eight, Register(spec)),
    ],
    [@ir.OutputPort::new("state", eight, state)],
  )
}

///|
fn drive_control(
  simulator : @sim.Simulator,
  name : String,
  value : UInt64,
) -> Unit raise {
  simulator.set_input(name, @wave.LogicValue::from_uint64(width=1, value~))
}

///|
test "synchronous reset wins over enable and enable otherwise selects hold" {
  let simulator = @sim.Simulator::prepare(controlled_register_module())
  drive_control(simulator, "reset", 0UL)
  drive_control(simulator, "enable", 0UL)
  simulator.set_input("next", @wave.LogicValue::from_uint64(width=8, value=9UL))
  simulator.rising_edge("clock")
  inspect(simulator.output("state").to_uint64(), content="3")
  drive_control(simulator, "enable", 1UL)
  simulator.rising_edge("clock")
  inspect(simulator.output("state").to_uint64(), content="9")
  drive_control(simulator, "reset", 1UL)
  drive_control(simulator, "enable", 1UL)
  simulator.set_input("next", @wave.LogicValue::from_uint64(width=8, value=7UL))
  simulator.rising_edge("clock")
  inspect(simulator.output("state").to_uint64(), content="0")
}

///|
test "unknown register controls merge possible next states bitwise" {
  let unknown_enable = @sim.Simulator::prepare(controlled_register_module())
  drive_control(unknown_enable, "reset", 0UL)
  unknown_enable.set_input("enable", @wave.LogicValue::unknown(width=1))
  unknown_enable.set_input(
    "next",
    @wave.LogicValue::from_uint64(width=8, value=5UL),
  )
  unknown_enable.rising_edge("clock")
  inspect(unknown_enable.output("state").to_bit_string(), content="00000xx1")

  let unknown_reset = @sim.Simulator::prepare(controlled_register_module())
  unknown_reset.set_input("reset", @wave.LogicValue::unknown(width=1))
  drive_control(unknown_reset, "enable", 1UL)
  unknown_reset.set_input(
    "next",
    @wave.LogicValue::from_uint64(width=8, value=9UL),
  )
  unknown_reset.rising_edge("clock")
  inspect(unknown_reset.output("state").to_bit_string(), content="0000x00x")
}

///|
fn drive_three_state_control(
  simulator : @sim.Simulator,
  name : String,
  state : Int,
) -> Unit raise {
  let value = match state {
    0 => @wave.LogicValue::zero(width=1)
    1 => @wave.LogicValue::one(width=1)
    _ => @wave.LogicValue::unknown(width=1)
  }
  simulator.set_input(name, value)
}

///|
test "reset and enable priority covers every known and unknown combination" {
  let expected = [
    "00000011", "00000101", "00000xx1", "00000000", "00000000", "00000000", "000000xx",
    "00000x0x", "00000xxx",
  ]
  for reset_state in 0..<3 {
    for enable_state in 0..<3 {
      let simulator = @sim.Simulator::prepare(controlled_register_module())
      drive_three_state_control(simulator, "reset", reset_state)
      drive_three_state_control(simulator, "enable", enable_state)
      simulator.set_input(
        "next",
        @wave.LogicValue::from_uint64(width=8, value=5UL),
      )
      simulator.rising_edge("clock")
      assert_eq(
        simulator.output("state").to_bit_string(),
        expected[reset_state * 3 + enable_state],
      )
    }
  }
}

///|
test "snapshot restore reproduces the same cycle and state transition" {
  let simulator = @sim.Simulator::prepare(controlled_register_module())
  drive_control(simulator, "reset", 0UL)
  drive_control(simulator, "enable", 1UL)
  simulator.set_input("next", @wave.LogicValue::from_uint64(width=8, value=9UL))
  simulator.rising_edge("clock")
  let snapshot = simulator.snapshot()
  inspect(snapshot.cycle().value(), content="1")
  simulator.set_input("next", @wave.LogicValue::from_uint64(width=8, value=7UL))
  simulator.rising_edge("clock")
  inspect(simulator.output("state").to_uint64(), content="7")
  simulator.restore(snapshot)
  inspect(simulator.cycle().value(), content="1")
  inspect(simulator.output("state").to_uint64(), content="9")
  simulator.set_input("next", @wave.LogicValue::from_uint64(width=8, value=7UL))
  simulator.rising_edge("clock")
  inspect(simulator.output("state").to_uint64(), content="7")
  inspect(simulator.cycle().value(), content="2")
}
