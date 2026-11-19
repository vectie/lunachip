///|
priv struct Bench {
  sim : @sim.Simulator
  reset_port : String
  events : Array[@verilator.AtomicStimulusEvent]
  rows : StringBuilder
  mut time : UInt64
  mut healthy_edges : Int32
  mut rising_edges : Int32
  mut asynchronous_events : Int32
}

///|
fn Bench::event(
  self : Bench,
  reset : Bool,
  edge : Bool,
  delta~ : UInt64 = 20UL,
) -> Unit raise {
  self.time += delta
  let bit = if reset { 1UL } else { 0UL }
  self.sim.apply_event(
    @sim.TimestampEvent::checked(
      @sim.SimulationTime::from_uint64(self.time),
      [
        @sim.InputDrive::checked(
          "reset",
          @wave.LogicValue::from_uint64(width=1, value=bit),
        ),
      ],
      if edge {
        [@ir.ClockDomainId::new(0)]
      } else {
        []
      },
    ),
  )
  // Independent host oracle counts only actual rising edges, never elapsed time.
  if reset {
    self.healthy_edges = 0
  } else if edge && self.healthy_edges < 128 {
    self.healthy_edges += 1
  }
  if edge {
    self.rising_edges += 1
  } else {
    self.asynchronous_events += 1
  }
  let output = self.sim.output("release_n")
  assert_true(output.is_fully_known())
  assert_eq(
    output.value_bits(),
    if self.healthy_edges == 128 {
      1UL
    } else {
      0UL
    },
    msg="reset oracle mismatch at time " + self.time.to_string(),
  )
  let boundary = self.events.length().to_uint64()
  self.events.push(
    @verilator.AtomicStimulusEvent::checked(
      self.time,
      boundary,
      [
        @verilator.AtomicStimulusDrive::checked(
          self.reset_port,
          @verilator.normalized_known(1, bit),
        ),
      ],
      if edge {
        [0]
      } else {
        []
      },
    ),
  )
  self.rows.write_string(
    self.time.to_string() +
    "\t" +
    boundary.to_string() +
    "\t" +
    output.value_bits().to_string() +
    "\n",
  )
}

///|
/// Finite digital reset replay with an independent edge-count oracle.
pub fn replay_bundle() -> ReadOnlyArray[@projection.Artifact] raise {
  let hw = @reset.hardware_module()
  let design = @ir.Design::single("pblaze3-reset/v1", hw)
  let emitted = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hw, emitted.manifest())
  let b : Bench = {
    sim: @sim.Simulator::prepare(hw),
    reset_port: ports
    .iter()
    .find_first(p => p.source_name() == "reset")
    .unwrap()
    .emitted_name(),
    events: [],
    rows: StringBuilder(),
    time: 0UL,
    healthy_edges: 0,
    rising_edges: 0,
    asynchronous_events: 0,
  }
  // Initial assertion and deassertion occur without any clock edge.
  b.event(true, false, delta=1UL)
  b.event(false, false, delta=1UL)
  for _ in 0..<127 {
    b.event(false, true)
  }
  assert_eq(b.healthy_edges, 127)
  b.event(false, false, delta=1000000UL) // a halted clock cannot release reset
  b.event(false, true)
  assert_eq(b.healthy_edges, 128)
  for _ in 0..<2048 {
    b.event(false, true)
  } // saturates, never wraps
  b.event(false, false, delta=1000000UL) // held released while clock halted
  b.event(true, false, delta=1UL) // fault asserts reset without a rising edge
  assert_eq(b.sim.output("release_n").value_bits(), 0UL)
  for _ in 0..<16 {
    b.event(true, true)
  }
  b.event(false, false, delta=1UL)
  b.event(false, false, delta=1000000UL) // deassertion alone cannot advance
  for count in [0, 1, 63, 127, 128] {
    for _ in 0..<count {
      b.event(false, true)
    }
    b.event(true, false, delta=1UL)
    b.event(false, false, delta=1UL)
    assert_eq(b.healthy_edges, 0)
  }
  for _ in 0..<127 {
    b.event(false, true)
  }
  b.event(true, true) // reset wins over the would-be 128th rising edge
  for _ in 0..<128 {
    b.event(false, true)
  }
  assert_eq(b.healthy_edges, 128)
  let mut seed = 0x70b1a53U
  for _ in 0..<12000 {
    seed = seed * 1664525U + 1013904223U
    b.event(
      (seed & 511U) == 0U,
      (seed & 3U) != 1U,
      delta=if (seed & 15U) == 0U { 1000000UL } else { 1UL },
    )
  }
  let stimulus = @verilator.AtomicStimulus::checked(
    1UL,
    [
      @verilator.StimulusDomain::checked(
        0,
        ports
        .iter()
        .find_first(p => p.source_name() == "clk")
        .unwrap()
        .emitted_name(),
      ),
    ],
    b.events,
  )
  let serialized = @codec.serialize(design)
  let prefix = "LUNACHIP-PBLAZE3-RESET-RESULT\t1\t" +
    @verilator.utf8_hex("pblaze3-reset/v1") +
    "\tsha256\t" +
    @verilator.sha256_hex(serialized) +
    "\tsha256\t" +
    @verilator.sha256_hex(stimulus.to_tsv()) +
    "\ttimebase\t1\n"
  ReadOnlyArray::from_array([
    { path: "design.lcir", content: serialized, },
    { path: emitted.modules()[0].filename(), content: emitted.source(), },
    {
      path: "manifest.json",
      content: @verilator.atomic_harness_json(
        emitted, ports, stimulus, "harness.cpp",
      ),
    },
    {
      path: "harness.cpp",
      content: @verilator.atomic_harness_cpp(
        ports,
        stimulus,
        prefix,
        AtomicEdges,
      ),
    },
    { path: "stimulus.tsv", content: stimulus.to_tsv(), },
    {
      path: "expected.tsv",
      content: prefix + "time\tboundary\trelease_n\n" + b.rows.to_string(),
    },
    {
      path: "fixture.txt",
      content: "rising_edges=" +
      b.rising_edges.to_string() +
      "\nasynchronous_events=" +
      b.asynchronous_events.to_string() +
      "\nevents=" +
      b.events.length().to_string() +
      "\nIndependent count oracle: exact128 release;2048edge saturation; retrigger at0/1/63/127/128; reset assertion between edges and onedge; halted clock before/after release; million-tick halted intervals. Seed0x70b1a53,12000 seeded events. No XPM/metastability or routed timing claim.\n",
    },
    {
      path: "job.json",
      content: "{\"schema_version\":\"lunachip.yosys-job/v1\",\"top_module\":\"" +
      emitted.modules()[0].identifier() +
      "\",\"sources\":[{\"path\":\"" +
      emitted.modules()[0].filename() +
      "\",\"sha256\":\"" +
      @verilator.sha256_hex(emitted.source()) +
      "\"}],\"formal_tasks\":[]}\n",
    },
  ])
}
