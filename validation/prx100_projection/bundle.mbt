///|
fn protocol() -> @verilator.ResultProtocol raise {
  @verilator.ResultProtocol::checked(
    "LUNACHIP-DDR-PROJECTION-RESULT", "1", "prx100-ddr-core/v1",
  )
}

///|
fn ports() -> ReadOnlyArray[@verilator.HarnessPort] raise {
  let h = @projection.controller()
  let e = @systemverilog.emit_design(
    @ir.Design::single("prx100-ddr-projection-controller/v1", h),
  )
  @verilator.collect_ports(h, e.manifest())
}

///|
fn projection_replay_bench() -> Bench raise {
  let b = bench(recording=true)
  assert_eq(b.write(0x10000000UL, 0x89abcdefUL, data_first=true, hold=3), 0UL)
  assert_eq(b.read(0x10000000UL, hold=5), 0x89abcdefUL)
  assert_eq(b.write(16UL, 1UL), 2UL)
  assert_eq(b.read(0x20000000UL, response=2UL), 0UL)
  let (a, w, partials, sums) = fixture(4, 3)
  store_codes(b, 0x100000U, w)
  store_codes(b, 0x200000U, a)
  b.configure(4)
  b.environment(stalled=true)
  assert_eq(b.write(16UL, 1UL), 0UL)
  for _ in 0..<50 {
    b.step()
  }
  assert_eq(b.write(0x10100000UL, 1UL), 2UL)
  b.environment()
  b.finish_job(4, partials, sums)
  assert_eq(b.write(16UL, 1UL), 0UL)
  b.finish_job(4, partials, sums)
  for j in 0..<8 {
    assert_eq(
      b.read(0x10400000UL + j.to_uint64() * 4UL),
      sums[j].reinterpret_as_uint().to_uint64(),
    )
  }
  b
}

///|
pub fn replay_bundle() -> ReadOnlyArray[@projection.Artifact] raise {
  let b = projection_replay_bench()
  let design = @ir.Design::single(
    "prx100-ddr-projection-controller/v1",
    b.hardware,
  )
  let e = @systemverilog.emit_design(design)
  let ports = ports()
  let stimulus = b.stimulus.to_string()
  let identity = @differential.ResultIdentity::checked(
    @differential.DesignIdentity::checked(
      protocol().semantic_version(),
      @verilator.sha256_hex(@codec.serialize(design)),
    ),
    @verilator.sha256_hex(stimulus),
  )
  let artifacts = @projection.digital_bundle().iter().to_array()
  let source = artifacts
    .iter()
    .find_first(a => a.path == "controller.sv")
    .unwrap().content
  artifacts.push({ path: e.modules()[0].filename(), content: source, })
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
    "\ncontroller driven by unchanged word-read core plus independent queued DDR activation-line/weight-stream model with response-beat gaps; two repeated four-tile jobs; prefetch requests=" +
    b.overlapped_reads.length().to_string() +
    "; simultaneous BRAM read/write edges=" +
    b.simultaneous_reads.length().to_string() +
    "; publications=" +
    b.publications.length().to_string() +
    "; core requests during result collection=" +
    b.collection_requests.length().to_string() +
    "\n",
  })
  ReadOnlyArray::from_array(artifacts)
}

///|
pub fn audit(expected : String, actual : String, cycles : Int32) -> Unit raise {
  let p = ports()
  assert_eq(
    @differential.compare(
      @verilator.parse_actual_tsv(expected, p, cycles, protocol()),
      @verilator.parse_actual_tsv(actual, p, cycles, protocol()),
    ),
    Equal,
  )
}

