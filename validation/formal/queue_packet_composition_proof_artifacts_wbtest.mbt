///|
test "private packet composition eight inputs bind complete source reports maps original properties and causal mutation" {
  let artifacts = queue_packet_composition_proof_artifacts()
  assert_eq(artifacts, queue_packet_composition_proof_artifacts())
  assert_eq(artifacts.map(artifact => artifact.path), [
    "sequential.lcir", "sequential-production.sv", "sequential-boolean.sv", "bridge.sv",
    "negative-packet-word.sv", "properties.lcfp", "names.lcnm", "bridge-inputs.txt",
  ])
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let inputs = queue_packet_composition_export(fixture)
  let sequential = inputs.sequential
  let report = queue_packet_composition_sequential_report(sequential)
  let marker = "CANDIDATE-PACKET-COMPOSITION source-bound-native-checkpoint-not-accepted-proof-boundary\n"
  guard artifacts[7].content.split(marker).to_array()
    is [inventory, report_tail] else {
    fail("one complete original source/projection report required")
  }
  assert_eq(marker + report_tail.to_owned(), report)
  assert_true(
    inventory.has_prefix(
      "SCOPE binary-original-seven-assert-packet-composition-supporting-inputs-not-proof-or-receipt\n",
    ),
  )
  assert_true(inventory.contains("TOP \{inputs.top_identifier}\n"))
  assert_true(
    inventory.contains(
      "PRODUCTION sha256 35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc\n",
    ),
  )
  assert_true(
    inventory.contains(
      "REVIEWED-INVENTORY sha256 01275b9792d9f2bd9bbb9b026a8de861931b0821dc9634f4439fa9f1c391e7b2\n",
    ),
  )
  assert_true(
    inventory.contains("PROJECTION-REPORT sha256 \{sha256_hex(report)}\n"),
  )
  assert_true(
    inventory.contains(
      "PROJECTED-IR sha256 \{sha256_hex(artifacts[0].content)}\n",
    ),
  )
  assert_true(inventory.contains("total1900bits-no-zero-storage-premise"))
  assert_true(
    inventory.contains(
      "12-original-public-pins89-foreign-registers-arbitrary-terminal-producer-payloads",
    ),
  )
  assert_true(
    inventory.contains("descriptor-hold-stability-response-hold-stability"),
  )
  assert_true(
    inventory.contains(
      "original-lc_pp_select-lc_pp_watch-public256bit-saved-packet",
    ),
  )
  assert_true(
    inventory.contains(
      "original-p13-same-public-watch-response-capture-reservation-and-ordinal-public-retirement",
    ),
  )
  assert_true(inventory.contains("checked-conclusions-never-premises"))
  assert_true(
    inventory.contains(
      "no-Store-DMA-numerical-MatMul-fetched-device-liveness-fairness-8x8-or-full-device-proof",
    ),
  )
  assert_true(
    inventory.contains(
      "QUALIFICATION Boolean-helper-equivalence-prepared-model-review-and-engine-execution-pending\n",
    ),
  )
  assert_eq(inventory.split("\nASSUMPTION ").count(), 5)
  assert_eq(inventory.split("\nASSERTION ").count(), 8)
  assert_eq(inventory.split("\nCOVER ").count(), 2)
  assert_eq(inventory.split("\nSTRENGTHENING-ASSERTION ").count(), 2)
  assert_eq(inventory.split("\nGLOBAL-ASSERTION ").count(), 2)
  assert_eq(inventory.split("\nMEMORY-ASSERTION ").count(), 9)
  assert_eq(inventory.split("\nCUT ").count(), 102)
  assert_eq(inventory.split("\nREGISTER ").count(), 55)
  assert_eq(inventory.split("\nMEMORY ").count(), 5)
  assert_eq(inventory.split("\nREAD-STATE ").count(), 5)
  assert_eq(inventory.split("\nSOURCE ").count(), 8)
  for artifact in artifacts[:7] {
    assert_eq(
      inventory
      .split("SOURCE \{artifact.path} sha256 \{sha256_hex(artifact.content)}\n")
      .count(),
      2,
    )
  }
  assert_eq(
    artifacts[0].content,
    @ir_codec.serialize(
      @ir.Design::single(
        "QueuePacketCompositionSequential",
        sequential.hardware,
      ),
    ),
  )
  assert_eq(artifacts[1].content, top_emitted_module(inputs.emitted).source())
  assert_eq(artifacts[2].content, inputs.boolean_source)
  assert_eq(artifacts[3].content, inputs.positive)
  assert_eq(artifacts[4].content, inputs.negative)
  assert_eq(artifacts[5].content, inputs.properties.manifest())
  assert_eq(artifacts[6].content, inputs.emitted.manifest().to_canonical_text())
  let (original_properties, _, _, _) = queue_property_export(PacketProvenance)
  let expected = original_properties
    .properties()
    .filter(property => {
      !(property.kind() is Cover) ||
      property.source_name() == "packet_provenance_transfer_cover"
    })
  assert_eq(inputs.properties.properties(), ReadOnlyArray::from_array(expected))
  for property in inputs.properties.properties() {
    let (kind, operation) = match property.kind() {
      Assumption => ("ASSUMPTION", "assume")
      Assertion => ("ASSERTION", "assert")
      Cover => ("COVER", "cover")
    }
    assert_eq(
      inventory
      .split(
        "\{kind} \{property.stable_name()} source \{property.source_name()}\n",
      )
      .count(),
      2,
    )
    let block = "  always @(posedge lc_clock) begin\n    \{property.stable_name()}: \{operation} ((lc_\{property.source_name()}) === 1'b1);\n  end\n"
    assert_eq(original_properties.source().split(block).count(), 2)
    assert_eq(artifacts[3].content.split(block).count(), 2)
    assert_eq(artifacts[4].content.split(block).count(), 2)
  }
  for label in inputs.memory_bounds {
    assert_eq(inventory.split("MEMORY-ASSERTION \{label}\n").count(), 2)
    assert_eq(artifacts[3].content.split(label + ": assert").count(), 2)
    assert_eq(artifacts[4].content.split(label + ": assert").count(), 2)
  }
  for label in inputs.strengthening_assertions {
    assert_eq(inventory.split("STRENGTHENING-ASSERTION \{label}\n").count(), 2)
    assert_eq(artifacts[3].content.split(label + ": assert").count(), 2)
    assert_eq(artifacts[4].content.split(label + ": assert").count(), 2)
  }
  for label in inputs.global_assertions {
    assert_eq(inventory.split("GLOBAL-ASSERTION \{label}\n").count(), 2)
    assert_eq(artifacts[3].content.split(label + ": assert").count(), 2)
    assert_eq(artifacts[4].content.split(label + ": assert").count(), 2)
  }
  for lane in sequential.probe.lanes {
    let read = dependency_generation_mapped(
      sequential.original_to_local,
      lane.result.id(),
    )
    let memory = queue_storage_sequential_mapped_memory(
      sequential.original_to_local_memory,
      lane.memory.id(),
    )
    assert_true(
      inventory.contains(
        "MEMORY lane \{lane.lane} original \{lane.memory.id().ordinal()} local \{memory.ordinal()} identifier \{inputs.memory_identifiers[lane.lane]} ",
      ),
    )
    assert_true(
      inventory.contains(
        "READ-STATE lane \{lane.lane} original \{lane.result.id().ordinal()} local \{read.ordinal()} type \{Repr(lane.result.signal_type())} output fifo_response_data_\{lane.lane}\n",
      ),
    )
  }
  let positive = "  wire [255:0] lc_pp_checked_response_packet = lc_pp_saved_packet;\n"
  let negative = "  wire [255:0] lc_pp_checked_response_packet = (lc_pp_saved_packet ^ (lc_pp_genuine_response ? (256'd1 << 128) : 256'd0));\n"
  assert_eq(artifacts[4].content.split(negative).count(), 2)
  assert_eq(
    artifacts[4].content.replace(old=negative, new=positive),
    artifacts[3].content,
  )
  assert_true(
    inventory.contains(
      "MUTATION original-checked-saved-packet-lane2-bit0-XOR-only-after-genuine-watched-raw-matching-FIFO-response",
    ),
  )
  // Opt-in stdout collector only: no filesystem writes or external jobs.
  if @env.get_env_var("LUNACHIP_PHASE6_PACKET_INPUTS_PRINT") == Some("1") {
    for artifact in artifacts {
      println(
        "PACKET-COMPOSITION-ARTIFACT \{artifact.path} sha256 \{sha256_hex(artifact.content)}",
      )
      println(artifact.content)
      println("END-PACKET-COMPOSITION-ARTIFACT \{artifact.path}")
    }
  }
}
