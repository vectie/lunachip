///|
fn pipeline_replay(root : String) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh arithmetic replay root") }
  @fs.create_dir(root)
  let hw = @fp.pipelined_multiplier()
  let semantic = "qwen-fp32-multiply-pipeline3/v1"
  let design = @ir.Design::single(semantic, hw)
  let emitted = @sv.emit_design(design)
  let ports = @v.collect_ports(hw, emitted.manifest())
  let r : Replay = {
    hw,
    sim: @sim.Simulator::prepare(hw),
    inputs: @v.input_ports(ports),
    outputs: @v.output_ports(ports),
    stimulus: StringBuilder(),
    expected: StringBuilder(),
    masks: StringBuilder(),
    cycles: 0,
    random: 0x9b7ec412U,
    job_limit: 10000,
    parallel_rows: 8,
    packed_weights: false,
    delivery: false,
  }
  r.stimulus.write_string(@v.tsv_header(r.inputs))
  r.expected.write_string(@v.tsv_header(r.outputs))
  r.masks.write_string(@v.tsv_header(r.outputs))
  for port in r.inputs {
    r.set(port.source_name(), port.width(), 0UL)
  }
  r.set("reset", 1, 1UL)
  r.step()
  r.set("reset", 1, 0UL)
  let edges = [
    0U, 0x80000000U, 1U, 0x7fffffU, 0x800000U, 0x3f800000U, 0xbf800000U, 0x33800000U,
    0x3f800001U, 0x7f7fffffU, 0xff7fffffU, 0x7f800000U, 0xff800000U, 0x7fc00000U,
  ]
  let pending : Array[UInt32] = []
  for i in 0..<100002 {
    r.random = r.random * 1664525U + 1013904223U
    let a = if i < edges.length() * edges.length() * 2 {
      edges[i / 2 / edges.length()]
    } else {
      r.random
    }
    r.random = r.random * 1664525U + 1013904223U
    let c = if i < edges.length() * edges.length() * 2 {
      edges[i / 2 % edges.length()]
    } else if i % 3 == 0 {
      a ^ 0x80000000U
    } else {
      r.random
    }
    r.set("a", 32, a.to_uint64())
    r.set("b", 32, c.to_uint64())
    r.step()
    let x = Float::reinterpret_from_uint(a)
    let y = Float::reinterpret_from_uint(c)
    let expected = x * y
    pending.push(
      if expected.is_nan() {
        0x7fc00000U
      } else {
        expected.reinterpret_as_uint()
      },
    )
    if pending.length() > 2 {
      assert_eq(r.get("result"), pending.remove(0).to_uint64())
    }
  }
  let stimulus = r.stimulus.to_string()
  let protocol = @v.ResultProtocol::checked(
    "LUNACHIP-QWEN-ALU-RESULT", "1", semantic,
  )
  let identity = @diff.ResultIdentity::checked(
    @diff.DesignIdentity::checked(
      semantic,
      @v.sha256_hex(@codec.serialize(design)),
    ),
    @v.sha256_hex(stimulus),
  )
  save(
    root,
    emitted.modules()[0].filename(),
    normalize(optimized(emitted.source())),
  )
  save(root, "design.lcir", @codec.serialize(design))
  save(root, "manifest.json", @v.harness_json(emitted, ports))
  save(root, "harness.cpp", @v.harness_cpp(ports, identity, protocol))
  save(root, "stimulus.tsv", stimulus)
  save(
    root,
    "expected.tsv",
    protocol.magic() +
    "\t1\t" +
    @v.utf8_hex(semantic) +
    "\tsha256\t" +
    identity.design().design_sha256() +
    "\tsha256\t" +
    identity.stimulus_sha256() +
    "\n" +
    r.expected.to_string(),
  )
  save(root, "care-masks.tsv", r.masks.to_string())
  save(root, "cycles.txt", (r.cycles - 1).to_string() + "\n")
  save(
    root,
    "scope.json",
    (
      {
        "status": "PASS",
        "cycles": 100002,
        "scope": "100000 checked native FP32 products from100002 boundary/seeded raw-bit pipeline edges,latency3 and initiation interval1,including signed zeros,subnormals,infinities and canonical NaNs. Generator identical to four full-layer lanes. Two final pipeline inputs only drain the preceding checked products.",
      } : Json).stringify(indent=2) +
    "\n",
  )
}
