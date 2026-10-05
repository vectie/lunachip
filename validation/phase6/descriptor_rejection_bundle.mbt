///|
/// Generate the finite fetched descriptor-location, branch and fault-priority
/// replay on the ordinary 2x2/K2 device. Successful arithmetic is only 1x1/K1.
/// Generation validates LunaWave and the independent host-byte oracle; it does
/// not invoke Verilator or claim complete malformed-input or formal coverage.
///
/// ```mbt check
/// test {
///   let bundle = @phase6.generate_descriptor_rejection_bundle()
///   assert_eq(bundle.id(), "fetched-concurrent-2x2-k2-descriptor-rejection")
///   assert_eq(bundle.ports().filter(port => port.is_output()).length(), 30)
///   assert_eq(bundle.artifacts().length(), 11)
/// }
/// ```
pub fn generate_descriptor_rejection_bundle() -> FixtureBundle raise {
  let configuration = descriptor_rejection_configuration()
  let hardware = @flux_tile.ring_concurrent_from_capabilities(configuration)
  let fixture_id = "fetched-concurrent-2x2-k2-descriptor-rejection"
  let design = @ir.Design::single("phase6-" + fixture_id, hardware)
  let emitted = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hardware, emitted.manifest())
  let run = descriptor_rejection_trace(design, hardware, ports)
  assemble_bundle(fixture_id, configuration, design, emitted, ports, run)
}
