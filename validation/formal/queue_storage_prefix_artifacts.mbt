///|
/// Export source-bound original q3 Bits64 FIFO-to-head proof inputs.
/// This is export only: no proof, task receipt, full packet-retirement
/// provenance, fairness or completed Phase 6 gate follows from generation.
pub fn generate_queue_storage_prefix_proof_artifacts() -> ReadOnlyArray[
  FormalBundleArtifact,
] raise {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let exported = queue_storage_prefix_export(fixture)
  let sequential = exported.sequential
  let design = @ir.Design::single("QueueStorageSequential", sequential.hardware)
  let artifacts : Array[FormalBundleArtifact] = [
    { path: "sequential.lcir", content: @ir_codec.serialize(design), },
    {
      path: "sequential-production.sv",
      content: top_emitted_module(exported.emitted).source(),
    },
    { path: "sequential-boolean.sv", content: exported.boolean_source, },
    { path: "bridge.sv", content: exported.positive, },
    { path: "negative-watched-response.sv", content: exported.negative, },
    { path: "properties.lcfp", content: exported.properties.manifest(), },
    {
      path: "names.lcnm",
      content: exported.emitted.manifest().to_canonical_text(),
    },
  ]
  let inventory = StringBuilder()
  inventory.write_string(
    "SCOPE binary-original-FIFO-to-head-prefix-inputs-not-proof-or-full-retirement\n" +
    "TOP \{exported.top_identifier}\n" +
    "DUT direct-queued-concurrent-1x1-K2-host1024-q3\n" +
    "STATE 28-original-registers309bits-four-original-q3-Bits64-memories768bits-four-original-read-states256bits-no-zero-storage-premise\n" +
    "BOUNDARY 59-shared-raw-cuts805bits-seven-public-inputs52-foreign-registers-arbitrary-terminal-poison-and-dispatch-timing\n" +
    "CLOCK global-toggle-one-rising-per-two-global-steps\n" +
    "ASSUMPTIONS one-first-sampled-joint-reset-only-later-reset-symbolic-no-ID-uniqueness-producer-stability-readiness-progress-internal-state-or-storage-premise\n" +
    "OBSERVER independent-public256bit-admission-ordinal-slot-rank-read-result-and-held-head-nonfeeding\n" +
    "MUTATION checked-response-lane2-bit0-only-after-genuine-watch-admission-pop-and-raw-matching-response\n" +
    "LIMITATION prefix-only-no-retirement-payload-ownership-generation-Store-DMA-fetched-fairness-8x8-or-full-device-proof\n" +
    "QUALIFICATION Boolean-helper-equivalence-prepared-model-review-and-engine-execution-pending\n" +
    "PRODUCTION sha256 \{sequential.probe.production_digest}\n" +
    "REVIEWED-INVENTORY sha256 \{sequential.inventory_digest}\n",
  )
  for root in sequential.probe.roots {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      root.node,
    )
    inventory.write_string(
      "REGISTER \{root.name} original \{root.node.ordinal()} local \{mapped.ordinal()} width \{root.signal_type.width().bits()}\n",
    )
  }
  for cut in sequential.cuts {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      cut.node,
    )
    inventory.write_string(
      "CUT original \{cut.node.ordinal()} local \{mapped.ordinal()} width \{cut.signal_type.width().bits()} roles \{cut.roles.iter().to_array().join(",")}\n",
    )
  }
  for index, lane in sequential.probe.lanes {
    let mapped = queue_storage_sequential_mapped_memory(
      sequential.original_to_local_memory,
      lane.memory.id(),
    )
    inventory.write_string(
      "MEMORY lane \{lane.lane} original \{lane.memory.id().ordinal()} local \{mapped.ordinal()} identifier \{exported.memory_identifiers[index]} depth3 width64 ReadOld OneCycle HoldLast\n",
    )
  }
  for property in exported.properties.properties() {
    let kind = match property.kind() {
      Assumption => "ASSUMPTION"
      Assertion => "ASSERTION"
      Cover => "COVER"
    }
    inventory.write_string(
      "\{kind} \{property.stable_name()} source \{property.source_name()}\n",
    )
  }
  for label in exported.global_assertions {
    inventory.write_string("GLOBAL-ASSERTION \{label}\n")
  }
  for label in exported.memory_bounds {
    inventory.write_string("MEMORY-ASSERTION \{label}\n")
  }
  for artifact in artifacts {
    inventory.write_string(
      "SOURCE \{artifact.path} sha256 \{sha256_hex(artifact.content)}\n",
    )
  }
  inventory.write_string(queue_storage_probe_report(sequential.probe))
  artifacts.push({ path: "bridge-inputs.txt", content: inventory.to_string(), })
  ReadOnlyArray::from_array(artifacts)
}
