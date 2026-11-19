///|
pub fn replay_bundle(
  high~ : Bool = false,
) -> ReadOnlyArray[@projection.Artifact] raise {
  let b = bench(high)
  exercise(b)
  let files : Array[@projection.Artifact] = []
  let sources : Array[String] = []
  let modules : Array[Json] = []
  for m in [b.control, b.bridge] {
    let ir = @codec.serialize(@ir.Design::single(m.identity, m.hw))
    files.push({ path: m.hw.name() + ".lcir", content: ir, })
    files.push({
      path: m.emitted.modules()[0].filename(),
      content: m.emitted.source(),
    })
    sources.push(m.emitted.modules()[0].filename())
    modules.push({
      "identity": m.identity,
      "ir_sha256": @v.sha256_hex(ir),
      "rtl_sha256": @v.sha256_hex(m.emitted.source()),
    })
  }
  let system = @memtest.wrapper(
    b.control.hw,
    b.control.emitted,
    b.bridge.hw,
    b.bridge.emitted,
    replay=true,
  )
  files.push({ path: "pblaze3_memtest_system.sv", content: system, })
  sources.push("pblaze3_memtest_system.sv")
  let identity : Json = {
    "schema": "lunachip.pblaze3-memtest-replay/v1",
    "modules": @json.to_json(modules),
    "system_sha256": @v.sha256_hex(system),
    "base": b.base,
    "beats": b.beats,
    "cases": @json.to_json(b.cases),
    "semantics": "freeze module inputs before simultaneous edge; settle after commit",
  }
  let composition = identity.stringify(indent=2) + "\n"
  let stimulus = @v.AtomicStimulus::checked(
    1UL,
    [@v.StimulusDomain::checked(0, "clock")],
    b.events,
  )
  let prefix = "LUNACHIP-PBLAZE3-MEMTEST-RESULT\t1\t" +
    @v.utf8_hex("pblaze3-memtest/v1") +
    "\tsha256\t" +
    @v.sha256_hex(composition) +
    "\tsha256\t" +
    @v.sha256_hex(stimulus.to_tsv()) +
    "\ttimebase\t1\n"
  let manifest : Json = {
    "schema_version": "lunachip.verilator-harness/v2",
    "top_module": "pblaze3_memtest_system",
    "sources": @json.to_json(sources),
    "harness_cpp": "harness.cpp",
    "stimulus": "stimulus.tsv",
    "stimulus_schema": "lunachip.verilator-stimulus/v2",
    "result": "actual.tsv",
    "domains": [{ "id": 0, "clock_port": "clock", "edge": "rising" }],
    "ports": @json.to_json(
      b.ports.map(p => {
        (
          {
            "name": p.emitted_name(),
            "direction": if p.is_input() {
              "input"
            } else {
              "output"
            },
            "width": p.width(),
            "signed": false,
          } : Json)
      }),
    ),
  }
  files.push({
    path: "manifest.json",
    content: manifest.stringify(indent=2) + "\n",
  })
  files.push({ path: "composition.json", content: composition, })
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
  ReadOnlyArray::from_array(files)
}

///|
pub fn digital_bundle() -> ReadOnlyArray[@projection.Artifact] raise {
  let control = @memtest.controller()
  let bridge = @axi.bridge()
  let cd = @ir.Design::single("pblaze3-memtest/v1", control)
  let bd = @ir.Design::single("pblaze3-axi/v1", bridge)
  let ce = @sv.emit_design(cd)
  let be = @sv.emit_design(bd)
  let source = @memtest.wrapper(control, ce, bridge, be)
  let files : Array[@projection.Artifact] = [
    { path: "controller.lcir", content: @codec.serialize(cd), },
    { path: "bridge.lcir", content: @codec.serialize(bd), },
    { path: ce.modules()[0].filename(), content: ce.source(), },
    { path: be.modules()[0].filename(), content: be.source(), },
    { path: "pblaze3_memtest_system.sv", content: source, },
  ]
  let job : Json = {
    "schema_version": "lunachip.yosys-job/v1",
    "top_module": "pblaze3_memtest_system",
    "sources": @json.to_json(
      files
      .filter(f => f.path.has_suffix(".sv"))
      .map(f => ({ "path": f.path, "sha256": @v.sha256_hex(f.content) } : Json)),
    ),
    "formal_tasks": [],
  }
  files.push({ path: "job.json", content: job.stringify(indent=2) + "\n", })
  ReadOnlyArray::from_array(files)
}
