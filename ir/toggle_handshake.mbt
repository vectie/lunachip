///|
/// A checked declaration for one one-item toggle handshake.
///
/// The record binds every externally visible endpoint and every structural
/// node that receives a CDC exemption. The enclosing module separately proves
/// the exact source/destination state machine, synchronizer chains, reset
/// contract, payload ownership, and hidden-fanout rules.
pub struct ToggleHandshakePrimitive {
  id : CdcPrimitiveId
  name : String
  source_domain : ClockDomainId
  destination_domain : ClockDomainId
  source_reset : ResetSpec
  destination_reset : ResetSpec
  payload_shape : @aggregate.Aggregate[SignalType]
  source_valid : NodeId
  source_ready : NodeId
  source_accept : NodeId
  source_payload : ReadOnlyArray[NodeId]
  held_payload : ReadOnlyArray[NodeId]
  request_toggle : NodeId
  request_stages : ReadOnlyArray[NodeId]
  request_changed : NodeId
  destination_ready : NodeId
  destination_valid : NodeId
  destination_capture : NodeId
  destination_consume : NodeId
  destination_available : NodeId
  destination_payload : ReadOnlyArray[NodeId]
  acknowledge_toggle : NodeId
  acknowledge_stages : ReadOnlyArray[NodeId]
} derive(Debug, Eq)

///|
fn add_unique_toggle_node(
  primitive : Int32,
  seen : Map[Int32, Unit],
  node : NodeId,
) -> Unit raise IrError {
  let ordinal = node.ordinal()
  if seen.contains(ordinal) {
    raise ToggleHandshakeDuplicateNode(primitive~, node=ordinal)
  }
  seen[ordinal] = ()
}

///|
pub fn ToggleHandshakePrimitive::checked(
  id : CdcPrimitiveId,
  name : String,
  source_domain : ClockDomainId,
  destination_domain : ClockDomainId,
  source_reset : ResetSpec,
  destination_reset : ResetSpec,
  payload_shape : @aggregate.Aggregate[SignalType],
  source_valid : NodeId,
  source_ready : NodeId,
  source_accept : NodeId,
  source_payload : ArrayView[NodeId],
  held_payload : ArrayView[NodeId],
  request_toggle : NodeId,
  request_stages : ArrayView[NodeId],
  request_changed : NodeId,
  destination_ready : NodeId,
  destination_valid : NodeId,
  destination_capture : NodeId,
  destination_consume : NodeId,
  destination_available : NodeId,
  destination_payload : ArrayView[NodeId],
  acknowledge_toggle : NodeId,
  acknowledge_stages : ArrayView[NodeId],
) -> ToggleHandshakePrimitive raise IrError {
  require_name(name, "CDC primitive")
  let primitive = id.ordinal()
  if source_domain == destination_domain {
    raise EqualToggleHandshakeDomains(
      primitive~,
      domain=source_domain.ordinal(),
    )
  }
  let request_count = request_stages.length()
  let acknowledge_count = acknowledge_stages.length()
  if request_count < 2 || request_count > 4 {
    raise InvalidToggleHandshakeStageCount(primitive~, actual=request_count)
  }
  if acknowledge_count != request_count {
    raise InvalidToggleHandshakeStageCount(primitive~, actual=acknowledge_count)
  }
  let shape_leaves = payload_shape.flatten()
  let expected = shape_leaves.length()
  if expected > 65536 {
    raise AggregateLeafLimitExceeded(
      binding=primitive,
      maximum=65536,
      minimum=expected,
    )
  }
  for leaf in shape_leaves {
    if !leaf.value().is_data() {
      raise ToggleHandshakeNodeTypeMismatch(
        primitive~,
        role="payload_shape",
        node=leaf.ordinal(),
      )
    }
  }
  if source_payload.length() != expected ||
    held_payload.length() != expected ||
    destination_payload.length() != expected {
    raise ToggleHandshakePayloadCountMismatch(
      primitive~,
      expected~,
      source=source_payload.length(),
      held=held_payload.length(),
      destination=destination_payload.length(),
    )
  }
  let seen : Map[Int32, Unit] = Map([])
  for
    node in [
      source_ready, source_accept, request_toggle, request_changed, destination_valid,
      destination_capture, destination_consume, destination_available, acknowledge_toggle,
    ] {
    add_unique_toggle_node(primitive, seen, node)
  }
  for
    nodes in [
      held_payload.to_owned(),
      request_stages.to_owned(),
      destination_payload.to_owned(),
      acknowledge_stages.to_owned(),
    ] {
    for node in nodes {
      add_unique_toggle_node(primitive, seen, node)
    }
  }
  {
    id,
    name,
    source_domain,
    destination_domain,
    source_reset,
    destination_reset,
    payload_shape,
    source_valid,
    source_ready,
    source_accept,
    source_payload: ReadOnlyArray::from_array(source_payload.to_owned()),
    held_payload: ReadOnlyArray::from_array(held_payload.to_owned()),
    request_toggle,
    request_stages: ReadOnlyArray::from_array(request_stages.to_owned()),
    request_changed,
    destination_ready,
    destination_valid,
    destination_capture,
    destination_consume,
    destination_available,
    destination_payload: ReadOnlyArray::from_array(
      destination_payload.to_owned(),
    ),
    acknowledge_toggle,
    acknowledge_stages: ReadOnlyArray::from_array(acknowledge_stages.to_owned()),
  }
}

