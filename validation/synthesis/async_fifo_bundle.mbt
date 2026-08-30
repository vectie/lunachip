///|
fn json_string_array(values : Array[String]) -> String {
  "[" + values.map(v => "\"\{v}\"").join(", ") + "]"
}

///|
fn json_int_array(values : Array[Int]) -> String {
  "[" + values.map(v => v.to_string()).join(", ") + "]"
}

///|
fn ids(
  emitted : @systemverilog.EmittedDesign,
  values : ReadOnlyArray[@ir.NodeId],
) -> Array[String] raise {
  let out : Array[String] = []
  for id in values {
    out.push(emitted_identifier(emitted, Node, id.ordinal()))
  }
  out
}

///|
fn async_fifo_expected_shape_json(
  kind : AsyncFifoSynthesisKind,
  design : @ir.Design,
  emitted : @systemverilog.EmittedDesign,
) -> String raise {
  guard design.top_module() is Some(hardware_module) else {
    raise MissingTopModule
  }
  guard hardware_module.cdc_primitives() is [AsyncFifo(spec)] else {
    fail("fixture must contain one asynchronous FIFO")
  }
  guard emitted.modules().get(emitted.manifest().top_module_ordinal())
    is Some(top) else {
    raise MissingEmittedTopModule
  }
  let node = fn(id : @ir.NodeId) raise {
    emitted_identifier(emitted, Node, id.ordinal())
  }
  let lanes = emitted
    .manifest()
    .mappings()
    .iter()
    .filter(m => m.kind() is AsyncFifoLane)
    .map(m => m.identifier())
    .to_array()
  let out = StringBuilder()
  out.write_string(
    "{\n  \"$schema\": \"https://lunachip.dev/schema/async-fifo-synthesis-shape-v1.json\",\n",
  )
  out.write_string(
    "  \"schema_version\": \"lunachip.async-fifo-synthesis-shape/v1\",\n  \"fixture\": \"\{kind.id()}\",\n  \"top_module\": \"\{top.identifier()}\",\n",
  )
  out.write_string(
    "  \"depth\": \{kind.depth()},\n  \"synchronizer_stages\": \{kind.stages()},\n  \"pointer_width\": \{spec.pointer_width()},\n  \"payload_widths\": \{json_int_array(kind.widths())},\n",
  )
  out.write_string(
    "  \"source_clock\": \"\{node(hardware_module.domains()[spec.source_domain().ordinal()].clock())}\",\n  \"destination_clock\": \"\{node(hardware_module.domains()[spec.destination_domain().ordinal()].clock())}\",\n  \"source_reset\": \"\{node(spec.source_reset().signal())}\",\n  \"destination_reset\": \"\{node(spec.destination_reset().signal())}\",\n",
  )
  out.write_string(
    "  \"write_binary\": \"\{node(spec.write_binary())}\",\n  \"write_binary_next\": \"\{node(spec.write_binary_next())}\",\n  \"write_gray\": \"\{node(spec.write_gray())}\",\n  \"write_gray_next\": \"\{node(spec.write_gray_next())}\",\n",
  )
  out.write_string(
    "  \"read_binary\": \"\{node(spec.read_binary())}\",\n  \"read_binary_next\": \"\{node(spec.read_binary_next())}\",\n  \"read_gray\": \"\{node(spec.read_gray())}\",\n  \"read_gray_next\": \"\{node(spec.read_gray_next())}\",\n",
  )
  out.write_string(
    "  \"full\": \"\{node(spec.full())}\",\n  \"full_next\": \"\{node(spec.full_next())}\",\n  \"nonempty\": \"\{node(spec.nonempty())}\",\n  \"nonempty_next\": \"\{node(spec.nonempty_next())}\",\n",
  )
  out.write_string(
    "  \"write_address\": \"\{node(spec.write_address())}\",\n  \"read_address\": \"\{node(spec.read_address())}\",\n  \"source_transfer\": \"\{node(spec.source_transfer())}\",\n  \"destination_transfer\": \"\{node(spec.destination_transfer())}\",\n",
  )
  out.write_string(
    "  \"read_gray_pipeline\": \{json_string_array(ids(emitted, spec.read_gray_stages()))},\n  \"write_gray_pipeline\": \{json_string_array(ids(emitted, spec.write_gray_stages()))},\n  \"source_payload\": \{json_string_array(ids(emitted, spec.source_payload()))},\n  \"raw_reads\": \{json_string_array(ids(emitted, spec.raw_reads()))},\n  \"visible_payload\": \{json_string_array(ids(emitted, spec.destination_payload()))},\n  \"lanes\": \{json_string_array(lanes)},\n",
  )
  out.write_string(
    "  \"claim_boundary\": { \"pre_map_rtlil_connectivity\": true, \"ram_inference\": false, \"timing\": false, \"physical_cdc\": false }\n}\n",
  )
  out.to_string()
}

///|
pub fn generate_async_fifo_synthesis_bundle(
  kind : AsyncFifoSynthesisKind,
) -> AsyncFifoSynthesisBundle raise {
  let design = async_fifo_synthesis_design(kind)
  let emitted = @systemverilog.emit_design(design)
  let expected = async_fifo_expected_shape_json(kind, design, emitted)
  let artifacts : Array[BundleArtifact] = [
    { path: "design.lcir", content: @ir_codec.serialize(design) },
  ]
  for source in emitted.modules() {
    artifacts.push({ path: source.filename(), content: source.source() })
  }
  artifacts.push({
    path: "names.lcnm",
    content: emitted.manifest().to_canonical_text(),
  })
  artifacts.push({ path: "job.json", content: job_json(emitted) })
  artifacts.push({ path: "expected-async-fifo-shape.json", content: expected })
  { artifacts: ReadOnlyArray::from_array(artifacts) }
}
