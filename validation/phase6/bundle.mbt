///|
/// Generate the deterministic 1x1/K2 fetched concurrent device fixture.
/// The bundle is ready for the existing pinned Verilator runner. Generation
/// performs only LunaWave/reference-host validation, not an external gate.
pub fn generate_bundle() -> FixtureBundle raise {
  let configuration = configuration()
  let hardware = @flux_tile.ring_concurrent_from_capabilities(configuration)
  let design = @ir.Design::single("phase6-fetched-concurrent-1x1-k2", hardware)
  let emitted = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hardware, emitted.manifest())
  let run = generate_run(design, hardware, ports)
  assemble_bundle(
    "fetched-concurrent-1x1-k2", configuration, design, emitted, ports, run,
  )
}

///|
/// Generate the predefined 1x1/K512 replay that requires measured DMA/Run
/// overlap and ordered retirement under completion backpressure. Generation
/// is reference validation only, not independent Verilator evidence.
pub fn generate_concurrent_bundle() -> FixtureBundle raise {
  let configuration = concurrent_configuration()
  let hardware = @flux_tile.ring_concurrent_from_capabilities(configuration)
  let design = @ir.Design::single(
    "phase6-fetched-concurrent-1x1-k512-overlap", hardware,
  )
  let emitted = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hardware, emitted.manifest())
  let run = generate_concurrent_run(design, hardware, ports)
  assemble_bundle(
    "fetched-concurrent-1x1-k512-overlap", configuration, design, emitted, ports,
    run,
  )
}

///|
/// Generate the predefined owned-reader-poison and joint-reset replay.
/// The trace checks finite public-boundary obligations in LunaWave; it does
/// not claim independent RTL agreement until the exported replay is audited.
pub fn generate_fault_reset_bundle() -> FixtureBundle raise {
  let configuration = fault_reset_configuration()
  let hardware = @flux_tile.ring_concurrent_from_capabilities(configuration)
  let design = @ir.Design::single(
    "phase6-fetched-concurrent-1x1-k64-reader-poison-reset", hardware,
  )
  let emitted = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hardware, emitted.manifest())
  let run = generate_fault_reset_run(design, hardware, ports)
  assemble_bundle(
    "fetched-concurrent-1x1-k64-reader-poison-reset", configuration, design, emitted,
    ports, run,
  )
}

///|
fn assemble_bundle(
  fixture_id : String,
  configuration : @capabilities.Capabilities,
  design : @ir.Design,
  emitted : @systemverilog.EmittedDesign,
  ports : ReadOnlyArray[@verilator.HarnessPort],
  run : FixtureRun,
) -> FixtureBundle raise {
  let artifacts : Array[BundleArtifact] = [
    { path: "design.lcir", content: @ir_codec.serialize(design), },
    { path: "capabilities.json", content: configuration.manifest(), },
  ]
  for artifact in emitted.modules() {
    artifacts.push({ path: artifact.filename(), content: artifact.source(), })
  }
  artifacts.push({
    path: "names.lcnm",
    content: emitted.manifest().to_canonical_text(),
  })
  artifacts.push({
    path: "manifest.json",
    content: @verilator.harness_json(emitted, ports),
  })
  artifacts.push({
    path: "harness.cpp",
    content: @verilator.harness_cpp(
      ports,
      run.expected.identity(),
      result_protocol(),
    ),
  })
  artifacts.push({ path: "stimulus.tsv", content: run.stimulus_tsv, })
  artifacts.push({ path: "expected.tsv", content: run.expected_tsv, })
  artifacts.push({
    path: "stimulus.audit",
    content: run.stimulus.to_canonical_text(),
  })
  artifacts.push({
    path: "expected.audit",
    content: run.expected.to_canonical_text(),
  })
  artifacts.push({ path: "workload.audit", content: run.summary, })
  {
    fixture_id,
    ports,
    expected: run.expected,
    expected_tsv: run.expected_tsv,
    post_reset_cycles: run.cycles,
    artifacts: ReadOnlyArray::from_array(artifacts),
  }
}
