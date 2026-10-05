///|
fn build_bundle(
  kind : HandshakeFixtureKind,
  sequential_bridge : Bool,
) -> HandshakeFixtureBundle raise {
  let design = fixture_design(kind)
  guard design.top_module() is Some(hardware_module) else {
    raise MissingTopModule
  }
  let emitted = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hardware_module, emitted.manifest())
  let stimulus = project_schedule(kind, fixture_schedule(kind), ports)
  let expected_tsv = generate_result_tsv(
    design, hardware_module, ports, stimulus, false,
  )
  let sequential_tsv = generate_result_tsv(
    design, hardware_module, ports, stimulus, true,
  )
  let harness_cpp = @verilator.atomic_harness_cpp(
    ports,
    stimulus,
    result_identity_prefix(
      design,
      stimulus.to_tsv(),
      stimulus.ticks_per_source_unit(),
    ),
    if sequential_bridge {
      SequentialEdges
    } else {
      AtomicEdges
    },
  )
  let artifacts : Array[BundleArtifact] = [
    { path: "design.lcir", content: @ir_codec.serialize(design), },
  ]
  for source in emitted.modules() {
    artifacts.push({ path: source.filename(), content: source.source(), })
  }
  artifacts.push({
    path: "names.lcnm",
    content: emitted.manifest().to_canonical_text(),
  })
  artifacts.push({
    path: "manifest.json",
    content: @verilator.atomic_harness_json(
      emitted, ports, stimulus, "harness.cpp",
    ),
  })
  artifacts.push({ path: "harness.cpp", content: harness_cpp, })
  artifacts.push({ path: "stimulus.tsv", content: stimulus.to_tsv(), })
  artifacts.push({ path: "expected.tsv", content: expected_tsv, })
  artifacts.push({
    path: "evidence-class.txt",
    content: "\{kind.evidence_class()}\n",
  })
  artifacts.push({
    path: "fixture-metadata.txt",
    content: if kind == SeededRational {
      "generator=lcg64\nseed=0x5eed1234\n"
    } else {
      "generator=directed\n"
    },
  })
  if sequential_bridge {
    artifacts.push({ path: "expected-sequential.tsv", content: sequential_tsv, })
  }
  {
    kind,
    design,
    emitted,
    stimulus,
    expected_tsv,
    sequential_tsv,
    artifacts: ReadOnlyArray::from_array(artifacts),
  }
}

///|
pub fn generate_handshake_fixture(
  kind : HandshakeFixtureKind,
) -> HandshakeFixtureBundle raise {
  build_bundle(kind, false)
}

///|
pub fn standard_handshake_fixtures() -> ReadOnlyArray[HandshakeFixtureKind] {
  ReadOnlyArray::from_array([
    DirectedScalar,
    MultiLeafRational,
    CoincidentRefill,
    CoordinatedResetFlush,
    SeededRational,
  ])
}

///|
pub fn generate_sequential_negative_fixture() -> HandshakeFixtureBundle raise {
  build_bundle(CoincidentRefill, true)
}

///|
pub fn required_sequential_mismatch() -> AtomicMismatch {
  {
    // Frozen after reviewing the first externally visible effect of wrongly
    // evaluating the source edge before the coincident destination edge.
    time: 40UL,
    boundary: 20UL,
    output: "destination_valid",
    expected: "0",
    actual: "1",
  }
}

///|
pub fn verify_sequential_negative(actual : String) -> AtomicMismatch raise {
  let bundle = generate_sequential_negative_fixture()
  let mismatch = match bundle.compare_actual(actual) {
    Some(found) => found
    None => raise MissingRequiredNegativeMismatch
  }
  if mismatch != required_sequential_mismatch() {
    raise UnexpectedMismatch(mismatch)
  }
  if actual != bundle.sequential_tsv() {
    raise InvalidActualResult(
      reason="negative bridge differs from the sequential-edge model",
      row=0,
    )
  }
  mismatch
}
