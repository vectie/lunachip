///|
fn two_client_arbiter_output(
  hardware : @ir.Module,
  name : String,
  signal_type : @ir.SignalType,
) -> @ir.NodeId raise FormalGateError {
  guard hardware.outputs().filter(output => output.name() == name) is [output] &&
    output.signal_type() == signal_type &&
    dependency_generation_node(hardware, output.driver()).signal_type() ==
    signal_type else {
    raise InvalidFormalBundleIdentity("arbiter probe: output " + name)
  }
  output.driver()
}

///|
fn two_client_arbiter_state_gate(
  hardware : @ir.Module,
  gate : @ir.NodeId,
  inactive : @ir.NodeId,
  value : UInt64,
) -> @ir.NodeId raise {
  let (comparison, reset_mask) = dependency_generation_decoder_and(
    hardware, gate,
  )
  if reset_mask != inactive {
    raise InvalidFormalBundleIdentity("arbiter probe: state reset mask")
  }
  dependency_generation_decoder_equal_constant(hardware, comparison, 2, value)
}

///|
fn two_client_arbiter_hold(
  hardware : @ir.Module,
  root : DependencyComputeRoot,
  event : @ir.NodeId,
) -> @ir.NodeId raise FormalGateError {
  let (update, value, hold) = dependency_generation_decoder_mux(
    hardware,
    root.spec.next(),
  )
  if update != event || hold != root.node || root.spec.enable() != None {
    raise InvalidFormalBundleIdentity("arbiter probe: exact latch " + root.name)
  }
  value
}

///|
fn two_client_arbiter_malformed(
  hardware : @ir.Module,
  event : @ir.NodeId,
  response_tag : @ir.NodeId,
  response_fault : @ir.NodeId,
) -> @ir.NodeId raise {
  guard dependency_generation_node(hardware, event).kind()
    is BitOr(tag_bad, fault_bad) &&
    dependency_generation_node(hardware, tag_bad).kind() is BitNot(equal) &&
    dependency_generation_node(hardware, equal).kind() is Equal(tag, expected) &&
    tag == response_tag &&
    dependency_generation_node(hardware, fault_bad).kind()
    is LessEqual(reserved, fault) &&
    fault == response_fault else {
    raise InvalidFormalBundleIdentity(
      "arbiter probe: original malformed equation",
    )
  }
  dependency_generation_decoder_constant(hardware, reserved, @wire.uint(2), 2UL)
  expected
}

///|
// Resolve the original routed ready/valid, tolerating independently built
// but equal state/complement constants without merging their actual nodes.
fn two_client_arbiter_route(
  hardware : @ir.Module,
  state : @ir.NodeId,
  inactive : @ir.NodeId,
  owner : @ir.NodeId,
  engine : Bool,
  peer : @ir.NodeId,
  state_value : UInt64,
  role : String,
) -> (@ir.NodeId, @ir.NodeId) raise FormalGateError {
  let matches = hardware
    .nodes()
    .filter(node => {
      guard node.signal_type().width().bits() == 1 &&
        node.kind() is BitAnd(mask, input) &&
        input == peer &&
        dependency_generation_node(hardware, mask).kind()
        is BitAnd(gate, selected) &&
        dependency_generation_node(hardware, gate).kind()
        is BitAnd(comparison, reset_mask) &&
        reset_mask == inactive &&
        dependency_generation_node(hardware, comparison).kind()
        is Equal(actual, constant) &&
        actual == state &&
        dependency_generation_node(hardware, constant).kind() ==
        Constant(state_value) else {
        return false
      }
      if engine {
        selected == owner
      } else {
        dependency_generation_node(hardware, selected).kind() == BitNot(owner)
      }
    })
  guard matches is [node] &&
    node.kind() is BitAnd(mask, _) &&
    dependency_generation_node(hardware, mask).kind() is BitAnd(gate, _) else {
    raise InvalidFormalBundleIdentity(
      "arbiter probe: ambiguous equation " + role,
    )
  }
  (node.id(), gate)
}

///|
fn two_client_arbiter_boundary(
  hardware : @ir.Module,
  candidates : Array[TwoClientArbiterCandidate],
  node : @ir.NodeId,
  signal_type : @ir.SignalType,
  role : String,
) -> Unit raise FormalGateError {
  let original = dependency_generation_node(hardware, node)
  if original.signal_type() != signal_type ||
    (
      !signal_type.is_data() &&
      !(signal_type is Reset && original.kind() is Input("reset"))
    ) ||
    original.kind() is AsyncFifoRead(..) {
    raise InvalidFormalBundleIdentity(
      "arbiter probe: raw interface type/kind " + role,
    )
  }
  for index, candidate in candidates {
    if candidate.roles.contains(role) {
      raise InvalidFormalBundleIdentity(
        "arbiter probe: repeated interface role",
      )
    }
    if candidate.original.id() == node {
      let roles = candidate.roles.iter().to_array()
      roles.push(role)
      candidates[index] = { original, roles: ReadOnlyArray::from_array(roles), }
      return
    }
  }
  candidates.push({ original, roles: [role], })
}

///|
// All cuts here are an inspection boundary, not accepted proof permission.
// Closure rejects every other input/register/memory leaf and retains all
// selection/grant/accept/malformed/route/poison operations unchanged.
fn two_client_arbiter_probe_closure(
  hardware : @ir.Module,
  roots : ArrayView[DependencyComputeRoot],
  candidates : ArrayView[TwoClientArbiterCandidate],
  events : ArrayView[QueueControlAlias],
) -> Array[@ir.Node] raise FormalGateError {
  if roots.length() != 11 ||
    roots
    .iter()
    .fold(init=0, (bits, root) => bits + root.signal_type.width().bits()) !=
    172 {
    raise InvalidFormalBundleIdentity("arbiter probe: essential inventory")
  }
  let boundaries : Array[DependencyGenerationCut] = []
  let seeds : Array[@ir.NodeId] = []
  for root in roots {
    if boundaries.any(previous => previous.node == root.node) {
      raise InvalidFormalBundleIdentity(
        "arbiter probe: repeated essential root",
      )
    }
    boundaries.push({
      node: root.node,
      signal_type: root.signal_type,
      roles: [root.name],
    })
    seeds.push(root.spec.next())
    if root.spec.reset() is Some(control) {
      seeds.push(control.signal())
    }
    if root.spec.enable() is Some(enable) {
      seeds.push(enable)
    }
  }
  for candidate in candidates {
    if boundaries.any(previous => previous.node == candidate.original.id()) ||
      events.any(event => event.node == candidate.original.id()) {
      raise InvalidFormalBundleIdentity(
        "arbiter probe: root/event interface overlap",
      )
    }
    // Raw constants are inspected interfaces, but retain their ORIGINAL
    // equations; do not manufacture additional symbolic client freedoms.
    if !(candidate.original.kind() is Constant(_)) {
      boundaries.push({
        node: candidate.original.id(),
        signal_type: candidate.original.signal_type(),
        roles: candidate.roles,
      })
    }
    seeds.push(candidate.original.id())
  }
  for event in events {
    seeds.push(event.node)
  }
  let cone = dependency_generation_closure(hardware, boundaries, seeds)
  for event in events {
    if !cone.any(node => node.id() == event.node) {
      raise InvalidFormalBundleIdentity("arbiter probe: missing derived event")
    }
  }
  cone
}
