///|
// Private supporting inputs only. No registry entry, public exporter, engine
// execution or result receipt. Nested reports retain full reviewed signatures
// and every original-to-local node/memory/output correspondence.
#warnings("-unused_value")
fn queue_packet_composition_proof_artifacts() -> ReadOnlyArray[
  FormalBundleArtifact,
] raise {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let inputs = queue_packet_composition_export(fixture)
  let sequential = inputs.sequential
  let canonical = @ir_codec.serialize(
    @ir.Design::single("QueuePacketCompositionSequential", sequential.hardware),
  )
  let report = queue_packet_composition_sequential_report(sequential)
  let artifacts : Array[FormalBundleArtifact] = [
    { path: "sequential.lcir", content: canonical, },
    {
      path: "sequential-production.sv",
      content: top_emitted_module(inputs.emitted).source(),
    },
    { path: "sequential-boolean.sv", content: inputs.boolean_source, },
    { path: "bridge.sv", content: inputs.positive, },
    { path: "negative-packet-word.sv", content: inputs.negative, },
    { path: "properties.lcfp", content: inputs.properties.manifest(), },
    {
      path: "names.lcnm",
      content: inputs.emitted.manifest().to_canonical_text(),
    },
  ]
  let registers = sequential.hardware
    .nodes()
    .filter(node => node.kind() is Register(_))
  let reads = sequential.hardware
    .nodes()
    .filter(node => node.kind() is MemoryRead(..))
  let register_bits = registers
    .iter()
    .fold(init=0, (count, node) => count + node.signal_type().width().bits())
  let read_bits = reads
    .iter()
    .fold(init=0, (count, node) => count + node.signal_type().width().bits())
  let cells = sequential.hardware
    .memories()
    .iter()
    .fold(init=0, (count, memory) => count + memory.depth().elements())
  let cell_bits = sequential.hardware
    .memories()
    .iter()
    .fold(init=0, (count, memory) => {
      count + memory.depth().elements() * memory.element_type().width().bits()
    })
  let public_cuts = sequential.probe.candidates.filter(candidate => {
    candidate.original.kind() is Input(_)
  })
  let foreign_cuts = sequential.probe.candidates.filter(candidate => {
    candidate.original.kind() is Register(_)
  })
  let cut_bits = sequential.cuts
    .iter()
    .fold(init=0, (count, cut) => count + cut.signal_type.width().bits())
  let assumptions = inputs.properties
    .properties()
    .filter(property => property.kind() is Assumption)
  let assertions = inputs.properties
    .properties()
    .filter(property => property.kind() is Assertion)
  let covers = inputs.properties
    .properties()
    .filter(property => property.kind() is Cover)
  if registers.length() != 54 ||
    register_bits != 876 ||
    sequential.hardware.memories().length() != 4 ||
    cells != 12 ||
    cell_bits != 768 ||
    reads.length() != 4 ||
    read_bits != 256 ||
    sequential.cuts.length() != 101 ||
    public_cuts.length() != 12 ||
    foreign_cuts.length() != 89 ||
    sequential.probe.observations.length() != 115 ||
    inputs.memory_bounds.length() != 8 ||
    assumptions.length() != 4 ||
    assertions.length() != 7 ||
    covers.length() != 1 ||
    covers[0].source_name() != "packet_provenance_transfer_cover" ||
    inputs.global_assertions != ["lc_packet_nonrising_hold"] ||
    inputs.strengthening_assertions != ["lc_packet_strengthening"] {
    raise InvalidFormalBundleIdentity(
      "packet composition artifacts: exact reviewed storage/boundary/property inventory",
    )
  }
  let inventory = StringBuilder()
  inventory.write_string(
    "SCOPE binary-original-seven-assert-packet-composition-supporting-inputs-not-proof-or-receipt\n" +
    "TOP \{inputs.top_identifier}\n" +
    "DUT direct-queued-concurrent-1x1-K2-host1024-q3\n" +
    "STATE 54-original-registers876bits-four-original-q3-Bits64-memories12cells768bits-four-original-read-states256bits-total1900bits-no-zero-storage-premise\n" +
    "BOUNDARY 101-shared-source-bound-cuts\{cut_bits}bits-12-original-public-pins89-foreign-registers-arbitrary-terminal-producer-payloads-not-Store-or-DMA-physical-data\n" +
    "CLOCK global-toggle-one-rising-per-two-global-steps\n" +
    "ASSUMPTIONS exactly-four-original-public-premises-first-sampled-joint-reset-descriptor-hold-stability-response-hold-stability-response-flushed-during-reset-later-reset-symbolic-no-private-state-storage-ID-uniqueness-readiness-progress-or-fairness-premise\n" +
    "OBSERVER original-lc_pp_select-lc_pp_watch-public256bit-saved-packet-ordinal-FIFO-and-retirement-ranks-reservation-entry-ticket-unchanged-record-immutability-monitor-nonfeeding\n" +
    "STRENGTHENING same-watch-only-two-bit-saved-FIFO-slot-actual-stage1-cell-location-stage2-ReadOld-response-stage3-held-head-stage4-ordinal-live-record-ticket-and-ID-checked-conclusions-never-premises\n" +
    "WITNESS original-p13-same-public-watch-response-capture-reservation-and-ordinal-public-retirement\n" +
    "MUTATION original-checked-saved-packet-lane2-bit0-XOR-only-after-genuine-watched-raw-matching-FIFO-response-no-DUT-saved-packet-rank-transfer-history-premise-or-raw-strengthening-change\n" +
    "LIMITATION packet-safety-only-no-Store-DMA-numerical-MatMul-fetched-device-liveness-fairness-8x8-or-full-device-proof\n" +
    "QUALIFICATION Boolean-helper-equivalence-prepared-model-review-and-engine-execution-pending\n" +
    "PRODUCTION sha256 \{sequential.probe.production_digest}\n" +
    "REVIEWED-INVENTORY sha256 \{sequential.inventory_digest}\n" +
    "PROJECTION-REPORT sha256 \{sha256_hex(report)}\n" +
    "PROJECTED-IR sha256 \{sha256_hex(canonical)}\n",
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
  for lane in sequential.probe.lanes {
    let mapped_memory = queue_storage_sequential_mapped_memory(
      sequential.original_to_local_memory,
      lane.memory.id(),
    )
    let mapped_read = dependency_generation_mapped(
      sequential.original_to_local,
      lane.result.id(),
    )
    inventory.write_string(
      "MEMORY lane \{lane.lane} original \{lane.memory.id().ordinal()} local \{mapped_memory.ordinal()} identifier \{inputs.memory_identifiers[lane.lane]} depth3 type Bits64 exact-original-ports-ReadOld-OneCycle-HoldLast-All-mask-Fault-bounds\n",
    )
    inventory.write_string(
      "READ-STATE lane \{lane.lane} original \{lane.result.id().ordinal()} local \{mapped_read.ordinal()} type \{Repr(lane.result.signal_type())} output fifo_response_data_\{lane.lane}\n",
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
  for label in inputs.strengthening_assertions {
    inventory.write_string("STRENGTHENING-ASSERTION \{label}\n")
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
  // Includes complete root specs, actual memory policies/ports/read nodes,
  // all cone operations, all candidate signatures and seed provenance, and
  // every mapped node, memory and output. The legacy candidate heading is
  // preserved exactly rather than rewriting accepted source-report bytes.
  inventory.write_string(report)
  artifacts.push({ path: "bridge-inputs.txt", content: inventory.to_string(), })
  ReadOnlyArray::from_array(artifacts)
}
