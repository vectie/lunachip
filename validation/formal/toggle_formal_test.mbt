///|
fn toggle_artifact(bundle : ToggleFormalBundle, path : String) -> String raise {
  for artifact in bundle.artifacts() {
    if artifact.path() == path {
      return artifact.content()
    }
  }
  fail("missing toggle formal artifact \{path}")
}

///|
test "toggle bundles bind public depths payloads and exact named properties" {
  let scalar = generate_toggle_formal_bundle(ValidToggleScalar2)
  let record = generate_toggle_formal_bundle(ValidToggleRecord3)
  let deep = generate_toggle_formal_bundle(ValidToggleRecord4)
  assert_eq(scalar, generate_toggle_formal_bundle(ValidToggleScalar2))
  assert_eq(scalar.top_identifier(), "lc_formal_toggle_top")
  assert_eq(scalar.completion_bound(), 24)
  assert_eq(record.completion_bound(), 28)
  assert_eq(deep.completion_bound(), 32)
  assert_eq(scalar.tasks().length(), 1)
  assert_eq(record.tasks().length(), 4)
  assert_eq(deep.tasks().length(), 1)
  for
    fixture_case in [
      (scalar, 2, "scalar-word8"),
      (record, 3, "record-word8-tag3"),
      (deep, 4, "record-word8-tag3"),
    ] {
    let (bundle, stages, payload) = fixture_case
    let source_set = toggle_artifact(bundle, "source-set.lcfs")
    assert_true(source_set.contains("FAMILY toggle-handshake\n"))
    assert_true(source_set.contains("SYNCHRONIZER-STAGES \{stages}\n"))
    assert_true(source_set.contains("PAYLOAD \{payload}\n"))
    assert_true(source_set.contains("COINCIDENCE atomic-global-pre-state\n"))
    assert_true(
      source_set.contains(
        "RESET coordinated-idle-initialization-unilateral-reset-excluded\n",
      ),
    )
    assert_eq(regenerate_formal_artifacts(source_set), bundle.artifacts())
  }
  let properties = @formal_core.parse_formal_property_manifest(
    toggle_artifact(record, "properties.lcfp"),
  )
  assert_eq(properties.properties().map(property => property.name()), [
    "source_clock_transition_legal", "destination_clock_transition_legal", "source_clock_fair",
    "destination_clock_fair", "coordinated_reset_initialization", "source_protocol_hold",
    "destination_eventual_ready", "one_item_in_flight_capacity", "source_payload_stable_while_outstanding",
    "destination_response_stable_under_backpressure", "no_duplicate_acknowledge_or_consume",
    "watched_transaction_data_integrity", "watched_transaction_completes_under_bounded_clocks_and_eventual_ready",
    "coincident_source_destination_edge", "simultaneous_destination_consume_and_refill",
    "watched_transaction_accept_capture_consume",
  ])
}

///|
test "toggle tasks use schema two sparse clocks and individual cover tasks" {
  let bundle = generate_toggle_formal_bundle(ValidToggleRecord3)
  let task_text = toggle_artifact(bundle, "valid-toggle-record-3-bmc.lcft")
  assert_true(task_text.has_prefix("LUNACHIP-FORMAL-TASK 2\n"))
  match @formal_core.parse_proof_task(task_text) {
    Bounded(task) => {
      guard task.timing_contract() is Some(timing) else {
        fail("toggle task omitted timing contract")
      }
      assert_eq(timing.global_timestep().steps(), 2)
      assert_eq(timing.clocks().map(clock => clock.domain().ordinal()), [0, 2])
      assert_eq(timing.legal_transition_assumptions().length(), 2)
      assert_eq(timing.fairness_assumptions().length(), 2)
      assert_eq(timing.coincidence_policy(), AtomicGlobalPreState)
    }
    _ => fail("expected bounded toggle task")
  }
  let cover_tasks = bundle
    .tasks()
    .filter(task => task.task_class() is BoundedCoverTask)
  assert_eq(cover_tasks.length(), 3)
  for task in cover_tasks {
    guard task.task() is Bounded(value) else { fail("cover must be bounded") }
    assert_eq(value.properties().length(), 1)
    assert_eq(task.expected_status(), "pass")
  }
}

