///|
// Derive the original eleven registers through public bus identities and
// their original selector/hold equations. No q1 fixture ordinals transplanted
// into this independently pinned q3/2x2 device, and no arbiter input cuts.
fn store_storage_projection_arbiter(
  probe : StorePreservationProbe,
) -> Array[DependencyComputeRoot] raise {
  let source = probe.source
  let halted = two_client_arbiter_output(
    source,
    "transport_halted",
    @wire.bits(1),
  )
  let (_, inactive) = dependency_generation_decoder_and(source, halted)
  guard dependency_generation_node(source, inactive).kind()
    is BitNot(normalized) &&
    dependency_generation_node(source, normalized).kind() ==
    Reinterpret(probe.reset) else {
    raise InvalidFormalBundleIdentity(
      "Store projection: arbiter reset normalization",
    )
  }
  let roots : Array[DependencyComputeRoot] = []
  fn root(
    name : String,
    id : @ir.NodeId,
    signal_type : @ir.SignalType,
  ) -> DependencyComputeRoot raise {
    let root = queue_control_root(
      source,
      { name, node: id, signal_type, },
      probe.clock,
      probe.reset,
    )
    if roots.any(previous => previous.node == id) || root.spec.enable() != None {
      raise InvalidFormalBundleIdentity(
        "Store projection: arbiter root alias/enable",
      )
    }
    roots.push(root)
    root
  }
  let offer = two_client_arbiter_output(
    source,
    "memory_request_valid",
    @wire.bits(1),
  )
  let state_node = two_client_arbiter_state_gate(source, offer, inactive, 1UL)
  if two_client_arbiter_state_gate(source, halted, inactive, 3UL) != state_node {
    raise InvalidFormalBundleIdentity(
      "Store projection: same arbiter Offer/poison state",
    )
  }
  let state = root("state", state_node, @wire.uint(2))
  let ready = two_client_arbiter_output(
    source,
    "memory_response_ready",
    @wire.bits(1),
  )
  let (wait, selected_ready) = dependency_generation_decoder_and(source, ready)
  if two_client_arbiter_state_gate(source, wait, inactive, 2UL) != state.node {
    raise InvalidFormalBundleIdentity("Store projection: arbiter Wait state")
  }
  let (owner_node, _, _) = dependency_generation_decoder_mux(
    source, selected_ready,
  )
  let owner = root("owner", owner_node, @wire.bits(1))
  let (grant, selector, owner_hold) = dependency_generation_decoder_mux(
    source,
    owner.spec.next(),
  )
  if owner_hold != owner.node {
    raise InvalidFormalBundleIdentity("Store projection: arbiter owner hold")
  }
  let (idle, _) = dependency_generation_decoder_and(source, grant)
  if two_client_arbiter_state_gate(source, idle, inactive, 0UL) != state.node {
    raise InvalidFormalBundleIdentity(
      "Store projection: arbiter grant Idle state",
    )
  }
  guard dependency_generation_node(source, selector).kind()
    is BitAnd(_, preference_mask) &&
    dependency_generation_node(source, preference_mask).kind()
    is BitOr(_, preference_node) else {
    raise InvalidFormalBundleIdentity(
      "Store projection: arbiter preference equation",
    )
  }
  let preference = root("preference", preference_node, @wire.bits(1))
  let (request_accept, preference_value, preference_hold) = dependency_generation_decoder_mux(
    source,
    preference.spec.next(),
  )
  if preference_hold != preference.node ||
    dependency_generation_node(source, preference_value).kind() !=
    BitNot(owner.node) {
    raise InvalidFormalBundleIdentity(
      "Store projection: arbiter preference update",
    )
  }
  let request_ready = dependency_generation_input(
    source,
    "memory_request_ready",
    @wire.bits(1),
  )
  if dependency_generation_node(source, request_accept).kind() !=
    BitAnd(offer, request_ready) {
    raise InvalidFormalBundleIdentity(
      "Store projection: public arbiter request acceptance",
    )
  }
  let next_tag = root(
    "next_tag",
    two_client_arbiter_output(source, "memory_request_tag", @wire.uint(32)),
    @wire.uint(32),
  )
  ignore(two_client_arbiter_hold(source, next_tag, request_accept))
  let (response_accept, response_state, _) = dependency_generation_decoder_mux(
    source,
    state.spec.next(),
  )
  let response_valid = dependency_generation_input(
    source,
    "memory_response_valid",
    @wire.bits(1),
  )
  if dependency_generation_node(source, response_accept).kind() !=
    BitAnd(ready, response_valid) {
    raise InvalidFormalBundleIdentity(
      "Store projection: public arbiter response acceptance",
    )
  }
  let (malformed, _, _) = dependency_generation_decoder_mux(
    source, response_state,
  )
  let expected_tag = root(
    "expected_tag",
    two_client_arbiter_malformed(
      source,
      malformed,
      dependency_generation_input(source, "memory_response_tag", @wire.uint(32)),
      dependency_generation_input(
        source,
        "memory_response_fault",
        @wire.uint(2),
      ),
    ),
    @wire.uint(32),
  )
  if two_client_arbiter_hold(source, expected_tag, request_accept) !=
    next_tag.node {
    raise InvalidFormalBundleIdentity(
      "Store projection: arbiter expected tag latch",
    )
  }
  for
    (name, signal_type) in [
      ("write", @wire.bits(1)),
      ("address", @wire.uint(32)),
      ("bytes", @wire.uint(3)),
      ("mask", @wire.bits(4)),
      ("data", @wire.bits(32)),
    ] {
    let saved = root(
      name,
      two_client_arbiter_output(source, "memory_request_" + name, signal_type),
      signal_type,
    )
    let value = two_client_arbiter_hold(source, saved, grant)
    let (choice, _, _) = dependency_generation_decoder_mux(source, value)
    if choice != selector {
      raise InvalidFormalBundleIdentity(
        "Store projection: shared arbiter payload selector",
      )
    }
  }
  let matches = source
    .nodes()
    .filter(node => {
      guard node.signal_type() == @wire.uint(32) &&
        node.kind() is Register(spec) &&
        !roots.any(root => root.node == node.id()) &&
        dependency_generation_node(source, spec.next()).kind()
        is Mux(select~, when_true~, when_false~) &&
        select == grant &&
        when_false == node.id() &&
        dependency_generation_node(source, when_true).kind()
        is Mux(select=choice, ..) else {
        return false
      }
      choice == selector
    })
  guard matches is [saved_local] else {
    raise InvalidFormalBundleIdentity(
      "Store projection: unique arbiter restored local tag",
    )
  }
  ignore(root("local_tag", saved_local.id(), @wire.uint(32)))
  if roots.length() != 11 ||
    roots
    .iter()
    .fold(init=0, (bits, root) => bits + root.signal_type.width().bits()) !=
    172 {
    raise InvalidFormalBundleIdentity(
      "Store projection: complete original arbiter inventory",
    )
  }
  roots
}
