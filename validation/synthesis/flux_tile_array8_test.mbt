///|
test "8x8 synthesis inputs retain replay identity and exact source memory types" {
  let artifacts = @synthesis.generate_flux_tile_array8_bundle()
  assert_eq(artifacts, @synthesis.generate_flux_tile_array8_bundle())
  assert_eq(artifacts.length(), 5)
  let configuration = @capabilities.Capabilities::new(
    rows=8,
    columns=8,
    max_reduction=16,
    host_bytes=4096UL,
    ring_depth=4,
    queue_depth=3,
  )
  assert_eq(
    flux_tile_artifact(artifacts, "capabilities.json"),
    configuration.manifest(),
  )
  let canonical = flux_tile_artifact(artifacts, "design.lcir")
  let design = @ir_codec.parse(canonical)
  assert_eq(@ir_codec.serialize(design), canonical)
  let replay_design = @ir.Design::single(
    "phase6-fetched-concurrent-8x8-k16-two-slots",
    @flux_tile.ring_concurrent_from_capabilities(configuration),
  )
  assert_eq(canonical, @ir_codec.serialize(replay_design))
  // Bind the source to the retained 8x8 replay without regenerating its trace.
  assert_eq(
    @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(canonical))),
    "37c1a39acc22bcf7730c377f97009e7798fe2bdc1418476a3f00825c1c08ffc8",
  )
  guard design.top_module() is Some(hardware) else {
    fail("8x8 fetched device must have a top module")
  }
  assert_eq(hardware.name(), "FluxTileHostConcurrent")
  assert_eq(hardware.memories().length(), 38)
  let emitted = @systemverilog.emit_design(replay_design)
  assert_eq(
    flux_tile_artifact(artifacts, "names.lcnm"),
    emitted.manifest().to_canonical_text(),
  )
  let memory_mappings = emitted
    .manifest()
    .mappings()
    .filter(mapping => mapping.kind() is Memory)
  assert_eq(memory_mappings.length(), 38)
  for index, memory in hardware.memories() {
    let (name, width, depth) = if index < 16 {
      ("a_slot_\{index % 2}_bank_\{index / 2}", 8, 16)
    } else if index < 32 {
      let bank_offset = index - 16
      ("b_slot_\{bank_offset % 2}_bank_\{bank_offset / 2}", 8, 16)
    } else if index < 34 {
      ("c_result_slot_\{index - 32}", 32, 64)
    } else {
      ("descriptor_lane_\{index - 34}.storage", 64, 3)
    }
    assert_eq(memory.name(), name)
    assert_eq(memory.element_type().width().bits(), width)
    if index < 34 {
      assert_true(memory.element_type() is SInt(_))
    } else {
      assert_true(memory.element_type() is Bits(_))
    }
    assert_eq(memory.depth().elements(), depth)
    assert_eq(memory.read_ports().length(), 1)
    assert_eq(memory.write_ports().length(), 1)
    assert_true(memory.read_write_policy() is ReadOld)
    assert_true(memory.multi_write_policy() is Reject)
    assert_true(memory.bounds_policy() is Fault)
    assert_true(memory.read_ports()[0].latency() is OneCycle)
    assert_true(memory.read_ports()[0].enable_behavior() is HoldLast)
    assert_true(memory.write_ports()[0].mask() is All)
    guard memory_mappings
      .iter()
      .find_first(mapping => {
        mapping.module_ordinal() == 0 &&
        mapping.local_ordinal() == memory.id().ordinal()
      })
      is Some(mapping) else {
      fail("missing emitted memory name: \{memory.name()}")
    }
    assert_eq(mapping.source_name(), name)
    let qualifier = if index < 34 { " signed" } else { "" }
    assert_true(
      emitted
      .source()
      .contains(
        "logic\{qualifier} [\{width - 1}:0] \{mapping.identifier()} [0:\{depth - 1}];",
      ),
    )
  }
  let job = flux_tile_artifact(artifacts, "job.json")
  guard @json.parse(job)
    is {
      "schema_version": String("lunachip.yosys-job/v1"),
      "top_module": String(top),
      "sources": Array(sources),
      "formal_tasks": Array([]),
      ..
    } else {
    fail("8x8 synthesis job must use the existing source-bound schema")
  }
  assert_eq(top, emitted.modules()[0].identifier())
  assert_eq(sources.length(), emitted.modules().length())
  for index, source in emitted.modules() {
    let rtl = flux_tile_artifact(artifacts, source.filename())
    assert_eq(rtl, source.source())
    guard sources[index]
      is { "path": String(path), "sha256": String(digest), .. } else {
      fail("synthesis source must carry path and digest")
    }
    assert_eq(path, source.filename())
    assert_eq(
      digest,
      @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(rtl))),
    )
  }
  assert_false(
    artifacts.any(artifact => {
      artifact.path == "harness.cpp" || artifact.path == "stimulus.tsv"
    }),
  )
}
