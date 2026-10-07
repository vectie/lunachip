///|
// Structural recovery from the fresh fetched public drivers. The reader side
// is returned for closure expansion, never declared an arbitrary client.
fn fetched_transport_arbiter(
  source : @ir.Module,
  clock : @ir.NodeId,
  reset : @ir.NodeId,
) -> FetchedTransportArbiter raise {
  let roots : Array[DependencyComputeRoot] = []
  let events : Array[QueueControlAlias] = []
  let boundaries : Array[TwoClientArbiterCandidate] = []
  let halted = two_client_arbiter_output(
    source,
    "transport_halted",
    @wire.bits(1),
  )
  let (_, inactive) = dependency_generation_decoder_and(source, halted)
  guard dependency_generation_node(source, inactive).kind() is BitNot(asserted) &&
    dependency_generation_node(source, asserted).kind() == Reinterpret(reset) else {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: original reset normalization",
    )
  }
  let offer = two_client_arbiter_output(
    source,
    "memory_request_valid",
    @wire.bits(1),
  )
  let state = fetched_transport_root(
    source,
    roots,
    clock,
    reset,
    "arbiter_state",
    two_client_arbiter_state_gate(source, offer, inactive, 1UL),
    @wire.uint(2),
  )
  if two_client_arbiter_state_gate(source, halted, inactive, 3UL) != state.node {
    raise InvalidFormalBundleIdentity("fetched discovery: same poison FSM")
  }
  let bus_ready = dependency_generation_input(
    source,
    "memory_request_ready",
    @wire.bits(1),
  )
  let response_valid = dependency_generation_input(
    source,
    "memory_response_valid",
    @wire.bits(1),
  )
  let response_tag = dependency_generation_input(
    source,
    "memory_response_tag",
    @wire.uint(32),
  )
  let response_fault = dependency_generation_input(
    source,
    "memory_response_fault",
    @wire.uint(2),
  )
  let response_data = dependency_generation_input(
    source,
    "memory_response_data",
    @wire.bits(32),
  )
  let response_ready = two_client_arbiter_output(
    source,
    "memory_response_ready",
    @wire.bits(1),
  )
  let (wait, selected_ready) = dependency_generation_decoder_and(
    source, response_ready,
  )
  if two_client_arbiter_state_gate(source, wait, inactive, 2UL) != state.node {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: actual Wait response mask",
    )
  }
  guard dependency_generation_node(source, selected_ready).kind()
    is BitOr(first, tail) &&
    dependency_generation_node(source, tail).kind() is BitOr(second, third) &&
    dependency_generation_node(source, first).kind() is BitAnd(selected0, _) &&
    dependency_generation_node(source, selected0).kind()
    is Equal(owner_node, zero) &&
    fetched_transport_constant(source, zero, 2, 0UL) else {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: three owner readiness terms",
    )
  }
  let owner = fetched_transport_root(
    source,
    roots,
    clock,
    reset,
    "arbiter_owner",
    owner_node,
    @wire.uint(2),
  )
  let readies = [
    fetched_transport_selected_peer(source, first, owner.node, 0),
    fetched_transport_selected_peer(source, second, owner.node, 1),
    fetched_transport_selected_peer(source, third, owner.node, 2),
  ]
  let (grant, choice, owner_hold) = dependency_generation_decoder_mux(
    source,
    owner.spec.next(),
  )
  if owner_hold != owner.node {
    raise InvalidFormalBundleIdentity("fetched discovery: owner grant hold")
  }
  let (idle, any_request) = dependency_generation_decoder_and(source, grant)
  if two_client_arbiter_state_gate(source, idle, inactive, 0UL) != state.node {
    raise InvalidFormalBundleIdentity("fetched discovery: actual Idle grant")
  }
  guard dependency_generation_node(source, any_request).kind()
    is BitOr(reader_valid, peers) &&
    dependency_generation_node(source, peers).kind()
    is BitOr(loader_valid, storer_valid) else {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: three original requesters",
    )
  }
  let valids = [reader_valid, loader_valid, storer_valid]
  let (response_accept, response_state, pending) = dependency_generation_decoder_mux(
    source,
    state.spec.next(),
  )
  if dependency_generation_node(source, response_accept).kind() !=
    BitAnd(response_ready, response_valid) {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: original response handshake",
    )
  }
  let (malformed, poison_value, zero_value) = dependency_generation_decoder_mux(
    source, response_state,
  )
  let (request_accept, wait_value, pending_grant) = dependency_generation_decoder_mux(
    source, pending,
  )
  let (state_grant, offer_value, state_hold) = dependency_generation_decoder_mux(
    source, pending_grant,
  )
  if state_grant != grant ||
    state_hold != state.node ||
    dependency_generation_node(source, request_accept).kind() !=
    BitAnd(offer, bus_ready) ||
    !fetched_transport_constant(source, poison_value, 2, 3UL) ||
    !fetched_transport_constant(source, zero_value, 2, 0UL) ||
    !fetched_transport_constant(source, wait_value, 2, 2UL) ||
    !fetched_transport_constant(source, offer_value, 2, 1UL) {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: exact state transition priorities",
    )
  }
  let next_tag = fetched_transport_root(
    source,
    roots,
    clock,
    reset,
    "arbiter_next_tag",
    two_client_arbiter_output(source, "memory_request_tag", @wire.uint(32)),
    @wire.uint(32),
  )
  let expected_tag = fetched_transport_root(
    source,
    roots,
    clock,
    reset,
    "arbiter_expected_tag",
    two_client_arbiter_malformed(
      source, malformed, response_tag, response_fault,
    ),
    @wire.uint(32),
  )
  if two_client_arbiter_hold(source, expected_tag, request_accept) !=
    next_tag.node {
    raise InvalidFormalBundleIdentity("fetched discovery: accepted global tag")
  }
  let incremented = two_client_arbiter_hold(source, next_tag, request_accept)
  guard dependency_generation_node(source, incremented).kind()
    is Add(raw_tag, one) &&
    raw_tag == next_tag.node &&
    fetched_transport_constant(source, one, 32, 1UL) else {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: modular global tag counter",
    )
  }
  let preference_node = fetched_transport_unique(source, "cyclic preference", node => {
    guard node.signal_type() == @wire.uint(2) &&
      node.kind() is Register(spec) &&
      dependency_generation_node(source, spec.next()).kind()
      is Mux(select~, when_true~, when_false~) &&
      select == request_accept &&
      when_false == node.id() &&
      dependency_generation_node(source, when_true).kind()
      is Mux(select=wrap, when_true=wrapped, when_false=advanced) &&
      dependency_generation_node(source, wrap).kind()
      is Equal(actual_owner, two) &&
      actual_owner == owner.node &&
      fetched_transport_constant(source, two, 2, 2UL) &&
      fetched_transport_constant(source, wrapped, 2, 0UL) &&
      dependency_generation_node(source, advanced).kind() is Add(actual, one) &&
      actual == owner.node &&
      fetched_transport_constant(source, one, 2, 1UL) else {
      return false
    }
    true
  })
  ignore(
    fetched_transport_root(
      source,
      roots,
      clock,
      reset,
      "arbiter_preference",
      preference_node,
      @wire.uint(2),
    ),
  )
  // The complete frozen original selection cone is retained. Confirm its three
  // preference arms and requester order rather than freeing chosen_owner.
  let mut choice_tail = choice
  for preference in [2, 1, 0] {
    let (selected, candidate, fallback) = dependency_generation_decoder_mux(
      source, choice_tail,
    )
    guard dependency_generation_node(source, selected).kind()
      is Equal(actual_preference, value) &&
      actual_preference == preference_node &&
      fetched_transport_constant(source, value, 2, preference.to_uint64()) else {
      raise InvalidFormalBundleIdentity(
        "fetched discovery: cyclic preference arm",
      )
    }
    let (valid, first_value, remaining) = dependency_generation_decoder_mux(
      source, candidate,
    )
    let (second_valid, second_value, third_value) = dependency_generation_decoder_mux(
      source, remaining,
    )
    if valid != valids[preference] ||
      second_valid != valids[(preference + 1) % 3] ||
      !fetched_transport_constant(
        source,
        first_value,
        2,
        preference.to_uint64(),
      ) ||
      !fetched_transport_constant(
        source,
        second_value,
        2,
        ((preference + 1) % 3).to_uint64(),
      ) ||
      !fetched_transport_constant(
        source,
        third_value,
        2,
        ((preference + 2) % 3).to_uint64(),
      ) {
      raise InvalidFormalBundleIdentity(
        "fetched discovery: cyclic skip equation",
      )
    }
    choice_tail = fallback
  }
  if !fetched_transport_constant(source, choice_tail, 2, 0UL) {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: original selection fallback",
    )
  }
  let all_fields : Array[Array[@ir.NodeId]] = []
  for
    (field, signal_type) in [
      ("write", @wire.bits(1)),
      ("address", @wire.uint(32)),
      ("bytes", @wire.uint(3)),
      ("mask", @wire.bits(4)),
      ("data", @wire.bits(32)),
    ] {
    let public_name = if field == "address" {
      "memory_request_address"
    } else {
      "memory_request_" + field
    }
    let root = fetched_transport_root(
      source,
      roots,
      clock,
      reset,
      "arbiter_" + field,
      two_client_arbiter_output(source, public_name, signal_type),
      signal_type,
    )
    all_fields.push(
      fetched_transport_fields(
        source,
        two_client_arbiter_hold(source, root, grant),
        choice,
      ),
    )
  }
  let local_node = fetched_transport_unique(source, "saved local tag", node => {
    guard node.signal_type() == @wire.uint(32) &&
      !roots.any(root => root.node == node.id()) &&
      node.kind() is Register(spec) &&
      dependency_generation_node(source, spec.next()).kind()
      is Mux(select~, when_true~, when_false~) &&
      select == grant &&
      when_false == node.id() &&
      dependency_generation_node(source, when_true).kind()
      is Mux(select=first_select, ..) &&
      dependency_generation_node(source, first_select).kind()
      is Equal(actual_choice, zero) &&
      actual_choice == choice &&
      fetched_transport_constant(source, zero, 2, 0UL) else {
      return false
    }
    true
  })
  let local_tag = fetched_transport_root(
    source,
    roots,
    clock,
    reset,
    "arbiter_local_tag",
    local_node,
    @wire.uint(32),
  )
  all_fields.push(
    fetched_transport_fields(
      source,
      two_client_arbiter_hold(source, local_tag, grant),
      choice,
    ),
  )
  for
    (name, id) in [
      ("reset", reset),
      ("request_ready", bus_ready),
      ("response_valid", response_valid),
      ("response_tag", response_tag),
      ("response_fault", response_fault),
      ("response_data", response_data),
    ] {
    two_client_arbiter_boundary(
      source,
      boundaries,
      id,
      dependency_generation_node(source, id).signal_type(),
      name,
    )
  }
  for index in 1..<3 {
    let prefix = if index == 1 { "loader" } else { "storer" }
    two_client_arbiter_boundary(
      source,
      boundaries,
      valids[index],
      @wire.bits(1),
      prefix + "_valid",
    )
    two_client_arbiter_boundary(
      source,
      boundaries,
      readies[index],
      @wire.bits(1),
      prefix + "_response_ready",
    )
    for field, name in ["write", "address", "bytes", "mask", "data", "tag"] {
      let id = all_fields[field][index]
      two_client_arbiter_boundary(
        source,
        boundaries,
        id,
        dependency_generation_node(source, id).signal_type(),
        prefix + "_" + name,
      )
    }
  }
  let reader_response_valid = fetched_transport_route(
    source,
    state.node,
    inactive,
    owner.node,
    0,
    response_valid,
    2UL,
  )
  let reader_request_ready = fetched_transport_route(
    source,
    state.node,
    inactive,
    owner.node,
    0,
    bus_ready,
    1UL,
  )
  let reader_response_fault = fetched_transport_unique(source, "routed fault", node => {
    guard node.signal_type() == @wire.uint(2) &&
      node.kind() is Mux(select~, when_true~, when_false~) &&
      when_false == response_fault &&
      fetched_transport_constant(source, when_true, 2, 2UL) else {
      return false
    }
    two_client_arbiter_malformed(source, select, response_tag, response_fault) ==
    expected_tag.node
  })
  for
    (name, id) in [
      ("arbiter_grant", grant),
      ("arbiter_choice", choice),
      ("arbiter_request_accept", request_accept),
      ("arbiter_response_accept", response_accept),
      ("arbiter_malformed", malformed),
      ("arbiter_offer", offer),
      ("arbiter_response_ready", response_ready),
      ("arbiter_poison", halted),
      ("reader_request_ready", reader_request_ready),
      ("reader_response_valid", reader_response_valid),
      ("reader_response_fault", reader_response_fault),
      ("raw_response_data", response_data),
    ] {
    fetched_transport_event(source, events, name, id)
  }
  {
    roots: ReadOnlyArray::from_array(roots),
    boundaries: ReadOnlyArray::from_array(boundaries),
    events: ReadOnlyArray::from_array(events),
    reader_fields: ReadOnlyArray::from_array(
      all_fields.map(fields => fields[0]),
    ),
    reader_valid,
    reader_ready: readies[0],
    reader_response_valid,
    inactive,
  }
}
