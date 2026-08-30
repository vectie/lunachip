///|
fn fifo_node(
  primitive : Int,
  role : String,
  id : NodeId,
  nodes : ArrayView[Node],
) -> Node raise IrError {
  match nodes.get(id.ordinal()) {
    Some(node) => node
    None => raise UnknownAsyncFifoNode(primitive~, role~, node=id.ordinal())
  }
}

///|
fn require_fifo_type(
  primitive : Int,
  role : String,
  id : NodeId,
  expected : SignalType,
  nodes : ArrayView[Node],
) -> Node raise IrError {
  let node = fifo_node(primitive, role, id, nodes)
  if node.signal_type() != expected {
    raise AsyncFifoNodeTypeMismatch(primitive~, role~, node=id.ordinal())
  }
  node
}

///|
fn require_fifo_reset(
  primitive : Int,
  role : String,
  reset : ResetSpec,
  nodes : ArrayView[Node],
) -> Unit raise IrError {
  let signal = fifo_node(primitive, role, reset.signal(), nodes)
  if !(signal.signal_type() is Reset) ||
    reset.mode() != Synchronous ||
    reset.polarity() != ActiveHigh ||
    reset.value() != 0UL {
    raise AsyncFifoResetMismatch(
      primitive~,
      role~,
      node=reset.signal().ordinal(),
    )
  }
}

///|
fn require_fifo_domain(
  primitive : Int,
  role : String,
  requested : ClockDomainId,
  domains : ArrayView[ClockDomain],
) -> Unit raise IrError {
  for domain in domains {
    if domain.id() == requested {
      return
    }
  }
  raise UnknownAsyncFifoDomain(primitive~, role~, domain=requested.ordinal())
}

///|
fn require_fifo_register(
  primitive : Int,
  role : String,
  id : NodeId,
  expected_type : SignalType,
  domain : ClockDomainId,
  next : NodeId,
  reset : ResetSpec,
  nodes : ArrayView[Node],
) -> Unit raise IrError {
  let node = require_fifo_type(primitive, role, id, expected_type, nodes)
  guard node.kind() is Register(register) else {
    raise AsyncFifoStructureMismatch(primitive~, role~)
  }
  if register.domain().id() != domain ||
    register.next() != next ||
    register.enable() is Some(_) {
    raise AsyncFifoStructureMismatch(primitive~, role~)
  }
  if register.reset() != Some(reset) {
    raise AsyncFifoResetMismatch(primitive~, role~, node=id.ordinal())
  }
}

///|
fn fifo_pair_matches(
  left : NodeId,
  right : NodeId,
  first : NodeId,
  second : NodeId,
) -> Bool {
  (left == first && right == second) || (left == second && right == first)
}

///|
fn require_fifo_and(
  primitive : Int,
  role : String,
  id : NodeId,
  first : NodeId,
  second : NodeId,
  nodes : ArrayView[Node],
) -> Unit raise IrError {
  let node = require_fifo_type(primitive, role, id, Bits(Width::new(1)), nodes)
  if !(node.kind() is BitAnd(left, right) &&
    fifo_pair_matches(left, right, first, second)) {
    raise AsyncFifoStructureMismatch(primitive~, role~)
  }
}

///|
fn require_fifo_not(
  primitive : Int,
  role : String,
  id : NodeId,
  operand : NodeId,
  nodes : ArrayView[Node],
) -> Unit raise IrError {
  let node = require_fifo_type(primitive, role, id, Bits(Width::new(1)), nodes)
  if !(node.kind() is BitNot(actual) && actual == operand) {
    raise AsyncFifoStructureMismatch(primitive~, role~)
  }
}

///|
fn require_fifo_binary_next(
  primitive : Int,
  role : String,
  next : NodeId,
  current : NodeId,
  transfer : NodeId,
  pointer_type : SignalType,
  nodes : ArrayView[Node],
) -> (NodeId, NodeId) raise IrError {
  let node = require_fifo_type(primitive, role, next, pointer_type, nodes)
  guard node.kind() is Mux(select~, when_true~, when_false~) &&
    select == transfer &&
    when_false == current else {
    raise AsyncFifoStructureMismatch(primitive~, role~)
  }
  let advance = require_fifo_type(
    primitive,
    "\{role}_advance",
    when_true,
    pointer_type,
    nodes,
  )
  guard advance.kind() is Add(left, right) else {
    raise AsyncFifoStructureMismatch(primitive~, role~)
  }
  let other = if left == current {
    right
  } else if right == current {
    left
  } else {
    raise AsyncFifoStructureMismatch(primitive~, role~)
  }
  let one = require_fifo_type(
    primitive,
    "\{role}_one",
    other,
    pointer_type,
    nodes,
  )
  if !(one.kind() is Constant(1UL)) {
    raise AsyncFifoStructureMismatch(primitive~, role~)
  }
  (when_true, other)
}

