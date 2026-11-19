///|
fn flux_tile_formal_artifact(
  bundle : @formal.FluxTileFormalBundle,
  path : String,
) -> String raise {
  for artifact in bundle.artifacts() {
    if artifact.path() == path {
      return artifact.content()
    }
  }
  fail("missing FluxTile formal artifact " + path)
}

///|
fn flux_tile_formal_dut_artifacts(
  bundle : @formal.FluxTileFormalBundle,
) -> ReadOnlyArray[@formal.FormalBundleArtifact] {
  let artifacts : Array[@formal.FormalBundleArtifact] = []
  for artifact in bundle.artifacts() {
    if artifact.path().has_suffix(".sv") &&
      artifact.path() != "formal-harness.sv" {
      artifacts.push(artifact)
    }
  }
  ReadOnlyArray::from_array(artifacts)
}

///|
test "FluxTile public transport bundle preserves canonical production graph" {
  let bundle = @formal.generate_flux_tile_formal_bundle(PublicTransport)
  assert_eq(bundle, @formal.generate_flux_tile_formal_bundle(PublicTransport))
  let hardware = @flux_tile.ring_concurrent_tile(
    rows=1,
    columns=1,
    max_reduction=2,
    host_bytes=1024UL,
    ring_depth=4,
    queue_depth=2,
  )
  let design = @ir.Design::single("phase6-fetched-concurrent-1x1-k2", hardware)
  assert_eq(
    flux_tile_formal_artifact(bundle, "design.lcir"),
    @ir_codec.serialize(design),
  )
  let emitted = @rtl.emit_design(design)
  let dut_sources = flux_tile_formal_dut_artifacts(bundle)
  assert_eq(dut_sources.length(), 1)
  assert_eq(dut_sources[0].path(), emitted.modules()[0].filename())
  assert_eq(dut_sources[0].content(), emitted.modules()[0].source())
  assert_eq(bundle.top_identifier(), "lc_formal_flux_tile_top")
  let harness = flux_tile_formal_artifact(bundle, "formal-harness.sv")
  assert_false(harness.contains("lc_dut."))
  assert_false(harness.contains("lc_formal_observe_"))
  for mapping in emitted.manifest().mappings() {
    if mapping.kind() is InputPort || mapping.kind() is OutputPort {
      assert_eq(
        harness
        .split(".\{mapping.identifier()}(lc_\{mapping.source_name()})")
        .count() -
        1,
        1,
      )
    }
  }
  assert_eq(
    @formal.regenerate_formal_artifacts(
      flux_tile_formal_artifact(bundle, "source-set.lcfs"),
    ),
    bundle.artifacts(),
  )
}

