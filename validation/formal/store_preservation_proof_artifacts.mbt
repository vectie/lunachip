///|
// Private supporting inputs, not a public exporter, task or result receipt.
// Every source digest is over the exact returned bytes; the complete original
// control/storage projection report remains nested, not replaced by counts.
#warnings("-unused_value")
fn store_preservation_proof_artifacts() -> ReadOnlyArray[FormalBundleArtifact] raise {
  let fixture = @flux_tile.queued_concurrent_store_preservation_fixture()
  let inputs = store_preservation_proof_inputs(fixture)
  let projection = inputs.projection
  let design = @ir.Design::single("StoreStorageProjection", projection.hardware)
  let canonical = @ir_codec.serialize(design)
  let report = store_storage_projection_report(projection)
  let artifacts : Array[FormalBundleArtifact] = [
    { path: "sequential.lcir", content: canonical, },
    {
      path: "sequential-production.sv",
      content: top_emitted_module(inputs.emitted).source(),
    },
    { path: "sequential-boolean.sv", content: inputs.boolean_source, },
    { path: "bridge.sv", content: inputs.positive, },
    { path: "negative-pending-word.sv", content: inputs.negative, },
    { path: "properties.lcfp", content: inputs.properties.manifest(), },
    {
      path: "names.lcnm",
      content: inputs.emitted.manifest().to_canonical_text(),
    },
  ]
  let registers = projection.hardware
    .nodes()
    .filter(node => node.kind() is Register(_))
  let reads = projection.hardware
    .nodes()
    .filter(node => node.kind() is MemoryRead(..))
  let cells = projection.plan.memories
    .iter()
    .fold(init=0, (count, memory) => count + memory.depth().elements())
  if projection.plan.arithmetic.length() != 4 ||
    registers.length() != 162 ||
    projection.plan.memories.length() != 6 ||
    reads.length() != 6 ||
    cells != 20 ||
    inputs.memory_bounds.length() != 12 ||
    inputs.global_assertions != ["lc_store_nonrising_hold"] {
    raise InvalidFormalBundleIdentity(
      "Store inputs: exact original storage inventory",
    )
  }
  let inventory = StringBuilder()
  inventory.write_string(
    "SCOPE binary-original-Store-data-control-supporting-inputs-not-proof-or-receipt\n" +
    "TOP \{inputs.top_identifier}\n" +
    "DUT direct-queued-concurrent-2x2-K2-host1024-q3-all-legal-rectangle-shapes\n" +
    "STATE 162-original-registers-six-original-memories20cells1024cell-bits-six-original-read-states320bits-no-zero-storage-premise\n" +
    "BOUNDARY four-shared-raw-SInt32-production-values128bits-arbitrary-each-sample-no-other-foreign-state-or-control-cuts\n" +
    "CLOCK global-toggle-one-rising-per-two-global-steps\n" +
    "ASSUMPTIONS one-first-sampled-joint-reset-only-later-reset-symbolic-no-producer-stability-readiness-progress-internal-state-or-storage-premise\n" +
    "OBSERVER independent-capture-produced-words-per-generation-rectangle-coverage-read-identity-real-pregrant-arbiter-payload-and-good-ACK-nonfeeding\n" +
    "WITNESS one-read-one-opposite-accepted-generation-pregrant-intermediate-and-final-capture-real-grant-public-write-good-ACK-then-successful2x2-rectangle-engine-completion-not-public-ordinal-retirement\n" +
    "MUTATION checked-pending-response-bit0-only-after-same-live-read-ID-slot-address-and-one-opposite-generation-intermediate-final-capture-while-original-loader-Wait-blocks-Store-no-raw-DUT-or-premise-change\n" +
    "LIMITATION binary-Store-preservation-only-no-numeric-MatMul-liveness-fairness-public-ordinal-retirement-or-full-device-proof\n" +
    "QUALIFICATION Boolean-helper-equivalence-prepared-model-review-and-engine-execution-pending\n" +
    "PRODUCTION sha256 \{projection.plan.probe.source_digest}\n" +
    "PROJECTION-REPORT sha256 \{sha256_hex(report)}\n" +
    "PROJECTED-IR sha256 \{sha256_hex(canonical)}\n",
  )
  for cut in projection.plan.arithmetic {
    let mapped = dependency_generation_mapped(
      projection.original_to_local,
      cut.id(),
    )
    inventory.write_string(
      "CUT original \{cut.id().ordinal()} local \{mapped.ordinal()} type \{Repr(cut.signal_type())} original-kind \{Repr(cut.kind())}\n",
    )
  }
  for original in projection.plan.selected {
    if projection.plan.arithmetic.any(cut => cut.id() == original.id()) {
      continue
    }
    let mapped = dependency_generation_mapped(
      projection.original_to_local,
      original.id(),
    )
    match original.kind() {
      Register(_) =>
        inventory.write_string(
          "REGISTER original \{original.id().ordinal()} local \{mapped.ordinal()} type \{Repr(original.signal_type())}\n",
        )
      MemoryRead(..) =>
        inventory.write_string(
          "READ-STATE original \{original.id().ordinal()} local \{mapped.ordinal()} type \{Repr(original.signal_type())}\n",
        )
      _ => ()
    }
  }
  let names = store_preservation_memory_identifiers(projection, inputs.emitted)
  for index, memory in projection.plan.memories {
    let mapped = queue_storage_sequential_mapped_memory(
      projection.original_to_local_memory,
      memory.id(),
    )
    inventory.write_string(
      "MEMORY original \{memory.id().ordinal()} local \{mapped.ordinal()} identifier \{names[index]} depth \{memory.depth().elements()} type \{Repr(memory.element_type())} exact-original-policies-and-ports-in-projection-report\n",
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
  for label in inputs.global_assertions {
    inventory.write_string("GLOBAL-ASSERTION \{label}\n")
  }
  for label in inputs.memory_bounds {
    inventory.write_string("MEMORY-ASSERTION \{label}\n")
  }
  for artifact in artifacts {
    inventory.write_string(
      "SOURCE \{artifact.path} sha256 \{sha256_hex(artifact.content)}\n",
    )
  }
  inventory.write_string(report)
  artifacts.push({ path: "bridge-inputs.txt", content: inventory.to_string(), })
  ReadOnlyArray::from_array(artifacts)
}
