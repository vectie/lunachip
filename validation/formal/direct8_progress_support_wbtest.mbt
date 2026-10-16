///|
test "direct8 FIFO induction support adds only eight conclusions on original address registers" {
  let plain = direct8_progress_test_bundle()
  let supported : Direct8CompletionBundle = {
    artifacts: generate_direct8_progress_artifacts(fifo_support=true),
  }
  let hardware = @flux_tile.queued_concurrent_tile(
    rows=8,
    columns=8,
    max_reduction=16,
    host_bytes=4096UL,
    queue_depth=3,
  )
  let emitted = @rtl.emit_design(
    @ir.Design::single("QueuedConcurrentDirect8CompletionPilot", hardware),
  )
  let overlay = direct8_progress_fifo_support(hardware, emitted)
  assert_eq(overlay.split("_range: assert (").count() - 1, 8)
  for forbidden in ["assume", "anyseq", "initial", " <= ", "assign ", "2'd2)"] {
    assert_false(overlay.contains(forbidden))
  }
  for lane in 0..<4 {
    for role in ["read", "write"] {
      assert_true(overlay.contains("lc_d8p_fifo_\{lane}_\{role}_range: assert"))
    }
  }
  assert_eq(
    direct8_completion_test_artifact(supported, "formal-dut.sv").replace(
      old=overlay,
      new="",
    ),
    direct8_completion_test_artifact(plain, "formal-dut.sv"),
  )
  for artifact in plain.artifacts {
    if artifact.path == "design.lcir" ||
      artifact.path == "names.lcnm" ||
      artifact.path == "formal-harness.sv" ||
      artifact.path == "properties.lcfp" ||
      artifact.path.has_prefix("production-") {
      assert_eq(
        direct8_completion_test_artifact(supported, artifact.path),
        artifact.content,
      )
    }
  }
  let source = direct8_completion_test_artifact(supported, "source-set.lcfs")
  assert_eq(regenerate_formal_artifacts(source), supported.artifacts)
  assert_eq(
    direct8_progress_artifacts_from_id(direct8_progress_supported_id),
    Some(supported.artifacts),
  )
  let name = direct8_progress_supported_id + "-prove"
  guard @formal_core.parse_proof_task(
      direct8_completion_test_artifact(supported, name + ".lcft"),
    )
    is Unbounded(task) else {
    fail("supported component must still be unbounded")
  }
  assert_eq(task.assumptions().length(), 7)
  assert_eq(task.properties().length(), 8)
  assert_eq(task.induction(), @formal_core.InductionMethod::k_induction(12))
  // The first attempt's inputs retain their original exact identities.
  assert_eq(
    sha256_hex(direct8_completion_test_artifact(plain, "source-set.lcfs")),
    "7af7698aeff60b7cba7b47f6de928ad1d33e9c7df84092f9bd50f8d94a2b74fd",
  )
  assert_eq(
    sha256_hex(direct8_completion_test_artifact(plain, "formal-harness.sv")),
    "5ffd8389cae84dc979f73daebbda6be34494319c536bce79ca78e2b7c037e737",
  )
}
