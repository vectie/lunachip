///|
// Adapt the external data bus into simulator-sized words. The
// instantiated digital system is the same wrapper exported for the board.
fn replay_wrapper(
  ports : ReadOnlyArray[@v.HarnessPort],
  lanes : Int32,
) -> String {
  let declarations : Array[String] = []
  let bindings : Array[String] = []
  let assignments : Array[String] = []
  for p in ports {
    let name = p.source_name()
    declarations.push(
      (if p.is_input() { "input" } else { "output" }) +
      " wire " +
      (if p.width() == 1 {
        ""
      } else {
        "[" + (p.width() - 1).to_string() + ":0] "
      }) +
      name,
    )
    if name.has_prefix("m_axi_wword") {
      for lane in 0..<lanes {
        if name == "m_axi_wword\{lane}" {
          assignments.push(
            "assign \{name} = write_data[\{lane*32+31}:\{lane*32}];",
          )
        }
      }
    } else if lanes == 32 && name.has_prefix("m_axi_wstrb") {
      if name == "m_axi_wstrb" {
        bindings.push(".m_axi_wstrb({m_axi_wstrb_hi,m_axi_wstrb})")
      }
    } else if !name.has_prefix("m_axi_rword") {
      bindings.push("." + name + "(" + name + ")")
    }
  }
  bindings.push(".m_axi_wdata(write_data)")
  bindings.push(
    ".m_axi_rdata({" +
    Array::makei(lanes, i => "m_axi_rword\{lanes-1-i}").join(",") +
    "})",
  )
  "`default_nettype none\nmodule pblaze3_layer_replay(\n" +
  declarations.join(",\n") +
  ");\nwire [\{lanes*32-1}:0] write_data;\n" +
  assignments.join("\n") +
  "\npblaze3_layer_system dut(" +
  bindings.join(",\n") +
  ");\nendmodule\n`default_nettype wire\n"
}

///|
/// Integrated control/core/memory replay with independent AXI backpressure.
/// Reuses the physical digital wrapper and emits all three canonical modules,
/// their exact RTL, a word-lane test adapter and a composition identity.
pub fn replay_bundle(
  streaming~ : Bool = false,
  profile~ : Bool = false,
  vectors~ : Bool = false,
  wide512~ : Bool = false,
  rows64~ : Bool = false,
  banked64~ : Bool = false,
  prefetch256~ : Bool = false,
  scalar_lines~ : Bool = false,
  store_bursts~ : Bool = false,
  chain~ : Bool = false,
  program_bursts~ : Bool = false,
  stream_unary~ : Bool = false,
  staged_decode~ : Bool = false,
  stream_reductions~ : Bool = false,
  paired_rows~ : Bool = false,
  full_rows~ : Bool = false,
  dual_read~ : Bool = false,
  indirect_bf16~ : Bool = false,
  bounded_add~ : Bool = false,
  deep_batch~ : Bool = false,
  strided_rows~ : Bool = false,
) -> ReadOnlyArray[@projection.Artifact] raise {
  let b = bench(
    recording=true,
    program_bursts~,
    stream_unary~,
    staged_decode~,
    stream_reductions~,
    paired_rows~,
    full_rows~,
    dual_read~,
    indirect_bf16~,
    bounded_add~,
    deep_batch~,
    strided_rows~,
    chain~,
    streaming~,
    profile~,
    vectors~,
    wide512~,
    rows64~,
    banked64~,
    prefetch256~,
    scalar_lines~,
    store_bursts~,
  )
  if stream_unary {
    exercise_stream_unary(b)
  }
  if staged_decode {
    exercise_staged_decode(b)
  }
  if stream_reductions {
    exercise_ordered_reductions(b, dual_read~, bounded_add~)
    b.reset()
  }
  exercise(b, program_bursts~)
  if indirect_bf16 {
    exercise_indirect_bf16(b)
  }
  if program_bursts {
    exercise_program_bursts(b)
  }
  if chain {
    exercise_chain(b)
  }
  if store_bursts {
    exercise_store_bursts(b)
  }
  if scalar_lines {
    exercise_load_lines(b)
  }
  if strided_rows {
    for columns in [2048, 3072] {
      exercise_wide_matrix(
        b,
        16,
        columns~,
        base=0x80000000UL - (32 * columns).to_uint64(),
        cancellation=true,
      )
    }
  }
  if full_rows {
    exercise_wide_matrix(
      b,
      256,
      columns=1024,
      base=0x7ff80000UL,
      cancellation=true,
    )
    exercise_wide_matrix(
      b,
      128,
      columns=512,
      base=0x40000e00UL,
      cancellation=true,
    )
  } else if paired_rows {
    exercise_wide_matrix(
      b,
      256,
      columns=512,
      base=0x40000e00UL,
      cancellation=true,
    )
    exercise_wide_matrix(b, 64)
  } else if prefetch256 {
    exercise_wide_matrix(b, 128, columns=512, base=0x40000e00UL)
  } else if wide512 {
    exercise_wide_matrix(b, if rows64 { 64 } else { 32 })
  }
  if vectors {
    exercise_vector_pipeline(b)
  }
  bench_bundle(
    b,
    smoke_workloads(),
    if prefetch256 {
      "1024-bit delivery with 512-byte row bursts, row-major two-stripe and two-group prefetch, short packed fallback and both write-strobe halves"
    } else if wide512 {
      "512-bit vector image: packed-16 and row-major matrix execution, high-address AXI traffic, write masks, stalls, reset and recovery"
    } else {
      "actual digital system wrapper; AXIL absolute BAR addressing, independent AW/W, held AXIL replies, uploaded programs and scratch, high2GiB FP32 load/add/store, packed N16K64 BF16 matrix, eight-word delivery, byte masks, AXI stalls, poisoned-wide-response drainage and coordinated reset with an outstanding read followed by fresh recovery; no physical DDR or timing claim"
    },
  )
}

