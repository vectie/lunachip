///|
fn protocol() -> @verilator.ResultProtocol raise {
  @verilator.ResultProtocol::checked(
    "LUNACHIP-DDR-RESULT", "1", "prx100-ddr-diagnostic/v1",
  )
}

///|
fn replay_ports() -> ReadOnlyArray[@verilator.HarnessPort] raise {
  let hw = @ddr.controller()
  let e = @systemverilog.emit_design(
    @ir.Design::single("prx100-standalone-ddr-diagnostic-v1", hw),
  )
  @verilator.collect_ports(hw, e.manifest())
}

///|
/// Native expectations from a separate queued/masked DRAM model.
pub fn generate_bundle() -> ReadOnlyArray[@ddr.Artifact] raise {
  let b = bench(64)
  assert_eq(b.get(0UL), 0x44445233UL)
  assert_eq(b.get(1UL, response=2UL), 0UL)
  assert_eq(b.write(20UL, 1UL, strobe=1UL), 2UL)
  for mode in 0..<6 {
    b.run(
      mode.to_uint64(),
      0x7101626UL,
      64,
      command=if mode % 2 == 0 { 1UL } else { 9UL },
    )
  }
  b.run(0UL, 42UL, 64)
  b.run(6UL, 42UL, 64)
  b.run(7UL, 42UL, 64, command=9UL)
  b.reset_model()
  b.run(7UL, 42UL, 64, command=11UL)
  b.run(4UL, 17UL, 1, command=5UL)
  b.run(4UL, 17UL, 1, command=3UL)
  let design = @ir.Design::single(
    "prx100-standalone-ddr-diagnostic-v1",
    b.hardware,
  )
  let e = @systemverilog.emit_design(design)
  let ports = replay_ports()
  let stimulus = b.stimulus.to_string()
  let identity = @differential.ResultIdentity::checked(
    @differential.DesignIdentity::checked(
      protocol().semantic_version(),
      @verilator.sha256_hex(@codec.serialize(design)),
    ),
    @verilator.sha256_hex(stimulus),
  )
  let artifacts = @ddr.export_bundle().iter().to_array()
  // The physical bundle is retained, while this harness reads only the digital
  // tester. Vendor MIG/clock/JTAG models are outside the replay's claim.
  let normalized = artifacts[artifacts
    .search_by(a => a.path == "tester.sv")
    .unwrap()].content
  artifacts.push({ path: e.modules()[0].filename(), content: normalized, })
  artifacts.push({
    path: "manifest.json",
    content: @verilator.harness_json(e, ports),
  })
  artifacts.push({
    path: "harness.cpp",
    content: @verilator.harness_cpp(ports, identity, protocol()),
  })
  artifacts.push({ path: "stimulus.tsv", content: stimulus, })
  artifacts.push({
    path: "expected.tsv",
    content: protocol().magic() +
    "\t1\t" +
    @verilator.utf8_hex(protocol().semantic_version()) +
    "\tsha256\t" +
    identity.design().design_sha256() +
    "\tsha256\t" +
    identity.stimulus_sha256() +
    "\n" +
    b.expected.to_string(),
  })
  artifacts.push({
    path: "fixture.txt",
    content: "cycles=" +
    (b.cycle - 1).to_string() +
    "\nbytes_per_test=1024\npatterns=0..7 plus reverse, read-only, write-only and reset retention\n",
  })
  ReadOnlyArray::from_array(artifacts)
}

///|
pub fn audit(expected : String, actual : String, cycles : Int32) -> Unit raise {
  let ports = replay_ports()
  let wanted = @verilator.parse_actual_tsv(expected, ports, cycles, protocol())
  let observed = @verilator.parse_actual_tsv(actual, ports, cycles, protocol())
  assert_eq(@differential.compare(wanted, observed), Equal)
}
