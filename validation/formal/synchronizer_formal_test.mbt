///|
fn synchronizer_artifact(
  bundle : SynchronizerFormalBundle,
  path : String,
) -> String raise {
  for artifact in bundle.artifacts() {
    if artifact.path() == path {
      return artifact.content()
    }
  }
  fail("missing synchronizer artifact \{path}")
}

///|
test "timed synchronizer bundle binds named schema two properties and clocks" {
  let first = generate_synchronizer_bundle(ValidSynchronizer)
  let second = generate_synchronizer_bundle(ValidSynchronizer)
  assert_eq(first, second)
  assert_eq(first.top_identifier(), "lc_formal_synchronizer_top")
  assert_eq(first.expected_failure(), "none")
  assert_eq(first.tasks().length(), 2)
  assert_eq(first.tasks()[0].task_class(), BoundedSafetyTask)
  assert_eq(first.tasks()[1].task_class(), BoundedCoverTask)
  let task_text = synchronizer_artifact(first, "valid-synchronizer-bmc.lcft")
  assert_true(task_text.has_prefix("LUNACHIP-FORMAL-TASK 2\n"))
  match @formal_core.parse_proof_task(task_text) {
    Bounded(task) => {
      guard task.timing_contract() is Some(timing) else {
        fail("synchronizer task omitted its timing contract")
      }
      assert_eq(timing.global_timestep().steps(), 2)
      assert_eq(timing.clocks().map(clock => clock.domain().ordinal()), [0, 2])
      assert_eq(timing.legal_transition_assumptions().length(), 2)
      assert_eq(timing.fairness_assumptions().length(), 2)
      assert_eq(timing.coincidence_policy(), AtomicGlobalPreState)
    }
    _ => fail("expected bounded synchronizer task")
  }
  let properties = @formal_core.parse_formal_property_manifest(
    synchronizer_artifact(first, "properties.lcfp"),
  )
  assert_eq(properties.properties().map(property => property.name()), [
    "source_clock_transition_legal", "destination_clock_transition_legal", "source_clock_fair",
    "destination_clock_fair", "pipeline_matches_previous_destination_samples", "synchronous_reset_clears_all_stages",
    "output_changes_only_on_destination_edge", "stable_source_converges_within_three_destination_edges",
    "coincident_source_destination_edge",
  ])
  let source_set = synchronizer_artifact(first, "source-set.lcfs")
  assert_true(source_set.contains("GLOBAL-TIMESTEP engine-steps 2\n"))
  assert_true(source_set.contains("COINCIDENCE atomic-global-pre-state\n"))
  assert_true(
    source_set.contains(
      "CLAIM-BOUNDARY digital-two-state-bounded-no-metastability-mtbf-placement-or-timing\n",
    ),
  )
  assert_eq(regenerate_formal_artifacts(source_set), first.artifacts())
}

///|
test "synchronizer harness states exact pipeline reset edge convergence and cover checks" {
  let bundle = generate_synchronizer_bundle(ValidSynchronizer)
  let harness = synchronizer_artifact(bundle, "formal-harness.sv")
  for
    required in [
      "lc_reference_stage0 <= lc_source_value;", "lc_reference_stage1 <= lc_reference_stage0;",
      "lc_reference_stage2 <= lc_reference_stage1;", "lc_reset_base = !lc_reset_sampled",
      "lc_last_destination_rise || (lc_synchronized == lc_previous_output)", "(lc_stable_destination_edges < 3) || (lc_synchronized == lc_tracked_source)",
      "lc_last_source_rise && lc_last_destination_rise", "always_ff @(posedge lc_formal_step_clock)",
      "always_ff @(negedge lc_formal_step_clock)",
    ] {
    assert_true(harness.contains(required))
  }
  assert_false(harness.contains("lc_dut."))
  let dut_sources = bundle
    .artifacts()
    .filter(artifact => {
      artifact.path().has_suffix(".sv") &&
      artifact.path() != "formal-harness.sv"
    })
  assert_eq(dut_sources.length(), 1)
  let dut = dut_sources[0].content()
  for
    port in [
      "lc_formal_observe_stage0", "lc_formal_observe_stage1", "lc_formal_observe_stage2",
      "lc_formal_observe_source_value",
    ] {
    assert_true(harness.contains(".\{port}("))
    assert_true(dut.contains("output logic \{port}"))
    assert_true(dut.contains("assign \{port} = lc_n"))
  }
}

///|
test "negative synchronizer fixtures isolate one declared stable label" {
  let fixtures : Array[SynchronizerFormalFixture] = [
    BrokenSynchronizerPipeline,
    BrokenSynchronizerDestinationEdge,
    BrokenSynchronizerConvergence,
  ]
  for fixture in fixtures {
    let bundle = generate_synchronizer_bundle(fixture)
    assert_eq(bundle.tasks().length(), 1)
    assert_eq(bundle.tasks()[0].expected_status(), "fail")
    assert_false(bundle.expected_failure() == "none")
    let execution = synchronizer_artifact(bundle, "\{fixture.id()}-bmc.lcfg")
    assert_true(
      execution.contains("EXPECTED-FAILURE \{bundle.expected_failure()}\n"),
    )
    let matching = @formal_core.parse_formal_property_manifest(
        synchronizer_artifact(bundle, "properties.lcfp"),
      )
      .properties()
      .filter(property => property.stable_name() == bundle.expected_failure())
    assert_eq(matching.length(), 1)
    assert_eq(matching[0].kind(), Assertion)
  }
}

///|
test "formal regeneration registry rejects unknown families and fixtures" {
  for
    source_set in [
      "LUNACHIP-PHASE9-FORMAL-SOURCE-SET 1\nFIXTURE future\nEND\n", "LUNACHIP-PHASE5-FORMAL-SOURCE-SET 1\nFAMILY bit-synchronizer\nFIXTURE forged\nEND\n",
    ] {
    try regenerate_formal_artifacts(source_set) catch {
      _ => ()
    } noraise {
      _ => fail("unknown formal bundle identity must be rejected")
    }
  }
}
