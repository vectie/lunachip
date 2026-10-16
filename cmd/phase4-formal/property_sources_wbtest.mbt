///|
fn property_source_artifact(
  artifacts : ReadOnlyArray[@gate.FormalBundleArtifact],
  path : String,
) -> String raise {
  guard artifacts.filter(artifact => artifact.path() == path) is [artifact] else {
    fail("fixture artifact missing")
  }
  artifact.content()
}

///|
fn property_source_fixture(
  artifacts : ReadOnlyArray[@gate.FormalBundleArtifact],
) -> (String, Array[(String, String)], @formal_core.FormalPropertyManifest) raise {
  let (top, roster) = compiled_source_roster(
    property_source_artifact(artifacts, "job.json"),
  )
  let sources : Array[(String, String)] = []
  for (path, expected) in roster {
    let source = property_source_artifact(artifacts, path)
    assert_eq(digest(path, source), expected)
    sources.push((path, source))
  }
  (
    top,
    sources,
    @formal_core.parse_formal_property_manifest(
      property_source_artifact(artifacts, "properties.lcfp"),
    ),
  )
}

///|
test "compiled property placement preserves all legacy FIFO harness checks and supports actual child conclusions" {
  for bundle in @gate.standard_fifo_formal_bundles() {
    let (top, sources, properties) = property_source_fixture(bundle.artifacts())
    verify_property_placement(top, sources, properties)
  }
  let artifacts = @gate.direct8_progress_artifacts_from_id(
    "phase6-flux-tile-direct8-q3-arbiter-queue-progress-r2-h2",
  ).unwrap()
  let (top, sources, properties) = property_source_fixture(artifacts)
  verify_property_placement(top, sources, properties)
  assert_eq(properties.properties().length(), 29)
}

///|
test "compiled child property labels cannot move scope duplicate or live outside their module" {
  let artifacts = @gate.direct8_progress_artifacts_from_id(
    "phase6-flux-tile-direct8-q3-arbiter-queue-progress-r2-h2",
  ).unwrap()
  let (top, sources, properties) = property_source_fixture(artifacts)
  let label = properties.properties()[15].stable_name() + ":"
  let dut = property_source_artifact(artifacts, "formal-dut.sv")
  let harness = property_source_artifact(artifacts, "formal-harness.sv")
  for
    malformed in [
      [("formal-dut.sv", dut), ("formal-harness.sv", harness + label)],
      [
        ("formal-dut.sv", dut.replace(old=label, new="wrong_label:")),
        ("formal-harness.sv", harness + label),
      ],
      [
        ("formal-dut.sv", dut.replace(old=label, new="wrong_label:") + label),
        ("formal-harness.sv", harness),
      ],
      [("uncompiled-production.sv", dut), ("formal-harness.sv", harness)],
      [
        ("formal-dut.sv", dut),
        (
          "formal-harness.sv",
          harness.replace(old=" lc_dut (", new=" other_instance ("),
        ),
      ],
    ] {
    try verify_property_placement(top, malformed, properties) catch {
      _ => ()
    } noraise {
      _ => fail("forged property placement must fail")
    }
  }
  // A different declared scope must not silently acquire child support.
  let altered = property_source_artifact(artifacts, "properties.lcfp").replace(
    old="6c635f666f726d616c5f6469726563745f636f6d706c6574696f6e5f746f702e6c635f647574",
    new="77726f6e675f73636f7065",
  )
  try
    verify_property_placement(
      top,
      sources,
      @formal_core.parse_formal_property_manifest(altered),
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("wrong declared child scope must fail")
  }
}

///|
test "compiled source roster rejects missing duplicate and unsafe files" {
  for
    text in [
      "{}", "{\"top_module\":\"top\",\"sources\":[]}", "{\"top_module\":\"top\",\"sources\":[{\"path\":\"../formal.sv\",\"sha256\":\"bad\"}]}",
      "{\"top_module\":\"top\",\"sources\":[{\"path\":\"a.sv\",\"sha256\":\"bad\"},{\"path\":\"a.sv\",\"sha256\":\"bad\"}]}",
    ] {
    try compiled_source_roster(text) catch {
      _ => ()
    } noraise {
      _ => fail("invalid compiled source roster must fail")
    }
  }
}
