///|
test "combinational cycle reports the shortest stable ordinal path" {
  let ty = @ir.SignalType::Bits(@ir.Width::new(1))
  let ids = Array::makei(5, index => @ir.NodeId::new(index))
  let nodes = [
    @ir.Node::new(ids[0], ty, BitNot(ids[2])),
    @ir.Node::new(ids[1], ty, BitNot(ids[0])),
    @ir.Node::new(ids[2], ty, BitNot(ids[1])),
    @ir.Node::new(ids[3], ty, BitNot(ids[4])),
    @ir.Node::new(ids[4], ty, BitNot(ids[3])),
  ]
  try @ir.Module::checked("Cycles", nodes, []) catch {
    CombinationalCycle(path) => debug_inspect(path, content="[3, 4, 3]")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected combinational-cycle rejection")
  }
}

///|
test "acyclic forward reference remains a distinct diagnostic" {
  let ty = @ir.SignalType::Bits(@ir.Width::new(1))
  let first = @ir.NodeId::new(0)
  let later = @ir.NodeId::new(1)
  let nodes = [
    @ir.Node::new(first, ty, BitNot(later)),
    @ir.Node::new(later, ty, Constant(0UL)),
  ]
  try @ir.Module::checked("Forward", nodes, []) catch {
    ForwardReference(node~, operand~) => {
      assert_eq(node, 0)
      assert_eq(operand, 1)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected forward-reference rejection")
  }
}

///|
test "minimal cycle is selected across every dependency edge" {
  let ty = @ir.SignalType::Bits(@ir.Width::new(1))
  let ids = Array::makei(5, index => @ir.NodeId::new(index))
  let nodes = [
    @ir.Node::new(
      ids[0],
      ty,
      Mux(select=ids[1], when_true=ids[4], when_false=ids[4]),
    ),
    @ir.Node::new(ids[1], ty, BitNot(ids[2])),
    @ir.Node::new(ids[2], ty, BitNot(ids[0])),
    @ir.Node::new(ids[3], ty, Constant(0UL)),
    @ir.Node::new(ids[4], ty, BitNot(ids[0])),
  ]
  try @ir.Module::checked("CompetingCycles", nodes, []) catch {
    CombinationalCycle(path) => debug_inspect(path, content="[0, 4, 0]")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected combinational-cycle rejection")
  }
}
