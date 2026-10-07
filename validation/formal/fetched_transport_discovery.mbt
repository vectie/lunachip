///|
// Construct independently: direct-device inventories and local node numbers
// are not inputs to this discovery. The complete canonical source is frozen.
fn fetched_transport_probe() -> FetchedTransportProbe raise {
  let design = flux_tile_formal_design()
  let production_digest = sha256_hex(@ir_codec.serialize(design))
  if production_digest !=
    "d47c7cccaa7dc7d8021b0fabc6a4eb7d4977bb53c1c5fa06416bbbb5e531cf79" {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: original canonical source drift",
    )
  }
  guard design.top_module() is Some(source) else { raise MissingTopModule }
  let clock = dependency_generation_input(source, "clock", Clock)
  let reset = dependency_generation_input(source, "reset", Reset)
  let arbiter = fetched_transport_arbiter(source, clock, reset)
  let roots = arbiter.roots.iter().to_array()
  let boundaries = arbiter.boundaries.iter().to_array()
  let events = arbiter.events.iter().to_array()
  fetched_transport_reader(
    source, clock, reset, arbiter, roots, boundaries, events,
  )
  // Recover the four original peer route decisions, not synthetic equations
  // over observed owner bits. The source graph and reviewed raw boundaries
  // stay unchanged; closure below retains these exact original route cones.
  guard roots.filter(root => root.name == "arbiter_state") is [arbiter_state] &&
    roots.filter(root => root.name == "arbiter_owner") is [arbiter_owner] else {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: route state/owner identity",
    )
  }
  let request_ready = dependency_generation_input(
    source,
    "memory_request_ready",
    @wire.bits(1),
  )
  let response_valid = dependency_generation_input(
    source,
    "memory_response_valid",
    @wire.bits(1),
  )
  for (index, prefix) in [(1, "loader"), (2, "storer")] {
    fetched_transport_event(
      source,
      events,
      prefix + "_request_ready",
      fetched_transport_route(
        source,
        arbiter_state.node,
        arbiter.inactive,
        arbiter_owner.node,
        index,
        request_ready,
        1UL,
      ),
    )
    fetched_transport_event(
      source,
      events,
      prefix + "_response_valid",
      fetched_transport_route(
        source,
        arbiter_state.node,
        arbiter.inactive,
        arbiter_owner.node,
        index,
        response_valid,
        2UL,
      ),
    )
  }
  if roots.length() != 26 ||
    roots.fold(init=0, (bits, root) => bits + root.signal_type.width().bits()) !=
    666 {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: complete original state inventory",
    )
  }
  // Deterministic original-node ordering with aliases retained separately.
  let ordered_boundaries : Array[TwoClientArbiterCandidate] = []
  for node in source.nodes() {
    for boundary in boundaries {
      if boundary.original.id() == node.id() {
        ordered_boundaries.push(boundary)
      }
    }
  }
  let candidates = ordered_boundaries.filter(boundary => {
    !(boundary.original.kind() is Constant(_))
  })
  let cone = fetched_transport_closure(source, roots, candidates, events)
  {
    source,
    production_digest,
    clock,
    reset,
    roots: ReadOnlyArray::from_array(roots),
    boundaries: ReadOnlyArray::from_array(ordered_boundaries),
    candidates: ReadOnlyArray::from_array(candidates),
    events: ReadOnlyArray::from_array(events),
    cone: ReadOnlyArray::from_array(cone),
  }
}

///|
fn fetched_transport_closure(
  source : @ir.Module,
  roots : ArrayView[DependencyComputeRoot],
  candidates : ArrayView[TwoClientArbiterCandidate],
  events : ArrayView[QueueControlAlias],
) -> Array[@ir.Node] raise {
  let cuts : Array[DependencyGenerationCut] = []
  let seeds : Array[@ir.NodeId] = []
  for root in roots {
    if cuts.any(cut => cut.node == root.node) {
      raise InvalidFormalBundleIdentity("fetched closure: repeated state root")
    }
    cuts.push({
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
    if cuts.any(cut => cut.node == candidate.original.id()) ||
      candidate.original.kind() is Constant(_) ||
      candidate.original.kind() is AsyncFifoRead(..) {
      raise InvalidFormalBundleIdentity(
        "fetched closure: invalid component boundary",
      )
    }
    cuts.push({
      node: candidate.original.id(),
      signal_type: candidate.original.signal_type(),
      roles: candidate.roles,
    })
    seeds.push(candidate.original.id())
  }
  for event in events {
    seeds.push(event.node)
  }
  // Reject every unlisted input/register/memory leaf: no automatic foreign
  // progress, packet, response or storage fallback can become a fresh input.
  dependency_generation_closure(source, cuts, seeds)
}
