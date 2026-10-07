///|
test "direct8 CLI exact IDs expose export only reports with actual LCFT task counts and refuse overwrite" {
  for
    (id, expected_tasks) in [
      ("phase6-flux-tile-direct8-q3-eventual-r2-h2-c2-d11718", 3),
      ("phase6-flux-tile-direct8-q3-useful-store-r2-h2-c2-d11718", 1),
      ("phase6-flux-tile-direct8-q3-negative-deadline1", 1),
    ] {
    assert_true(usage().contains(id))
    guard @gate.direct8_completion_artifacts_from_id(id) is Some(artifacts) else {
      fail("CLI direct8 artifacts missing")
    }
    let task_count = artifacts
      .filter(item => item.path().has_suffix(".lcft"))
      .length()
    assert_eq(task_count, expected_tasks)
    assert_eq(
      direct8_completion_export_report(id, artifacts, "output"),
      "fixture=\{id} artifacts=\{artifacts.length()} tasks=\{task_count} exported=output\n" +
      "Export only; no formal result or completed Phase 6 gate claimed.",
    )
    try run_command(["export", id, "."]) catch {
      FormalFixtureCliError::ExistingOutput(path=".") => ()
      other => fail("unexpected direct8 overwrite error: \{Repr(other)}")
    } noraise {
      _ => fail("direct8 output must not be reused")
    }
  }
  assert_true(
    usage().contains(
      "separate ordinary 8x8/K16 direct-q3 inputs only; no proof",
    ),
  )
}

///|
test "direct8 CLI unknown IDs and wrong arity preserve existing checked errors" {
  for
    id in [
      "phase6-flux-tile-direct8-q3-unknown", "phase6-flux-tile-direct8-q3-eventual-r2-h2-c2-d11718/extra",
      "phase6-flux-tile-direct8-q3-negative-deadline1s",
    ] {
    try run_command(["export", id, "."]) catch {
      FormalFixtureCliError::UnknownFixture(id=actual) => assert_eq(actual, id)
      other => fail("unexpected direct8 chooser rejection: \{Repr(other)}")
    } noraise {
      _ => fail("unapproved direct8 ID exported")
    }
  }
  for
    args in [
      ["export", "phase6-flux-tile-direct8-q3-eventual-r2-h2-c2-d11718"],
      ["export", "phase6-flux-tile-direct8-q3-negative-deadline1", ".", "extra"],
    ] {
    try run_command(args) catch {
      FormalFixtureCliError::Usage(actual) => assert_eq(actual, usage())
      other => fail("unexpected direct8 arity rejection: \{Repr(other)}")
    } noraise {
      _ => fail("invalid direct8 export arguments ran")
    }
  }
}
