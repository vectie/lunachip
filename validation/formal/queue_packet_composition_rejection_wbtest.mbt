///|
test "packet composition rejects complete same-count source root boundary cone seed and memory drift" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let probe = queue_packet_composition_probe(fixture)
  let roots = probe.roots.iter().to_array()
  roots[0] = { ..roots[0], name: "different_original_role", }
  let candidates = probe.candidates.iter().to_array()
  guard candidates is [first, ..] else { fail("no original symbolic boundary") }
  candidates[0] = {
    ..first,
    original: @ir.Node::new(
      first.original.id(),
      first.original.signal_type(),
      Input("different_original_boundary"),
    ),
  }
  let history = probe.candidates.iter().to_array()
  history[0] = { ..first, provenance: [], }
  let cone = probe.cone.iter().to_array()
  guard cone.filter(node => node.kind() is Constant(_)) is [constant, ..] &&
    constant.kind() is Constant(value) else {
    fail("no original constant")
  }
  for index, node in cone {
    if node.id() == constant.id() {
      cone[index] = @ir.Node::new(
        node.id(),
        node.signal_type(),
        Constant(value ^ 1UL),
      )
    }
  }
  let lanes = probe.lanes.iter().to_array()
  let lane = lanes[0]
  let memory = lane.memory
  lanes[0] = {
    ..lane,
    memory: @ir.MemorySpec::new(
      memory.id(),
      memory.name(),
      memory.element_type(),
      memory.depth(),
      memory.domain(),
      memory.read_ports(),
      memory.write_ports(),
      NoChange,
      memory.multi_write_policy(),
      memory.bounds_policy(),
    ),
  }
  let reads = probe.lanes.iter().to_array()
  reads[0] = {
    ..lane,
    result: @ir.Node::new(
      lane.result.id(),
      lane.result.signal_type(),
      Input("not_registered_read_state"),
    ),
  }
  let observations = probe.observations.iter().to_array()
  observations[0] = { ..observations[0], name: "different_observation", }
  let seeds = probe.seeds.iter().to_array()
  seeds[0] = { ..seeds[0], origin: RootNext("not_source_clock"), }
  let changed_source = @ir.Module::checked_with_memories(
    "ChangedSourceName",
    probe.source.nodes(),
    probe.source.memories(),
    probe.source.outputs(),
  )
  let drifts : Array[QueuePacketCompositionProbe] = [
    { ..probe, roots: ReadOnlyArray::from_array(roots), },
    { ..probe, candidates: ReadOnlyArray::from_array(candidates), },
    { ..probe, candidates: ReadOnlyArray::from_array(history), },
    { ..probe, cone: ReadOnlyArray::from_array(cone), },
    { ..probe, lanes: ReadOnlyArray::from_array(lanes), },
    { ..probe, lanes: ReadOnlyArray::from_array(reads), },
    { ..probe, observations: ReadOnlyArray::from_array(observations), },
    { ..probe, seeds: ReadOnlyArray::from_array(seeds), },
    { ..probe, source: changed_source, },
    { ..probe, clock: probe.reset, },
    { ..probe, reset: probe.clock, },
    { ..probe, production_digest: "changed_full_source", },
    { ..probe, owner_inventory_digest: "changed_owner_inventory", },
    { ..probe, storage_inventory_digest: "changed_storage_inventory", },
  ]
  for drift in drifts {
    assert_eq(drift.roots.length(), probe.roots.length())
    assert_eq(drift.candidates.length(), probe.candidates.length())
    assert_eq(drift.cone.length(), probe.cone.length())
    assert_eq(drift.lanes.length(), probe.lanes.length())
    try queue_packet_composition_sequential_from_probe(fixture, drift) catch {
      InvalidFormalBundleIdentity(message) =>
        assert_eq(message, "packet composition: full original closure drift")
      _ => fail("unexpected rejection")
    } noraise {
      _ => fail("same-count original source drift bypassed rederivation")
    }
  }
  // Missing state, storage, or seed is also refused before any copied module.
  for
    drift in [
      { ..probe, roots: ReadOnlyArray::from_array(probe.roots[1:].to_owned()), },
      { ..probe, lanes: ReadOnlyArray::from_array(probe.lanes[1:].to_owned()), },
      { ..probe, seeds: ReadOnlyArray::from_array(probe.seeds[1:].to_owned()), },
    ] {
    try queue_packet_composition_sequential_from_probe(fixture, drift) catch {
      InvalidFormalBundleIdentity(_) => ()
      _ => fail("unexpected omission rejection")
    } noraise {
      _ => fail("essential omission bypassed source closure equality")
    }
  }
}
