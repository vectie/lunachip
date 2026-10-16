///|
fn direct8_progress_test_bundle() -> Direct8CompletionBundle raise {
  { artifacts: generate_direct8_progress_artifacts(), }
}

///|
test "direct8 progress reuses original device IR and all seven public assumptions without a deadline cut" {
  let bundle = direct8_progress_test_bundle()
  let original = generate_direct8_completion_bundle(Eventual)
  for path in ["design.lcir", "formal-dut.sv", "names.lcnm"] {
    assert_eq(
      direct8_completion_test_artifact(bundle, path),
      direct8_completion_test_artifact(original, path),
    )
  }
  assert_eq(
    sha256_hex(direct8_completion_test_artifact(bundle, "design.lcir")),
    "12e94f78c7136ada755eed2f35c92af52d77aa75fa2f1398bab19872057ff3ae",
  )
  assert_eq(
    sha256_hex(direct8_completion_test_artifact(original, "formal-harness.sv")),
    "5f1748cc9234ff8f7b0ba07d9733b6389e4d904df236d12edf39d2a6d58d4778",
  )
  let (exported, legal, fairness, assertions, covers) = direct_completion_export_definitions(
    direct8_progress_definitions(),
  )
  let (_, old_legal, old_fairness, _, _) = direct_completion_property_export(
    Eventual,
  )
  assert_eq((legal, fairness), (old_legal, old_fairness))
  assert_eq((assertions.length(), covers.length()), (8, 0))
  assert_eq(
    exported.properties().filter(item => item.kind() is Assumption).length(),
    7,
  )
  assert_false(exported.source().contains("lc_dc_watched_retirement_deadline"))
  let harness = direct8_completion_test_artifact(bundle, "formal-harness.sv")
  assert_true(harness.contains(direct_completion_host_source()))
  assert_true(harness.contains(direct8_progress_source()))
  assert_true(harness.contains("14'd11718"))
  assert_false(harness.contains("assume(lc_dc_response_readiness"))
}

///|
test "direct8 progress registry binds one typed unbounded component and not a shortened BMC" {
  let bundle = direct8_progress_test_bundle()
  let source = direct8_completion_test_artifact(bundle, "source-set.lcfs")
  assert_eq(regenerate_formal_artifacts(source), bundle.artifacts)
  assert_eq(
    direct8_progress_artifacts_from_id(direct8_progress_id),
    Some(bundle.artifacts),
  )
  assert_eq(
    direct8_progress_artifacts_from_id(direct8_completion_id(Eventual)),
    None,
  )
  let name = direct8_progress_id + "-prove"
  guard @formal_core.parse_proof_task(
      direct8_completion_test_artifact(bundle, name + ".lcft"),
    )
    is Unbounded(task) else {
    fail("progress must be an unbounded component")
  }
  assert_eq(
    (task.name(), task.assumptions().length(), task.properties().length()),
    (name, 7, 8),
  )
  assert_eq(task.induction(), @formal_core.InductionMethod::k_induction(12))
  assert_true(task.timing_contract() is Some(_))
  let execution = direct8_completion_test_artifact(bundle, name + ".lcfg")
  for
    marker in [
      "MODE prove\n", "BOUND 12\n", "TIMEOUT-SECONDS 600\n", "SELECTED-ASSUMPTIONS 7\n",
      "SELECTED-PROPERTIES 8\n", "EXPECTED-FAILURE none\n",
    ] {
    assert_true(execution.contains(marker))
  }
  assert_true(execution.contains("not-completion-deadline"))
  assert_eq(direct8_completion_budget().deadline, 11718)
  assert_eq(direct8_completion_budget().global_steps, 23552)
}

///|
test "direct8 progress counts full ages independently of offered-response history" {
  let source = direct8_progress_source()
  assert_false(source.contains("lc_dc_response_offered"))
  assert_true(source.contains("lc_d8p_reply_age < 2'd3"))
  assert_true(source.contains("lc_d8p_service_age < 2'd3"))
  assert_true(
    source.contains("lc_dc_response_accept || lc_d8p_reply_age < 2'd2"),
  )
  assert_true(
    source.contains("lc_dc_response_accept || lc_d8p_service_age < 2'd3"),
  )
  assert_false(source.contains("anyseq"))
}
