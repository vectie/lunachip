///|
test "formal fixture CLI accepts four exact FluxTile fixture identities" {
  let cases : Array[(String, @gate.FluxTileFormalFixture)] = [
    ("phase6-flux-tile-public-transport", PublicTransport),
    ("phase6-flux-tile-negative-request-bounds", NegativeRequestBounds),
    ("phase6-flux-tile-negative-request-stability", NegativeRequestStability),
    ("phase6-flux-tile-directed-first-terminal", DirectedFirstTerminal),
  ]
  for (id, expected) in cases {
    assert_eq(parse_fixture(id), expected)
    assert_eq(parse_fixture(id).id(), id)
    assert_true(usage().contains(id))
  }
  for
    id in [
      "", "public-transport", "phase6-flux-tile-unknown", "phase6-flux-tile-directed-first-terminals",
    ] {
    try parse_fixture(id) catch {
      UnknownFixture(id=actual) => assert_eq(actual, id)
      other => fail("unexpected fixture selection error: \{Repr(other)}")
    } noraise {
      _ => fail("unknown fixture must not be exported")
    }
  }
}

///|
test "formal fixture exporter exposes canonical artifacts without claiming proof" {
  let bundle = @gate.generate_flux_tile_formal_bundle(PublicTransport)
  assert_eq(bundle.fixture(), PublicTransport)
  assert_true(bundle.tasks().length() > 0)
  for path in ["design.lcir", "properties.lcfp", "source-set.lcfs", "job.json"] {
    assert_true(bundle.artifacts().any(artifact => artifact.path() == path))
  }
  assert_eq(
    export_report(bundle, "output"),
    "fixture=phase6-flux-tile-public-transport artifacts=\{bundle.artifacts().length()} tasks=\{bundle.tasks().length()} exported=output\n" +
    "Export only; no formal result claimed.",
  )
}

///|
test "formal fixture exporter refuses an existing output without writing" {
  try checked_new_directory(".") catch {
    FormalFixtureCliError::ExistingOutput(path=".") => ()
    other => fail("unexpected overwrite error: \{Repr(other)}")
  } noraise {
    _ => fail("existing output must not be reused")
  }
}

///|
test "formal fixture CLI help and argument validation are explicit" {
  for args in [[], ["help"], ["--help"], ["-h"]] {
    assert_eq(run_command(args), usage())
  }
  assert_true(
    usage().has_prefix(
      "Usage: phase6-formal-fixtures export FIXTURE_ID DIRECTORY | generation-lemma DIRECTORY | compute-generation DIRECTORY | queue-control DIRECTORY | queue-monitor DIRECTORY | queue-owner DIRECTORY | dma-arbiter DIRECTORY | help\n" +
      "Fixtures: phase6-flux-tile-public-transport | phase6-flux-tile-negative-request-bounds | phase6-flux-tile-negative-request-stability",
    ),
  )
  for
    args in [
      ["export"],
      ["export", "phase6-flux-tile-public-transport"],
      ["export", "phase6-flux-tile-public-transport", ".", "extra"],
      ["unknown"],
      ["generation-lemma"],
      ["generation-lemma", ".", "extra"],
      ["compute-generation"],
      ["compute-generation", ".", "extra"],
      ["queue-control"],
      ["queue-control", ".", "extra"],
      ["queue-monitor"],
      ["queue-monitor", ".", "extra"],
      ["queue-owner"],
      ["queue-owner", ".", "extra"],
      ["dma-arbiter"],
      ["dma-arbiter", ".", "extra"],
    ] {
    try run_command(args) catch {
      FormalFixtureCliError::Usage(actual) => assert_eq(actual, usage())
      other => fail("unexpected usage error: \{Repr(other)}")
    } noraise {
      _ => fail("invalid command must not run")
    }
  }
}

