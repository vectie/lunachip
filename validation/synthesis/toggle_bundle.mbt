///|
fn node_type(
  hardware_module : @ir.Module,
  id : @ir.NodeId,
) -> @ir.SignalType raise {
  for node in hardware_module.nodes() {
    if node.id() == id {
      return node.signal_type()
    }
  }
  fail("missing toggle synthesis node \{id.ordinal()}")
}

///|
fn write_state_entry(
  out : StringBuilder,
  emitted : @systemverilog.EmittedDesign,
  hardware_module : @ir.Module,
  id : @ir.NodeId,
  clock : String,
  reset : String,
  enable : Bool,
  comma : Bool,
) -> Unit raise {
  out.write_string("    { \"signal\": \"")
  out.write_string(emitted_identifier(emitted, Node, id.ordinal()))
  out.write_string("\", \"width\": ")
  out.write_string(node_type(hardware_module, id).width().bits().to_string())
  out.write_string(", \"clock\": \"")
  out.write_string(clock)
  out.write_string("\", \"reset\": \"")
  out.write_string(reset)
  out.write_string("\", \"enable\": ")
  out.write_string(if enable { "true" } else { "false" })
  out.write_string(if comma { " },\n" } else { " }\n" })
}

///|
fn toggle_expected_shape_json(
  kind : ToggleSynthesisKind,
  design : @ir.Design,
  emitted : @systemverilog.EmittedDesign,
) -> String raise {
  guard design.top_module() is Some(hardware_module) else {
    raise MissingTopModule
  }
  guard hardware_module.cdc_primitives() is [ToggleHandshake(spec)] else {
    fail("toggle synthesis fixture must contain exactly one handshake")
  }
  guard emitted.modules().get(emitted.manifest().top_module_ordinal())
    is Some(top) else {
    raise MissingEmittedTopModule
  }
  let source_clock = emitted_identifier(
    emitted,
    Node,
    hardware_module.domains()[spec.source_domain().ordinal()].clock().ordinal(),
  )
  let destination_clock = emitted_identifier(
    emitted,
    Node,
    hardware_module.domains()[spec.destination_domain().ordinal()]
    .clock()
    .ordinal(),
  )
  let source_reset = emitted_identifier(
    emitted,
    Node,
    spec.source_reset().signal().ordinal(),
  )
  let destination_reset = emitted_identifier(
    emitted,
    Node,
    spec.destination_reset().signal().ordinal(),
  )
  let state_count = kind.stage_count() * 2 + 3 + kind.payload_leaf_count() * 2
  let out = StringBuilder()
  out.write_string("{\n")
  out.write_string(
    "  \"$schema\": \"https://lunachip.dev/schema/toggle-synthesis-shape-v1.json\",\n",
  )
  out.write_string(
    "  \"schema_version\": \"lunachip.toggle-synthesis-shape/v1\",\n",
  )
  out.write_string("  \"fixture\": \"\{kind.id()}\",\n")
  out.write_string("  \"top_module\": \"\{top.identifier()}\",\n")
  out.write_string("  \"synchronizer_stages\": \{kind.stage_count()},\n")
  out.write_string("  \"payload_leaf_count\": \{kind.payload_leaf_count()},\n")
  out.write_string("  \"state_count\": \{state_count},\n")
  out.write_string("  \"state\": [\n")
  let states : Array[(@ir.NodeId, String, String, Bool)] = []
  states.push((spec.request_toggle(), source_clock, source_reset, false))
  for id in spec.held_payload() {
    states.push((id, source_clock, source_reset, true))
  }
  for id in spec.request_stages() {
    states.push((id, destination_clock, destination_reset, false))
  }
  states.push(
    (spec.destination_valid(), destination_clock, destination_reset, false),
  )
  for id in spec.destination_payload() {
    states.push((id, destination_clock, destination_reset, true))
  }
  states.push(
    (spec.acknowledge_toggle(), destination_clock, destination_reset, false),
  )
  for id in spec.acknowledge_stages() {
    states.push((id, source_clock, source_reset, false))
  }
  for index, state in states {
    let (id, clock, reset, enable) = state
    write_state_entry(
      out,
      emitted,
      hardware_module,
      id,
      clock,
      reset,
      enable,
      index + 1 < states.length(),
    )
  }
  out.write_string("  ],\n")
  out.write_string("  \"edge\": \"positive\",\n")
  out.write_string("  \"reset_mode\": \"synchronous-active-high-zero\"\n")
  out.write_string("}\n")
  out.to_string()
}

///|
pub fn generate_toggle_synthesis_bundle(
  kind : ToggleSynthesisKind,
) -> ToggleSynthesisBundle raise {
  let design = toggle_synthesis_design(kind)
  let emitted = @systemverilog.emit_design(design)
  let expected_shape = toggle_expected_shape_json(kind, design, emitted)
  let artifacts : Array[BundleArtifact] = [
    { path: "design.lcir", content: @ir_codec.serialize(design), },
  ]
  for source in emitted.modules() {
    artifacts.push({ path: source.filename(), content: source.source(), })
  }
  artifacts.push({
    path: "names.lcnm",
    content: emitted.manifest().to_canonical_text(),
  })
  artifacts.push({ path: "job.json", content: job_json(emitted), })
  artifacts.push({
    path: "expected-toggle-shape.json",
    content: expected_shape,
  })
  {
    kind,
    design,
    emitted,
    expected_shape_json: expected_shape,
    artifacts: ReadOnlyArray::from_array(artifacts),
  }
}