///|
fn bench_bundle(
  b : Bench,
  workloads : String,
  description : String,
) -> ReadOnlyArray[@projection.Artifact] raise {
  let files : Array[@projection.Artifact] = []
  let sources : Array[String] = []
  let modules : Array[Json] = []
  for
    (name, m) in [
      ("core", b.core),
      ("control", b.control),
      ("bridge", b.bridge),
    ] {
    let ir = @codec.serialize(@ir.Design::single(m.identity, m.hw))
    let source = m.emitted.source()
    let file = m.emitted.modules()[0].filename()
    files.push({ path: name + ".lcir", content: ir, })
    files.push({ path: file, content: source, })
    sources.push(file)
    modules.push({
      "name": @json.to_json(name),
      "lcir_sha256": @json.to_json(@v.sha256_hex(ir)),
      "source": @json.to_json(file),
      "source_sha256": @json.to_json(@v.sha256_hex(source)),
    })
  }
  let system = @system.wrapper(
    b.core.hw,
    b.core.emitted,
    b.control.hw,
    b.control.emitted,
    b.bridge.hw,
    b.bridge.emitted,
  )
  let adapter = replay_wrapper(b.ports, b.lanes)
  files.push({ path: "pblaze3_layer_system.sv", content: system, })
  files.push({ path: "pblaze3_layer_replay.sv", content: adapter, })
  sources.push("pblaze3_layer_system.sv")
  sources.push("pblaze3_layer_replay.sv")
  let composition : Json = {
    "schema_version": "lunachip.pblaze3-layer-composition/v1",
    "modules": @json.to_json(modules),
    "system_sha256": @json.to_json(@v.sha256_hex(system)),
    "adapter_sha256": @json.to_json(@v.sha256_hex(adapter)),
    "edge_semantics": "shared clock; all module inputs frozen before simultaneous state commit; settle interconnect after commit",
  }
  let identity = composition.stringify(indent=2) + "\n"
  let stimulus = @v.AtomicStimulus::checked(
    1UL,
    [@v.StimulusDomain::checked(0, "clock")],
    b.events,
  )
  let prefix = "LUNACHIP-PBLAZE3-LAYER-RESULT\t1\t" +
    @v.utf8_hex("pblaze3-layer/v1") +
    "\tsha256\t" +
    @v.sha256_hex(identity) +
    "\tsha256\t" +
    @v.sha256_hex(stimulus.to_tsv()) +
    "\ttimebase\t1\n"
  let ports = b.ports.map(p => {
    (
      {
        "name": @json.to_json(p.emitted_name()),
        "direction": @json.to_json(
          if p.is_input() {
            "input"
          } else {
            "output"
          },
        ),
        "width": @json.to_json(p.width()),
        "signed": false,
      } : Json)
  })
  let manifest : Json = {
    "$schema": "https://lunachip.dev/schema/verilator-harness-v2.json",
    "schema_version": "lunachip.verilator-harness/v2",
    "top_module": "pblaze3_layer_replay",
    "sources": @json.to_json(sources),
    "harness_cpp": "harness.cpp",
    "stimulus": "stimulus.tsv",
    "stimulus_schema": "lunachip.verilator-stimulus/v2",
    "result": "actual.tsv",
    "domains": [{ "id": 0, "clock_port": "clock", "edge": "rising" }],
    "ports": @json.to_json(ports),
  }
  files.push({
    path: "manifest.json",
    content: manifest.stringify(indent=2) + "\n",
  })
  files.push({ path: "composition.json", content: identity, })
  files.push({
    path: "harness.cpp",
    content: @v.atomic_harness_cpp(b.ports, stimulus, prefix, AtomicEdges),
  })
  files.push({ path: "stimulus.tsv", content: stimulus.to_tsv(), })
  files.push({
    path: "expected.tsv",
    content: prefix +
    "time\tboundary\t" +
    @v.output_ports(b.ports).map(p => p.source_name()).join("\t") +
    "\n" +
    b.rows.to_string(),
  })
  files.push({ path: "workloads.json", content: workloads, })
  files.push({
    path: "fixture.txt",
    content: "events=" +
    b.events.length().to_string() +
    "\n" +
    description +
    "\n",
  })
  ReadOnlyArray::from_array(files)
}
