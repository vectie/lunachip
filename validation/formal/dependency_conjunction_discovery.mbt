///|
fn dependency_conjunction_add_root(
  roots : Array[DependencyComputeRoot],
  root : DependencyComputeRoot,
) -> Unit raise FormalGateError {
  match roots.filter(prior => prior.node == root.node) {
    [] => {
      if roots.any(prior => prior.name == root.name) {
        raise InvalidFormalBundleIdentity(
          "dependency conjunction: root name alias",
        )
      }
      roots.push(root)
    }
    [same] =>
      if same.spec != root.spec || same.signal_type != root.signal_type {
        raise InvalidFormalBundleIdentity(
          "dependency conjunction: shared state drift",
        )
      }
    _ =>
      raise InvalidFormalBundleIdentity("dependency conjunction: repeated root")
  }
}

///|
#warnings("-unused_value")
fn dependency_conjunction_probe(
  queue_fixture : @flux_tile.QueueConservationFixture,
  dependency_fixture : @flux_tile.QueuedConcurrentFormalFixture,
) -> DependencyConjunctionProbe raise {
  let packet = queue_packet_composition_probe(queue_fixture)
  queue_packet_composition_require_inventory(packet)
  let source = packet.source
  // Both observation seams must reference the complete SAME production graph.
  // Neither IDs nor equal counts are sufficient evidence of correspondence.
  if source != dependency_fixture.hardware() {
    raise InvalidFormalBundleIdentity(
      "dependency conjunction: ordinary device identity",
    )
  }
  let bindings = dependency_generation_bindings(dependency_fixture)
  dependency_generation_validate_bindings(source, bindings)
  let generation = dependency_generation_discover(dependency_fixture)
  let compute = dependency_compute_discover(dependency_fixture)
  if generation.clock != packet.clock ||
    generation.reset != packet.reset ||
    compute.clock != packet.clock ||
    compute.reset != packet.reset {
    raise InvalidFormalBundleIdentity(
      "dependency conjunction: shared semantic clock/reset",
    )
  }
  let roots = packet.roots.iter().to_array()
  for root in generation.roots {
    dependency_conjunction_add_root(roots, {
      name: "generation_" + dependency_role_name(root.binding.role),
      node: root.binding.node,
      signal_type: root.binding.signal_type,
      spec: root.spec,
    })
  }
  for root in compute.roots {
    dependency_conjunction_add_root(roots, {
      ..root,
      name: "compute_" + root.name,
    })
  }
  for
    role in [
      @flux_tile.QueuedConcurrentFormalRole::LoadTerminalFault,
      StoreTerminalFault,
    ] {
    let binding = dependency_generation_binding(bindings, role)
    dependency_conjunction_add_root(
      roots,
      queue_control_root(
        source,
        {
          name: "dependency_" + dependency_role_name(role),
          node: binding.node,
          signal_type: binding.signal_type,
        },
        packet.clock,
        packet.reset,
      ),
    )
  }
  roots.sort_by((a, b) => a.node.ordinal() - b.node.ordinal())
  let observations = packet.observations.iter().to_array()
  for binding in bindings {
    observations.push({
      name: "dependency_" + dependency_role_name(binding.role),
      node: binding.node,
      signal_type: binding.signal_type,
    })
  }
  let seeds = queue_packet_composition_seeds(
    source,
    roots,
    packet.lanes,
    observations,
    packet.clock,
    packet.reset,
  )
  let (candidates, cone) = dependency_conjunction_walk(
    packet, roots, observations, seeds,
  )
  // Every directly observed dependency register is actual retained state;
  // ready, preflight, accept, local reject/fault and terminal are original cones.
  for binding in bindings {
    let original = dependency_generation_node(source, binding.node)
    if original.kind() is Register(_) {
      if !roots.any(root => root.node == binding.node) {
        raise InvalidFormalBundleIdentity(
          "dependency conjunction: observed state cut",
        )
      }
    } else if !cone.contains(original) {
      raise InvalidFormalBundleIdentity(
        "dependency conjunction: derived observation cut",
      )
    }
    if candidates.any(candidate => candidate.original.id() == binding.node) {
      raise InvalidFormalBundleIdentity(
        "dependency conjunction: dependency role shadowed",
      )
    }
  }
  {
    packet,
    bindings: ReadOnlyArray::from_array(bindings),
    roots: ReadOnlyArray::from_array(roots),
    observations: ReadOnlyArray::from_array(observations),
    seeds: ReadOnlyArray::from_array(seeds),
    candidates: ReadOnlyArray::from_array(candidates),
    cone: ReadOnlyArray::from_array(cone),
  }
}
