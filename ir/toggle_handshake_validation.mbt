///|
fn toggle_node(
  primitive : Int32,
  role : String,
  id : NodeId,
  nodes : ArrayView[Node],
) -> Node raise IrError {
  match nodes.get(id.ordinal()) {
    Some(node) => node
    None =>
      raise UnknownToggleHandshakeNode(primitive~, role~, node=id.ordinal())
  }
}

///|
fn require_toggle_bit(
  primitive : Int32,
  role : String,
  id : NodeId,
  nodes : ArrayView[Node],
) -> Node raise IrError {
  let node = toggle_node(primitive, role, id, nodes)
  if !is_one_bit_data(node.signal_type()) {
    raise ToggleHandshakeNodeTypeMismatch(primitive~, role~, node=id.ordinal())
  }
  node
}

///|
fn unordered_pair_matches(
  left : NodeId,
  right : NodeId,
  first : NodeId,
  second : NodeId,
) -> Bool {
  (left == first && right == second) || (left == second && right == first)
}

///|
fn require_toggle_not(
  primitive : Int32,
  role : String,
  node : NodeId,
  operand : NodeId,
  nodes : ArrayView[Node],
) -> Unit raise IrError {
  let actual = require_toggle_bit(primitive, role, node, nodes)
  if !(actual.kind() is BitNot(found) && found == operand) {
    raise ToggleHandshakeStructureMismatch(primitive~, role~)
  }
}

///|
priv enum ToggleBinaryKind {
  ToggleAnd
  ToggleEqual
}

///|
fn require_toggle_binary(
  primitive : Int32,
  role : String,
  node : NodeId,
  first : NodeId,
  second : NodeId,
  expected : ToggleBinaryKind,
  nodes : ArrayView[Node],
) -> Unit raise IrError {
  let actual = require_toggle_bit(primitive, role, node, nodes)
  let matches = match (expected, actual.kind()) {
    (ToggleAnd, BitAnd(left, right)) | (ToggleEqual, Equal(left, right)) =>
      unordered_pair_matches(left, right, first, second)
    _ => false
  }
  if !matches {
    raise ToggleHandshakeStructureMismatch(primitive~, role~)
  }
}

///|
fn require_toggle_register(
  primitive : Int32,
  role : String,
  node : NodeId,
  expected_type : SignalType,
  domain : ClockDomainId,
  next : NodeId,
  enable : NodeId?,
  reset : ResetSpec,
  nodes : ArrayView[Node],
) -> Unit raise IrError {
  let actual = toggle_node(primitive, role, node, nodes)
  if actual.signal_type() != expected_type {
    raise ToggleHandshakeNodeTypeMismatch(
      primitive~,
      role~,
      node=node.ordinal(),
    )
  }
  guard actual.kind() is Register(spec) else {
    raise ToggleHandshakeStructureMismatch(primitive~, role~)
  }
  if spec.domain().id() != domain ||
    spec.next() != next ||
    spec.enable() != enable {
    raise ToggleHandshakeStructureMismatch(primitive~, role~)
  }
  if spec.reset() != Some(reset) {
    raise ToggleHandshakeResetMismatch(primitive~, role~, node=node.ordinal())
  }
}

///|
fn require_toggle_reset(
  primitive : Int32,
  role : String,
  reset : ResetSpec,
  nodes : ArrayView[Node],
) -> Unit raise IrError {
  let signal = toggle_node(primitive, role, reset.signal(), nodes)
  if !(signal.signal_type() is Reset) ||
    reset.mode() != Synchronous ||
    reset.polarity() != ActiveHigh ||
    reset.value() != 0UL {
    raise ToggleHandshakeResetMismatch(
      primitive~,
      role~,
      node=reset.signal().ordinal(),
    )
  }
}

///|
fn require_toggle_domain(
  primitive : Int32,
  role : String,
  requested : ClockDomainId,
  domains : ArrayView[ClockDomain],
) -> Unit raise IrError {
  for domain in domains {
    if domain.id() == requested {
      return
    }
  }
  raise UnknownToggleHandshakeDomain(
    primitive~,
    role~,
    domain=requested.ordinal(),
  )
}

///|
fn toggle_direct_consumer_allowed(
  consumer : NodeId,
  allowed : ArrayView[NodeId],
) -> Bool {
  for item in allowed {
    if item == consumer {
      return true
    }
  }
  false
}