///|
pub fn ToggleHandshakePrimitive::id(
  self : ToggleHandshakePrimitive,
) -> CdcPrimitiveId {
  self.id
}

///|
pub fn ToggleHandshakePrimitive::name(
  self : ToggleHandshakePrimitive,
) -> String {
  self.name
}

///|
pub fn ToggleHandshakePrimitive::source_domain(
  self : ToggleHandshakePrimitive,
) -> ClockDomainId {
  self.source_domain
}

///|
pub fn ToggleHandshakePrimitive::destination_domain(
  self : ToggleHandshakePrimitive,
) -> ClockDomainId {
  self.destination_domain
}

///|
pub fn ToggleHandshakePrimitive::source_reset(
  self : ToggleHandshakePrimitive,
) -> ResetSpec {
  self.source_reset
}

///|
pub fn ToggleHandshakePrimitive::destination_reset(
  self : ToggleHandshakePrimitive,
) -> ResetSpec {
  self.destination_reset
}

///|
pub fn ToggleHandshakePrimitive::payload_shape(
  self : ToggleHandshakePrimitive,
) -> @aggregate.Aggregate[SignalType] {
  self.payload_shape
}

///|
pub fn ToggleHandshakePrimitive::source_valid(
  self : ToggleHandshakePrimitive,
) -> NodeId {
  self.source_valid
}

///|
pub fn ToggleHandshakePrimitive::source_ready(
  self : ToggleHandshakePrimitive,
) -> NodeId {
  self.source_ready
}

///|
pub fn ToggleHandshakePrimitive::source_accept(
  self : ToggleHandshakePrimitive,
) -> NodeId {
  self.source_accept
}

///|
pub fn ToggleHandshakePrimitive::source_payload(
  self : ToggleHandshakePrimitive,
) -> ReadOnlyArray[NodeId] {
  self.source_payload
}

///|
pub fn ToggleHandshakePrimitive::held_payload(
  self : ToggleHandshakePrimitive,
) -> ReadOnlyArray[NodeId] {
  self.held_payload
}

///|
pub fn ToggleHandshakePrimitive::request_toggle(
  self : ToggleHandshakePrimitive,
) -> NodeId {
  self.request_toggle
}

///|
pub fn ToggleHandshakePrimitive::request_stages(
  self : ToggleHandshakePrimitive,
) -> ReadOnlyArray[NodeId] {
  self.request_stages
}

///|
pub fn ToggleHandshakePrimitive::request_changed(
  self : ToggleHandshakePrimitive,
) -> NodeId {
  self.request_changed
}

///|
pub fn ToggleHandshakePrimitive::destination_ready(
  self : ToggleHandshakePrimitive,
) -> NodeId {
  self.destination_ready
}

///|
pub fn ToggleHandshakePrimitive::destination_valid(
  self : ToggleHandshakePrimitive,
) -> NodeId {
  self.destination_valid
}

///|
pub fn ToggleHandshakePrimitive::destination_capture(
  self : ToggleHandshakePrimitive,
) -> NodeId {
  self.destination_capture
}

///|
pub fn ToggleHandshakePrimitive::destination_consume(
  self : ToggleHandshakePrimitive,
) -> NodeId {
  self.destination_consume
}

///|
pub fn ToggleHandshakePrimitive::destination_available(
  self : ToggleHandshakePrimitive,
) -> NodeId {
  self.destination_available
}

///|
pub fn ToggleHandshakePrimitive::destination_payload(
  self : ToggleHandshakePrimitive,
) -> ReadOnlyArray[NodeId] {
  self.destination_payload
}

///|
pub fn ToggleHandshakePrimitive::acknowledge_toggle(
  self : ToggleHandshakePrimitive,
) -> NodeId {
  self.acknowledge_toggle
}

///|
pub fn ToggleHandshakePrimitive::acknowledge_stages(
  self : ToggleHandshakePrimitive,
) -> ReadOnlyArray[NodeId] {
  self.acknowledge_stages
}

///|
fn ToggleHandshakePrimitive::implementation_nodes(
  self : ToggleHandshakePrimitive,
) -> Array[NodeId] {
  let nodes = [
    self.source_ready,
    self.source_accept,
    self.request_toggle,
    self.request_changed,
    self.destination_valid,
    self.destination_capture,
    self.destination_consume,
    self.destination_available,
    self.acknowledge_toggle,
  ]
  for
    group in [
      self.held_payload,
      self.request_stages,
      self.destination_payload,
      self.acknowledge_stages,
    ] {
    for node in group {
      nodes.push(node)
    }
  }
  nodes
}

///|
pub extend ToggleHandshakePrimitive with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend ToggleHandshakePrimitive with Eq::{not_equal, equal}
