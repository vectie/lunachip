///|
// Only combinational nodes may survive outside this fixed fixture's explicit
// cuts. An unlisted sequential/memory/input leaf is a review stop, never zero.
fn dependency_generation_operands(
  kind : @ir.NodeKind,
) -> Array[@ir.NodeId] raise FormalGateError {
  match kind {
    Constant(_) => []
    BitNot(value)
    | ZeroExtend(value)
    | SignExtend(value)
    | Truncate(value)
    | Reinterpret(value)
    | Slice(value~, ..) => [value]
    Add(left, right)
    | Sub(left, right)
    | MulLow(left, right)
    | MulFull(left, right)
    | BitAnd(left, right)
    | BitOr(left, right)
    | BitXor(left, right)
    | Equal(left, right)
    | LessThan(left, right)
    | LessEqual(left, right) => [left, right]
    ShiftLeft(value~, amount~)
    | LogicalShiftRight(value~, amount~)
    | ArithmeticShiftRight(value~, amount~) => [value, amount]
    Concat(most_significant~, least_significant~) =>
      [most_significant, least_significant]
    Mux(select~, when_true~, when_false~) => [select, when_true, when_false]
    Input(_) | Register(_) | MemoryRead(..) | AsyncFifoRead(..) =>
      raise InvalidFormalBundleIdentity(
        "generation discovery: unlisted graph leaf",
      )
  }
}

///|
fn dependency_generation_closure(
  hardware : @ir.Module,
  cuts : ArrayView[DependencyGenerationCut],
  seeds : ArrayView[@ir.NodeId],
) -> Array[@ir.Node] raise FormalGateError {
  // Checked canonical modules already reject combinational cycles. This bounded
  // worklist visits each exact original node once and emits original ID order.
  let visited = Array::make(hardware.nodes().length(), false)
  let pending = seeds.to_owned()
  // Loop invariant: 0 <= cursor <= pending.length(). Only an unvisited node
  // appends operands, so the finite canonical inventory bounds total work.
  for cursor = 0; cursor < pending.length(); cursor = cursor + 1 {
    let id = pending[cursor]
    let node = dependency_generation_node(hardware, id)
    if visited[id.ordinal()] {
      continue
    }
    visited[id.ordinal()] = true
    if cuts.any(cut => cut.node == id) {
      continue
    }
    if !node.signal_type().is_data() {
      raise InvalidFormalBundleIdentity(
        "generation discovery: control type in cone",
      )
    }
    for operand in dependency_generation_operands(node.kind()) {
      pending.push(operand)
    }
  }
  hardware
  .nodes()
  .iter()
  .filter(node => {
    visited[node.id().ordinal()] && !cuts.any(cut => cut.node == node.id())
  })
  .to_array()
}