///|
test "FluxTile public transport tasks select bounded safety and nonvacuity covers" {
  let bundle = @formal.generate_flux_tile_formal_bundle(PublicTransport)
  assert_eq(bundle.tasks().length(), 4)
  assert_eq(bundle.tasks()[0].task_class(), BoundedSafetyTask)
  assert_eq(bundle.tasks().map(task => task.bound()), [256, 256, 256, 256])
  assert_eq(bundle.expected_failure(), "none")
  let properties = @formal_core.parse_formal_property_manifest(
    flux_tile_formal_artifact(bundle, "properties.lcfp"),
  )
  assert_eq(properties.properties().map(item => item.name()), [
    "initial_joint_reset", "host_config_stable_until_accept", "host_publication_stable_until_accept",
    "host_response_stable_until_accept", "host_response_flushed_during_reset", "transport_request_address_in_aperture",
    "transport_request_payload_legal", "transport_request_stable_until_accept", "command_completion_stable_until_accept",
    "transport_at_most_one_outstanding", "transport_response_has_owner", "transport_no_response_edge_request",
    "joint_reset_suppresses_public_transfers", "reachable_held_request", "reachable_owned_response",
    "reachable_first_command_terminal",
  ])
  for index, gate in bundle.tasks() {
    let task = gate.task()
    assert_eq(@formal_core.parse_proof_task(task.to_canonical_text()), task)
    @formal.verify_task_property_binding(task, properties)
    guard task is Bounded(value) else {
      fail("pilot must not claim unbounded proof")
    }
    guard value.timing_contract() is Some(timing) else {
      fail("missing explicit timing")
    }
    assert_eq(timing.global_timestep().steps(), 2)
    assert_eq(timing.clocks().length(), 1)
    assert_eq(timing.legal_transition_assumptions().length(), 5)
    assert_eq(timing.fairness_assumptions().length(), 0)
    assert_eq(value.assumptions().length(), 5)
    assert_eq(value.properties().length(), if index == 0 { 8 } else { 1 })
    assert_eq(gate.expected_status(), "pass")
    if index > 0 {
      assert_eq(gate.task_class(), BoundedCoverTask)
    }
    let execution = flux_tile_formal_artifact(bundle, gate.name() + ".lcfg")
    assert_true(
      execution.contains("BOUND-MAPPING 256-global-steps-128-dut-clocks\n"),
    )
    assert_true(execution.contains("TIMING-CONTRACT formal-task-schema-2\n"))
  }
  let source_set = flux_tile_formal_artifact(bundle, "source-set.lcfs")
  assert_true(
    source_set.contains("PILOT-BOUND global-steps 256 dut-clocks 128\n"),
  )
  assert_true(source_set.contains("FAIRNESS none\n"))
  assert_true(
    source_set.contains("PILOT-LIMIT write-path-assertion-branch-unexercised\n"),
  )
  assert_true(
    source_set.contains(
      "REMAINING actual-write-cover-and-safety-horizon-reaching-write\n",
    ),
  )
  assert_true(
    source_set.contains(
      "bounded-public-transport-no-private-queue-dependency-liveness-or-full-product-proof",
    ),
  )
}

///|
test "FluxTile public transport harness samples genuine preedge handshakes and hold release" {
  let bundle = @formal.generate_flux_tile_formal_bundle(PublicTransport)
  let harness = flux_tile_formal_artifact(bundle, "formal-harness.sv")
  for
    required in [
      "always @($global_clock) lc_clock <= ~lc_clock;", "always_ff @(posedge lc_clock)",
      "logic lc_owned = 1'b0;", "lc_request_accept = !lc_reset && lc_memory_request_valid && lc_memory_request_ready",
      "lc_response_accept = !lc_reset && lc_memory_response_valid && lc_memory_response_ready",
      "if (lc_request_accept) lc_owned <= 1'b1;", "else if (lc_response_accept) lc_owned <= 1'b0;",
      "lc_previous_request_payload <= lc_request_payload;", "lc_memory_request_valid && lc_checked_request_payload == lc_previous_request_payload",
      "lc_completion_valid && lc_completion_payload == lc_previous_completion_payload",
      "wire [33:0] lc_checked_request_end", "lc_checked_request_end <= 34'd1024",
      "lc_memory_request_bytes == 3'd1 && lc_memory_request_mask == 4'd1", "lc_memory_request_bytes == 3'd4 && lc_memory_request_mask == 4'd15",
      "lc_memory_request_address[1:0] == 2'd0", "lc_memory_request_data == 32'd0",
      "!lc_memory_response_ready || lc_owned", "!(lc_request_accept && lc_response_accept)",
      ": assume (", ": assert (", ": cover (",
    ] {
    assert_true(harness.contains(required))
  }
  assert_false(harness.contains(" property (@"))
  assert_false(harness.contains("assume (lc_completion_valid"))
  assert_false(harness.contains("assume (lc_memory_response_tag"))
}

