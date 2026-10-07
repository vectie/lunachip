///|
test "packet proof source rechecks complete source report maps and canonical emitter fail closed" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let exported = queue_packet_composition_export(fixture)
  let sequential = exported.sequential
  let changed_probe : QueuePacketCompositionProbe = {
    ..sequential.probe,
    production_digest: "changed",
  }
  let changed_report : QueuePacketCompositionSequential = {
    ..sequential,
    probe: changed_probe,
  }
  try
    queue_packet_composition_source(fixture, changed_report, exported.emitted)
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong report rejection")
  } noraise {
    _ => fail("changed complete report accepted")
  }
  let candidates = sequential.probe.candidates.iter().to_array()
  candidates[0] = { ..candidates[0], provenance: [], }
  let wrong_provenance : QueuePacketCompositionProbe = {
    ..sequential.probe,
    candidates: ReadOnlyArray::from_array(candidates),
  }
  assert_eq(
    wrong_provenance.candidates.length(),
    sequential.probe.candidates.length(),
  )
  try queue_packet_composition_require_inventory(wrong_provenance) catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong same-count inventory rejection")
  } noraise {
    _ => fail("same-count changed full provenance accepted")
  }
  let changed_digest : QueuePacketCompositionSequential = {
    ..sequential,
    inventory_digest: "changed",
  }
  try
    queue_packet_composition_source(fixture, changed_digest, exported.emitted)
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong inventory rejection")
  } noraise {
    _ => fail("changed inventory digest accepted")
  }
  let memory_mapping = sequential.original_to_local_memory.iter().to_array()
  memory_mapping[sequential.probe.lanes[0].memory.id().ordinal()] = None
  let changed_mapping : QueuePacketCompositionSequential = {
    ..sequential,
    original_to_local_memory: ReadOnlyArray::from_array(memory_mapping),
  }
  try
    queue_packet_composition_source(fixture, changed_mapping, exported.emitted)
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong memory map rejection")
  } noraise {
    _ => fail("missing original memory mapping accepted")
  }
  let node_mapping = sequential.original_to_local.iter().to_array()
  node_mapping[sequential.probe.clock.ordinal()] = None
  let changed_node_mapping : QueuePacketCompositionSequential = {
    ..sequential,
    original_to_local: ReadOnlyArray::from_array(node_mapping),
  }
  try
    queue_packet_composition_source(
      fixture,
      changed_node_mapping,
      exported.emitted,
    )
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong clock map rejection")
  } noraise {
    _ => fail("missing original clock mapping accepted")
  }
  let wrong_hardware = @ir.Module::checked_with_memories(
    "WrongPacketComposition",
    sequential.hardware.nodes(),
    sequential.hardware.memories(),
    sequential.hardware.outputs(),
  )
  let wrong_emitter = @rtl.emit_design(
    @ir.Design::single("QueuePacketCompositionSequential", wrong_hardware),
  )
  try
    queue_packet_composition_source(fixture, sequential, wrong_emitter)
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong emitter rejection")
  } noraise {
    _ => fail("wrong emitter accepted")
  }
  let nodes = sequential.hardware.nodes().iter().to_array()
  let root = nodes[queue_storage_test_node(
      sequential.original_to_local,
      sequential.probe.roots[0].node,
    ).ordinal()]
  guard root.kind() is Register(spec) && spec.reset() is Some(reset) else {
    fail("missing original reset")
  }
  let replacement = @ir.ResetSpec::explicit(
    reset.signal(),
    1UL,
    reset.mode(),
    reset.polarity(),
  )
  nodes[root.id().ordinal()] = @ir.Node::new(
    root.id(),
    root.signal_type(),
    Register(
      @ir.RegisterSpec::new(spec.domain(), spec.next(), reset=replacement),
    ),
  )
  let changed_hardware = @ir.Module::checked_with_memories(
    sequential.hardware.name(),
    nodes,
    sequential.hardware.memories(),
    sequential.hardware.outputs(),
  )
  let changed_sequential : QueuePacketCompositionSequential = {
    ..sequential,
    hardware: changed_hardware,
  }
  let changed_emitter = @rtl.emit_design(
    @ir.Design::single("QueuePacketCompositionSequential", changed_hardware),
  )
  try
    queue_packet_composition_source(
      fixture, changed_sequential, changed_emitter,
    )
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong jointly changed graph/emitter rejection")
  } noraise {
    _ => fail("changed original reset with matching emitter accepted")
  }
}
