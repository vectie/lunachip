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
      "Usage: phase6-formal-fixtures export FIXTURE_ID DIRECTORY | help\n" +
      "Fixtures: phase6-flux-tile-public-transport | phase6-flux-tile-negative-request-bounds | phase6-flux-tile-negative-request-stability",
    ),
  )
  for
    args in [
      ["export"],
      ["export", "phase6-flux-tile-public-transport"],
      ["export", "phase6-flux-tile-public-transport", ".", "extra"],
      ["unknown"],
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
test "dependency formal CLI chooser accepts all four exact identities" {
  let cases : Array[(String, @gate.DependencyFormalFixture)] = [
    ("phase6-dependency-latest-writer", LatestWriter),
    ("phase6-dependency-negative-failed-generation", NegativeFailedGeneration),
    (
      "phase6-dependency-negative-new-intent-priority",
      NegativeNewIntentPriority,
    ),
    ("phase6-dependency-negative-inner-identity", NegativeInnerIdentity),
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