///|
test "FluxTile negative fixtures alter isolated monitor inputs not production RTL" {
  let valid = @formal.generate_flux_tile_formal_bundle(PublicTransport)
  let fixtures : Array[@formal.FluxTileFormalFixture] = [
    NegativeRequestBounds,
    NegativeRequestStability,
  ]
  for fixture in fixtures {
    let bundle = @formal.generate_flux_tile_formal_bundle(fixture)
    assert_eq(bundle.tasks().length(), 1)
    assert_eq(bundle.tasks()[0].expected_status(), "fail")
    assert_eq(
      flux_tile_formal_artifact(bundle, "design.lcir"),
      flux_tile_formal_artifact(valid, "design.lcir"),
    )
    assert_eq(
      flux_tile_formal_dut_artifacts(bundle),
      flux_tile_formal_dut_artifacts(valid),
    )
    assert_eq(
      flux_tile_formal_artifact(bundle, "properties.lcfp"),
      flux_tile_formal_artifact(valid, "properties.lcfp"),
    )
    assert_eq(
      @formal.regenerate_formal_artifacts(
        flux_tile_formal_artifact(bundle, "source-set.lcfs"),
      ),
      bundle.artifacts(),
    )
    guard bundle.tasks()[0].task() is Bounded(task) else {
      fail("expected bounded sensitivity task")
    }
    assert_eq(task.properties(), [bundle.expected_failure()])
    let properties = @formal_core.parse_formal_property_manifest(
      flux_tile_formal_artifact(bundle, "properties.lcfp"),
    )
    @formal.verify_task_property_binding(bundle.tasks()[0].task(), properties)
    let expected_name = if fixture is NegativeRequestBounds {
      "transport_request_address_in_aperture"
    } else {
      "transport_request_stable_until_accept"
    }
    assert_true(
      properties
      .properties()
      .any(item => {
        item.name() == expected_name &&
        item.stable_name() == bundle.expected_failure()
      }),
    )
    let harness = flux_tile_formal_artifact(bundle, "formal-harness.sv")
    if fixture is NegativeRequestBounds {
      assert_true(
        harness.contains(
          "lc_checked_request_address = {1'b1, lc_memory_request_address}",
        ),
      )
      assert_false(harness.contains("lc_previous_request_hold ? 32'd1"))
    } else {
      assert_true(
        harness.contains(
          "lc_memory_request_data ^ (lc_previous_request_hold ? 32'd1 : 32'd0)",
        ),
      )
      assert_true(
        harness.contains("lc_previous_request_payload <= lc_request_payload;"),
      )
      assert_true(
        harness.contains(
          "lc_checked_request_address = {1'b0, lc_memory_request_address}",
        ),
      )
    }
  }
}

///|
test "FluxTile bounded outcomes retain witnesses and counterexamples without proof promotion" {
  let valid = @formal.generate_flux_tile_formal_bundle(PublicTransport)
  match @formal.map_sby_result(valid.tasks()[0].task(), "PASS").result() {
    BoundedResult(value) => assert_eq(value.outcome(), BoundedPass)
    _ => fail("bounded pilot cannot produce Proved")
  }
  try @formal.map_sby_result(valid.tasks()[1].task(), "PASS") catch {
    MissingCoverWitness(_) => ()
    _ => fail("unexpected cover evidence error")
  } noraise {
    _ => fail("vacuous cover PASS must not be accepted")
  }
  let witness = @formal.SbyEvidence::checked(
    CoverWitnessTrace,
    "engine_0/trace.vcd",
    "retained witness",
  )
  match
    @formal.map_sby_result(valid.tasks()[1].task(), "PASS", evidence=witness).result() {
    BoundedResult(value) => assert_true(value.outcome() is CoverWitness(_))
    _ => fail("expected bounded cover witness")
  }
  let negative = @formal.generate_flux_tile_formal_bundle(NegativeRequestBounds)
  let trace = @formal.SbyEvidence::checked(
    BaseCounterexampleTrace,
    "engine_0/trace.vcd",
    "retained wrapper counterexample",
  )
  match
    @formal.map_sby_result(negative.tasks()[0].task(), "FAIL", evidence=trace).result() {
    BoundedResult(value) =>
      assert_true(value.outcome() is SafetyCounterexample(_))
    _ => fail("expected bounded wrapper sensitivity counterexample")
  }
}
