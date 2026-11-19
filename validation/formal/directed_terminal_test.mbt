///|
test "formal registry rejects directed and symbolic family cross-selection" {
  for
    source_set in [
      "LUNACHIP-PHASE6-FORMAL-SOURCE-SET 1\nFAMILY flux-tile-public-transport\nFIXTURE phase6-flux-tile-directed-first-terminal\n",
      "LUNACHIP-PHASE6-FORMAL-SOURCE-SET 1\nFAMILY flux-tile-directed-first-terminal\nFIXTURE phase6-flux-tile-public-transport\n",
      "LUNACHIP-PHASE6-FORMAL-SOURCE-SET 1\nFAMILY flux-tile-dependency\nFIXTURE phase6-flux-tile-directed-first-terminal\n",
      "LUNACHIP-PHASE6-FORMAL-SOURCE-SET 1\nFAMILY flux-tile-directed-first-terminal\nFIXTURE phase6-dependency-latest-writer\n",
    ] {
    try @formal.regenerate_formal_artifacts(source_set) catch {
      @formal.InvalidFormalBundleIdentity(_) => ()
      other => fail("unexpected registry error: \{Repr(other)}")
    } noraise {
      _ => fail("cross-family fixture must not be selected")
    }
  }
}

///|
test "directed terminal cover preserves production and original pilot inventory" {
  let bundle = @formal.generate_flux_tile_formal_bundle(DirectedFirstTerminal)
  let original = @formal.generate_flux_tile_formal_bundle(PublicTransport)
  assert_eq(
    bundle,
    @formal.generate_flux_tile_formal_bundle(DirectedFirstTerminal),
  )
  assert_eq(bundle.fixture().id(), "phase6-flux-tile-directed-first-terminal")
  assert_eq(
    @formal.FluxTileFormalFixture::from_id(bundle.fixture().id()),
    Some(DirectedFirstTerminal),
  )
  assert_eq(
    flux_tile_formal_artifact(bundle, "design.lcir"),
    flux_tile_formal_artifact(original, "design.lcir"),
  )
  assert_eq(
    flux_tile_formal_dut_artifacts(bundle),
    flux_tile_formal_dut_artifacts(original),
  )
  assert_eq(
    @formal.standard_flux_tile_formal_bundles().map(value => value.fixture()),
    [PublicTransport, NegativeRequestBounds, NegativeRequestStability],
  )
  assert_eq(
    @formal.regenerate_formal_artifacts(
      flux_tile_formal_artifact(bundle, "source-set.lcfs"),
    ),
    bundle.artifacts(),
  )
}

///|
test "directed terminal selects only a bounded legal-host reachability cover" {
  let bundle = @formal.generate_flux_tile_formal_bundle(DirectedFirstTerminal)
  assert_eq(bundle.tasks().length(), 1)
  let gate = bundle.tasks()[0]
  assert_eq(
    gate.name(),
    "phase6-flux-tile-directed-first-terminal-cover-successful-fence",
  )
  assert_eq(gate.task_class(), BoundedCoverTask)
  assert_eq(gate.bound(), 256)
  assert_eq(gate.timeout_seconds(), 600)
  assert_eq(gate.expected_status(), "pass")
  assert_eq(bundle.expected_failure(), "none")
  let properties = @formal_core.parse_formal_property_manifest(
    flux_tile_formal_artifact(bundle, "properties.lcfp"),
  )
  assert_eq(properties.properties().map(item => item.name()), [
    "initial_joint_reset", "host_config_stable_until_accept", "host_publication_stable_until_accept",
    "host_response_stable_until_accept", "host_response_flushed_during_reset", "directed_initial_reset_only",
    "directed_single_legal_config", "directed_single_publication", "directed_unstalled_ready",
    "directed_owned_response_available", "directed_matching_success_response", "directed_fence_memory_image",
    "directed_successful_first_fence",
  ])
  assert_eq(
    properties.properties().filter(item => item.kind() is Assertion).length(),
    0,
  )
  assert_eq(
    properties.properties().filter(item => item.kind() is Assumption).length(),
    12,
  )
  assert_eq(
    properties.properties().filter(item => item.kind() is Cover).length(),
    1,
  )
  @formal.verify_task_property_binding(gate.task(), properties)
  assert_eq(
    @formal_core.parse_proof_task(gate.task().to_canonical_text()),
    gate.task(),
  )
  guard gate.task() is Bounded(task) else {
    fail("directed reachability cannot be unbounded proof")
  }
  assert_eq(task.assumptions().length(), 12)
  assert_eq(task.properties().length(), 1)
  guard task.timing_contract() is Some(timing) else {
    fail("missing directed cover clock contract")
  }
  assert_eq(timing.global_timestep().steps(), 2)
  assert_eq(timing.clocks().length(), 1)
  assert_eq(timing.legal_transition_assumptions().length(), 12)
  assert_eq(timing.fairness_assumptions().length(), 0)
  let execution = flux_tile_formal_artifact(bundle, gate.name() + ".lcfg")
  assert_true(
    execution.contains("BOUND-MAPPING 256-global-steps-128-dut-clocks\n"),
  )
  assert_true(execution.contains("EXPECTED-FAILURE none\n"))
  let source_set = flux_tile_formal_artifact(bundle, "source-set.lcfs")
  for
    required in [
      "FAMILY flux-tile-directed-first-terminal\n", "RESET first-edge-joint-reset-then-no-reset\n",
      "HOST directed-config512-origin0-one-published-fence-id1\n", "HOST-RESPONSE actual-request-owned-immediate-matching-tag-status0-fixed-byte-image\n",
      "COVER actual-retirement-after-32-ordered-read-requests-and-32-owned-acknowledgements\n",
      "DUT-PROGRESS-ASSUMPTIONS none\n", "ORIGINAL-SYMBOLIC-TASKS unchanged-and-not-replaced\n",
      "directed-fetched-fence-reachability-only-no-safety-dependency-liveness-write-or-product-proof",
    ] {
    assert_true(source_set.contains(required))
  }
  try @formal.map_sby_result(gate.task(), "PASS") catch {
    MissingCoverWitness(_) => ()
    _ => fail("unexpected directed cover result error")
  } noraise {
    _ => fail("directed cover cannot accept PASS without an actual witness")
  }
}

