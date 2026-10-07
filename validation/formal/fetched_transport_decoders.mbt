///|
fn fetched_transport_unique(
  source : @ir.Module,
  name : String,
  predicate : (@ir.Node) -> Bool raise,
) -> @ir.NodeId raise {
  guard source.nodes().filter(predicate) is [node] else {
    raise InvalidFormalBundleIdentity("fetched discovery: ambiguous " + name)
  }
  node.id()
}

///|
fn fetched_transport_root(
  source : @ir.Module,
  roots : Array[DependencyComputeRoot],
  clock : @ir.NodeId,
  reset : @ir.NodeId,
  name : String,
  id : @ir.NodeId,
  signal_type : @ir.SignalType,
) -> DependencyComputeRoot raise FormalGateError {
  let root = queue_control_root(
    source,
    { name, node: id, signal_type, },
    clock,
    reset,
  )
  if root.spec.enable() != None ||
    roots.any(old => old.node == id || old.name == name) {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: root alias/enable " + name,
    )
  }
  roots.push(root)
  root
}

///|
fn fetched_transport_event(
  source : @ir.Module,
  events : Array[QueueControlAlias],
  name : String,
  id : @ir.NodeId,
) -> Unit raise FormalGateError {
  if events.any(old => old.name == name) {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: repeated event " + name,
    )
  }
  let node = dependency_generation_node(source, id)
  if !node.signal_type().is_data() {
    raise InvalidFormalBundleIdentity("fetched discovery: event type " + name)
  }
  events.push({ name, node: id, signal_type: node.signal_type(), })
}

///|
fn fetched_transport_constant(
  source : @ir.Module,
  id : @ir.NodeId,
  width : Int,
  value : UInt64,
) -> Bool {
  source.nodes().get(id.ordinal()) is Some(node) &&
  node.id() == id &&
  node.signal_type().width().bits() == width &&
  node.kind() == Constant(value)
}

///|
// Recover all three original fields from the actual owner-selected payload
// mux, preserving each original constant and duplicate constant node.
fn fetched_transport_fields(
  source : @ir.Module,
  selected : @ir.NodeId,
  choice : @ir.NodeId,
) -> Array[@ir.NodeId] raise FormalGateError {
  let (is_zero, reader, rest) = dependency_generation_decoder_mux(
    source, selected,
  )
  let (is_one, loader, storer) = dependency_generation_decoder_mux(source, rest)
  guard dependency_generation_node(source, is_zero).kind()
    is Equal(owner0, zero) &&
    dependency_generation_node(source, is_one).kind() is Equal(owner1, one) &&
    owner0 == choice &&
    owner1 == choice &&
    fetched_transport_constant(source, zero, 2, 0UL) &&
    fetched_transport_constant(source, one, 2, 1UL) else {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: actual three-way fields",
    )
  }
  [reader, loader, storer]
}

///|
fn fetched_transport_selected_peer(
  source : @ir.Module,
  term : @ir.NodeId,
  owner : @ir.NodeId,
  index : Int,
) -> @ir.NodeId raise {
  guard dependency_generation_node(source, term).kind()
    is BitAnd(selected, peer) &&
    dependency_generation_node(source, selected).kind()
    is Equal(actual, constant) &&
    actual == owner &&
    fetched_transport_constant(source, constant, 2, index.to_uint64()) else {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: owner-selected readiness",
    )
  }
  peer
}

///|
fn fetched_transport_route(
  source : @ir.Module,
  state : @ir.NodeId,
  inactive : @ir.NodeId,
  owner : @ir.NodeId,
  index : Int,
  peer : @ir.NodeId,
  state_value : UInt64,
) -> @ir.NodeId raise {
  fetched_transport_unique(source, "actual client route", node => {
    guard node.kind() is BitAnd(mask, raw) &&
      raw == peer &&
      dependency_generation_node(source, mask).kind() is BitAnd(gate, selected) &&
      dependency_generation_node(source, gate).kind()
      is BitAnd(comparison, reset_mask) &&
      reset_mask == inactive &&
      dependency_generation_node(source, comparison).kind()
      is Equal(actual_state, value) &&
      actual_state == state &&
      fetched_transport_constant(source, value, 2, state_value) &&
      dependency_generation_node(source, selected).kind()
      is Equal(actual_owner, selected_value) &&
      actual_owner == owner &&
      fetched_transport_constant(source, selected_value, 2, index.to_uint64()) else {
      return false
    }
    true
  })
}

///|
fn fetched_transport_find_latch(
  source : @ir.Module,
  event : @ir.NodeId,
  value : @ir.NodeId,
  width : Int,
  name : String,
) -> @ir.NodeId raise {
  fetched_transport_unique(source, name, node => {
    guard node.signal_type().width().bits() == width &&
      node.kind() is Register(spec) &&
      dependency_generation_node(source, spec.next()).kind()
      is Mux(select~, when_true~, when_false~) else {
      return false
    }
    select == event && when_true == value && when_false == node.id()
  })
}