///|
test "generation lemma CLI refuses existing output before writing" {
  assert_true(usage().contains("generation-lemma DIRECTORY"))
  try run_command(["generation-lemma", "."]) catch {
    FormalFixtureCliError::ExistingOutput(path=".") => ()
    other => fail("unexpected lemma overwrite error: \{Repr(other)}")
  } noraise {
    _ => fail("generation lemma output must not be reused")
  }
}

///|
test "dependency formal CLI chooser accepts all five exact identities" {
  let cases : Array[(String, @gate.DependencyFormalFixture)] = [
    ("phase6-dependency-latest-writer", LatestWriter),
    ("phase6-dependency-negative-failed-generation", NegativeFailedGeneration),
    (
      "phase6-dependency-negative-new-intent-priority",
      NegativeNewIntentPriority,
    ),
    ("phase6-dependency-negative-inner-identity", NegativeInnerIdentity),
    ("phase6-dependency-generation-support", LatestWriterGenerationSupport),
  ]
  for (id, expected) in cases {
    assert_eq(@gate.DependencyFormalFixture::from_id(id), Some(expected))
    assert_eq(expected.id(), id)
    assert_true(usage().contains(id))
  }
}

///|
test "dependency formal exporter preserves canonical paths and refuses existing output" {
  let bundle = @gate.generate_dependency_formal_bundle(LatestWriter)
  assert_eq(bundle.fixture(), LatestWriter)
  assert_true(bundle.tasks().length() > 0)
  for path in ["design.lcir", "properties.lcfp", "source-set.lcfs", "job.json"] {
    assert_true(bundle.artifacts().any(artifact => artifact.path() == path))
  }
  assert_eq(
    dependency_export_report(bundle, "output"),
    "fixture=phase6-dependency-latest-writer artifacts=\{bundle.artifacts().length()} tasks=\{bundle.tasks().length()} exported=output\n" +
    "Export only; no formal result claimed.",
  )
  try write_artifacts(bundle.artifacts(), ".") catch {
    FormalFixtureCliError::ExistingOutput(path=".") => ()
    other => fail("unexpected dependency overwrite error: \{Repr(other)}")
  } noraise {
    _ => fail("dependency output directory must not be reused")
  }
}

///|
test "dependency formal CLI rejects unapproved identities and incorrect arity" {
  for
    id in [
      "latest-writer", "phase6-dependency-unknown", "phase6-dependency-negative-failed-generations",
      "phase6-dependency-latest-writer/extra",
    ] {
    try run_command(["export", id, "."]) catch {
      UnknownFixture(id=actual) => assert_eq(actual, id)
      other => fail("unexpected dependency selection error: \{Repr(other)}")
    } noraise {
      _ => fail("unapproved dependency fixture must not be exported")
    }
  }
  for
    args in [
      ["export", "phase6-dependency-latest-writer"],
      ["export", "phase6-dependency-latest-writer", ".", "extra"],
    ] {
    try run_command(args) catch {
      FormalFixtureCliError::Usage(actual) => assert_eq(actual, usage())
      other => fail("unexpected dependency arity error: \{Repr(other)}")
    } noraise {
      _ => fail("invalid dependency export command must not run")
    }
  }
}

///|
test "compute generation CLI exports only inputs and refuses existing output" {
  assert_true(usage().contains("compute-generation DIRECTORY"))
  try run_command(["compute-generation", "."]) catch {
    FormalFixtureCliError::ExistingOutput(path=".") => ()
    other => fail("unexpected composition overwrite error: \{Repr(other)}")
  } noraise {
    _ => fail("compute generation output must not be reused")
  }
}

