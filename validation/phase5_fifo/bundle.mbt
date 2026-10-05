///|
fn coverage_text(c : FifoCoverage) -> String {
  "enqueues=\{c.enqueues}\ndequeues=\{c.dequeues}\nenqueue_only=\{c.enqueue_only}\ndequeue_only=\{c.dequeue_only}\nsimultaneous=\{c.simultaneous}\ncoincidences=\{c.coincidences}\nbackpressure=\{c.backpressure}\nfull_entries=\{c.full_entries}\nfull_exits=\{c.full_exits}\nempty_entries=\{c.empty_entries}\nempty_exits=\{c.empty_exits}\nwrite_wraps=\{c.write_wraps}\nread_wraps=\{c.read_wraps}\nsource_reset_assertions=\{c.source_reset_assertions}\nsource_reset_releases=\{c.source_reset_releases}\ndestination_reset_assertions=\{c.destination_reset_assertions}\ndestination_reset_releases=\{c.destination_reset_releases}\n"
}

///|
fn build_bundle(
  kind : FifoFixtureKind,
  sequential_harness : Bool,
) -> BuiltFifoFixture raise {
  let design = fixture_design(kind)
  guard design.top_module() is Some(hardware_module) else {
    raise MissingTopModule
  }
  let emitted = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hardware_module, emitted.manifest())
  let stimulus = project_schedule(
    kind,
    hardware_module,
    fixture_schedule(kind),
    ports,
  )
  let (expected, coverage) = generate_results(
    kind, design, hardware_module, ports, stimulus, false,
  )
  let (sequential, _) = generate_results(
    kind, design, hardware_module, ports, stimulus, true,
  )
  let harness = @verilator.atomic_harness_cpp(
    ports,
    stimulus,
    identity_prefix(design, stimulus),
    if sequential_harness {
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
  artifacts.push({ path: "harness.cpp", content: harness, })
  artifacts.push({ path: "stimulus.tsv", content: stimulus.to_tsv(), })
  artifacts.push({ path: "expected.tsv", content: expected, })
  artifacts.push({ path: "coverage.txt", content: coverage_text(coverage), })
  artifacts.push({
    path: "fixture-metadata.txt",
    content: "id=\{kind.id()}\ndepth=\{kind.depth()}\nstages=\{kind.stages()}\ntimebase=\{stimulus.ticks_per_source_unit()}\nevents=\{stimulus.events().length()}\ngenerator=deterministic-stateful\nledger=pre-edge-dequeue-before-enqueue\n",
  })
  if sequential_harness {
    artifacts.push({ path: "expected-sequential.tsv", content: sequential, })
  }
  let frozen_artifacts = ReadOnlyArray::from_array(artifacts)
  {
    kind,
    design,
    emitted,
    stimulus,
    expected_tsv: expected,
    sequential_tsv: sequential,
    coverage,
    artifacts: frozen_artifacts,
    bundle: { expected_tsv: expected, artifacts: frozen_artifacts, },
  }
}

///|
pub fn generate_fifo_fixture(kind : FifoFixtureKind) -> FifoFixtureBundle raise {
  build_bundle(kind, false).bundle
}

///|
pub fn standard_fifo_fixtures() -> ReadOnlyArray[FifoFixtureKind] {
  ReadOnlyArray::from_array([
    Depth4ScalarTwoStage,
    Depth8AggregateThreeStage,
    Depth4AsymmetricFourStage,
  ])
}

///|
pub fn generate_sequential_negative_fixture() -> FifoFixtureBundle raise {
  build_bundle(Depth4AsymmetricFourStage, true).bundle
}

///|
fn lines(source : String) -> Array[String] raise FifoFixtureError {
  if !source.has_suffix("\n") {
    raise InvalidActualResult(reason="missing final newline", row=0)
  }
  source.split("\n").map(x => x.to_owned()).to_array()
}

///|
fn cells(source : String) -> Array[String] {
  source.split("\t").map(x => x.to_owned()).to_array()
}

///|
fn canonical_hex(value : String) -> Bool {
  if value.is_empty() {
    return false
  }
  value.all(c => (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))
}

///|
fn decimal(value : String, row : Int) -> UInt64 raise FifoFixtureError {
  if value.is_empty() || (value.length() > 1 && value[0] == '0') {
    raise InvalidActualResult(reason="noncanonical decimal", row~)
  }
  @string.parse_uint64(value) catch {
    _ => raise InvalidActualResult(reason="invalid decimal", row~)
  }
}

///|
pub fn FifoFixtureBundle::compare_actual(
  self : FifoFixtureBundle,
  actual : String,
) -> AtomicMismatch? raise {
  let expected = lines(self.expected_tsv)
  let observed = lines(actual)
  if expected.length() != observed.length() {
    raise InvalidActualResult(reason="wrong result row count", row=0)
  }
  if expected[0] != observed[0] {
    raise InvalidActualResult(reason="identity header mismatch", row=1)
  }
  if expected[1] != observed[1] {
    raise InvalidActualResult(reason="output header mismatch", row=2)
  }
  let names = cells(expected[1])
  let mut first_mismatch : AtomicMismatch? = None
  for row in 2..<(expected.length() - 1) {
    let a = cells(observed[row])
    let e = cells(expected[row])
    if a.length() != e.length() {
      raise InvalidActualResult(reason="wrong column count", row=row + 1)
    }
    let time = decimal(a[0], row + 1)
    let boundary = decimal(a[1], row + 1)
    if a[0] != e[0] || a[1] != e[1] {
      raise InvalidActualResult(reason="time or boundary mismatch", row=row + 1)
    }
    for col in 2..<a.length() {
      if !canonical_hex(a[col]) || a[col].length() != e[col].length() {
        raise InvalidActualResult(
          reason="noncanonical hexadecimal result",
          row=row + 1,
        )
      }
      if a[col] != e[col] && first_mismatch is None {
        first_mismatch = Some({
          time,
          boundary,
          output: names[col],
          expected: e[col],
          actual: a[col],
        })
      }
    }
  }
  first_mismatch
}

///|
/// Frozen after running the deliberately sequential bridge over the fixture.
fn required_sequential_mismatch() -> AtomicMismatch {
  {
    time: 133UL,
    boundary: 133UL,
    output: "destination_lane0",
    expected: "00",
    actual: "fc",
  }
}

///|
pub fn verify_sequential_negative(actual : String) -> AtomicMismatch raise {
  let built = build_bundle(Depth4AsymmetricFourStage, true)
  guard built.bundle.compare_actual(actual) is Some(found) else {
    raise MissingRequiredNegativeMismatch
  }
  if found != required_sequential_mismatch() {
    raise UnexpectedMismatch(found)
  }
  if actual != built.sequential_tsv {
    raise InvalidActualResult(reason="not sequential model", row=0)
  }
  found
}
