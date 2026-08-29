///|
test "width rejects zero and negative values" {
  for bits in [0, -1, -32] {
    try @ir.Width::new(bits) catch {
      InvalidWidth(actual) => assert_eq(actual, bits)
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected invalid width")
    }
  }
}

///|
test "ground types keep clock reset bits and numeric values distinct" {
  let width = @ir.Width::new(8)
  let types = [
    @ir.SignalType::Clock,
    Reset,
    Bits(width),
    UInt(width),
    SInt(width),
  ]
  debug_inspect(
    types.map(signal_type => signal_type.width().bits()),
    content="[1, 1, 8, 8, 8]",
  )
  assert_true(types[2].is_data())
  assert_false(types[2].is_numeric())
  assert_true(types[3].is_numeric())
}

///|
test "module preserves canonical construction order" {
  let width = @ir.Width::new(8)
  let ty = @ir.SignalType::UInt(width)
  let a_id = @ir.NodeId::new(0)
  let b_id = @ir.NodeId::new(1)
  let sum_id = @ir.NodeId::new(2)
  let nodes = [
    @ir.Node::new(a_id, ty, Input("a")),
    @ir.Node::new(b_id, ty, Input("b")),
    @ir.Node::new(sum_id, ty, Add(a_id, b_id)),
  ]
  let outputs = [@ir.OutputPort::new("sum", ty, sum_id)]
  let hardware_module = @ir.Module::checked("Adder", nodes, outputs)
  let ordinals = hardware_module.nodes().map(node => node.id().ordinal())
  debug_inspect(
    ordinals,
    content=(
      #|<ReadOnlyArray: [0, 1, 2]>
    ),
  )
  debug_inspect(
    hardware_module.outputs().map(port => port.name()),
    content=(
      #|<ReadOnlyArray: ["sum"]>
    ),
  )
}

///|
test "module rejects width mismatch" {
  let one = @ir.SignalType::UInt(@ir.Width::new(1))
  let eight = @ir.SignalType::UInt(@ir.Width::new(8))
  let a = @ir.NodeId::new(0)
  let b = @ir.NodeId::new(1)
  let sum = @ir.NodeId::new(2)
  let nodes = [
    @ir.Node::new(a, one, Input("a")),
    @ir.Node::new(b, eight, Input("b")),
    @ir.Node::new(sum, eight, Add(a, b)),
  ]
  try @ir.Module::checked("BadAdder", nodes, []) catch {
    WidthMismatch(operation~, expected~, actual~) => {
      inspect(operation, content="add")
      inspect(expected, content="8")
      inspect(actual, content="1")
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected width mismatch")
  }
}

///|
test "module rejects a forward reference" {
  let ty = @ir.SignalType::UInt(@ir.Width::new(8))
  let first = @ir.NodeId::new(0)
  let later = @ir.NodeId::new(1)
  let nodes = [
    @ir.Node::new(first, ty, BitNot(later)),
    @ir.Node::new(later, ty, Constant(0UL)),
  ]
  try @ir.Module::checked("CycleLike", nodes, []) catch {
    ForwardReference(node~, operand~) => {
      inspect(node, content="0")
      inspect(operand, content="1")
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected forward-reference rejection")
  }
}

///|
test "register next state may depend on its own earlier value" {
  let clock_type = @ir.SignalType::Clock
  let data_type = @ir.SignalType::UInt(@ir.Width::new(8))
  let clock = @ir.NodeId::new(0)
  let state = @ir.NodeId::new(1)
  let one = @ir.NodeId::new(2)
  let next = @ir.NodeId::new(3)
  let nodes = [
    @ir.Node::new(clock, clock_type, Input("clock")),
    @ir.Node::new(state, data_type, Register(clock~, next~, initial=Some(0UL))),
    @ir.Node::new(one, data_type, Constant(1UL)),
    @ir.Node::new(next, data_type, Add(state, one)),
  ]
  let hardware_module = @ir.Module::checked("Counter", nodes, [
    @ir.OutputPort::new("count", data_type, state),
  ])
  debug_inspect(
    hardware_module.nodes().map(node => node.id().ordinal()),
    content="<ReadOnlyArray: [0, 1, 2, 3]>",
  )
}
