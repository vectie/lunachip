///|
// Source-bound supporting inputs only. No task, receipt or theorem is created.
#warnings("-unused_field")
priv struct DependencyConjunctionProofInputs {
  sequential : DependencyConjunctionSequential
  emitted : @rtl.EmittedDesign
  boolean_source : String
  positive : String
  negatives : ReadOnlyArray[String]
  properties : @formal_core.FormalExport
  top_identifier : String
  memory_identifiers : ReadOnlyArray[String]
  memory_bounds : ReadOnlyArray[String]
  global_assertions : ReadOnlyArray[String]
}

///|
fn dependency_conjunction_proof_require_inventory(
  sequential : DependencyConjunctionSequential,
) -> Unit raise {
  let report = dependency_conjunction_report(sequential.probe)
  let canonical = @ir_codec.serialize(
    @ir.Design::single("DependencyConjunctionSequential", sequential.hardware),
  )
  if sha256_hex(report) !=
    "442cb1ac95b10b5e4c8cd9983ca80c9e2b93bbf07e08588d21214ad92f9e1fa4" ||
    sequential.inventory_digest != sha256_hex(report) ||
    sha256_hex(canonical) !=
    "26214abad606bbe414fa9a7186d47fc9d7766bae3481d38f7b5aaa5c636860cd" ||
    sequential.probe.packet.production_digest !=
    "35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc" {
    raise InvalidFormalBundleIdentity(
      "dependency proof inputs: complete reviewed source/report/IR drift",
    )
  }
  // These are measured inventory cross-checks, not the acceptance authority.
  // The literal hashes bind original/materialized signatures. The source gate
  // below additionally rederives cuts and BOTH original-to-local maps fully.
  if sequential.probe.roots.length() != 79 ||
    sequential.cuts.length() != 78 ||
    sequential.probe.candidates
    .filter(leaf => leaf.original.kind() is Input(_))
    .length() !=
    12 ||
    sequential.probe.candidates
    .filter(leaf => leaf.original.kind() is Register(_))
    .length() !=
    66 ||
    sequential.probe.cone.length() != 1572 ||
    sequential.hardware.nodes().length() != 1734 ||
    sequential.hardware.outputs().length() != 274 ||
    sequential.probe.observations.length() != 163 {
    raise InvalidFormalBundleIdentity(
      "dependency proof inputs: measured original union inventory",
    )
  }
}

///|
fn dependency_conjunction_proof_source(
  queue_fixture : @flux_tile.QueueConservationFixture,
  dependency_fixture : @flux_tile.QueuedConcurrentFormalFixture,
  sequential : DependencyConjunctionSequential,
  emitted : @rtl.EmittedDesign,
  variant~ : DependencyFormalFixture = LatestWriter,
) -> String raise {
  if variant is LatestWriterGenerationSupport {
    raise InvalidFormalBundleIdentity(
      "dependency proof inputs: only original seven conditions",
    )
  }
  let expected = dependency_conjunction_sequential(
    queue_fixture, dependency_fixture,
  )
  dependency_conjunction_proof_require_inventory(expected)
  dependency_conjunction_proof_require_inventory(sequential)
  let canonical = @ir.Design::single(
    "DependencyConjunctionSequential",
    expected.hardware,
  )
  if sequential.hardware != expected.hardware ||
    sequential.probe != expected.probe ||
    sequential.cuts != expected.cuts ||
    sequential.original_to_local != expected.original_to_local ||
    sequential.original_to_local_memory != expected.original_to_local_memory ||
    emitted != @rtl.emit_design(canonical) {
    raise InvalidFormalBundleIdentity(
      "dependency proof inputs: fresh original binding/mapping/emission drift",
    )
  }
  let observer = dependency_conjunction_proof_bindings(sequential, emitted) +
    dependency_conjunction_proof_original_monitor(sequential, emitted, variant) +
    dependency_conjunction_proof_retention(sequential, emitted)
  dependency_conjunction_proof_adapter(sequential, emitted, observer)
}

///|
fn dependency_conjunction_proof_memory_identifiers(
  sequential : DependencyConjunctionSequential,
  emitted : @rtl.EmittedDesign,
) -> ReadOnlyArray[String] raise {
  let names : Array[String] = []
  for lane in sequential.probe.packet.lanes {
    let mapped = queue_storage_sequential_mapped_memory(
      sequential.original_to_local_memory,
      lane.memory.id(),
    )
    guard emitted
      .manifest()
      .mappings()
      .filter(mapping => {
        mapping.kind() is Memory &&
        mapping.module_ordinal() == emitted.manifest().top_module_ordinal() &&
        mapping.local_ordinal() == mapped.ordinal() &&
        mapping.source_name() == lane.memory.name()
      })
      is [mapping] else {
      raise InvalidFormalBundleIdentity(
        "dependency proof inputs: exact original array name binding",
      )
    }
    names.push(mapping.identifier())
  }
  ReadOnlyArray::from_array(names)
}

///|
#warnings("-unused_value")
fn dependency_conjunction_proof_inputs(
  queue_fixture : @flux_tile.QueueConservationFixture,
  dependency_fixture : @flux_tile.QueuedConcurrentFormalFixture,
) -> DependencyConjunctionProofInputs raise {
  let sequential = dependency_conjunction_sequential(
    queue_fixture, dependency_fixture,
  )
  dependency_conjunction_proof_require_inventory(sequential)
  let emitted = @rtl.emit_design(
    @ir.Design::single("DependencyConjunctionSequential", sequential.hardware),
  )
  let top = top_emitted_module(emitted)
  let (boolean_source, _) = dependency_boolean_helpers(
    sequential.hardware,
    top.source(),
  )
  let bounds : Array[String] = []
  for memory in sequential.hardware.memories() {
    for read in memory.read_ports() {
      bounds.push(
        "lc_mem\{memory.id().ordinal()}_read\{read.id().ordinal()}_bounds",
      )
    }
    for write in memory.write_ports() {
      bounds.push(
        "lc_mem\{memory.id().ordinal()}_write\{write.id().ordinal()}_bounds",
      )
    }
  }
  let (properties, legal, assertions, covers) = dependency_property_export(
    LatestWriter,
  )
  if legal.length() != 4 ||
    assertions.length() != 7 ||
    covers.length() != 5 ||
    properties.properties().length() != 16 ||
    bounds.length() != 8 ||
    !bounds.all(label => top.source().split(label + ": assert").count() == 2) {
    raise InvalidFormalBundleIdentity(
      "dependency proof inputs: original property/memory bound inventory",
    )
  }
  let negatives : Array[String] = []
  for
    variant in [
      DependencyFormalFixture::NegativeFailedGeneration,
      NegativeNewIntentPriority,
      NegativeInnerIdentity,
    ] {
    negatives.push(
      dependency_conjunction_proof_source(
        queue_fixture,
        dependency_fixture,
        sequential,
        emitted,
        variant~,
      ),
    )
  }
  {
    sequential,
    emitted,
    boolean_source,
    properties,
    positive: dependency_conjunction_proof_source(
      queue_fixture, dependency_fixture, sequential, emitted,
    ),
    negatives: ReadOnlyArray::from_array(negatives),
    top_identifier: top.identifier(),
    memory_identifiers: dependency_conjunction_proof_memory_identifiers(
      sequential, emitted,
    ),
    memory_bounds: ReadOnlyArray::from_array(bounds),
    global_assertions: ["lc_dependency_nonrising_hold"],
  }
}
