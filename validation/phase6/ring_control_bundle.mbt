///|
/// Generate the finite fetched ring-configuration/publication rejection and
/// joint-reset recovery replay. Generation checks LunaWave against independent
/// host-byte expectations; it does not invoke independent RTL or formal tools.
///
/// ```mbt check
/// test {
///   let bundle = @phase6.generate_ring_control_bundle()
///   assert_eq(bundle.id(), "fetched-concurrent-1x1-k512-ring-control-recovery")
///   assert_eq(bundle.ports().filter(port => port.is_output()).length(), 30)
///   assert_eq(bundle.artifacts().length(), 11)
/// }
/// ```
pub fn generate_ring_control_bundle() -> FixtureBundle raise {
  let configuration = ring_control_configuration()
  let hardware = @flux_tile.ring_concurrent_from_capabilities(configuration)
  let fixture_id = "fetched-concurrent-1x1-k512-ring-control-recovery"
  let design = @ir.Design::single("phase6-" + fixture_id, hardware)
  let emitted = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hardware, emitted.manifest())
  let run = ring_control_trace(design, hardware, ports)
  assemble_bundle(fixture_id, configuration, design, emitted, ports, run)
}
