///|
/// Replay the passive monitor against emitted RTL, including live counter
/// reads, scope CDC, rejected writes, stalled AXI-Lite replies and resets.
pub fn mig_profile_replay() -> ReadOnlyArray[@projection.Artifact] raise {
  let hw = @control.mig_monitor()
  let design = @ir.Design::single("pblaze3-mig-monitor/v1", hw)
  let emitted = @sv.emit_design(design)
  let ports = @v.collect_ports(hw, emitted.manifest())
  let simulation = @sim.Simulator::prepare(hw)
  let inputs : Map[String, UInt64] = Map([])
  for p in ports {
    if p.is_input() {
      inputs[p.source_name()] = 0UL
    }
  }
  let events : Array[@v.AtomicStimulusEvent] = []
  let rows = StringBuilder()
  let outputs = @v.output_ports(ports)
  let mut seed = 0x193a719bU
  for cycle in 0..<10000 {
    seed = seed * 1664525U + 1013904223U
    inputs["reset"] = if cycle == 0 || cycle == 5000 { 1UL } else { 0UL }
    inputs["weight_scope"] = if cycle % 97 < 65 { 1UL } else { 0UL }
    for j, prefix in ["mig", "narrow", "wide"] {
      for
        i, name in [
          "arvalid", "arready", "arselect", "rvalid", "rready", "rselect", "rlast",
        ] {
        inputs[prefix + "_" + name] = ((seed >> ((i + j * 7) % 31)) & 1U).to_uint64()
      }
    }
    inputs["s_axi_arvalid"] = 1UL
    inputs["s_axi_araddr"] = (0x100 * (cycle / 184 % 3 + 1) + cycle / 8 % 23 * 4).to_uint64()
    inputs["s_axi_rready"] = if cycle % 8 == 7 { 1UL } else { 0UL }
    inputs["s_axi_awvalid"] = (seed & 1U).to_uint64()
    inputs["s_axi_wvalid"] = ((seed >> 1) & 1U).to_uint64()
    inputs["s_axi_bready"] = ((seed >> 2) & 1U).to_uint64()
    inputs["s_axi_awaddr"] = seed.to_uint64()
    inputs["s_axi_wdata"] = (seed ^ 0x5a193c07U).to_uint64()
    inputs["s_axi_wstrb"] = (seed & 15U).to_uint64()
    let drives : Array[@v.AtomicStimulusDrive] = []
    for p in ports {
      if p.is_input() && p.source_name() != "clock" {
        let value = inputs[p.source_name()]
        simulation.set_input(
          p.source_name(),
          @wave.LogicValue::from_uint64(width=p.width(), value~),
        )
        drives.push(
          @v.AtomicStimulusDrive::checked(
            p.emitted_name(),
            @v.normalized_known(p.width(), value),
          ),
        )
      }
    }
    simulation.rising_edge("clock")
    let time = (cycle + 1).to_uint64()
    events.push(
      @v.AtomicStimulusEvent::checked(time, cycle.to_uint64(), drives, [0]),
    )
    let row = [time.to_string(), cycle.to_string()]
    for p in outputs {
      let value = simulation.output(p.source_name())
      assert_true(value.is_fully_known())
      row.push(@v.padded_hex(value.value_bits(), p.width()))
    }
    rows.write_string(row.join("\t") + "\n")
  }
  let clock = ports
    .iter()
    .find_first(p => p.source_name() == "clock")
    .unwrap()
    .emitted_name()
  let stimulus = @v.AtomicStimulus::checked(
    1UL,
    [@v.StimulusDomain::checked(0, clock)],
    events,
  )
  let ir = @codec.serialize(design)
  let prefix = "LUNACHIP-MIG-PROFILE-RESULT\t1\t" +
    @v.utf8_hex("pblaze3-mig-monitor/v1") +
    "\tsha256\t" +
    @v.sha256_hex(ir) +
    "\tsha256\t" +
    @v.sha256_hex(stimulus.to_tsv()) +
    "\ttimebase\t1\n"
  let filename = emitted.modules()[0].filename()
  let job : Json = {
    "schema_version": "lunachip.yosys-job/v1",
    "top_module": emitted.modules()[0].identifier(),
    "sources": [{ "path": filename, "sha256": @v.sha256_hex(emitted.source()) }],
    "formal_tasks": [],
  }
  ReadOnlyArray::from_array([
    { path: "design.lcir", content: ir, },
    { path: filename, content: emitted.source(), },
    {
      path: "manifest.json",
      content: @v.atomic_harness_json(emitted, ports, stimulus, "harness.cpp"),
    },
    {
      path: "harness.cpp",
      content: @v.atomic_harness_cpp(ports, stimulus, prefix, AtomicEdges),
    },
    { path: "stimulus.tsv", content: stimulus.to_tsv(), },
    {
      path: "expected.tsv",
      content: prefix +
      "time\tboundary\t" +
      outputs.map(p => p.source_name()).join("\t") +
      "\n" +
      rows.to_string(),
    },
    { path: "job.json", content: job.stringify(indent=2), },
  ])
}
