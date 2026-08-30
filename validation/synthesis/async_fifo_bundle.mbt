///|
fn json_string_array(values : Array[String]) -> String {
  "[" + values.map(v => "\"\{v}\"").join(", ") + "]"
}

///|
fn AsyncFifoSynthesisDomainRole::to_json(
  self : AsyncFifoSynthesisDomainRole,
  indent : String,
) -> String {
  indent +
  "{ \"clock\": \"\{self.clock}\", \"edge\": \"positive\", " +
  "\"reset\": { \"signal\": \"\{self.reset}\", \"kind\": \"synchronous\", " +
  "\"polarity\": \"high\", \"value\": \"zero\" } }"
}

///|
fn AsyncFifoSynthesisLaneRole::to_json(
  self : AsyncFifoSynthesisLaneRole,
  indent : String,
) -> String {
  indent +
  "{ \"index\": \{self.index}, \"memory\": \"\{self.memory}\", " +
  "\"width\": \{self.width}, \"source_payload\": \"\{self.source_payload}\", " +
  "\"raw_read\": \"\{self.raw_read}\", \"visible_payload\": \"\{self.visible_payload}\" }"
}

///|
fn AsyncFifoSynthesisExpectedContract::to_json(
  self : AsyncFifoSynthesisExpectedContract,
  indent : String,
) -> String {
  indent +
  "{ \"kind\": \"\{self.kind}\", " +
  "\"pre_map_typed_graph\": \{self.pre_map_typed_graph}, " +
  "\"ram_mapping\": \{self.ram_mapping}, \"timing\": \{self.timing}, " +
  "\"physical_cdc\": \{self.physical_cdc}, " +
  "\"metastability\": \{self.metastability}, " +
  "\"four_state_equivalence\": \{self.four_state_equivalence} }"
}

///|
fn async_fifo_role_domain(
  hardware_module : @ir.Module,
  emitted : @systemverilog.EmittedDesign,
  domain : @ir.ClockDomainId,
  reset : @ir.ResetSpec,
) -> AsyncFifoSynthesisDomainRole raise {
  guard hardware_module.domain(domain) is Some(definition) else {
    fail("asynchronous FIFO domain must exist")
  }
  guard reset.mode() is Synchronous && reset.polarity() is ActiveHigh else {
    fail("synthesis inventory supports synchronous active-high FIFO reset")
  }
  guard reset.value() == 0UL else {
    fail("synthesis inventory supports zero-valued FIFO reset")
  }
  {
    clock: emitted_identifier(emitted, Node, definition.clock().ordinal()),
    reset: emitted_identifier(emitted, Node, reset.signal().ordinal()),
  }
}

///|
fn async_fifo_lane_memory(
  emitted : @systemverilog.EmittedDesign,
  raw_read : @ir.NodeId,
) -> String raise {
  guard emitted
    .manifest()
    .mappings()
    .iter()
    .find_first(mapping => {
      mapping.kind() is AsyncFifoLane &&
      mapping.local_ordinal() == raw_read.ordinal()
    })
    is Some(mapping) else {
    fail("asynchronous FIFO lane mapping must exist")
  }
  mapping.identifier()
}

///|
fn async_fifo_role_lanes(
  spec : @ir.AsyncFifoPrimitive,
  emitted : @systemverilog.EmittedDesign,
) -> Array[AsyncFifoSynthesisLaneRole] raise {
  let shape = spec.payload_shape().flatten()
  let source = spec.source_payload()
  let raw = spec.raw_reads()
  let visible = spec.destination_payload()
  guard shape.length() == source.length() &&
    source.length() == raw.length() &&
    raw.length() == visible.length() else {
    fail("asynchronous FIFO lane roles must have equal cardinality")
  }
  let lanes : Array[AsyncFifoSynthesisLaneRole] = []
  for index in 0..<shape.length() {
    lanes.push({
      index,
      memory: async_fifo_lane_memory(emitted, raw[index]),
      width: shape[index].value().width().bits(),
      source_payload: emitted_identifier(emitted, Node, source[index].ordinal()),
      raw_read: emitted_identifier(emitted, Node, raw[index].ordinal()),
      visible_payload: emitted_identifier(
        emitted,
        Node,
        visible[index].ordinal(),
      ),
    })
  }
  lanes
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
fn async_fifo_role_inventory_json(
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
  let source_domain = async_fifo_role_domain(
    hardware_module,
    emitted,
    spec.source_domain(),
    spec.source_reset(),
  )
  let destination_domain = async_fifo_role_domain(
    hardware_module,
    emitted,
    spec.destination_domain(),
    spec.destination_reset(),
  )
  guard kind.address_width() == spec.pointer_width() - 1 else {
    fail("asynchronous FIFO fixture address width must match its pointer")
  }
  let lanes = async_fifo_role_lanes(spec, emitted)
  let expected_contract : AsyncFifoSynthesisExpectedContract = {
    kind: "canonical-ir-role-inventory-only",
    pre_map_typed_graph: false,
    ram_mapping: false,
    timing: false,
    physical_cdc: false,
    metastability: false,
    four_state_equivalence: false,
  }
  let out = StringBuilder()
  out.write_string(
    "{\n  \"schema_version\": \"lunachip.async-fifo-role-inventory/v2\",\n",
  )
  out.write_string(
    "  \"artifact_kind\": \"async-fifo-pre-map-expected-contract\",\n  \"fixture\": \"\{kind.id()}\",\n  \"top_module\": \"\{top.identifier()}\",\n",
  )
  out.write_string(
    "  \"depth\": \{spec.depth()},\n  \"synchronizer_stages\": \{spec.synchronizer_stages()},\n  \"pointer_width\": \{spec.pointer_width()},\n  \"address_width\": \{kind.address_width()},\n",
  )
  out.write_string("  \"source_domain\": ")
  out.write_string(source_domain.to_json(""))
  out.write_string(",\n  \"destination_domain\": ")
  out.write_string(destination_domain.to_json(""))
  out.write_string(",\n")
  out.write_string(
    "  \"source_valid\": \"\{node(spec.source_valid())}\",\n  \"source_ready\": \"\{node(spec.source_ready())}\",\n  \"destination_ready\": \"\{node(spec.destination_ready())}\",\n  \"destination_valid\": \"\{node(spec.destination_valid())}\",\n",
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
    "  \"read_gray_pipeline\": \{json_string_array(ids(emitted, spec.read_gray_stages()))},\n  \"write_gray_pipeline\": \{json_string_array(ids(emitted, spec.write_gray_stages()))},\n",
  )
  out.write_string("  \"lanes\": [\n")
  for index, lane in lanes {
    out.write_string(lane.to_json("    "))
    out.write_string(if index + 1 == lanes.length() { "\n" } else { ",\n" })
  }
  out.write_string("  ],\n")
  out.write_string("  \"expected_contract\": ")
  out.write_string(expected_contract.to_json(""))
  out.write_string("\n}\n")
  out.to_string()
}

///|
pub fn generate_async_fifo_synthesis_bundle(
  kind : AsyncFifoSynthesisKind,
) -> AsyncFifoSynthesisBundle raise {
  let design = async_fifo_synthesis_design(kind)
  let emitted = @systemverilog.emit_design(design)
  let expected = async_fifo_role_inventory_json(kind, design, emitted)
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
  artifacts.push({ path: "async-fifo-role-inventory.json", content: expected })
  { artifacts: ReadOnlyArray::from_array(artifacts) }
}