///|
fn require_fifo_gray_next(
  primitive : Int,
  role : String,
  gray_next : NodeId,
  binary_next : NodeId,
  pointer_type : SignalType,
  nodes : ArrayView[Node],
) -> (NodeId, NodeId) raise IrError {
  let node = require_fifo_type(primitive, role, gray_next, pointer_type, nodes)
  guard node.kind() is BitXor(left, right) else {
    raise AsyncFifoStructureMismatch(primitive~, role~)
  }
  let shifted = if left == binary_next {
    right
  } else if right == binary_next {
    left
  } else {
    raise AsyncFifoStructureMismatch(primitive~, role~)
  }
  let shift = require_fifo_type(
    primitive,
    "\{role}_shift",
    shifted,
    pointer_type,
    nodes,
  )
  guard shift.kind() is LogicalShiftRight(value~, amount~) &&
    value == binary_next else {
    raise AsyncFifoStructureMismatch(primitive~, role~)
  }
  let one = require_fifo_type(
    primitive,
    "\{role}_amount",
    amount,
    pointer_type,
    nodes,
  )
  if !(one.kind() is Constant(1UL)) {
    raise AsyncFifoStructureMismatch(primitive~, role~)
  }
  (shifted, amount)
}

///|
fn require_fifo_address(
  primitive : Int,
  role : String,
  address : NodeId,
  pointer : NodeId,
  address_width : Int,
  nodes : ArrayView[Node],
) -> NodeId raise IrError {
  let address_node = require_fifo_type(
    primitive,
    role,
    address,
    UInt(Width::new(address_width)),
    nodes,
  )
  guard address_node.kind() is Reinterpret(slice_id) else {
    raise AsyncFifoStructureMismatch(primitive~, role~)
  }
  let slice = require_fifo_type(
    primitive,
    "\{role}_slice",
    slice_id,
    Bits(Width::new(address_width)),
    nodes,
  )
  if !(slice.kind() is Slice(value~, msb~, lsb~) &&
    value == pointer &&
    msb == address_width - 1 &&
    lsb == 0) {
    raise AsyncFifoStructureMismatch(primitive~, role~)
  }
  slice_id
}

///|
fn require_fifo_synchronizer(
  primitive : Int,
  role : String,
  source : NodeId,
  stages : ReadOnlyArray[NodeId],
  pointer_type : SignalType,
  domain : ClockDomainId,
  reset : ResetSpec,
  nodes : ArrayView[Node],
) -> Unit raise IrError {
  for index, stage in stages {
    require_fifo_register(
      primitive,
      "\{role}_\{index}",
      stage,
      pointer_type,
      domain,
      if index == 0 {
        source
      } else {
        stages[index - 1]
      },
      reset,
      nodes,
    )
  }
}

///|
fn validate_fifo_hidden_fanout(
  primitive : Int,
  role : String,
  requested : NodeId,
  allowed : ArrayView[NodeId],
  nodes : ArrayView[Node],
  memories : ArrayView[MemorySpec],
  outputs : ArrayView[OutputPort],
) -> Unit raise IrError {
  for node in nodes {
    if node_uses(node, requested) {
      let mut accepted = false
      for consumer in allowed {
        if consumer == node.id() {
          accepted = true
        }
      }
      if !accepted {
        raise AsyncFifoHiddenFanout(
          primitive~,
          role~,
          node=requested.ordinal(),
          consumer="node:\{node.id().ordinal()}",
        )
      }
    }
  }
  for memory in memories {
    match memory_use(memory, requested) {
      Some(consumer) =>
        raise AsyncFifoHiddenFanout(
          primitive~,
          role~,
          node=requested.ordinal(),
          consumer~,
        )
      None => ()
    }
  }
  for output in outputs {
    if output.driver() == requested {
      raise AsyncFifoHiddenFanout(
        primitive~,
        role~,
        node=requested.ordinal(),
        consumer="output:\{output.name()}",
      )
    }
  }
}

///|
