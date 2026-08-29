///|
pub fn generate_bundle(plan : FixturePlan) -> FixtureBundle raise {
  let design = fixture_design(plan.kind)
  guard design.top_module() is Some(hardware_module) else {
    raise MissingTopModule
  }
  let emitted = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hardware_module, emitted.manifest())
  let (stimulus, expected, stimulus_tsv, expected_tsv) = generate_run(
    plan, design, hardware_module, ports,
  )
  let protocol = result_protocol()
  let json = @verilator.harness_json(emitted, ports)
  let cpp = @verilator.harness_cpp(ports, expected.identity(), protocol)
  let artifacts : Array[BundleArtifact] = []
  artifacts.push({ path: "design.lcir", content: @ir_codec.serialize(design) })
  for module_artifact in emitted.modules() {
    artifacts.push({
      path: module_artifact.filename(),
      content: module_artifact.source(),
    })
  }
  artifacts.push({
    path: "names.lcnm",
    content: emitted.manifest().to_canonical_text(),
  })
  artifacts.push({ path: "manifest.json", content: json })
  artifacts.push({ path: "harness.cpp", content: cpp })
  artifacts.push({ path: "stimulus.tsv", content: stimulus_tsv })
  artifacts.push({ path: "expected.tsv", content: expected_tsv })
  artifacts.push({
    path: "stimulus.audit",
    content: stimulus.to_canonical_text(),
  })
  artifacts.push({
    path: "expected.audit",
    content: expected.to_canonical_text(),
  })
  {
    plan,
    design,
    emitted,
    ports,
    stimulus,
    expected,
    harness_json: json,
    harness_cpp: cpp,
    stimulus_tsv,
    expected_tsv,
    artifacts: ReadOnlyArray::from_array(artifacts),
  }
}

///|
pub fn FixtureBundle::parse_actual_tsv(
  self : FixtureBundle,
  source : String,
) -> @differential.ObservationSet raise {
  @verilator.parse_actual_tsv(
    source,
    self.ports,
    self.plan.post_reset_cycles,
    result_protocol(),
  )
}

///|
pub fn FixtureBundle::compare_actual_tsv(
  self : FixtureBundle,
  source : String,
) -> @differential.Comparison raise {
  @differential.compare(self.expected, self.parse_actual_tsv(source))
}
