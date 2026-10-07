///|
test "original queue monitor CLI exports exact API inputs and refuses overwrite" {
  assert_true(usage().contains("queue-monitor DIRECTORY"))
  assert_true(
    usage().contains(
      "queue-monitor exports original monitor inputs only; no proof or full-device result receipt.",
    ),
  )
  let artifacts = @gate.generate_queue_monitor_proof_artifacts()
  let directory = queue_control_cli_test_directory()
  let output = directory + "/out"
  defer {
    // Only exact artifacts created under this test's atomically owned parent.
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
  assert_false(@fs.path_exists(output))
  assert_eq(
    run_command(["queue-monitor", output]),
    "Original queue-monitor proof inputs: artifacts=\{artifacts.length()} exported=\{output}\n" +
    "Export only; no proof, result receipt, memory safety or full-device gate claimed.",
  )
  let names = @fs.read_dir(output)
  assert_eq(names.length(), 6)
  assert_eq(names.length(), artifacts.length())
  for artifact in artifacts {
    assert_true(names.contains(artifact.path()))
    assert_eq(
      @fs.read_file_to_string(output + "/" + artifact.path()),
      artifact.content(),
    )
    assert_false(artifact.path().has_suffix(".lcfg"))
    assert_false(artifact.path().has_suffix(".lcfr"))
  }
  try run_command(["queue-monitor", output]) catch {
    FormalFixtureCliError::ExistingOutput(path~) => assert_eq(path, output)
    other => fail("unexpected queue-monitor overwrite error: \{Repr(other)}")
  } noraise {
    _ => fail("queue-monitor output must not be reused")
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
