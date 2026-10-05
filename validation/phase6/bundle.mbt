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
/// Generate the predefined signed 8x8/K16 two-slot replay, including all 128
/// stored result words and padded host layouts. Generation validates only the
/// reference trace; independent RTL agreement requires the exported audit.
pub fn generate_array8_bundle() -> FixtureBundle raise {
  let configuration = array8_configuration()
  let hardware = @flux_tile.ring_concurrent_from_capabilities(configuration)
  let design = @ir.Design::single(
    "phase6-fetched-concurrent-8x8-k16-two-slots", hardware,
  )
  let emitted = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hardware, emitted.manifest())
  let run = generate_array8_run(design, hardware, ports)
  assemble_bundle(
    "fetched-concurrent-8x8-k16-two-slots", configuration, design, emitted, ports,
    run,
  )
}

///|
/// Generate the fixed-seed signed 8x8/K16 replay using independent matrix,
/// readiness and response-latency streams. Generation checks the reference
/// trace only; independent RTL agreement requires replay and typed audit.
pub fn generate_seeded_bundle() -> FixtureBundle raise {
  let configuration = array8_configuration()
  let hardware = @flux_tile.ring_concurrent_from_capabilities(configuration)
  let fixture_id = "fetched-concurrent-8x8-k16-seed-5eedc0de20261005"
  let design = @ir.Design::single("phase6-" + fixture_id, hardware)
  let emitted = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hardware, emitted.manifest())
  let run = generate_seeded_run(design, hardware, ports)
  assemble_bundle(fixture_id, configuration, design, emitted, ports, run)
}

///|
/// Generate the fetched writer-rejection and recovery replay. It distinguishes
/// syntax rejection from Failed writer generations and checks all host bytes.
/// Generation validates LunaWave only; independent RTL agreement requires
/// replaying the frozen bundle and auditing actual.tsv.
///
/// ```mbt check
/// test {
///   let bundle = @phase6.generate_writer_fault_bundle()
///   assert_eq(bundle.id(), "fetched-concurrent-1x1-k2-writer-fault-recovery")
///   assert_eq(bundle.ports().filter(port => port.is_output()).length(), 30)
///   assert_eq(bundle.artifacts().length(), 11)
/// }
/// ```
pub fn generate_writer_fault_bundle() -> FixtureBundle raise {
  let configuration = writer_fault_configuration()
  let hardware = @flux_tile.ring_concurrent_from_capabilities(configuration)
  let fixture_id = "fetched-concurrent-1x1-k2-writer-fault-recovery"
  let design = @ir.Design::single("phase6-" + fixture_id, hardware)
  let emitted = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hardware, emitted.manifest())
  let run = generate_writer_fault_run(design, hardware, ports)
  assemble_bundle(fixture_id, configuration, design, emitted, ports, run)
}

///|
/// Generate the fixed loader/storer protocol-owner replay. It checks owned
/// malformed responses, ACK-backed cancellation progress and compute drainage.
/// Generation validates only the frozen LunaWave trace, not independent RTL.
///
/// ```mbt check
/// test {
///   let bundle = @phase6.generate_dma_poison_bundle()
///   assert_eq(bundle.id(), "fetched-concurrent-8x8-k64-dma-poison-owners")
///   assert_eq(bundle.ports().filter(port => port.is_output()).length(), 30)
///   assert_eq(bundle.artifacts().length(), 11)
/// }
/// ```
pub fn generate_dma_poison_bundle() -> FixtureBundle raise {
  let configuration = dma_poison_configuration()
  let hardware = @flux_tile.ring_concurrent_from_capabilities(configuration)
  let fixture_id = "fetched-concurrent-8x8-k64-dma-poison-owners"
  let design = @ir.Design::single("phase6-" + fixture_id, hardware)
  let emitted = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hardware, emitted.manifest())
  let run = generate_dma_poison_run(design, hardware, ports)
  assemble_bundle(fixture_id, configuration, design, emitted, ports, run)
}

///|
/// Generate the fixed matching-remote-failure replay, including a partial
/// host write and same-generation retry without reset. This validates only
/// LunaWave; independent RTL agreement requires replay and typed audit.
///
/// ```mbt check
/// test {
///   let bundle = @phase6.generate_remote_fault_bundle()
///   assert_eq(bundle.id(), "fetched-concurrent-1x2-k2-remote-fault-recovery")
///   assert_eq(bundle.ports().filter(port => port.is_output()).length(), 30)
///   assert_eq(bundle.artifacts().length(), 11)
/// }
/// ```
pub fn generate_remote_fault_bundle() -> FixtureBundle raise {
  let configuration = remote_fault_configuration()
  let hardware = @flux_tile.ring_concurrent_from_capabilities(configuration)
  let fixture_id = "fetched-concurrent-1x2-k2-remote-fault-recovery"
  let design = @ir.Design::single("phase6-" + fixture_id, hardware)
  let emitted = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hardware, emitted.manifest())
  let run = generate_remote_fault_run(design, hardware, ports)
  assemble_bundle(fixture_id, configuration, design, emitted, ports, run)
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
