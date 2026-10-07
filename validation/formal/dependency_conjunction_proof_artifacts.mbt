///|
// Private source collector only, with all three original isolated controls.
// No CLI/registry entry, task, runner, engine invocation or result receipt.
#warnings("-unused_value")
fn dependency_conjunction_proof_artifacts() -> ReadOnlyArray[
  FormalBundleArtifact,
] raise {
  let queue_fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let dependency_fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let inputs = dependency_conjunction_proof_inputs(
    queue_fixture, dependency_fixture,
  )
  let sequential = inputs.sequential
  let canonical = @ir_codec.serialize(
    @ir.Design::single("DependencyConjunctionSequential", sequential.hardware),
  )
  let report = dependency_conjunction_sequential_report(sequential)
  let artifacts : Array[FormalBundleArtifact] = [
    { path: "sequential.lcir", content: canonical, },
    {
      path: "sequential-production.sv",
      content: top_emitted_module(inputs.emitted).source(),
    },
    { path: "sequential-boolean.sv", content: inputs.boolean_source, },
    { path: "bridge.sv", content: inputs.positive, },
    { path: "negative-failed-generation.sv", content: inputs.negatives[0], },
    { path: "negative-new-intent-priority.sv", content: inputs.negatives[1], },
    { path: "negative-inner-identity.sv", content: inputs.negatives[2], },
    { path: "properties.lcfp", content: inputs.properties.manifest(), },
    {
      path: "names.lcnm",
      content: inputs.emitted.manifest().to_canonical_text(),
    },
  ]
  let cut_bits = sequential.cuts
    .iter()
    .fold(init=0, (count, cut) => count + cut.signal_type.width().bits())
  let inventory = StringBuilder()
  inventory.write_string(
    "SCOPE original-seven-dependency-conjunction-source-bound-supporting-inputs-not-proof-or-receipt\n" +
    "TOP \{inputs.top_identifier}\n" +
    "DUT direct-queued-concurrent-1x1-K2-host1024-q3\n" +
    "STATE 79-original-registers1202bits-four-original-q3-Bits64-memories12cells768bits-four-original-read-states256bits-total2226bits-no-zero-storage-premise\n" +
    "BOUNDARY 78-shared-source-bound-cuts\{cut_bits}bits-12-original-public-pins66-raw-foreign-registers-no-derived-control-or-observed-dependency-cut\n" +
    "CLOCK global-toggle-one-rising-per-two-global-steps\n" +
    "ASSUMPTIONS exactly-four-original-public-premises-initial-joint-reset-descriptor-hold-stability-response-hold-stability-response-flushed-during-reset-later-reset-symbolic\n" +
    "OBSERVER exact-original-decoder-complete-six-generation-ghost-Load-Compute-Store-accepted-ownership-and-saved-outer-authorization-no-current-writer-substitution\n" +
    "PROPERTIES exact-original-p0-through-p15-four-premises-seven-assertions-five-covers-no-filtered-or-strengthened-original-condition\n" +
    "GLOBAL-HOLD checked-2226-actual-original-storage-bits-no-new-premise\n" +
    "MUTATIONS exact-original-comparison-only-Failed-as-Success-new-intent-as-old-ticket-inner-reduction-bit0-on-actual-accept-three-separate-controls\n" +
    "LIMITATION raw-terminal-producer-overapproximation-no-physical-Store-DMA-data-numerical-MatMul-private-readiness-ID-uniqueness-progress-fairness-or-8x8-proof\n" +
    "QUALIFICATION native-correspondence-Boolean-helper-equivalence-prepared-model-review-and-engine-execution-required-before-proof-claim\n" +
    "PRODUCTION sha256 \{sequential.probe.packet.production_digest}\n" +
    "REVIEWED-INVENTORY sha256 \{sequential.inventory_digest}\n" +
    "PROJECTED-IR sha256 \{sha256_hex(canonical)}\n" +
    "PROJECTION-REPORT sha256 \{sha256_hex(report)}\n",
  )
  for root in sequential.probe.roots {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      root.node,
    )
    inventory.write_string(
      "REGISTER \{root.name} original \{root.node.ordinal()} local \{mapped.ordinal()} type \{Repr(root.signal_type)}\n",
    )
  }
  for cut in sequential.cuts {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      cut.node,
    )
    inventory.write_string(
      "CUT original \{cut.node.ordinal()} local \{mapped.ordinal()} type \{Repr(cut.signal_type)} roles \{cut.roles.iter().to_array().join(",")}\n",
    )
  }
  for lane in sequential.probe.packet.lanes {
    let memory = queue_storage_sequential_mapped_memory(
      sequential.original_to_local_memory,
      lane.memory.id(),
    )
    let read = dependency_generation_mapped(
      sequential.original_to_local,
      lane.result.id(),
    )
    inventory.write_string(
      "MEMORY lane \{lane.lane} original \{lane.memory.id().ordinal()} local \{memory.ordinal()} identifier \{inputs.memory_identifiers[lane.lane]} depth3 Bits64 original-full-ports-ReadOld-OneCycle-HoldLast-All-mask-Fault-bounds\n",
    )
    inventory.write_string(
      "READ-STATE lane \{lane.lane} original \{lane.result.id().ordinal()} local \{read.ordinal()} type \{Repr(lane.result.signal_type())}\n",
    )
  }
  for property in inputs.properties.properties() {
    let kind = match property.kind() {
      Assumption => "ASSUMPTION"
      Assertion => "ASSERTION"
      Cover => "COVER"
    }
    inventory.write_string(
      "\{kind} \{property.stable_name()} source \{property.source_name()}\n",
    )
  }
  for
    (variant, filename) in [
      (
        DependencyFormalFixture::NegativeFailedGeneration,
        "negative-failed-generation.sv",
      ),
      (NegativeNewIntentPriority, "negative-new-intent-priority.sv"),
      (NegativeInnerIdentity, "negative-inner-identity.sv"),
    ] {
    let selected = dependency_expected_failure(
      variant,
      inputs.properties.property_manifest(),
    )
    inventory.write_string(
      "NEGATIVE \{filename} selected-original-assertion \{selected}\n",
    )
  }
  for label in inputs.memory_bounds {
    inventory.write_string("MEMORY-ASSERTION \{label}\n")
  }
  for label in inputs.global_assertions {
    inventory.write_string("GLOBAL-ASSERTION \{label}\n")
  }
  for artifact in artifacts {
    inventory.write_string(
      "SOURCE \{artifact.path} sha256 \{sha256_hex(artifact.content)}\n",
    )
  }
  // Preserve complete accepted source-report bytes, including its historical
  // candidate heading, signatures, per-seed provenance and every local mapping.
  inventory.write_string(report)
  artifacts.push({ path: "bridge-inputs.txt", content: inventory.to_string(), })
  ReadOnlyArray::from_array(artifacts)
}
