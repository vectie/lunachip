///|
fn validate_register_initials(
  hardware_module : @ir.Module,
) -> Unit raise EmitError {
  for node in hardware_module.nodes() {
    match node.kind() {
      Register(spec) =>
        match spec.initial() {
          Some(value) =>
            raise UnsupportedExplicitRegisterInitial(
              module_name=hardware_module.name(),
              node=node.id().ordinal(),
              value~,
            )
          None => ()
        }
      _ => ()
    }
  }
}

///|
fn reachability_dependencies(
  hardware_module : @ir.Module,
  kind : @ir.NodeKind,
) -> Array[@ir.NodeId] raise EmitError {
  match kind {
    Input(_) | Constant(_) => []
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
    Register(spec) => {
      let dependencies = [spec.domain().clock(), spec.next()]
      if spec.reset() is Some(reset) {
        dependencies.push(reset.signal())
      }
      if spec.enable() is Some(enable) {
        dependencies.push(enable)
      }
      dependencies
    }
    MemoryRead(memory~, ..) =>
      memory_dependencies(memory_at(hardware_module, memory))
    AsyncFifoRead(..) => []
  }
}

///|
fn mark_reachable(
  hardware_module : @ir.Module,
  reachable : Array[Bool],
  pending : Array[@ir.NodeId],
  id : @ir.NodeId,
) -> Unit raise EmitError {
  let ordinal = id.ordinal()
  if ordinal < 0 || ordinal >= reachable.length() {
    raise InvalidNodeReference(module_name=hardware_module.name(), node=ordinal)
  }
  if !reachable[ordinal] {
    reachable[ordinal] = true
    pending.push(id)
  }
}

///|
fn validate_all_nodes_reachable(
  hardware_module : @ir.Module,
) -> Unit raise EmitError {
  let nodes = hardware_module.nodes()
  if nodes.is_empty() {
    return
  }
  let reachable = Array::make(nodes.length(), false)
  let pending : Array[@ir.NodeId] = []
  for output in hardware_module.outputs() {
    mark_reachable(hardware_module, reachable, pending, output.driver())
  }
  // Memories are stateful roots even when a module intentionally exposes no
  // read result. Write-only initialization stores and externally inspected
  // memories must retain every declared port dependency.
  for memory in hardware_module.memories() {
    for dependency in memory_dependencies(memory) {
      mark_reachable(hardware_module, reachable, pending, dependency)
    }
  }
  // FIFO private storage is stateful even if a caller intentionally does not
  // expose its destination. Its exact write/read boundary remains reachable.
  for primitive in hardware_module.cdc_primitives() {
    match primitive {
      AsyncFifo(fifo) =>
        for dependency in async_fifo_dependencies(hardware_module, fifo) {
          mark_reachable(hardware_module, reachable, pending, dependency)
        }
      _ => ()
    }
  }
  let mut cursor = 0
  while cursor < pending.length() {
    let id = pending[cursor]
    cursor += 1
    let node = node_at(hardware_module, id)
    for dependency in reachability_dependencies(hardware_module, node.kind()) {
      mark_reachable(hardware_module, reachable, pending, dependency)
    }
  }
  for ordinal in 0..<reachable.length() {
    if !reachable[ordinal] {
      raise UnreachableNode(module_name=hardware_module.name(), node=ordinal)
    }
  }
}

///|
fn validate_module_capabilities(
  hardware_module : @ir.Module,
) -> Unit raise EmitError {
  validate_register_initials(hardware_module)
  validate_all_nodes_reachable(hardware_module)
}
