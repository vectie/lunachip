///|
fn queue_packet_composition_inventory(
  fixture : @flux_tile.QueueConservationFixture,
) -> (
  Array[DependencyComputeRoot],
  Array[QueueStorageLane],
  Array[QueueControlAlias],
  @ir.NodeId,
  @ir.NodeId,
  String,
  String,
) raise {
  let owner = queue_owner_probe(fixture)
  let storage = queue_storage_probe(fixture)
  queue_owner_require_inventory(owner)
  queue_storage_require_inventory(storage)
  if owner.clock != storage.clock || owner.reset != storage.reset {
    raise InvalidFormalBundleIdentity(
      "packet composition: original domains differ",
    )
  }
  let source = fixture.hardware()
  let roots = owner.roots.iter().to_array()
  // Deduplicate shared production identities, never union prior free cuts.
  for root in storage.roots {
    match roots.filter(prior => prior.node == root.node) {
      [] => roots.push(root)
      [same] =>
        if same != root {
          raise InvalidFormalBundleIdentity(
            "packet composition: shared root drift",
          )
        }
      _ =>
        raise InvalidFormalBundleIdentity("packet composition: duplicate root")
    }
  }
  for entry in 0..<3 {
    for
      role in [
        @flux_tile.QueueConservationRole::EntryId(entry),
        EntryFault(entry),
        EntryProgress(entry),
        EntryAddress(entry),
      ] {
      let root = queue_control_root(
        source,
        queue_control_binding(fixture, role),
        owner.clock,
        owner.reset,
      )
      if roots.any(prior => prior.node == root.node) {
        raise InvalidFormalBundleIdentity(
          "packet composition: aliased record field",
        )
      }
      roots.push(root)
    }
  }
  roots.sort_by((a, b) => a.node.ordinal() - b.node.ordinal())
  if roots.length() != 54 ||
    roots.iter().fold(init=0, (n, root) => n + root.signal_type.width().bits()) !=
    876 {
    raise InvalidFormalBundleIdentity(
      "packet composition: essential 54/876 inventory",
    )
  }
  let observations : Array[QueueControlAlias] = []
  let expected = queue_expected_observations()
  if fixture.observations().length() != 115 || expected.length() != 115 {
    raise InvalidFormalBundleIdentity(
      "packet composition: original observation inventory",
    )
  }
  for (role, _) in expected {
    observations.push(queue_control_binding(fixture, role))
  }
  (
    roots,
    storage.lanes.iter().to_array(),
    observations,
    owner.clock,
    owner.reset,
    sha256_hex(queue_owner_probe_report(owner)),
    sha256_hex(queue_storage_probe_report(storage)),
  )
}

///|
fn queue_packet_composition_seeds(
  source : @ir.Module,
  roots : ArrayView[DependencyComputeRoot],
  lanes : ArrayView[QueueStorageLane],
  observations : ArrayView[QueueControlAlias],
  clock : @ir.NodeId,
  reset : @ir.NodeId,
) -> Array[QueuePacketCompositionSeed] {
  let seeds : Array[QueuePacketCompositionSeed] = [
    { origin: Clock, node: clock, },
    { origin: Reset, node: reset, },
  ]
  for root in roots {
    seeds.push({ origin: RootNext(root.name), node: root.spec.next(), })
    if root.spec.reset() is Some(control) {
      seeds.push({ origin: RootReset(root.name), node: control.signal(), })
    }
    if root.spec.enable() is Some(enable) {
      seeds.push({ origin: RootEnable(root.name), node: enable, })
    }
  }
  for observation in observations {
    seeds.push({
      origin: Observation(observation.name),
      node: observation.node,
    })
  }
  // Keep even presently unused public input bits: the original packet task's
  // host-response stability premise must see the full public response payload.
  for node in source.nodes() {
    if node.kind() is Input(name) && node.id() != clock && node.id() != reset {
      seeds.push({ origin: PublicInput(name), node: node.id(), })
    }
  }
  for output in source.outputs() {
    seeds.push({ origin: PublicOutput(output.name()), node: output.driver(), })
  }
  for lane in lanes {
    let index = lane.lane
    seeds.push({
      origin: MemoryClock(index),
      node: lane.memory.domain().clock(),
    })
    seeds.push({ origin: ReadClock(index), node: lane.read.domain().clock(), })
    seeds.push({ origin: ReadResult(index), node: lane.result.id(), })
    seeds.push({ origin: ReadAddress(index), node: lane.read.address(), })
    if lane.read.enable() is Some(enable) {
      seeds.push({ origin: ReadEnable(index), node: enable, })
    }
    seeds.push({ origin: WriteClock(index), node: lane.write.domain().clock(), })
    seeds.push({ origin: WriteAddress(index), node: lane.write.address(), })
    seeds.push({ origin: WriteData(index), node: lane.write.data(), })
    if lane.write.enable() is Some(enable) {
      seeds.push({ origin: WriteEnable(index), node: enable, })
    }
    if lane.write.mask() is Granular(signal~, ..) {
      seeds.push({ origin: WriteMask(index), node: signal, })
    }
  }
  seeds
}
