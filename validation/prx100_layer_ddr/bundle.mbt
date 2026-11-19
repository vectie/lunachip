///|
pub fn bridge_replay_bundle(
  wide~ : Bool = false,
  batch~ : Bool = false,
  streaming~ : Bool = false,
  period~ : Int32 = 4,
  read_ahead~ : Bool = false,
  eight_row~ : Bool = false,
  sixteen_row~ : Bool = false,
  aligned_extent~ : Bool = false,
  delivery~ : Bool = false,
) -> ReadOnlyArray[@projection.Artifact] raise {
  let b = bridge_bench(
    recording=true,
    wide~,
    batch~,
    streaming~,
    period~,
    read_ahead~,
    eight_row~,
    sixteen_row~,
    aligned_extent~,
    delivery~,
  )
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
  b.read_delay = 60
  b.begin_line(0UL, burst=true)
  for _ in 0..<200 {
    b.step()
  }
  assert_eq(b.max_outstanding.val, 8)
  for _ in 0..<32 {
    ignore(b.line_beat(11))
  }
  b.begin_line(0UL, burst=true)
  for _ in 0..<20 {
    b.step()
  }
  b.environment(bad_end=true)
  let mut failed = false
  for _ in 0..<32 {
    let (_, fault, _) = b.line_beat(3)
    if fault != 0UL {
      failed = true
    }
  }
  assert_true(failed)
  b.environment()
  b.reset()
  if wide {
    wide_bridge_replay(b)
  }
  if batch {
    if streaming {
      b.read_delay = 60
    }
    if read_ahead {
      read_ahead_bridge_replay(b)
    } else {
      batch_bridge_replay(b)
    }
  }
  if streaming {
    // Repeated mixed requests exercise pointer wrap, byte masks, ownership
    // changes and source stalls on the exact native-width implementation.
    let mut sequence = 0
    while b.tick < 110000 {
      let address = (sequence % 256 * 4).to_uint64()
      let word = (sequence.reinterpret_as_uint() * 1664525U + 1013904223U).to_uint64()
      set(b.sim, "request_wide", 1, 0UL)
      set(b.sim, "request_data", 32, 0UL)
      assert_eq(b.transaction(address, word~, hold=sequence % 11), (0UL, 0UL))
      assert_eq(b.transaction(address, hold=sequence % 13), (word, 0UL))
      sequence += 1
      if sequence % 64 == 0 {
        b.reset()
      }
    }
  }
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
  assert_eq(b.transaction(0UL), (b.memory[0][0].to_uint64(), 0UL))
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
  let source = e.source()
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
