///|
fn core_protocol() -> @verilator.ResultProtocol raise {
  @verilator.ResultProtocol::checked(
    "LUNACHIP-WORD-CORE-RESULT", "1", "flux-tile-word32/v1",
  )
}

///|
pub fn core_replay_bundle() -> ReadOnlyArray[@projection.Artifact] raise {
  let b = projection_replay_bench()
  assert_eq(b.memory_requests.length(), 608)
  assert_eq(b.memory_requests.filter(r => r.1 == 0UL).length(), 544)
  assert_true(b.memory_requests.all(r => r.3 == 4UL && r.2 % 4UL == 0UL))
  let d = @ir.Design::single(
    "phase6-fetched-concurrent-word32-8x8-k16-two-slots",
    b.core_hw,
  )
  let e = @systemverilog.emit_design(d)
  let source = @projection.digital_bundle()
    .iter()
    .find_first(a => a.path == "core.sv")
    .unwrap().content
  let stimulus = b.core_stimulus.to_string()
  let identity = @differential.ResultIdentity::checked(
    @differential.DesignIdentity::checked(
      core_protocol().semantic_version(),
      @verilator.sha256_hex(@codec.serialize(d)),
    ),
    @verilator.sha256_hex(stimulus),
  )
  ReadOnlyArray::from_array([
    { path: "design.lcir", content: @codec.serialize(d), },
    { path: e.modules()[0].filename(), content: source, },
    { path: "core.sv", content: source, },
    {
      path: "manifest.json",
      content: @verilator.harness_json(e, b.core_ports),
    },
    {
      path: "harness.cpp",
      content: @verilator.harness_cpp(b.core_ports, identity, core_protocol()),
    },
    { path: "stimulus.tsv", content: stimulus, },
    {
      path: "expected.tsv",
      content: core_protocol().magic() +
      "\t1\t" +
      @verilator.utf8_hex(core_protocol().semantic_version()) +
      "\tsha256\t" +
      identity.design().design_sha256() +
      "\tsha256\t" +
      identity.stimulus_sha256() +
      "\n" +
      b.core_expected.to_string(),
    },
    {
      path: "fixture.txt",
      content: "cycles=" +
      (b.cycle - 1).to_string() +
      "\nall core outputs; real controller/staging input trace; two repeated signed four-tile jobs with CPU-checked partials/finals\n",
    },
    {
      path: "memory-requests.tsv",
      content: "cycle\twrite\taddress\tbytes\n" +
      b.memory_requests
      .map(r => {
        r.0.to_string() +
        "\t" +
        r.1.to_string() +
        "\t" +
        r.2.to_string() +
        "\t" +
        r.3.to_string()
      })
      .join("\n") +
      "\n",
    },
    {
      path: "job.json",
      content: "{\"schema_version\":\"lunachip.yosys-job/v1\",\"top_module\":\"" +
      e.modules()[0].identifier() +
      "\",\"sources\":[{\"path\":\"core.sv\",\"sha256\":\"" +
      @verilator.sha256_hex(source) +
      "\"}],\"formal_tasks\":[]}\n",
    },
  ])
}

///|
pub fn audit_core(
  expected : String,
  actual : String,
  cycles : Int32,
) -> Unit raise {
  let d = @ir.Design::single(
    "phase6-fetched-concurrent-word32-8x8-k16-two-slots",
    @projection.core(),
  )
  let p = @verilator.collect_ports(
    @projection.core(),
    @systemverilog.emit_design(d).manifest(),
  )
  assert_eq(
    @differential.compare(
      @verilator.parse_actual_tsv(expected, p, cycles, core_protocol()),
      @verilator.parse_actual_tsv(actual, p, cycles, core_protocol()),
    ),
    Equal,
  )
}
