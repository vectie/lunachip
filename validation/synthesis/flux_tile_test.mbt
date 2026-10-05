///|
fn flux_tile_artifact(
  artifacts : ReadOnlyArray[@synthesis.BundleArtifact],
  path : String,
) -> String raise {
  guard artifacts.iter().find_first(artifact => artifact.path == path)
    is Some(artifact) else {
    fail("missing fetched-device synthesis artifact: \{path}")
  }
  artifact.content
}

///|
test "fetched device synthesis inputs retain replay identity and source memories" {
  let artifacts = @synthesis.generate_flux_tile_bundle()
  assert_eq(artifacts, @synthesis.generate_flux_tile_bundle())
  assert_eq(artifacts.length(), 5)
  let configuration = @capabilities.Capabilities::new(
    rows=1,
    columns=1,
    max_reduction=512,
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
    "phase6-fetched-concurrent-1x1-k512-overlap",
    @flux_tile.ring_concurrent_from_capabilities(configuration),
  )
  assert_eq(canonical, @ir_codec.serialize(replay_design))
  // Bind to the exact source artifact of the retained independent replay,
  // without regenerating its 9,041-cycle reference trace in this test.
  assert_eq(
    @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(canonical))),
    "4b10085bf8190905952a181df5a6080791f2116af78c6fff76e0b0a183930a5d",
  )
  guard design.top_module() is Some(hardware) else {
    fail("fetched device must have a top module")
  }
  assert_eq(hardware.name(), "FluxTileHostConcurrent")
  assert_eq(
    hardware.memories().length(),
    2 * configuration.rows + 2 * configuration.columns + 6,
  )
  // The codec sorts output ports by name; emitted ordinals retain generator
  // order. Bind RTL and names to the same generator as the replay, while the
  // parsed canonical module independently checks the source memory inventory.
  let emitted = @systemverilog.emit_design(replay_design)
  assert_eq(
    flux_tile_artifact(artifacts, "names.lcnm"),
    emitted.manifest().to_canonical_text(),
  )
  let names = [
    "a_slot_0_bank_0", "a_slot_1_bank_0", "b_slot_0_bank_0", "b_slot_1_bank_0", "c_result_slot_0",
    "c_result_slot_1", "descriptor_lane_0.storage", "descriptor_lane_1.storage",
    "descriptor_lane_2.storage", "descriptor_lane_3.storage",
  ]
  let memory_mappings = emitted
    .manifest()
    .mappings()
    .filter(mapping => mapping.kind() is Memory)
  assert_eq(memory_mappings.length(), 10)
  for index, memory in hardware.memories() {
    assert_eq(memory.name(), names[index])
    let (width, depth, signed) = if index < 4 {
      (8, 512, true)
    } else if index < 6 {
      (32, 1, true)
    } else {
      (64, 3, false)
    }
    assert_eq(memory.element_type().width().bits(), width)
    assert_eq(memory.element_type() is SInt(_), signed)
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
    assert_eq(mapping.source_name(), memory.name())
    let qualifier = if signed { " signed" } else { "" }
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
    fail("synthesis job must use the existing source-bound schema")
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
