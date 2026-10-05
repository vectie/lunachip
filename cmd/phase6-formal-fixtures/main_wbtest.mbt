///|
test "formal fixture CLI accepts only the three exact fixture identities" {
  let cases : Array[(String, @gate.FluxTileFormalFixture)] = [
    ("phase6-flux-tile-public-transport", PublicTransport),
    ("phase6-flux-tile-negative-request-bounds", NegativeRequestBounds),
    ("phase6-flux-tile-negative-request-stability", NegativeRequestStability),
  ]
  for (id, expected) in cases {
    assert_eq(parse_fixture(id), expected)
    assert_eq(parse_fixture(id).id(), id)
    assert_true(usage().contains(id))
  }
  for id in ["", "public-transport", "phase6-flux-tile-unknown"] {
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
