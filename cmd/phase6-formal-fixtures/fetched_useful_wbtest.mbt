///|
test "fetched useful CLI exact ID reports two input tasks and preserves output and chooser errors" {
  let id = "phase6-flux-tile-fetched-useful-store-r1-h1-c1"
  guard @gate.fetched_useful_artifacts_from_id(id) is Some(artifacts) else {
    fail("exact fetched useful CLI identity missing")
  }
  assert_eq(artifacts.length(), 12)
  assert_eq(
    artifacts.filter(item => item.path().has_suffix(".lcft")).length(),
    2,
  )
  assert_eq(
    direct8_completion_export_report(id, artifacts, "output"),
    "fixture=\{id} artifacts=12 tasks=2 exported=output\n" +
    "Export only; no formal result or completed Phase 6 gate claimed.",
  )
  assert_true(usage().contains(id))
  assert_true(
    usage().contains("directed full-device R1/H1/C1 inputs only; no proof"),
  )
  assert_true(
    usage().contains("phase6-flux-tile-direct8-q3-eventual-r2-h2-c2-d11718"),
  )
  try run_command(["export", id, "."]) catch {
    FormalFixtureCliError::ExistingOutput(path=".") => ()
    other => fail("unexpected fetched useful overwrite error: \{Repr(other)}")
  } noraise {
    _ => fail("existing output directory reused")
  }
  for
    unknown in [id + "/extra", "phase6-flux-tile-fetched-useful-store-unknown"] {
    try run_command(["export", unknown, "."]) catch {
      FormalFixtureCliError::UnknownFixture(id=actual) =>
        assert_eq(actual, unknown)
      other => fail("unexpected fetched useful chooser error: \{Repr(other)}")
    } noraise {
      _ => fail("unapproved fetched useful identity selected")
    }
  }
  for args in [["export", id], ["export", id, ".", "extra"]] {
    try run_command(args) catch {
      FormalFixtureCliError::Usage(actual) => assert_eq(actual, usage())
      other => fail("unexpected fetched useful arity error: \{Repr(other)}")
    } noraise {
      _ => fail("wrong fetched useful arity ran")
    }
  }
}