///|
test "toggle harness binds production RTL atomic ghosts and claim boundaries" {
  let bundle = generate_toggle_formal_bundle(ValidToggleRecord3)
  let harness = toggle_artifact(bundle, "formal-harness.sv")
  for
    required in [
      "always_ff @(posedge lc_formal_step_clock)", "always_ff @(negedge lc_formal_step_clock)",
      "lc_source_accept_event = lc_protocol_active && lc_source_rise_now && lc_source_accept",
      "lc_destination_capture_event = lc_protocol_active && lc_destination_rise_now && lc_destination_capture",
      "case ({lc_source_accept_event, lc_destination_capture_event})", "lc_watched_word <= lc_scheduled_source_word",
      "lc_cover_consume_refill <= 1'b1", "lc_watched_age >= 8'd28",
    ] {
    assert_true(harness.contains(required))
  }
  let source_set = toggle_artifact(bundle, "source-set.lcfs")
  assert_true(
    source_set.contains(
      "CLAIM-BOUNDARY digital-two-state-bounded-no-metastability-mtbf-placement-reset-recovery-or-timing\n",
    ),
  )
  assert_true(
    source_set.contains(
      "COMPLETION-BOUND scheduling-intervals 28 formula 4*(stages+3+1)\n",
    ),
  )
}

///|
test "six toggle negatives isolate one declared assertion label" {
  let valid = generate_toggle_formal_bundle(ValidToggleRecord3)
  let valid_ir = toggle_artifact(valid, "design.lcir")
  let valid_rtl = valid
    .artifacts()
    .filter(artifact => artifact.path().has_suffix(".sv"))
    .filter(artifact => artifact.path() != "formal-harness.sv")
  assert_eq(valid_rtl.length(), 1)
  let fixtures : Array[ToggleFormalFixture] = [
    BrokenToggleCapacity,
    BrokenToggleSourcePayload,
    BrokenToggleBackpressure,
    BrokenToggleDuplicate,
    BrokenToggleDataIntegrity,
    BrokenToggleCompletion,
  ]
  let mutant_markers = [
    "lc_capacity_source_accept_event = lc_source_accept_event || (lc_transport_outstanding && lc_source_rise_now && lc_scheduled_source_valid)",
    "lc_monitored_held_word = lc_held_word ^", "lc_monitored_backpressure_word = lc_destination_word ^",
    "lc_monitored_consume_event = lc_destination_consume_event ||", "lc_monitored_integrity_word = lc_destination_word ^",
    "lc_watched_consume_event = 1'b0",
  ]
  let unchanged_predicates = [
    "lc_one_item_in_flight_capacity = lc_capacity_base;", "lc_source_payload_stable_while_outstanding = lc_source_payload_base;",
    "lc_destination_response_stable_under_backpressure = lc_backpressure_base;",
    "lc_no_duplicate_acknowledge_or_consume = lc_duplicate_base;", "lc_watched_transaction_data_integrity = lc_integrity_base;",
    "lc_watched_transaction_completes = lc_completion_base;",
  ]
  for fixture in fixtures {
    let bundle = generate_toggle_formal_bundle(fixture)
    assert_eq(toggle_artifact(bundle, "design.lcir"), valid_ir)
    let rtl = bundle
      .artifacts()
      .filter(artifact => artifact.path().has_suffix(".sv"))
      .filter(artifact => artifact.path() != "formal-harness.sv")
    assert_eq(rtl.length(), 1)
    assert_eq(rtl[0], valid_rtl[0])
    let harness = toggle_artifact(bundle, "formal-harness.sv")
    assert_true(unchanged_predicates.all(line => harness.contains(line)))
    assert_true(
      harness.contains(
        "if (lc_model_response_valid && !((lc_destination_word == lc_model_response_word)",
      ),
    )
    assert_eq(
      mutant_markers.filter(marker => harness.contains(marker)).length(),
      1,
    )
    assert_eq(bundle.tasks().length(), 1)
    assert_eq(bundle.tasks()[0].expected_status(), "fail")
    assert_false(bundle.expected_failure() == "none")
    let execution = toggle_artifact(bundle, fixture.id() + "-bmc.lcfg")
    assert_true(
      execution.contains("EXPECTED-FAILURE \{bundle.expected_failure()}\n"),
    )
    assert_true(
      execution.contains(
        "COMPLETION-BOUND-DERIVATION 4*(3+3+1)=28-scheduling-intervals\n",
      ),
    )
    let matching = @formal_core.parse_formal_property_manifest(
        toggle_artifact(bundle, "properties.lcfp"),
      )
      .properties()
      .filter(property => property.stable_name() == bundle.expected_failure())
    assert_eq(matching.length(), 1)
    assert_eq(matching[0].kind(), Assertion)
  }
}

///|
test "toggle registry rejects unknown fixture identity" {
  let source_set = "LUNACHIP-PHASE5-FORMAL-SOURCE-SET 1\nFAMILY toggle-handshake\nFIXTURE forged\nEND\n"
  try regenerate_formal_artifacts(source_set) catch {
    _ => ()
  } noraise {
    _ => fail("unknown toggle fixture must be rejected")
  }
}
