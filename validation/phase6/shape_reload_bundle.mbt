///|
/// Generate a signed 3x5/K17 then 8x8/K1 fetched replay on an 8x8 device with
/// non-power-of-two reduction capacity 17. Exact source reloads reuse A1/B0;
/// both persistent result slots and every host byte are checked independently.
/// This is reference generation only; the exported replay needs a pinned RTL audit.
pub fn generate_shape_reload_bundle() -> FixtureBundle raise {
  let configuration = shape_reload_configuration()
  let hardware = @flux_tile.ring_concurrent_from_capabilities(configuration)
  let fixture_id = "fetched-concurrent-8x8-k17-dynamic-shape-reload"
  let design = @ir.Design::single("phase6-" + fixture_id, hardware)
  let emitted = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hardware, emitted.manifest())
  let run = generate_shape_reload_run(design, hardware, ports)
  assemble_bundle(fixture_id, configuration, design, emitted, ports, run)
}