///|
test "queue formal CLI selects only the six approved identities" {
  let cases : Array[(String, @gate.QueueFormalFixture)] = [
    ("phase6-queue-conservation", Conservation),
    ("phase6-queue-negative-population", NegativePopulation),
    ("phase6-queue-retirement-records", RetirementRecords),
    ("phase6-queue-negative-held-payload", NegativeHeldPayload),
    ("phase6-queue-packet-provenance", PacketProvenance),
    ("phase6-queue-negative-packet-provenance", NegativePacketProvenance),
  ]
  for (id, fixture) in cases {
    assert_eq(@gate.QueueFormalFixture::from_id(id), Some(fixture))
    assert_eq(fixture.id(), id)
    assert_true(usage().contains(id))
  }
  for
    id in [
      "queue-conservation", "phase6-queue-unknown", "phase6-queue-negative-populations",
      "phase6-queue-retirement-record", "phase6-queue-negative-held-payloads", "phase6-queue-packet-provenances",
      "phase6-queue-negative-packet-provenance/extra",
    ] {
    try run_command(["export", id, "."]) catch {
      UnknownFixture(id=actual) => assert_eq(actual, id)
      other => fail("unexpected queue selection error: \{Repr(other)}")
    } noraise {
      _ => fail("unapproved queue fixture must not be exported")
    }
  }
  for
    args in [
      ["export", "phase6-queue-conservation"],
      ["export", "phase6-queue-negative-population", ".", "extra"],
      ["export", "phase6-queue-retirement-records"],
      ["export", "phase6-queue-negative-held-payload", ".", "extra"],
    ] {
    try run_command(args) catch {
      FormalFixtureCliError::Usage(actual) => assert_eq(actual, usage())
      other => fail("unexpected queue arity error: \{Repr(other)}")
    } noraise {
      _ => fail("invalid queue export command must not run")
    }
  }
}

///|
test "queue formal export report is export-only and refuses existing output" {
  let bundle = @gate.generate_queue_formal_bundle(Conservation)
  assert_eq(bundle.fixture(), Conservation)
  assert_eq(bundle.artifacts().length(), 11)
  assert_eq(bundle.tasks().length(), 2)
  assert_eq(
    queue_export_report(bundle, "output"),
    "fixture=phase6-queue-conservation artifacts=11 tasks=2 exported=output\n" +
    "Export only; no formal result claimed.",
  )
  try write_artifacts(bundle.artifacts(), ".") catch {
    FormalFixtureCliError::ExistingOutput(path=".") => ()
    other => fail("unexpected queue overwrite error: \{Repr(other)}")
  } noraise {
    _ => fail("queue output directory must not be reused")
  }
}

///|
test "held payload sensitivity export remains export-only and refuses existing output" {
  let bundle = @gate.generate_queue_formal_bundle(NegativeHeldPayload)
  assert_eq(bundle.fixture(), NegativeHeldPayload)
  assert_eq(bundle.artifacts().length(), 9)
  assert_eq(bundle.tasks().length(), 1)
  assert_eq(
    queue_export_report(bundle, "output"),
    "fixture=phase6-queue-negative-held-payload artifacts=9 tasks=1 exported=output\n" +
    "Export only; no formal result claimed.",
  )
  try write_artifacts(bundle.artifacts(), ".") catch {
    FormalFixtureCliError::ExistingOutput(path=".") => ()
    other => fail("unexpected held payload overwrite error: \{Repr(other)}")
  } noraise {
    _ => fail("held payload output directory must not be reused")
  }
}

///|
// Claim a fresh test-owned parent atomically; never clear a prior run's files.
fn queue_control_cli_test_directory() -> String raise {
  for index in 0..<1024 {
    let directory = ".phase6-queue-control-cli-test-\{index}"
    if @fs.path_exists(directory) {
      continue
    }
    try @fs.create_dir(directory) catch {
      error => if !@fs.path_exists(directory) { raise error }
    } noraise {
      _ => return directory
    }
  }
  fail("no fresh queue-control CLI test directory")
}

///|
fn queue_control_cli_test_cleanup(directory : String) -> Unit raise {
  // Only these exact names are written under the parent owned by this test.
  for
    name in [
      "sequential.lcir", "sequential-production.sv", "sequential-boolean.sv", "bridge.sv",
      "negative-reserve.sv", "bridge-inputs.txt",
    ] {
    let path = directory + "/out/" + name
    if @fs.path_exists(path) {
      @fs.remove_file(path)
    }
  }
  if @fs.path_exists(directory + "/out") {
    @fs.remove_dir(directory + "/out")
  }
  @fs.remove_dir(directory)
}

