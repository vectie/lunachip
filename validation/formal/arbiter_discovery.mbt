///|
#warnings("-unused_value")
fn two_client_arbiter_probe(
  fixture : @flux_tile.QueueConservationFixture,
) -> TwoClientArbiterProbe raise {
  let hardware = fixture.hardware()
  let digest = sha256_hex(
    @ir_codec.serialize(
      @ir.Design::single("QueuedConcurrentQueueConservationPilot", hardware),
    ),
  )
  if digest !=
    "35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc" {
    raise InvalidFormalBundleIdentity("arbiter probe: frozen production drift")
  }
  two_client_arbiter_probe_original(hardware, digest)
}

///|
// The caller pins its complete original profile. Discovery only reads existing
// equations; this function does not materialize any free-input projection.
fn two_client_arbiter_probe_original(
  hardware : @ir.Module,
  digest : String,
) -> TwoClientArbiterProbe raise {
  let clock = dependency_generation_input(hardware, "clock", Clock)
  let reset = dependency_generation_input(hardware, "reset", Reset)
  let public_halted = two_client_arbiter_output(
    hardware,
    "transport_halted",
    @wire.bits(1),
  )
  let (_, inactive) = dependency_generation_decoder_and(hardware, public_halted)
  guard dependency_generation_node(hardware, inactive).kind()
    is BitNot(asserted) &&
    dependency_generation_node(hardware, asserted).kind() is Reinterpret(source) &&
    source == reset else {
    raise InvalidFormalBundleIdentity(
      "arbiter probe: original reset normalization",
    )
  }
  let offer = two_client_arbiter_output(
    hardware,
    "memory_request_valid",
    @wire.bits(1),
  )
  let state_node = two_client_arbiter_state_gate(hardware, offer, inactive, 1UL)
  if two_client_arbiter_state_gate(hardware, public_halted, inactive, 3UL) !=
    state_node {
    raise InvalidFormalBundleIdentity("arbiter probe: poison state identity")
  }
  let roots : Array[DependencyComputeRoot] = []
  fn root(
    name : String,
    node : @ir.NodeId,
    signal_type : @ir.SignalType,
  ) -> DependencyComputeRoot raise {
    let result = queue_control_root(
      hardware,
      { name, node, signal_type, },
      clock,
      reset,
    )
    if roots.any(previous => previous.node == node) ||
      result.spec.enable() != None {
      raise InvalidFormalBundleIdentity(
        "arbiter probe: essential root alias/enable",
      )
    }
    roots.push(result)
    result
  }
  let state = root("state", state_node, @wire.uint(2))
  let response_ready = two_client_arbiter_output(
    hardware,
    "memory_response_ready",
    @wire.bits(1),
  )
  let (wait_controller, selected_ready) = dependency_generation_decoder_and(
    hardware, response_ready,
  )
  if two_client_arbiter_state_gate(hardware, wait_controller, inactive, 2UL) !=
    state.node {
    raise InvalidFormalBundleIdentity("arbiter probe: response Wait identity")
  }
  let (owner_node, engine_ready, reader_ready) = dependency_generation_decoder_mux(
    hardware, selected_ready,
  )
  let owner = root("owner", owner_node, @wire.bits(1))
  let (grant, choose_engine, owner_hold) = dependency_generation_decoder_mux(
    hardware,
    owner.spec.next(),
  )
  if owner_hold != owner.node {
    raise InvalidFormalBundleIdentity("arbiter probe: granted owner hold")
  }
  let (idle, any_request) = dependency_generation_decoder_and(hardware, grant)
  if two_client_arbiter_state_gate(hardware, idle, inactive, 0UL) != state.node {
    raise InvalidFormalBundleIdentity("arbiter probe: grant Idle identity")
  }
  guard dependency_generation_node(hardware, any_request).kind()
    is BitOr(reader_valid, engine_valid) &&
    dependency_generation_node(hardware, choose_engine).kind()
    is BitAnd(engine, preference_mask) &&
    engine == engine_valid &&
    dependency_generation_node(hardware, preference_mask).kind()
    is BitOr(reader_absent, preference_node) &&
    dependency_generation_node(hardware, reader_absent).kind() ==
    BitNot(reader_valid) else {
    raise InvalidFormalBundleIdentity(
      "arbiter probe: original selection equation",
    )
  }
  let preference = root("preference", preference_node, @wire.bits(1))
  let (request_accept, preference_value, preference_hold) = dependency_generation_decoder_mux(
    hardware,
    preference.spec.next(),
  )
  if preference_hold != preference.node ||
    dependency_generation_node(hardware, preference_value).kind() !=
    BitNot(owner.node) {
    raise InvalidFormalBundleIdentity(
      "arbiter probe: preference acceptance update",
    )
  }
  let bus_ready = dependency_generation_input(
    hardware,
    "memory_request_ready",
    @wire.bits(1),
  )
  if dependency_generation_node(hardware, request_accept).kind() !=
    BitAnd(offer, bus_ready) {
    raise InvalidFormalBundleIdentity(
      "arbiter probe: public request acceptance",
    )
  }
  let response_valid = dependency_generation_input(
    hardware,
    "memory_response_valid",
    @wire.bits(1),
  )
  let response_tag = dependency_generation_input(
    hardware,
    "memory_response_tag",
    @wire.uint(32),
  )
  let response_fault = dependency_generation_input(
    hardware,
    "memory_response_fault",
    @wire.uint(2),
  )
  let response_data = dependency_generation_input(
    hardware,
    "memory_response_data",
    @wire.bits(32),
  )
  let (response_accept, response_state, pending) = dependency_generation_decoder_mux(
    hardware,
    state.spec.next(),
  )
  if dependency_generation_node(hardware, response_accept).kind() !=
    BitAnd(response_ready, response_valid) {
    raise InvalidFormalBundleIdentity(
      "arbiter probe: public response acceptance",
    )
  }
  let (malformed, poison_value, idle_value) = dependency_generation_decoder_mux(
    hardware, response_state,
  )
  dependency_generation_decoder_constant(
    hardware,
    poison_value,
    @wire.uint(2),
    3UL,
  )
  dependency_generation_decoder_constant(
    hardware,
    idle_value,
    @wire.uint(2),
    0UL,
  )
  let (accepted, wait_value, pending_grant) = dependency_generation_decoder_mux(
    hardware, pending,
  )
  let (granted, offer_value, state_hold) = dependency_generation_decoder_mux(
    hardware, pending_grant,
  )
  if accepted != request_accept || granted != grant || state_hold != state.node {
    raise InvalidFormalBundleIdentity("arbiter probe: exact state priorities")
  }
  dependency_generation_decoder_constant(
    hardware,
    wait_value,
    @wire.uint(2),
    2UL,
  )
  dependency_generation_decoder_constant(
    hardware,
    offer_value,
    @wire.uint(2),
    1UL,
  )
  let next_tag = root(
    "next_tag",
    two_client_arbiter_output(hardware, "memory_request_tag", @wire.uint(32)),
    @wire.uint(32),
  )
  let next_value = two_client_arbiter_hold(hardware, next_tag, request_accept)
  guard dependency_generation_node(hardware, next_value).kind()
    is Add(current_tag, increment) &&
    current_tag == next_tag.node else {
    raise InvalidFormalBundleIdentity(
      "arbiter probe: modular global tag increment",
    )
  }
  dependency_generation_decoder_constant(
    hardware,
    increment,
    @wire.uint(32),
    1UL,
  )
  let expected_tag = root(
    "expected_tag",
    two_client_arbiter_malformed(
      hardware, malformed, response_tag, response_fault,
    ),
    @wire.uint(32),
  )
  if two_client_arbiter_hold(hardware, expected_tag, request_accept) !=
    next_tag.node {
    raise InvalidFormalBundleIdentity(
      "arbiter probe: expected original global tag",
    )
  }
  let candidates : Array[TwoClientArbiterCandidate] = []
  for
    (name, node, signal_type) in [
      ("reset", reset, @wire.reset()),
      ("request_ready", bus_ready, @wire.bits(1)),
      ("response_valid", response_valid, @wire.bits(1)),
      ("response_tag", response_tag, @wire.uint(32)),
      ("response_fault", response_fault, @wire.uint(2)),
      ("response_data", response_data, @wire.bits(32)),
      ("reader_valid", reader_valid, @wire.bits(1)),
      ("engine_valid", engine_valid, @wire.bits(1)),
      ("reader_response_ready", reader_ready, @wire.bits(1)),
      ("engine_response_ready", engine_ready, @wire.bits(1)),
    ] {
    two_client_arbiter_boundary(hardware, candidates, node, signal_type, name)
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
      two_client_arbiter_output(hardware, "memory_request_" + name, signal_type),
      signal_type,
    )
    let selected = two_client_arbiter_hold(hardware, saved, grant)
    let (choice, engine, reader) = dependency_generation_decoder_mux(
      hardware, selected,
    )
    if choice != choose_engine {
      raise InvalidFormalBundleIdentity(
        "arbiter probe: shared payload selection",
      )
    }
    two_client_arbiter_boundary(
      hardware,
      candidates,
      engine,
      signal_type,
      "engine_" + name,
    )
    two_client_arbiter_boundary(
      hardware,
      candidates,
      reader,
      signal_type,
      "reader_" + name,
    )
  }
  // The unique remaining UInt32 register with the SAME grant/selector/hold
  // equation is the saved local tag, not the already identified address.
  let local_matches = hardware
    .nodes()
    .filter(node => {
      if roots.any(previous => previous.node == node.id()) ||
        node.signal_type() != @wire.uint(32) {
        return false
      }
      guard node.kind() is Register(spec) &&
        dependency_generation_node(hardware, spec.next()).kind()
        is Mux(select~, when_true~, when_false~) &&
        select == grant &&
        when_false == node.id() &&
        dependency_generation_node(hardware, when_true).kind()
        is Mux(select=selector, ..) else {
        return false
      }
      selector == choose_engine
    })
  guard local_matches is [saved_local] else {
    raise InvalidFormalBundleIdentity(
      "arbiter probe: unique local tag register",
    )
  }
  let local_tag = root("local_tag", saved_local.id(), @wire.uint(32))
  let (local_select, engine_tag, reader_tag) = dependency_generation_decoder_mux(
    hardware,
    two_client_arbiter_hold(hardware, local_tag, grant),
  )
  if local_select != choose_engine {
    raise InvalidFormalBundleIdentity("arbiter probe: local tag selection")
  }
  two_client_arbiter_boundary(
    hardware,
    candidates,
    engine_tag,
    @wire.uint(32),
    "engine_tag",
  )
  two_client_arbiter_boundary(
    hardware,
    candidates,
    reader_tag,
    @wire.uint(32),
    "reader_tag",
  )
  if candidates
    .iter()
    .fold(init=0, (count, candidate) => count + candidate.roles.length()) !=
    22 {
    raise InvalidFormalBundleIdentity(
      "arbiter probe: raw interface role inventory",
    )
  }
  candidates.sort_by((left, right) => {
    left.original.id().ordinal() - right.original.id().ordinal()
  })
  let events : Array[QueueControlAlias] = []
  fn event(name : String, node : @ir.NodeId) -> Unit raise {
    if events.any(previous => previous.name == name) {
      raise InvalidFormalBundleIdentity("arbiter probe: repeated event")
    }
    events.push({
      name,
      node,
      signal_type: dependency_generation_node(hardware, node).signal_type(),
    })
  }
  for
    (name, node) in [
      ("idle", idle),
      ("offer", offer),
      ("wait_controller", wait_controller),
      ("poisoned", public_halted),
      ("grant", grant),
      ("choose_engine", choose_engine),
      ("request_accept", request_accept),
      ("response_ready", response_ready),
      ("response_accept", response_accept),
      ("malformed_controller", malformed),
    ] {
    event(name, node)
  }
  // Bind original route nodes by exact equations; do not create new masks.
  let mut shared_wait : @ir.NodeId? = None
  for (prefix, engine) in [("reader", false), ("engine", true)] {
    let (route_request_ready, route_offer) = two_client_arbiter_route(
      hardware,
      state.node,
      inactive,
      owner.node,
      engine,
      bus_ready,
      1UL,
      prefix + " request ready",
    )
    let (route_response_valid, route_wait) = two_client_arbiter_route(
      hardware,
      state.node,
      inactive,
      owner.node,
      engine,
      response_valid,
      2UL,
      prefix + " response valid",
    )
    if route_offer != offer ||
      (shared_wait is Some(previous) && previous != route_wait) {
      raise InvalidFormalBundleIdentity(
        "arbiter probe: original shared route state gates",
      )
    }
    shared_wait = Some(route_wait)
    event(prefix + "_request_ready", route_request_ready)
    event(prefix + "_response_valid", route_response_valid)
  }
  guard shared_wait is Some(wait_route) else {
    raise InvalidFormalBundleIdentity("arbiter probe: missing route Wait")
  }
  event("wait_route", wait_route)
  let fault_matches = hardware
    .nodes()
    .filter(node => {
      guard node.signal_type() == @wire.uint(2) &&
        node.kind() is Mux(select~, when_true~, when_false~) &&
        when_false == response_fault &&
        dependency_generation_node(hardware, when_true).kind() == Constant(2UL) &&
        dependency_generation_node(hardware, select).kind()
        is BitOr(tag_bad, fault_bad) &&
        dependency_generation_node(hardware, tag_bad).kind() is BitNot(equal) &&
        dependency_generation_node(hardware, equal).kind() ==
        Equal(response_tag, expected_tag.node) &&
        dependency_generation_node(hardware, fault_bad).kind()
        is LessEqual(reserved, fault) &&
        fault == response_fault else {
        return false
      }
      dependency_generation_node(hardware, reserved).kind() == Constant(2UL)
    })
  guard fault_matches is [route_fault] && route_fault.kind() is Mux(select~, ..) else {
    raise InvalidFormalBundleIdentity(
      "arbiter probe: original route fault mapping",
    )
  }
  if two_client_arbiter_malformed(
      hardware, select, response_tag, response_fault,
    ) !=
    expected_tag.node {
    raise InvalidFormalBundleIdentity(
      "arbiter probe: restored route fault identity",
    )
  }
  event("malformed_route", select)
  event("route_response_fault", route_fault.id())
  let nonconstant = candidates.filter(candidate => {
    !(candidate.original.kind() is Constant(_))
  })
  let cone = two_client_arbiter_probe_closure(
    hardware, roots, nonconstant, events,
  )
  {
    roots: ReadOnlyArray::from_array(roots),
    boundaries: ReadOnlyArray::from_array(candidates),
    candidates: ReadOnlyArray::from_array(nonconstant),
    cone: ReadOnlyArray::from_array(cone),
    events: ReadOnlyArray::from_array(events),
    clock,
    reset,
    production_digest: digest,
  }
}

