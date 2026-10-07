///|
// Acceptance is private and separate from the candidate inspection surface.
priv struct QueueOwnerPlan {
  probe : QueueOwnerProbe
  cuts : ReadOnlyArray[DependencyGenerationCut]
  inventory_digest : String
}

///|
fn queue_owner_require_inventory(
  probe : QueueOwnerProbe,
) -> Unit raise FormalGateError {
  if probe.production_digest !=
    "35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc" ||
    sha256_hex(queue_owner_probe_report(probe)) !=
    "ad6dc56cf01fc55a28eacc6be5dc16493f882b665e1d9570e6e737f9985b289a" {
    raise InvalidFormalBundleIdentity("queue owner: reviewed inventory drift")
  }
}

///|
fn queue_owner_discover(
  fixture : @flux_tile.QueueConservationFixture,
) -> QueueOwnerPlan raise {
  let source = fixture.hardware()
  let probe = queue_owner_probe(fixture)
  queue_owner_require_inventory(probe)
  if dependency_generation_input(source, "clock", Clock) != probe.clock ||
    dependency_generation_input(source, "reset", Reset) != probe.reset {
    raise InvalidFormalBundleIdentity("queue owner: clock/reset identity")
  }
  let cuts : Array[DependencyGenerationCut] = []
  let membership = Array::make(source.nodes().length(), 0)
  let boundaries : Array[DependencyGenerationCut] = []
  let seeds : Array[@ir.NodeId] = []
  for root in probe.roots {
    let binding : QueueControlAlias = {
      name: root.name,
      node: root.node,
      signal_type: root.signal_type,
    }
    if queue_control_root(source, binding, probe.clock, probe.reset) != root {
      raise InvalidFormalBundleIdentity("queue owner: root source drift")
    }
    membership[root.node.ordinal()] += 1
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
  let mut previous = -1
  for candidate in probe.candidates {
    let original = candidate.original
    if original.id().ordinal() <= previous ||
      dependency_generation_node(source, original.id()) != original ||
      queue_owner_candidate_leaf(source, original, probe.reset) != candidate {
      raise InvalidFormalBundleIdentity(
        "queue owner: candidate source/order drift",
      )
    }
    previous = original.id().ordinal()
    let role = match original.kind() {
      Input(name) => name
      Register(_) => "foreign_n\{original.id().ordinal()}"
      _ =>
        raise InvalidFormalBundleIdentity("queue owner: unreviewed leaf kind")
    }
    let cut : DependencyGenerationCut = {
      node: original.id(),
      signal_type: original.signal_type(),
      roles: [role],
    }
    cuts.push(cut)
    boundaries.push(cut)
    membership[original.id().ordinal()] += 1
  }
  for original in probe.cone {
    if dependency_generation_node(source, original.id()) != original {
      raise InvalidFormalBundleIdentity("queue owner: cone source drift")
    }
    ignore(dependency_generation_operands(original.kind()))
    membership[original.id().ordinal()] += 1
  }
  membership[probe.clock.ordinal()] += 1
  for count in membership {
    if count > 1 {
      raise InvalidFormalBundleIdentity(
        "queue owner: overlapping retained sets",
      )
    }
  }
  for event in probe.events {
    seeds.push(event.node)
  }
  // Independent closed-cone walk stops only at the accepted roots/cuts. It
  // rejects an unlisted leaf and detects missing or extra combinational nodes.
  if dependency_generation_closure(source, boundaries, seeds) !=
    probe.cone.iter().to_array() {
    raise InvalidFormalBundleIdentity("queue owner: exact required cone drift")
  }
  {
    probe,
    cuts: ReadOnlyArray::from_array(cuts),
    inventory_digest: "ad6dc56cf01fc55a28eacc6be5dc16493f882b665e1d9570e6e737f9985b289a",
  }
}
