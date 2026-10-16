///|
test "direct8 arbiter task retains the exact parent device and seven premises" {
  let artifacts = generate_direct8_arbiter_artifacts()
  let bundle : Direct8CompletionBundle = { artifacts, }
  let parent : Direct8CompletionBundle = {
    artifacts: generate_direct8_progress_artifacts(fifo_support=true),
  }
  let fixture = direct8_arbiter_fixture()
  let emitted = @rtl.emit_design(
    @ir.Design::single(
      "QueuedConcurrentDirect8CompletionPilot",
      fixture.hardware(),
    ),
  )
  let exported = direct8_arbiter_property_export(
    port_identifier(emitted, InputPort, "clock"),
  )
  let (overlay, _) = direct8_arbiter_overlay(fixture, emitted, exported)
  assert_eq(overlay.split(": assert (").count() - 1, 14)
  for
    text in [
      "anyseq", ": assume", "lc_dut.", "initial begin", "meminit", "input ", "output ",
    ] {
    assert_false(overlay.contains(text))
  }
  assert_eq(
    direct8_completion_test_artifact(bundle, "formal-dut.sv").replace(
      old=overlay,
      new="",
    ),
    direct8_completion_test_artifact(parent, "formal-dut.sv"),
  )
  assert_eq(
    sha256_hex(direct8_completion_test_artifact(parent, "formal-dut.sv")),
    "84cdb249bfaf025a2d562a84fbde9e9ef0f94e53b13079e746b48e56da6e8aac",
  )
  for artifact in parent.artifacts {
    if artifact.path == "design.lcir" ||
      artifact.path == "names.lcnm" ||
      artifact.path == "formal-harness.sv" ||
      artifact.path.has_prefix("production-") {
      assert_eq(
        direct8_completion_test_artifact(bundle, artifact.path),
        artifact.content,
      )
    }
  }
  let old = @formal_core.parse_formal_property_manifest(
    direct8_completion_test_artifact(parent, "properties.lcfp"),
  )
  let fresh = @formal_core.parse_formal_property_manifest(
    direct8_completion_test_artifact(bundle, "properties.lcfp"),
  )
  assert_eq(fresh.properties().length(), 29)
  for index, property in old.properties() {
    assert_eq(fresh.properties()[index], property)
  }
  assert_eq(
    fresh
    .properties()
    .filter(property => property.kind() is Assumption)
    .length(),
    7,
  )
  let source = direct8_completion_test_artifact(bundle, "source-set.lcfs")
  assert_eq(regenerate_formal_artifacts(source), artifacts)
  assert_eq(
    direct8_progress_artifacts_from_id(direct8_arbiter_id),
    Some(artifacts),
  )
  let name = direct8_arbiter_id + "-prove"
  guard @formal_core.parse_proof_task(
      direct8_completion_test_artifact(bundle, name + ".lcft"),
    )
    is Unbounded(task) else {
    fail("grant/regrant composition must be unbounded")
  }
  assert_eq((task.assumptions().length(), task.properties().length()), (7, 22))
  assert_eq(task.induction(), @formal_core.InductionMethod::k_induction(32))
  let execution = direct8_completion_test_artifact(bundle, name + ".lcfg")
  for
    text in [
      "MODE prove\n", "BOUND 32\n", "TIMEOUT-SECONDS 600\n", "SELECTED-ASSUMPTIONS 7\n",
      "SELECTED-PROPERTIES 22\n",
    ] {
    assert_true(execution.contains(text))
  }
  assert_eq(direct8_completion_budget().deadline, 11718)
}

///|
test "direct8 arbiter watches preserve inclusive full-width payload and post-acceptance ages" {
  let source = direct8_arbiter_source()
  assert_true(source.contains("wire [103:0] lc_g_payload"))
  assert_true(source.contains("lc_g_r_address"))
  assert_true(source.contains("lc_g_r_local_tag"))
  assert_true(source.contains("!lc_g_c0_accepted && !lc_g_c0_valid"))
  assert_true(source.contains("!lc_g_c1_accepted && !lc_g_c1_valid"))
  assert_true(source.contains("lc_g_c0_ack || lc_g_c0_age < 4'd12"))
  assert_true(
    source.contains("lc_g_e_response_accept || lc_g_service_age < 3'd6"),
  )
  assert_true(source.contains("lc_g_c0_age < 4'd15"))
  assert_false(source.contains("response_offered"))
  assert_false(source.contains("assume"))
  assert_true(source.contains("!lc_g_q_entry_allocate_0"))
  assert_true(source.contains("lc_g_q_engine_state_2 == 0"))
}