///|
#warnings("-unused_value")
fn two_client_arbiter_probe_report(probe : TwoClientArbiterProbe) -> String {
  let out = StringBuilder()
  out.write_string("CANDIDATE-PROBE ONLY-not-accepted-projection-or-proof\n")
  out.write_string("PRODUCTION sha256 \{probe.production_digest}\n")
  out.write_string("ESSENTIAL roots \{probe.roots.length()} bits172\n")
  out.write_string(
    "BOUNDARIES \{probe.boundaries.length()} CANDIDATES \{probe.candidates.length()} CONE \{probe.cone.length()} EVENTS \{probe.events.length()}\n",
  )
  for root in probe.roots {
    let spec = "\{Repr(root.spec)}".replace_all(old="\n", new="")
    out.write_string(
      "ROOT \{root.name} node \{root.node.ordinal()} type \{Repr(root.signal_type)} spec \{spec}\n",
    )
  }
  for event in probe.events {
    out.write_string(
      "EVENT \{event.name} node \{event.node.ordinal()} type \{Repr(event.signal_type)}\n",
    )
  }
  for candidate in probe.boundaries {
    let original = candidate.original
    let kind = "\{Repr(original.kind())}".replace_all(old="\n", new="")
    let status = if original.kind() is Constant(_) {
      "retained-constant"
    } else {
      "unreviewed-interface-candidate"
    }
    out.write_string(
      "BOUNDARY \{status} roles \{candidate.roles.join(",")} node \{original.id().ordinal()} type \{Repr(original.signal_type())} kind \{kind}\n",
    )
  }
  out.to_string()
}
