///|
test "dependency proof source rejects same-count source provenance cuts maps emitter and reset drift" {
  let queue_fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let dependency_fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let inputs = dependency_conjunction_proof_inputs(
    queue_fixture, dependency_fixture,
  )
  let sequential = inputs.sequential
  let reject = fn(changed : DependencyConjunctionSequential) -> Unit raise {
    try
      dependency_conjunction_proof_source(
        queue_fixture,
        dependency_fixture,
        changed,
        inputs.emitted,
      )
    catch {
      InvalidFormalBundleIdentity(_) => ()
      _ => fail("wrong source drift rejection")
    } noraise {
      _ => fail("changed source accepted")
    }
  }
  reject({ ..sequential, inventory_digest: "changed", })
  let packet : QueuePacketCompositionProbe = {
    ..sequential.probe.packet,
    production_digest: "changed",
  }
  let changed_probe : DependencyConjunctionProbe = {
    ..sequential.probe,
    packet,
  }
  reject({ ..sequential, probe: changed_probe, })
  let candidates = sequential.probe.candidates.iter().to_array()
  candidates[0] = { ..candidates[0], provenance: [], }
  let changed_provenance : DependencyConjunctionProbe = {
    ..sequential.probe,
    candidates: ReadOnlyArray::from_array(candidates),
  }
  assert_eq(
    changed_provenance.candidates.length(),
    sequential.probe.candidates.length(),
  )
  reject({ ..sequential, probe: changed_provenance, })
  let cuts = sequential.cuts.iter().to_array()
  cuts[0] = { ..cuts[0], roles: ["wrong_public_role"], }
  reject({ ..sequential, cuts: ReadOnlyArray::from_array(cuts), })
  let nodes = sequential.original_to_local.iter().to_array()
  nodes[sequential.probe.packet.clock.ordinal()] = None
  reject({ ..sequential, original_to_local: ReadOnlyArray::from_array(nodes), })
  let memories = sequential.original_to_local_memory.iter().to_array()
  memories[sequential.probe.packet.lanes[0].memory.id().ordinal()] = None
  reject({
    ..sequential,
    original_to_local_memory: ReadOnlyArray::from_array(memories),
  })
  let other_hardware = @ir.Module::checked_with_memories(
    "ChangedDependencyEmitter",
    sequential.hardware.nodes(),
    sequential.hardware.memories(),
    sequential.hardware.outputs(),
  )
  let other_emitter = @rtl.emit_design(
    @ir.Design::single("DependencyConjunctionSequential", other_hardware),
  )
  try
    dependency_conjunction_proof_source(
      queue_fixture, dependency_fixture, sequential, other_emitter,
    )
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong emitter drift rejection")
  } noraise {
    _ => fail("changed emitter accepted")
  }
  let changed_nodes = sequential.hardware.nodes().iter().to_array()
  let root = changed_nodes[queue_storage_test_node(
      sequential.original_to_local,
      sequential.probe.roots[0].node,
    ).ordinal()]
  guard root.kind() is Register(spec) && spec.reset() is Some(reset) else {
    fail("actual reset missing")
  }
  let replacement = @ir.ResetSpec::explicit(
    reset.signal(),
    1UL,
    reset.mode(),
    reset.polarity(),
  )
  changed_nodes[root.id().ordinal()] = @ir.Node::new(
    root.id(),
    root.signal_type(),
    Register(
      @ir.RegisterSpec::new(spec.domain(), spec.next(), reset=replacement),
    ),
  )
  let changed_hardware = @ir.Module::checked_with_memories(
    sequential.hardware.name(),
    changed_nodes,
    sequential.hardware.memories(),
    sequential.hardware.outputs(),
  )
  let changed_emitter = @rtl.emit_design(
    @ir.Design::single("DependencyConjunctionSequential", changed_hardware),
  )
  let changed_sequential : DependencyConjunctionSequential = {
    ..sequential,
    hardware: changed_hardware,
  }
  try
    dependency_conjunction_proof_source(
      queue_fixture, dependency_fixture, changed_sequential, changed_emitter,
    )
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong jointly changed source/emitter rejection")
  } noraise {
    _ => fail("changed reset with matching emitter accepted")
  }
  try
    dependency_conjunction_proof_source(
      queue_fixture,
      dependency_fixture,
      sequential,
      inputs.emitted,
      variant=LatestWriterGenerationSupport,
    )
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong unsupported strengthening rejection")
  } noraise {
    _ => fail("unapproved eighth condition accepted")
  }
}
