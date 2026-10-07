///|
test "engine ownership CLI exports exact API inputs and preserves an existing directory" {
  assert_true(usage().contains("queue-owner DIRECTORY"))
  let artifacts = @gate.generate_queue_owner_proof_artifacts()
  let directory = queue_control_cli_test_directory()
  let output = directory + "/out"
  defer {
    for artifact in artifacts {
      let path = output + "/" + artifact.path()
      if @fs.path_exists(path) {
        @fs.remove_file(path)
      }
    }
    if @fs.path_exists(output) {
      @fs.remove_dir(output)
    }
    @fs.remove_dir(directory)
  }
  assert_eq(
    run_command(["queue-owner", output]),
    "Engine/live-entry ownership proof inputs: artifacts=6 exported=\{output}\n" +
    "Export only; no proof, result receipt, payload correctness or full-device gate claimed.",
  )
  let names = @fs.read_dir(output)
  assert_eq(names.length(), 6)
  for artifact in artifacts {
    assert_true(names.contains(artifact.path()))
    assert_eq(
      @fs.read_file_to_string(output + "/" + artifact.path()),
      artifact.content(),
    )
  }
  try run_command(["queue-owner", output]) catch {
    FormalFixtureCliError::ExistingOutput(path~) => assert_eq(path, output)
    other => fail("unexpected ownership overwrite error: \{Repr(other)}")
  } noraise {
    _ => fail("ownership input directory must not be reused")
  }
  let preserved = @fs.read_dir(output)
  assert_eq(preserved.length(), names.length())
  for artifact in artifacts {
    assert_true(preserved.contains(artifact.path()))
    assert_eq(
      @fs.read_file_to_string(output + "/" + artifact.path()),
      artifact.content(),
    )
  }
}
