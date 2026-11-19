///|
/// Return canonical, ascending combinational dependencies. Register next-state
/// and clock references are deliberately absent: a register is a cycle break.
fn node_dependencies(kind : NodeKind) -> Array[Int32] {
  let dependencies = match kind {
    Input(_) | Constant(_) | Register(_) | MemoryRead(..) | AsyncFifoRead(..) =>
      []
    BitNot(value)
    | ZeroExtend(value)
    | SignExtend(value)
    | Truncate(value)
    | Reinterpret(value)
    | Slice(value~, ..) => [value.ordinal()]
    Add(lhs, rhs)
    | Sub(lhs, rhs)
    | MulLow(lhs, rhs)
    | MulFull(lhs, rhs)
    | BitAnd(lhs, rhs)
    | BitOr(lhs, rhs)
    | BitXor(lhs, rhs)
    | Equal(lhs, rhs)
    | LessThan(lhs, rhs)
    | LessEqual(lhs, rhs) => [lhs.ordinal(), rhs.ordinal()]
    ShiftLeft(value~, amount~)
    | LogicalShiftRight(value~, amount~)
    | ArithmeticShiftRight(value~, amount~) =>
      [value.ordinal(), amount.ordinal()]
    Concat(most_significant~, least_significant~) =>
      [most_significant.ordinal(), least_significant.ordinal()]
    Mux(select~, when_true~, when_false~) =>
      [select.ordinal(), when_true.ordinal(), when_false.ordinal()]
  }
  dependencies.sort()
  dependencies
}

///|
fn shortest_cycle_through_edge(
  dependencies : Array[Array[Int32]],
  start : Int32,
  first : Int32,
) -> Array[Int32]? {
  if first == start {
    return Some([start, start])
  }
  let predecessor = Array::make(dependencies.length(), -1)
  let queue : Array[Int32] = [first]
  predecessor[first] = start
  let mut cursor = 0
  while cursor < queue.length() {
    let current = queue[cursor]
    cursor += 1
    for next in dependencies[current] {
      if next == start {
        let reversed : Array[Int32] = [current]
        let mut node = current
        while predecessor[node] != start {
          node = predecessor[node]
          reversed.push(node)
        }
        let path : Array[Int32] = [start]
        path.append(reversed.rev())
        path.push(start)
        return Some(path)
      }
      if predecessor[next] == -1 {
        predecessor[next] = current
        queue.push(next)
      }
    }
  }
  None
}

///|
fn shortest_cycle_from(
  dependencies : Array[Array[Int32]],
  start : Int32,
) -> Array[Int32]? {
  let mut shortest : Array[Int32]? = None
  for first in dependencies[start] {
    if shortest_cycle_through_edge(dependencies, start, first)
      is Some(candidate) {
      match shortest {
        None => shortest = Some(candidate)
        Some(previous) =>
          if candidate.length() < previous.length() {
            shortest = Some(candidate)
          }
      }
    }
  }
  shortest
}

///|
fn validate_combinational_cycles(nodes : ArrayView[Node]) -> Unit raise IrError {
  let dependencies : Array[Array[Int32]] = []
  for node in nodes {
    let node_dependencies = node_dependencies(node.kind())
    for operand in node_dependencies {
      if operand < 0 || operand >= nodes.length() {
        raise UnknownNodeId(operand)
      }
    }
    dependencies.push(node_dependencies)
  }
  let mut shortest : Array[Int32]? = None
  for start in 0..<dependencies.length() {
    if shortest_cycle_from(dependencies, start) is Some(candidate) {
      match shortest {
        None => shortest = Some(candidate)
        Some(previous) =>
          if candidate.length() < previous.length() {
            shortest = Some(candidate)
          }
      }
    }
  }
  if shortest is Some(path) {
    raise CombinationalCycle(path)
  }
}
