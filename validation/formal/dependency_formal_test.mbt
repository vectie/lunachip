///|
fn dependency_formal_artifact(
  bundle : @formal.DependencyFormalBundle,
  path : String,
) -> String raise {
  for artifact in bundle.artifacts() {
    if artifact.path() == path {
      return artifact.content()
    }
  }
  fail("missing dependency formal artifact " + path)
}

///|
test "dependency formal identities are exact and exclude public transport IDs" {
  let fixtures : Array[(@formal.DependencyFormalFixture, String)] = [
    (LatestWriter, "phase6-dependency-latest-writer"),
    (NegativeFailedGeneration, "phase6-dependency-negative-failed-generation"),
    (
      NegativeNewIntentPriority,
      "phase6-dependency-negative-new-intent-priority",
    ),
    (NegativeInnerIdentity, "phase6-dependency-negative-inner-identity"),
  ]
  for item in fixtures {
    let (fixture, id) = item
    assert_eq(fixture.id(), id)
    assert_eq(@formal.DependencyFormalFixture::from_id(id), Some(fixture))
  }
  assert_eq(
    @formal.DependencyFormalFixture::from_id(
      "phase6-flux-tile-public-transport",
    ),
    None,
  )
  assert_eq(
    @formal.DependencyFormalFixture::from_id("dependency-latest-writer"),
    None,
  )
}

