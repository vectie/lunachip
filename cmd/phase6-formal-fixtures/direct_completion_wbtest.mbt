///|
test "completion fixture CLI exposes isolated scopes and refuses existing output" {
  for
    fixture in [
      @gate.DirectCompletionFixture::Eventual,
      UsefulStore,
      NegativeDeadline,
    ] {
    let id = fixture.id()
    assert_true(usage().contains(id))
    try run_command(["export", id, "."]) catch {
      FormalFixtureCliError::ExistingOutput(path=".") => ()
      other =>
        fail("unexpected completion fixture overwrite error: \{Repr(other)}")
    } noraise {
      _ => fail("completion fixture output must not be reused")
    }
  }
}
