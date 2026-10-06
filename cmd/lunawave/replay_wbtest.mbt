///|
test "LunaWave CLI replays a schema1 file and emits only the exact trace and VCD" {
  let draft = cli_test_legacy_bundle(AtCycle(1UL), cli_test_digest())
  let expected = @replay.execute(draft)
  let bundle = cli_test_legacy_bundle(AtCycle(1UL), expected.digest())
  cli_test_with_directory("legacy", directory => {
    cli_test_write_bundle(directory, bundle)
    let report = run_command([
      "replay",
      directory + "/input.replay",
      directory + "/out",
    ])
    assert_true(report.has_prefix("stop_reached=true expected_matches=true\n"))
    assert_true(
      report.contains("actual_digest=" + digest_text(expected.digest())),
    )
    cli_test_artifacts(directory, expected)
  })
}

///|
test "LunaWave CLI preserves schema2 coincident domains and unknown masks" {
  let draft = cli_test_atomic_bundle(cli_test_digest())
  let expected = @replay.execute(draft)
  let bundle = cli_test_atomic_bundle(expected.digest())
  cli_test_with_directory("atomic", directory => {
    cli_test_write_bundle(directory, bundle)
    ignore(
      run_command(["replay", directory + "/input.replay", directory + "/out"]),
    )
    cli_test_artifacts(directory, expected)
    let trace = @trace.parse(
      @fs.read_file_to_string(directory + "/out/trace.txt"),
    )
    assert_true(trace.schema() is Atomic2)
    assert_eq(trace.timebase(), Some(6UL))
    assert_eq(trace.atomic_frames().length(), 2)
    let batch = trace.atomic_frames()[1]
    assert_eq(batch.time(), 5UL)
    assert_eq(batch.boundary(), 1UL)
    assert_eq(batch.active_domains().iter().to_array(), [0, 1])
    assert_eq(batch.drives().iter().to_array(), ["probe"])
    assert_eq(batch.changes().length(), 3)
    assert_eq(batch.changes()[0].signal_index(), 0)
    assert_eq(batch.changes()[0].value().known_mask(), 3UL)
    assert_eq(batch.changes()[0].value().value_bits(), 3UL)
    assert_eq(batch.changes()[1].value().to_uint64(), 3UL)
    assert_eq(batch.changes()[2].value().to_uint64(), 4UL)
  })
}

///|
test "LunaWave CLI retains both actual artifacts before reporting digest mismatch" {
  let bundle = cli_test_legacy_bundle(AtCycle(1UL), cli_test_digest())
  let expected = @replay.execute(bundle)
  assert_true(expected.stop_reached())
  assert_false(expected.expected_matches())
  cli_test_with_directory("mismatch", directory => {
    cli_test_write_bundle(directory, bundle)
    try
      run_command(["replay", directory + "/input.replay", directory + "/out"])
    catch {
      LunaWaveCliError::ReplayFailed(
        stop_reached=true,
        expected_matches=false,
        expected_digest~,
        actual_digest~,
        output~
      ) => {
        assert_eq(expected_digest, digest_text(bundle.expected_result()))
        assert_eq(actual_digest, digest_text(expected.digest()))
        assert_eq(output, directory + "/out")
      }
      other => fail("unexpected replay error: \{Repr(other)}")
    } noraise {
      _ => fail("wrong expected trace must not pass")
    }
    cli_test_artifacts(directory, expected)
  })
}

///|
test "LunaWave CLI fails an unreached stop even when the partial trace digest matches" {
  let draft = cli_test_legacy_bundle(AtCycle(2UL), cli_test_digest())
  let expected = @replay.execute(draft)
  let bundle = cli_test_legacy_bundle(AtCycle(2UL), expected.digest())
  cli_test_with_directory("stop", directory => {
    cli_test_write_bundle(directory, bundle)
    try
      run_command(["replay", directory + "/input.replay", directory + "/out"])
    catch {
      LunaWaveCliError::ReplayFailed(
        stop_reached=false,
        expected_matches=true,
        expected_digest~,
        actual_digest~,
        output~
      ) => {
        assert_eq(expected_digest, actual_digest)
        assert_eq(output, directory + "/out")
      }
      other => fail("unexpected stop error: \{Repr(other)}")
    } noraise {
      _ => fail("matching an incomplete trace must not pass")
    }
    cli_test_artifacts(directory, expected)
  })
}

///|
test "LunaWave CLI rejects malformed input without creating outputs" {
  cli_test_with_directory("malformed", directory => {
    @fs.write_string_to_file(directory + "/input.replay", "broken\n")
    try
      run_command(["replay", directory + "/input.replay", directory + "/out"])
    catch {
      @replay.ReplayError::UnexpectedLine(..) => ()
      other => fail("unexpected parse error: \{Repr(other)}")
    } noraise {
      _ => fail("malformed replay must not execute")
    }
    assert_false(@fs.path_exists(directory + "/out"))
  })
}

///|
test "LunaWave CLI refuses existing output without reading missing input or touching its files" {
  cli_test_with_directory("existing", directory => {
    @fs.create_dir(directory + "/out")
    @fs.write_string_to_file(directory + "/out/sentinel", "keep these bytes\n")
    try
      run_command(["replay", directory + "/missing.replay", directory + "/out"])
    catch {
      LunaWaveCliError::ExistingOutput(path~) =>
        assert_eq(path, directory + "/out")
      other => fail("unexpected existing-output error: \{Repr(other)}")
    } noraise {
      _ => fail("existing output must not be reused")
    }
    assert_eq(
      @fs.read_file_to_string(directory + "/out/sentinel"),
      "keep these bytes\n",
    )
    assert_eq(@fs.read_dir(directory + "/out"), ["sentinel"])
  })
}

///|
test "LunaWave CLI help and invalid argument counts are explicit" {
  for args in [[], ["help"], ["--help"], ["-h"]] {
    assert_eq(run_command(args), usage())
  }
  for
    args in [
      ["replay"],
      ["replay", "input"],
      ["replay", "input", "out", "extra"],
      ["unknown"],
    ] {
    try run_command(args) catch {
      LunaWaveCliError::Usage(actual) => assert_eq(actual, usage())
      other => fail("unexpected usage error: \{Repr(other)}")
    } noraise {
      _ => fail("invalid arguments must not run a replay")
    }
  }
}

///|
test "LunaWave CLI refuses existing empty directories and files" {
  for is_directory in [true, false] {
    cli_test_with_directory("existing-kind", directory => {
      let output = directory + "/out"
      if is_directory {
        @fs.create_dir(output)
      } else {
        @fs.write_string_to_file(output, "keep this file\n")
      }
      try run_command(["replay", directory + "/missing.replay", output]) catch {
        LunaWaveCliError::ExistingOutput(path~) => assert_eq(path, output)
        other => fail("unexpected existing-path error: \{Repr(other)}")
      } noraise {
        _ => fail("an existing path must not be reused")
      }
      if is_directory {
        assert_eq(@fs.read_dir(output).length(), 0)
      } else {
        assert_eq(@fs.read_file_to_string(output), "keep this file\n")
      }
    })
  }
}