///|
test "dependency formal bundle preserves production and exact bounded monitor scope" {
  // Generate each expensive graph only once in this test. These are structural
  // export/result-contract checks, not actual BMC/cover/negative execution.
  let valid = @formal.generate_dependency_formal_bundle(LatestWriter)
  let ordinary = @ir.Design::single(
    "QueuedConcurrentDependencyPilot",
    @flux_tile.queued_concurrent_tile(
      rows=1,
      columns=1,
      max_reduction=2,
      host_bytes=1024UL,
      queue_depth=3,
    ),
  )
  let emitted = @rtl.emit_design(ordinary)
  let production = emitted.modules()[0]
  let production_path = "production-" + production.filename()
  assert_eq(
    dependency_formal_artifact(valid, "design.lcir"),
    @ir_codec.serialize(ordinary),
  )
  assert_eq(
    dependency_formal_artifact(valid, production_path),
    production.source(),
  )
  assert_false(production.source().contains("lc_formal_observe_"))
  assert_false(valid.job_json().contains(production_path))
  assert_true(valid.job_json().contains("formal-dut.sv"))
  assert_eq(valid.top_identifier(), "lc_formal_dependency_top")
  let adapter = dependency_formal_artifact(valid, "formal-dut.sv")
  let source_set = dependency_formal_artifact(valid, "source-set.lcfs")
  let names = [
    "head_lane_0", "head_lane_1", "head_lane_2", "head_lane_3", "head_state", "head_reserve",
    "next_ticket", "head_ticket", "writer_status_0", "writer_ticket_0", "writer_status_1",
    "writer_ticket_1", "writer_status_2", "writer_ticket_2", "writer_status_3", "writer_ticket_3",
    "writer_status_4", "writer_ticket_4", "writer_status_5", "writer_ticket_5", "dependency_status_0",
    "dependency_ticket_0", "dependency_status_1", "dependency_ticket_1", "load_accept",
    "compute_accept", "store_accept", "load_terminal", "load_terminal_ticket", "load_terminal_fault",
    "compute_terminal", "compute_terminal_ticket", "compute_terminal_fault", "store_terminal",
    "store_terminal_ticket", "store_terminal_fault", "compute_preflight", "inner_command_valid",
    "inner_command_ready", "compute_latched_ticket", "compute_latched_a", "compute_latched_b",
    "compute_latched_c", "compute_latched_rows", "compute_latched_columns", "compute_latched_reduction",
    "local_reject", "local_fault",
  ]
  let view = @flux_tile.queued_concurrent_dependency_formal_fixture()
  assert_eq(view.observations().length(), names.length())
  for index, reference in view.observations() {
    let name = names[index]
    let mappings = emitted
      .manifest()
      .mappings()
      .filter(mapping => {
        mapping.kind() is Node &&
        mapping.module_ordinal() == emitted.manifest().top_module_ordinal() &&
        mapping.local_ordinal() == reference.node().ordinal()
      })
    assert_eq(mappings.length(), 1)
    assert_eq(
      adapter
      .split("assign lc_formal_observe_\{name} = \{mappings[0].identifier()};")
      .length(),
      2,
    )
    assert_true(
      source_set.contains(
        "OBSERVATION \{name} node \{reference.node().ordinal()} width \{reference.signal_type().width().bits()}\n",
      ),
    )
  }
  assert_eq(source_set.split("OBSERVATION ").length(), 49)
  assert_true(source_set.contains("FAMILY flux-tile-dependency\n"))
  assert_true(
    source_set.contains("PILOT-BOUND global-steps 256 dut-clocks 128\n"),
  )
  assert_true(source_set.contains("FAIRNESS none\n"))
  assert_true(
    source_set.contains(
      "no-FIFO-retirement-leases-ticket-wrap-liveness-or-full-product-proof",
    ),
  )
  assert_true(
    source_set.contains(
      "COVERS require-all-five-actual-witnesses-no-vacuous-pass\n",
    ),
  )
  assert_eq(@formal.regenerate_formal_artifacts(source_set), valid.artifacts())

  let properties = @formal_core.parse_formal_property_manifest(
    dependency_formal_artifact(valid, "properties.lcfp"),
  )
  assert_eq(properties.properties().map(item => item.name()), [
    "initial_joint_reset", "host_descriptor_stable_until_accept", "host_response_stable_until_accept",
    "host_response_flushed_during_reset", "latest_writer_matches_independent_model",
    "source_snapshots_prepublication_match_model", "consumer_admission_requires_successful_generations",
    "unavailable_dependency_rejection_exact", "new_intent_wins_matching_older_terminal",
    "inner_compute_preserves_saved_authorization", "terminal_ticket_matches_accepted_owner",
    "reachable_failed_reload_then_mat_fault4", "reachable_failed_mat_then_store_fault5",
    "reachable_invalid_syntax_preserves_usable_generation", "reachable_older_terminal_with_new_intent",
    "reachable_authorized_outer_to_inner_compute",
  ])
  assert_eq(valid.tasks().length(), 6)
  assert_eq(valid.expected_failure(), "none")
  for index, gate in valid.tasks() {
    assert_eq(gate.bound(), 256)
    assert_eq(gate.expected_status(), "pass")
    assert_eq(
      gate.task_class(),
      if index == 0 {
        BoundedSafetyTask
      } else {
        BoundedCoverTask
      },
    )
    assert_eq(
      @formal_core.parse_proof_task(gate.task().to_canonical_text()),
      gate.task(),
    )
    @formal.verify_task_property_binding(gate.task(), properties)
    guard gate.task() is Bounded(task) else {
      fail("dependency pilot must remain bounded")
    }
    assert_eq(task.assumptions().length(), 4)
    assert_eq(task.properties().length(), if index == 0 { 7 } else { 1 })
    guard task.timing_contract() is Some(timing) else {
      fail("dependency timing must be explicit")
    }
    assert_eq(timing.global_timestep().steps(), 2)
    assert_eq(timing.clocks().length(), 1)
    assert_eq(timing.legal_transition_assumptions().length(), 4)
    assert_eq(timing.fairness_assumptions().length(), 0)
    assert_true(
      dependency_formal_artifact(valid, gate.name() + ".lcfg").contains(
        "BOUND-MAPPING 256-global-steps-128-dut-clocks\n",
      ),
    )
  }
  let harness = dependency_formal_artifact(valid, "formal-harness.sv")
  assert_false(harness.contains("lc_dut."))
  assert_false(harness.contains("dependency_ready"))
  assert_false(harness.contains(" property (@"))
  for
    required in [
      "lc_raw_opcode = lc_o_head_lane_0[23:16]", "lc_raw_opcode > 8'd4 ? 4'd1", "lc_raw_rows <= 16'd8191",
      "lc_raw_syntax_fault == 4'd0", "lc_g_snapshot_status[0] <= lc_g_status[lc_raw_source0]",
      "lc_g_snapshot_ticket[1] <= lc_g_ticket[lc_raw_source1]", "lc_g_ticket[lc_slot] <= lc_g_next",
      "terminal_ticket == lc_g_ticket[lc_slot]", "lc_g_expected_reject && lc_raw_syntax_ok && lc_raw_is_writer",
      "if (lc_g_collect[lc_slot])", "if (lc_g_local_fail[lc_slot])", "if (lc_g_intent[lc_slot])",
      "lc_g_authorized_ticket <= lc_g_head", "lc_g_authorized_a <= lc_raw_a", "lc_g_authorized_reduction <= lc_raw_reduction[12:0]",
      "lc_o_compute_preflight == 4'd0", "lc_g_authorized && lc_inner_identity_matches",
      "lc_o_local_fault == lc_g_expected_local_fault", "lc_o_load_terminal_ticket == lc_g_load_ticket",
      "lc_priority_old_ticket != lc_priority_ticket", "always @($global_clock) lc_clock <= ~lc_clock;",
      ": assume (", ": assert (", ": cover (",
    ] {
    assert_true(harness.contains(required))
  }
  // Monitor captures genuine independent history. Checked mutations never
  // feed assumptions, source snapshots, owner snapshots, or state updates.
  let negatives : Array[(@formal.DependencyFormalFixture, String, String)] = [
    (
      NegativeFailedGeneration,
      "latest_writer_matches_independent_model",
      "lc_g_status[0] == 2'd3 && lc_o_status[0] == 2'd3 ? 2'd2 : lc_o_status[0]",
    ),
    (
      NegativeNewIntentPriority,
      "new_intent_wins_matching_older_terminal",
      "lc_priority_check ? lc_priority_old_ticket : lc_o_ticket[lc_priority_slot]",
    ),
    (
      NegativeInnerIdentity,
      "inner_compute_preserves_saved_authorization",
      "lc_o_compute_latched_reduction ^ (lc_inner_accept ? 13'd1 : 13'd0)",
    ),
  ]
  for item in negatives {
    let (fixture, expected_name, mutation) = item
    let negative = @formal.generate_dependency_formal_bundle(fixture)
    assert_eq(
      dependency_formal_artifact(negative, "design.lcir"),
      dependency_formal_artifact(valid, "design.lcir"),
    )
    assert_eq(
      dependency_formal_artifact(negative, production_path),
      production.source(),
    )
    assert_eq(dependency_formal_artifact(negative, "formal-dut.sv"), adapter)
    assert_eq(
      dependency_formal_artifact(negative, "properties.lcfp"),
      dependency_formal_artifact(valid, "properties.lcfp"),
    )
    assert_eq(negative.tasks().length(), 1)
    assert_eq(negative.tasks()[0].expected_status(), "fail")
    guard negative.tasks()[0].task() is Bounded(task) else {
      fail("sensitivity must remain bounded")
    }
    assert_eq(task.properties(), [negative.expected_failure()])
    @formal.verify_task_property_binding(negative.tasks()[0].task(), properties)
    assert_true(
      properties
      .properties()
      .any(item => {
        item.name() == expected_name &&
        item.stable_name() == negative.expected_failure()
      }),
    )
    let negative_harness = dependency_formal_artifact(
      negative, "formal-harness.sv",
    )
    assert_true(negative_harness.contains(mutation))
    assert_eq(
      negative_harness.split("  wire [1:0] lc_checked_status").to_array()[0],
      harness.split("  wire [1:0] lc_checked_status").to_array()[0],
    )
    assert_true(
      negative_harness.contains(
        "lc_g_authorized_reduction <= lc_raw_reduction[12:0]",
      ),
    )
    assert_true(
      negative_harness.contains(
        "lc_g_snapshot_status[0] <= lc_g_status[lc_raw_source0]",
      ),
    )
    let trace = @formal.SbyEvidence::checked(
      BaseCounterexampleTrace,
      "engine_0/trace.vcd",
      "example retained monitor counterexample mapping, not tool evidence",
    )
    match
      @formal.map_sby_result(negative.tasks()[0].task(), "FAIL", evidence=trace).result() {
      BoundedResult(value) =>
        assert_true(value.outcome() is SafetyCounterexample(_))
      _ =>
        fail("expected isolated bounded monitor counterexample classification")
    }
  }
  // Existing typed result mapping: generated artifacts are not execution, and
  // bounded status can never promote to an unbounded proof or a vacuous cover.
  match @formal.map_sby_result(valid.tasks()[0].task(), "PASS").result() {
    BoundedResult(value) => assert_eq(value.outcome(), BoundedPass)
    _ => fail("bounded dependency pilot cannot yield Proved")
  }
  for index in 1..<valid.tasks().length() {
    try @formal.map_sby_result(valid.tasks()[index].task(), "PASS") catch {
      MissingCoverWitness(_) => ()
      _ => fail("unexpected cover evidence error")
    } noraise {
      _ => fail("cover requires retained witness")
    }
  }
  let witness = @formal.SbyEvidence::checked(
    CoverWitnessTrace,
    "engine_0/trace.vcd",
    "example retained witness mapping, not tool evidence",
  )
  match
    @formal.map_sby_result(valid.tasks()[1].task(), "PASS", evidence=witness).result() {
    BoundedResult(value) => assert_true(value.outcome() is CoverWitness(_))
    _ => fail("expected bounded witness classification")
  }
}
