///|
test "two client arbiter exporter preserves exact original state and returns proof inputs only" {
  let artifacts = @formal.generate_two_client_arbiter_proof_artifacts()
  assert_eq(artifacts, @formal.generate_two_client_arbiter_proof_artifacts())
  assert_eq(artifacts.map(artifact => artifact.path()), [
    "sequential.lcir", "sequential-production.sv", "sequential-boolean.sv", "bridge.sv",
    "negative-stalled-payload.sv", "bridge-inputs.txt",
  ])
  fn content(path : String) -> String raise {
    guard artifacts.filter(artifact => artifact.path() == path) is [artifact] else {
      fail("missing arbiter proof input")
    }
    artifact.content()
  }
  let design = @ir_codec.parse(content("sequential.lcir"))
  assert_eq(design.name(), "TwoClientArbiterSequential")
  guard design.top_module() is Some(hardware) else {
    fail("missing arbiter slice")
  }
  let registers = hardware.nodes().filter(node => node.kind() is Register(_))
  assert_eq(registers.length(), 11)
  assert_eq(
    registers.fold(init=0, (bits, node) => {
      bits + node.signal_type().width().bits()
    }),
    172,
  )
  assert_eq(hardware.nodes().length(), 108)
  assert_eq(
    hardware.nodes().filter(node => node.kind() is Input(_)).length(),
    16,
  )
  assert_eq(hardware.outputs().length(), 29)
  guard hardware
    .outputs()
    .filter(output => output.name() == "raw_response_data_observation")
    is [observation] else {
    fail("missing unique raw response data observation")
  }
  assert_eq(observation.signal_type(), @wire.bits(32))
  assert_eq(observation.driver().ordinal(), 8)
  assert_eq(hardware.memories().length(), 0)
  assert_eq(hardware.domains().length(), 1)
  let inventory = content("bridge-inputs.txt")
  assert_true(
    inventory.contains(
      "SCOPE binary-local-original-two-client-DMA-arbiter-inputs-not-proof-or-full-device-gate\n",
    ),
  )
  assert_true(
    inventory.contains(
      "EMISSION-VIEW exact-108-original-nodes-and-28-core-aliases-plus-one-raw_response_data_observation-direct-boundary-alias-29-outputs-no-new-node-state-or-theorem\n",
    ),
  )
  assert_true(
    inventory.contains(
      "ASSUMPTIONS startup-reset-only-no-client-stability-readiness-response-match-history-fairness-or-payload-premise\n",
    ),
  )
  assert_true(
    inventory.contains(
      "TAG-RESTORATION original-saved-local_tag-versus-independent-raw-grant-tag; client-record-tag-and-data-mapping-source-reviewed-alias-contract-not-named-IR-ports-or-separate-passthrough-theorem\n",
    ),
  )
  assert_true(
    inventory.contains(
      "LIMITATION direct-1x1-two-client-component-not-fetched-arbiter-no-response-data-stability-DMA-cursor-bounds-Store-lease-memory-fairness-or-full-device-claim\n",
    ),
  )
  assert_true(
    inventory.contains(
      "QUALIFICATION Boolean-helper-equivalence-and-engine-execution-not-established-by-export\n",
    ),
  )
  assert_true(
    inventory.contains(
      "REVIEWED-INVENTORY sha256 cc867599656fda1bc3897b42d971feb75736de72e22112a6ef1d0364af32d138\n",
    ),
  )
  assert_true(
    inventory.contains(
      "PRODUCTION sha256 35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc\n",
    ),
  )
  assert_eq(inventory.split("\nREGISTER ").length() - 1, 11)
  assert_eq(inventory.split("\nCUT node ").length() - 1, 15)
  assert_eq(inventory.split("\nCONSTANT node ").length() - 1, 7)
  // The appended original probe also has EVENT lines; count the mapped roster.
  assert_eq(
    inventory
    .split("\n")
    .filter(line => line.has_prefix("EVENT ") && line.contains(" original "))
    .length(),
    17,
  )
  assert_eq(inventory.split("\nASSUMPTION ").length() - 1, 1)
  assert_eq(inventory.split("\nASSERTION ").length() - 1, 8)
  assert_eq(inventory.split("\nSOURCE ").length() - 1, 5)
  assert_true(inventory.contains("ASSUMPTION lc_initial_joint_reset\n"))
  for artifact in artifacts {
    if artifact.path() != "bridge-inputs.txt" {
      let digest = @crypto.bytes_to_hex_string(
        @crypto.sha256(@utf8.encode(artifact.content())),
      )
      assert_true(
        inventory.contains("SOURCE \{artifact.path()} sha256 \{digest}\n"),
      )
    }
  }
  let positive = content("bridge.sv")
  let negative = content("negative-stalled-payload.sv")
  for bridge in [positive, negative] {
    assert_true(bridge.contains("module lc_two_client_arbiter_bridge;"))
    assert_eq(bridge.split(": assert (").length() - 1, 8)
    assert_eq(bridge.split(": assume (").length() - 1, 1)
    for
      label in [
        "lc_arbiter_payload", "lc_arbiter_history", "lc_arbiter_routes", "lc_arbiter_arbitration",
        "lc_arbiter_edge_updates", "lc_arbiter_reset_zero", "lc_arbiter_established",
        "lc_arbiter_nonrising_hold",
      ] {
      assert_true(inventory.contains("ASSERTION \{label}\n"))
      assert_true(bridge.contains("\{label}: assert ("))
    }
    assert_true(bridge.contains("lc_initial_joint_reset: assume ("))
    // This compares original saved state with independently sampled grant tag,
    // not an invented named client response-tag or response-data output.
    assert_true(bridge.contains("lc_o_local_tag == lc_accepted_local_tag"))
  }
  assert_eq(
    negative.replace_all(
      old="(lc_raw_payload ^ (lc_genuine_stalled_offer ? (104'd1 << 32) : 104'd0))",
      new="lc_raw_payload",
    ),
    positive,
  )
  assert_false(
    artifacts.any(artifact => {
      artifact.path().has_suffix(".lcfr") ||
      artifact.path().has_suffix(".lcfg") ||
      artifact.path().has_suffix(".sby") ||
      artifact.path() == "job.json" ||
      artifact.path() == "source-set.lcfs"
    }),
  )
  assert_true(content("sequential-production.sv").contains("always_ff"))
  assert_true(
    content("sequential-production.sv") != content("sequential-boolean.sv"),
  )
}
