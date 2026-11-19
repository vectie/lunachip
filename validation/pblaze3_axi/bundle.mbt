///|
/// Deterministic independent-RTL replay inputs for the production AXI bridge.
/// At least100000 recorded edges mix stalls, high addresses, masked writes,
/// strided packets, reset and injected response errors.
pub fn replay_bundle(
  streaming~ : Bool = false,
) -> ReadOnlyArray[@projection.Artifact] raise {
  let b = bench(recording=true, streaming~)
  exercise(b)
  for first_address in [true, false] {
    b.aw_pause = !first_address
    b.w_pause = first_address
    b.begin(12UL, write=true, data=[0xabcdef01UL, 0UL, 0UL, 0UL])
    for _ in 0..<20 {
      b.step()
    }
    b.aw_pause = false
    b.w_pause = false
    assert_eq(b.finish()[0].1, 0UL)
  }
  for (response, bad_last) in [(2UL, false), (3UL, false), (0UL, true)] {
    b.read_fault = response
    b.bad_last = bad_last
    b.begin(0UL, line=true, burst=true, wide=true)
    for (_, fault, _) in b.finish() {
      assert_eq(fault, 3UL)
    }
    b.reset()
  }
  b.ar_pause = true
  b.begin(0UL)
  for _ in 0..<10 {
    b.step()
  }
  set(b.sim, "calibrated", 1, 0UL)
  for _ in 0..<10 {
    b.step()
  }
  b.ar_pause = false
  assert_eq(b.finish()[0].1, 2UL)
  b.reset()
  let mut sequence = 0
  while b.cycle < (if streaming { 10000 } else { 100000 }) {
    let address = 0x40000000UL + (sequence % 8192 * 4).to_uint64()
    let word = (sequence.reinterpret_as_uint() * 1664525U + 1013904223U).to_uint64()
    b.begin(address, write=true, data=[word, 0UL, 0UL, 0UL])
    assert_eq(b.finish(hold=sequence % 7)[0].1, 0UL)
    b.begin(address)
    assert_eq(b.finish(hold=sequence % 11)[0].0[0], word)
    sequence += 1
    if sequence % 127 == 0 {
      b.reset()
    }
  }
  let design = @ir.Design::single("pblaze3-axi/v1", b.hw)
  let emitted = @systemverilog.emit_design(design)
  let stimulus = @verilator.AtomicStimulus::checked(
    1UL,
    [
      @verilator.StimulusDomain::checked(
        0,
        b.ports
        .iter()
        .find_first(p => p.source_name() == "clock")
        .unwrap()
        .emitted_name(),
      ),
    ],
    b.events,
  )
  let prefix = "LUNACHIP-PBLAZE3-AXI-RESULT\t1\t" +
    @verilator.utf8_hex("pblaze3-axi/v1") +
    "\tsha256\t" +
    @verilator.sha256_hex(@codec.serialize(design)) +
    "\tsha256\t" +
    @verilator.sha256_hex(stimulus.to_tsv()) +
    "\ttimebase\t1\n"
  let header = "time\tboundary\t" +
    @verilator.output_ports(b.ports).map(p => p.source_name()).join("\t") +
    "\n"
  ReadOnlyArray::from_array([
    { path: "design.lcir", content: @codec.serialize(design), },
    { path: emitted.modules()[0].filename(), content: emitted.source(), },
    { path: "bridge.sv", content: emitted.source(), },
    {
      path: "manifest.json",
      content: @verilator.atomic_harness_json(
        emitted,
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
      "\nsingle-clock, independent AXI channels, 2GiB high addresses, all Qwen request modes, response backpressure, response errors, coordinated reset; AXI data lanes = \{b.lanes}\n",
    },
    {
      path: "job.json",
      content: "{\"schema_version\":\"lunachip.yosys-job/v1\",\"top_module\":\"" +
      emitted.modules()[0].identifier() +
      "\",\"sources\":[{\"path\":\"bridge.sv\",\"sha256\":\"" +
      @verilator.sha256_hex(emitted.source()) +
      "\"}],\"formal_tasks\":[]}\n",
    },
  ])
}