///|
test "queue control CLI exports exact API inputs into a fresh directory without a proof receipt" {
  assert_true(usage().contains("queue-control DIRECTORY"))
  assert_true(
    usage().contains(
      "queue-control exports local proof inputs only; no proof or result receipt.",
    ),
  )
  let artifacts = @gate.generate_queue_control_proof_artifacts()
  let directory = queue_control_cli_test_directory()
  defer queue_control_cli_test_cleanup(directory)
  let output = directory + "/out"
  assert_false(@fs.path_exists(output))
  assert_eq(
    run_command(["queue-control", output]),
    "Local queue-control proof inputs: artifacts=\{artifacts.length()} exported=\{output}\n" +
    "Export only; no proof, result receipt, engine ownership or full-device composition claimed.",
  )
  let names = @fs.read_dir(output)
  let expected_names = [
    "bridge-inputs.txt", "bridge.sv", "negative-reserve.sv", "sequential-boolean.sv",
    "sequential-production.sv", "sequential.lcir",
  ]
  assert_eq(names.length(), expected_names.length())
  for name in expected_names {
    assert_true(names.contains(name))
  }
  assert_eq(artifacts.length(), names.length())
  for artifact in artifacts {
    assert_eq(
      @fs.read_file_to_string(output + "/" + artifact.path()),
      artifact.content(),
    )
  }
  try run_command(["queue-control", output]) catch {
    FormalFixtureCliError::ExistingOutput(path~) => assert_eq(path, output)
    other => fail("unexpected queue-control overwrite error: \{Repr(other)}")
  } noraise {
    _ => fail("queue-control output must not be reused")
  }
  let preserved = @fs.read_dir(output)
  assert_eq(preserved.length(), names.length())
  for name in names {
    assert_true(preserved.contains(name))
  }
  for artifact in artifacts {
    assert_eq(
      @fs.read_file_to_string(output + "/" + artifact.path()),
      artifact.content(),
    )
  }
}

///|
test "two client DMA arbiter CLI exports exact API inputs and refuses overwrite" {
  assert_true(usage().contains("dma-arbiter DIRECTORY"))
  let artifacts = @gate.generate_two_client_arbiter_proof_artifacts()
  let expected_names = [
    "sequential.lcir", "sequential-production.sv", "sequential-boolean.sv", "bridge.sv",
    "negative-stalled-payload.sv", "bridge-inputs.txt",
  ]
  assert_eq(
    artifacts.map(artifact => artifact.path()),
    ReadOnlyArray::from_array(expected_names),
  )
  let directory = queue_control_cli_test_directory()
  let output = directory + "/out"
  defer {
    // Only the six exact names below this test's atomically owned parent.
    for name in expected_names {
      let path = output + "/" + name
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
    run_command(["dma-arbiter", output]),
    "Original two-client DMA arbiter proof inputs: artifacts=6 exported=\{output}\n" +
    "Export only; no proof, result receipt, DMA bounds or full-device gate claimed.",
  )
  let names = @fs.read_dir(output)
  assert_eq(names.length(), expected_names.length())
  for name in expected_names {
    assert_true(names.contains(name))
  }
  for artifact in artifacts {
    assert_eq(
      @fs.read_file_to_string(output + "/" + artifact.path()),
      artifact.content(),
    )
  }
  try run_command(["dma-arbiter", output]) catch {
    FormalFixtureCliError::ExistingOutput(path~) => assert_eq(path, output)
    other => fail("unexpected DMA arbiter overwrite error: \{Repr(other)}")
  } noraise {
    _ => fail("DMA arbiter input directory must not be reused")
  }
  let preserved = @fs.read_dir(output)
  assert_eq(preserved.length(), names.length())
  for name in expected_names {
    assert_true(preserved.contains(name))
  }
  for artifact in artifacts {
    assert_eq(
      @fs.read_file_to_string(output + "/" + artifact.path()),
      artifact.content(),
    )
  }
}