///|
fn validate_toggle_hidden_fanout(
  primitive : Int32,
  role : String,
  requested : NodeId,
  allowed : ArrayView[NodeId],
  nodes : ArrayView[Node],
  memories : ArrayView[MemorySpec],
  outputs : ArrayView[OutputPort],
) -> Unit raise IrError {
  for node in nodes {
    if node_uses(node, requested) &&
      !toggle_direct_consumer_allowed(node.id(), allowed) {
      raise ToggleHandshakeHiddenFanout(
        primitive~,
        role~,
        node=requested.ordinal(),
        consumer="node:\{node.id().ordinal()}",
      )
    }
  }
  for memory in memories {
    match memory_use(memory, requested) {
      Some(consumer) =>
        raise ToggleHandshakeHiddenFanout(
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
      raise ToggleHandshakeHiddenFanout(
        primitive~,
        role~,
        node=requested.ordinal(),
        consumer="output:\{output.name()}",
      )
    }
  }
}

///|
fn validate_toggle_synchronizer(
  primitive : Int32,
  role : String,
  source : NodeId,
  stages : ReadOnlyArray[NodeId],
  domain : ClockDomainId,
  reset : ResetSpec,
  final_consumers : ArrayView[NodeId],
  nodes : ArrayView[Node],
  memories : ArrayView[MemorySpec],
  outputs : ArrayView[OutputPort],
) -> Unit raise IrError {
  let bit_type = Bits(Width::new(1))
  for index, stage in stages {
    let expected_next = if index == 0 { source } else { stages[index - 1] }
    require_toggle_register(
      primitive,
      "\{role}_stage_\{index}",
      stage,
      bit_type,
      domain,
      expected_next,
      None,
      reset,
      nodes,
    )
    let allowed = if index + 1 < stages.length() {
      [stages[index + 1]]
    } else {
      final_consumers.to_owned()
    }
    validate_toggle_hidden_fanout(
      primitive,
      "\{role}_stage_\{index}",
      stage,
      allowed,
      nodes,
      memories,
      outputs,
    )
  }
}

///|
fn validate_toggle_handshake(
  spec : ToggleHandshakePrimitive,
  domains : ArrayView[ClockDomain],
  nodes : ArrayView[Node],
  memories : ArrayView[MemorySpec],
  outputs : ArrayView[OutputPort],
) -> Unit raise IrError {
  let primitive = spec.id().ordinal()
  require_toggle_domain(
    primitive,
    "source_domain",
    spec.source_domain(),
    domains,
  )
  require_toggle_domain(
    primitive,
    "destination_domain",
    spec.destination_domain(),
    domains,
  )
  require_toggle_reset(primitive, "source_reset", spec.source_reset(), nodes)
  require_toggle_reset(
    primitive,
    "destination_reset",
    spec.destination_reset(),
    nodes,
  )
  for
    item in [
      ("source_valid", spec.source_valid()),
      ("source_ready", spec.source_ready()),
      ("source_accept", spec.source_accept()),
      ("request_toggle", spec.request_toggle()),
      ("request_changed", spec.request_changed()),
      ("destination_ready", spec.destination_ready()),
      ("destination_valid", spec.destination_valid()),
      ("destination_available", spec.destination_available()),
      ("destination_capture", spec.destination_capture()),
      ("destination_consume", spec.destination_consume()),
      ("acknowledge_toggle", spec.acknowledge_toggle()),
    ] {
    ignore(require_toggle_bit(primitive, item.0, item.1, nodes))
  }
  let request_output = spec.request_stages()[spec.request_stages().length() - 1]
  let acknowledge_output = spec.acknowledge_stages()[spec
    .acknowledge_stages()
    .length() -
    1]
  require_toggle_binary(
    primitive,
    "source_ready",
    spec.source_ready(),
    spec.request_toggle(),
    acknowledge_output,
    ToggleEqual,
    nodes,
  )
  require_toggle_binary(
    primitive,
    "source_accept",
    spec.source_accept(),
    spec.source_valid(),
    spec.source_ready(),
    ToggleAnd,
    nodes,
  )
  let request_node = toggle_node(
    primitive,
    "request_toggle",
    spec.request_toggle(),
    nodes,
  )
  guard request_node.kind() is Register(request_register) else {
    raise ToggleHandshakeStructureMismatch(primitive~, role="request_toggle")
  }
  let request_next = toggle_node(
    primitive,
    "request_toggle_next",
    request_register.next(),
    nodes,
  )
  guard request_next.kind()
    is Mux(
      select=request_accept,
      when_true=request_inverted,
      when_false=request_held
    ) &&
    request_accept == spec.source_accept() &&
    request_held == spec.request_toggle() else {
    raise ToggleHandshakeStructureMismatch(
      primitive~,
      role="request_toggle_next",
    )
  }
  require_toggle_not(
    primitive,
    "request_inverted",
    request_inverted,
    spec.request_toggle(),
    nodes,
  )
  require_toggle_register(
    primitive,
    "request_toggle",
    spec.request_toggle(),
    Bits(Width::new(1)),
    spec.source_domain(),
    request_register.next(),
    None,
    spec.source_reset(),
    nodes,
  )
  let shape = spec.payload_shape().flatten()
  for index, leaf in shape {
    let source = spec.source_payload()[index]
    let held = spec.held_payload()[index]
    let destination = spec.destination_payload()[index]
    let source_node = toggle_node(
      primitive,
      "source_payload_\{index}",
      source,
      nodes,
    )
    if source_node.signal_type() != leaf.value() {
      raise ToggleHandshakeNodeTypeMismatch(
        primitive~,
        role="source_payload_\{index}",
        node=source.ordinal(),
      )
    }
    require_toggle_register(
      primitive,
      "held_payload_\{index}",
      held,
      leaf.value(),
      spec.source_domain(),
      source,
      Some(spec.source_accept()),
      spec.source_reset(),
      nodes,
    )
    require_toggle_register(
      primitive,
      "destination_payload_\{index}",
      destination,
      leaf.value(),
      spec.destination_domain(),
      held,
      Some(spec.destination_capture()),
      spec.destination_reset(),
      nodes,
    )
    validate_toggle_hidden_fanout(
      primitive,
      "held_payload_\{index}",
      held,
      [destination],
      nodes,
      memories,
      outputs,
    )
  }
  let request_changed_node = toggle_node(
    primitive,
    "request_changed",
    spec.request_changed(),
    nodes,
  )
  guard request_changed_node.kind() is BitNot(request_equal) else {
    raise ToggleHandshakeStructureMismatch(primitive~, role="request_changed")
  }
  require_toggle_binary(
    primitive,
    "request_equal",
    request_equal,
    request_output,
    spec.acknowledge_toggle(),
    ToggleEqual,
    nodes,
  )
  let acknowledge_node = toggle_node(
    primitive,
    "acknowledge_toggle",
    spec.acknowledge_toggle(),
    nodes,
  )
  guard acknowledge_node.kind() is Register(acknowledge_register) else {
    raise ToggleHandshakeStructureMismatch(
      primitive~,
      role="acknowledge_toggle",
    )
  }
  let acknowledge_next = toggle_node(
    primitive,
    "acknowledge_toggle_next",
    acknowledge_register.next(),
    nodes,
  )
  guard acknowledge_next.kind()
    is Mux(
      select=acknowledge_capture,
      when_true=acknowledge_request,
      when_false=acknowledge_held
    ) &&
    acknowledge_capture == spec.destination_capture() &&
    acknowledge_request == request_output &&
    acknowledge_held == spec.acknowledge_toggle() else {
    raise ToggleHandshakeStructureMismatch(
      primitive~,
      role="acknowledge_toggle_next",
    )
  }
  validate_toggle_synchronizer(
    primitive,
    "request",
    spec.request_toggle(),
    spec.request_stages(),
    spec.destination_domain(),
    spec.destination_reset(),
    [request_equal, acknowledge_register.next()],
    nodes,
    memories,
    outputs,
  )
  let available_node = toggle_node(
    primitive,
    "destination_available",
    spec.destination_available(),
    nodes,
  )
  guard available_node.kind() is BitOr(not_valid, ready) &&
    ready == spec.destination_ready() else {
    raise ToggleHandshakeStructureMismatch(
      primitive~,
      role="destination_available",
    )
  }
  require_toggle_not(
    primitive,
    "destination_not_valid",
    not_valid,
    spec.destination_valid(),
    nodes,
  )
  require_toggle_binary(
    primitive,
    "destination_capture",
    spec.destination_capture(),
    spec.request_changed(),
    spec.destination_available(),
    ToggleAnd,
    nodes,
  )
  require_toggle_binary(
    primitive,
    "destination_consume",
    spec.destination_consume(),
    spec.destination_valid(),
    spec.destination_ready(),
    ToggleAnd,
    nodes,
  )
  let valid_node = toggle_node(
    primitive,
    "destination_valid",
    spec.destination_valid(),
    nodes,
  )
  guard valid_node.kind() is Register(valid_register) else {
    raise ToggleHandshakeStructureMismatch(primitive~, role="destination_valid")
  }
  let valid_next = toggle_node(
    primitive,
    "destination_valid_next",
    valid_register.next(),
    nodes,
  )
  guard valid_next.kind() is BitOr(capture, retained) &&
    capture == spec.destination_capture() else {
    raise ToggleHandshakeStructureMismatch(
      primitive~,
      role="destination_valid_next",
    )
  }
  let retained_node = toggle_node(
    primitive, "destination_retained", retained, nodes,
  )
  guard retained_node.kind() is BitAnd(valid, not_consume) &&
    valid == spec.destination_valid() else {
    raise ToggleHandshakeStructureMismatch(
      primitive~,
      role="destination_retained",
    )
  }
  require_toggle_not(
    primitive,
    "destination_not_consume",
    not_consume,
    spec.destination_consume(),
    nodes,
  )
  require_toggle_register(
    primitive,
    "destination_valid",
    spec.destination_valid(),
    Bits(Width::new(1)),
    spec.destination_domain(),
    valid_register.next(),
    None,
    spec.destination_reset(),
    nodes,
  )
  require_toggle_register(
    primitive,
    "acknowledge_toggle",
    spec.acknowledge_toggle(),
    Bits(Width::new(1)),
    spec.destination_domain(),
    acknowledge_register.next(),
    None,
    spec.destination_reset(),
    nodes,
  )
  validate_toggle_synchronizer(
    primitive,
    "acknowledge",
    spec.acknowledge_toggle(),
    spec.acknowledge_stages(),
    spec.source_domain(),
    spec.source_reset(),
    [spec.source_ready()],
    nodes,
    memories,
    outputs,
  )
  let private_fanouts : Array[(String, NodeId, Array[NodeId])] = [
    (
      "request_toggle",
      spec.request_toggle(),
      [
        request_inverted,
        request_register.next(),
        spec.request_stages()[0],
        spec.source_ready(),
      ],
    ),
    ("request_inverted", request_inverted, [request_register.next()]),
    ("request_toggle_next", request_register.next(), [spec.request_toggle()]),
    (
      "source_accept",
      spec.source_accept(),
      [request_register.next(), ..spec.held_payload().iter().to_array()],
    ),
    ("request_equal", request_equal, [spec.request_changed()]),
    ("request_changed", spec.request_changed(), [spec.destination_capture()]),
    (
      "destination_available",
      spec.destination_available(),
      [spec.destination_capture()],
    ),
    (
      "destination_capture",
      spec.destination_capture(),
      [
        valid_register.next(),
        acknowledge_register.next(),
        ..spec.destination_payload().iter().to_array(),
      ],
    ),
    ("destination_consume", spec.destination_consume(), [not_consume]),
    ("destination_not_valid", not_valid, [spec.destination_available()]),
    ("destination_not_consume", not_consume, [retained]),
    ("destination_retained", retained, [valid_register.next()]),
    (
      "destination_valid_next",
      valid_register.next(),
      [spec.destination_valid()],
    ),
    (
      "acknowledge_toggle",
      spec.acknowledge_toggle(),
      [request_equal, acknowledge_register.next(), spec.acknowledge_stages()[0]],
    ),
    (
      "acknowledge_toggle_next",
      acknowledge_register.next(),
      [spec.acknowledge_toggle()],
    ),
  ]
  for item in private_fanouts {
    validate_toggle_hidden_fanout(
      primitive,
      item.0,
      item.1,
      item.2,
      nodes,
      memories,
      outputs,
    )
  }
}