///|
test "directed terminal host observes real saved ownership and ordered bytes" {
  let bundle = @formal.generate_flux_tile_formal_bundle(DirectedFirstTerminal)
  let harness = flux_tile_formal_artifact(bundle, "formal-harness.sv")
  assert_false(harness.contains("(* anyseq *)"))
  let original = @formal.generate_flux_tile_formal_bundle(PublicTransport)
  assert_eq(
    flux_tile_formal_artifact(original, "formal-harness.sv")
    .split("(* anyseq *)")
    .count(),
    13,
  )
  for
    assignment in [
      "assign lc_reset = !lc_seen_edge;", "assign lc_config_valid = !lc_reset && !lc_directed_config_accepted;",
      "assign lc_config_base = 32'd512;", "assign lc_config_origin = 32'd0;", "assign lc_publish_valid = !lc_reset && lc_directed_config_accepted && !lc_directed_publication_accepted;",
      "assign lc_publish_producer = 32'd1;", "assign lc_completion_ready = 1'b1;",
      "assign lc_memory_request_ready = 1'b1;", "assign lc_memory_response_valid = !lc_reset && lc_owned;",
      "assign lc_memory_response_tag = lc_owned ? lc_directed_saved_tag : 32'd0;",
      "assign lc_memory_response_fault = 2'd0;", "assign lc_memory_response_data = lc_owned ? lc_directed_fence_byte : 32'd0;",
    ] {
    assert_eq(harness.split(assignment).count(), 2)
  }
  for
    required in [
      "always @($global_clock) lc_clock <= ~lc_clock;", "lc_request_accept = !lc_reset && lc_memory_request_valid && lc_memory_request_ready",
      "lc_response_accept = !lc_reset && lc_memory_response_valid && lc_memory_response_ready",
      "if (lc_request_accept) lc_owned <= 1'b1;", "else if (lc_response_accept) lc_owned <= 1'b0;",
      "lc_directed_saved_address <= lc_memory_request_address;", "lc_directed_saved_tag <= lc_memory_request_tag;",
      "lc_directed_saved_address == 32'd513 ? 32'd2", "lc_directed_saved_address == 32'd514 ? 32'd4",
      "lc_directed_saved_address == 32'd516 ? 32'd1", "lc_config_base == 32'd512 && lc_config_origin == 32'd0",
      "lc_memory_response_valid == (!lc_reset && lc_owned)", "lc_directed_requests == 6'd32",
      "lc_directed_acks == 6'd32 && !lc_owned", "&& !lc_request_accept && !lc_response_accept",
      "lc_directed_sequence_ok <= 1'b0;", "lc_memory_request_address == (32'd512 + {26'd0, lc_directed_requests})",
      "lc_directed_saved_address == (32'd512 + {26'd0, lc_directed_acks})", "lc_completion_valid && lc_completion_ready",
      "lc_completion_id == 32'd1 && lc_completion_fault == 4'd0", "lc_producer_count == 32'd1 && lc_consumer_count == 32'd1",
      ": assume (", ": cover (",
    ] {
    assert_true(harness.contains(required))
  }
  assert_false(harness.contains(": assert ("))
  assert_false(harness.contains("lc_dut."))
  assert_false(harness.contains("lc_formal_observe_"))
  assert_false(harness.contains("assume (lc_completion_valid"))
  assert_false(harness.contains("property (@"))
}