///|
pub fn bridge_replay_bundle() -> ReadOnlyArray[@projection.Artifact] raise {
  let b = bridge_bench(recording=true)
  for lane in 0..<4 {
    assert_eq(
      b.transaction(
        lane.to_uint64() * 4UL,
        word=0xabcdef00UL + lane.to_uint64(),
        hold=9,
      ),
      (0UL, 0UL),
    )
  }
  for lane in 0..<4 {
    assert_eq(
      b.transaction(lane.to_uint64() * 4UL, hold=7),
      (0xabcdef00UL + lane.to_uint64(), 0UL),
    )
  }
  assert_eq(b.transaction(1020UL, word=0x89abcdefUL), (0UL, 0UL))
  assert_eq(b.transaction(1020UL), (0x89abcdefUL, 0UL))
  assert_eq(b.transaction(1UL, word=1UL), (0UL, 1UL))
  let streamed = b.line_transaction(0UL, 9)
  for lane in 0..<4 {
    assert_eq(
      streamed[lane],
      (0xabcdef00UL + lane.to_uint64(), 0UL, if lane == 3 { 1UL } else { 0UL }),
    )
  }
  let rejected = b.line_transaction(4UL, 3)
  for lane in 0..<4 {
    assert_eq(rejected[lane], (0UL, 1UL, if lane == 3 { 1UL } else { 0UL }))
  }
  b.begin_line(0UL)
  assert_eq(b.line_beat(5), (0xabcdef00UL, 0UL, 0UL))
  b.reset()
  assert_eq(b.line_transaction(0UL, 3), streamed)
  // The stream installs the line. Force the native-fault probe to miss it.
  assert_eq(b.transaction(0UL, word=0xabcdef00UL), (0UL, 0UL))
  b.environment(bad_end=true)
  assert_eq(b.transaction(0UL), (0UL, 3UL))
  b.environment()
  b.reset()
  assert_eq(b.transaction(0UL), (0xabcdef00UL, 0UL))
  write_line_replay(b)
  stream_bridge_replay(b)
  if b.tick % 2 == 0 {
    b.step()
  }
  set(b.sim, "calibrated", 1, 0UL)
  b.step()
  set(b.sim, "calibrated", 1, 1UL)
  for _ in 0..<16 {
    b.step()
  }
  assert_eq(value(b.sim, "memory_healthy"), 0UL)
  assert_eq(b.transaction(0UL), (0UL, 2UL))
  b.reset()
  assert_eq(b.transaction(0UL), (0xabcdef00UL, 0UL))
  let d = @ir.Design::single("prx100-ddr-projection-bridge/v1", b.hardware)
  let e = @systemverilog.emit_design(d)
  fn emitted(name : String) -> String {
    b.ports
    .iter()
    .find_first(p => p.source_name() == name)
    .unwrap()
    .emitted_name()
  }
  let stimulus = @verilator.AtomicStimulus::checked(
    1UL,
    [
      @verilator.StimulusDomain::checked(0, emitted("clock")),
      @verilator.StimulusDomain::checked(1, emitted("ui_clock")),
    ],
    b.events,
  )
  let prefix = "LUNACHIP-DDR-BRIDGE-RESULT\t2\t" +
    @verilator.utf8_hex("prx100-ddr-word-bridge/v1") +
    "\tsha256\t" +
    @verilator.sha256_hex(@codec.serialize(d)) +
    "\tsha256\t" +
    @verilator.sha256_hex(stimulus.to_tsv()) +
    "\ttimebase\t1\n"
  let header = "time\tboundary\t" +
    @verilator.output_ports(b.ports).map(p => p.source_name()).join("\t") +
    "\n"
  let all = @projection.digital_bundle()
  let source = all.iter().find_first(a => a.path == "bridge.sv").unwrap().content
  ReadOnlyArray::from_array([
    { path: "design.lcir", content: @codec.serialize(d), },
    { path: e.modules()[0].filename(), content: source, },
    { path: "bridge.sv", content: source, },
    {
      path: "manifest.json",
      content: @verilator.atomic_harness_json(
        e,
        b.ports,
        stimulus,
        "harness.cpp",
      ),
    },
    {
      path: "harness.cpp",
      content: @verilator.atomic_harness_cpp(
        b.ports,
        stimulus,
        prefix,
        AtomicEdges,
      ),
    },
    { path: "stimulus.tsv", content: stimulus.to_tsv(), },
    { path: "expected.tsv", content: prefix + header + b.rows.to_string(), },
    {
      path: "fixture.txt",
      content: "events=" +
      b.events.length().to_string() +
      "\natomic coincident50/100MHz edges, independent command/WDF stalls, lane masks, held four-beat lines and32-beat weight streams, latched burst addresses, invalid alignment, partial-stream reset, protocol fault and reset\n",
    },
    {
      path: "job.json",
      content: "{\"schema_version\":\"lunachip.yosys-job/v1\",\"top_module\":\"" +
      e.modules()[0].identifier() +
      "\",\"sources\":[{\"path\":\"bridge.sv\",\"sha256\":\"" +
      @verilator.sha256_hex(source) +
      "\"}],\"formal_tasks\":[]}\n",
    },
  ])
}
