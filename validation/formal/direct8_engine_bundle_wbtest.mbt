///|
test "direct8 engine task preserves exact parent inputs premises unknown memories and full deadline" {
  let bundle : Direct8CompletionBundle = {
    artifacts: generate_direct8_arbiter_artifacts(
      engine_progress=true,
      owner_support=true,
    ),
  }
  let parent : Direct8CompletionBundle = {
    artifacts: generate_direct8_arbiter_artifacts(),
  }
  assert_eq(
    sha256_hex(direct8_completion_test_artifact(parent, "formal-dut.sv")),
    "5693cc7d3e08fb237ccfd838034d5b7d80d5c46d2379c42da079e7e719e59c41",
  )
  let first : Direct8CompletionBundle = {
    artifacts: generate_direct8_arbiter_artifacts(engine_progress=true),
  }
  for
    (path, expected) in [
      (
        "formal-dut.sv", "19aa87319f82b60d40face2c3e0eaa415110857f2e340c9ab97d4215bc3b36b0",
      ),
      (
        "source-set.lcfs", "2d03d73bac7a690dfd7713b40047bf6b732cc9c961d2b5044ada94521399fc42",
      ),
      (
        "properties.lcfp", "63a98e0598d320f7434855b4efffcb9fd70df99e4c7fddc5bc2c061c923bbaab",
      ),
    ] {
    assert_eq(
      sha256_hex(direct8_completion_test_artifact(first, path)),
      expected,
    )
  }
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
  let fixture = direct8_arbiter_fixture()
  let emitted = @rtl.emit_design(
    @ir.Design::single(
      "QueuedConcurrentDirect8CompletionPilot",
      fixture.hardware(),
    ),
  )
  let exported = direct8_arbiter_property_export(
    port_identifier(emitted, InputPort, "clock"),
    engine_progress=true,
    owner_support=true,
  )
  let (overlay, report) = direct8_arbiter_overlay(
    fixture,
    emitted,
    exported,
    engine_progress=true,
    owner_support=true,
  )
  assert_eq(report.split("\nNODE ").count() - 1, 257)
  assert_eq(overlay.split(": assert (").count() - 1, 35)
  for
    forbidden in [
      "anyseq", ": assume", "lc_dut.", "initial begin", "meminit", "input ", "output ",
    ] {
    assert_false(overlay.contains(forbidden))
  }
  let supported : Direct8CompletionBundle = {
    artifacts: generate_direct8_progress_artifacts(fifo_support=true),
  }
  assert_eq(
    direct8_completion_test_artifact(bundle, "formal-dut.sv").replace(
      old=overlay,
      new="",
    ),
    direct8_completion_test_artifact(supported, "formal-dut.sv"),
  )
  let before = @formal_core.parse_formal_property_manifest(
    direct8_completion_test_artifact(parent, "properties.lcfp"),
  )
  let after = @formal_core.parse_formal_property_manifest(
    direct8_completion_test_artifact(bundle, "properties.lcfp"),
  )
  assert_eq(after.properties().length(), 50)
  for index, property in before.properties() {
    assert_eq(after.properties()[index], property)
  }
  let task_name = direct8_engine_supported_id + "-prove"
  guard @formal_core.parse_proof_task(
      direct8_completion_test_artifact(bundle, task_name + ".lcft"),
    )
    is Unbounded(task) else {
    fail("engine progress must retain unbounded task identity")
  }
  assert_eq((task.assumptions().length(), task.properties().length()), (7, 43))
  assert_eq(task.induction(), @formal_core.InductionMethod::k_induction(32))
  assert_eq(
    regenerate_formal_artifacts(
      direct8_completion_test_artifact(bundle, "source-set.lcfs"),
    ),
    bundle.artifacts,
  )
  let execution = direct8_completion_test_artifact(bundle, task_name + ".lcfg")
  assert_true(execution.contains("TIMEOUT-SECONDS 600\n"))
  assert_eq(
    (
      direct8_completion_budget().deadline,
      direct8_completion_budget().global_steps,
    ),
    (11718, 23552),
  )
}

///|
test "direct8 engine proof observers retain full widths independent recurrence and release priority" {
  let source = direct8_engine_source()
  assert_false(source.contains("assume"))
  assert_false(source.contains("anyseq"))
  assert_true(source.contains("logic [103:0] lc_e_reader_payload"))
  assert_true(source.contains("logic [103:0] lc_e_engine_payload"))
  assert_true(source.contains("logic [12:0] lc_e_reader_row"))
  assert_true(source.contains("lc_g_t_reader_row < lc_g_t_reader_rows"))
  assert_true(source.contains("lc_g_t_engine_column < lc_g_t_engine_columns"))
  assert_true(
    source.contains(
      "lc_g_x_compute_legal_accept ? 1'b1 : lc_g_x_release ? 1'b0",
    ),
  )
  assert_true(source.contains("!lc_g_c0_cancel && !lc_g_c1_cancel"))
  assert_eq(direct8_engine_property_names().length(), 14)
  assert_eq(direct8_engine_property_names(owner_support=true).length(), 21)
}
