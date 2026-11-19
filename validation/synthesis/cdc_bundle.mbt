///|
fn emitted_identifier(
  emitted : @systemverilog.EmittedDesign,
  kind : @systemverilog.SymbolKind,
  ordinal : Int32,
) -> String raise {
  for mapping in emitted.manifest().mappings() {
    if mapping.module_ordinal() == 0 &&
      mapping.kind() == kind &&
      mapping.local_ordinal() == ordinal {
      return mapping.identifier()
    }
  }
  fail("missing emitted identifier for ordinal \{ordinal}")
}

///|
fn cdc_expected_shape_json(
  stage_count : Int32,
  design : @ir.Design,
  emitted : @systemverilog.EmittedDesign,
) -> String raise {
  guard design.top_module() is Some(hardware_module) else {
    raise MissingTopModule
  }
  guard hardware_module.cdc_primitives() is [BitSynchronizer(spec)] else {
    fail("CDC synthesis fixture must contain exactly one bit synchronizer")
  }
  guard emitted.modules().get(emitted.manifest().top_module_ordinal())
    is Some(top) else {
    raise MissingEmittedTopModule
  }
  let mut destination_domain : @ir.ClockDomain? = None
  for domain in hardware_module.domains() {
    if domain.id() == spec.destination() {
      destination_domain = Some(domain)
    }
  }
  guard destination_domain is Some(destination) else {
    fail("CDC synthesis fixture is missing its destination domain")
  }
  let out = StringBuilder()
  out.write_string("{\n")
  out.write_string(
    "  \"$schema\": \"https://lunachip.dev/schema/cdc-synthesis-shape-v1.json\",\n",
  )
  out.write_string(
    "  \"schema_version\": \"lunachip.cdc-synthesis-shape/v1\",\n",
  )
  out.write_string(
    "  \"fixture\": \"bit-synchronizer-\{stage_count}-stage\",\n",
  )
  out.write_string("  \"top_module\": \"\{top.identifier()}\",\n")
  out.write_string("  \"stage_count\": \{stage_count},\n")
  out.write_string(
    "  \"clock_signal\": \"\{emitted_identifier(emitted, Node, destination.clock().ordinal())}\",\n",
  )
  out.write_string(
    "  \"source_signal\": \"\{emitted_identifier(emitted, Node, spec.source().ordinal())}\",\n",
  )
  out.write_string("  \"stage_signals\": [")
  for index, stage in spec.stages() {
    if index > 0 {
      out.write_string(", ")
    }
    out.write_string(
      "\"\{emitted_identifier(emitted, Node, stage.ordinal())}\"",
    )
  }
  out.write_string("],\n")
  out.write_string(
    "  \"output_signal\": \"\{emitted_identifier(emitted, OutputPort, 0)}\",\n",
  )
  out.write_string("  \"edge\": \"positive\",\n")
  out.write_string("  \"width\": 1,\n")
  out.write_string("  \"reset\": false\n")
  out.write_string("}\n")
  out.to_string()
}

///|
pub fn generate_bit_synchronizer_bundle(
  stage_count : Int32,
) -> CdcSynthesisBundle raise {
  let design = cdc_bit_synchronizer_design(stage_count)
  let emitted = @systemverilog.emit_design(design)
  let job = job_json(emitted)
  let expected_shape = cdc_expected_shape_json(stage_count, design, emitted)
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
  artifacts.push({ path: "job.json", content: job, })
  artifacts.push({ path: "expected-cdc-shape.json", content: expected_shape, })
  {
    stage_count,
    design,
    emitted,
    expected_shape_json: expected_shape,
    artifacts: ReadOnlyArray::from_array(artifacts),
  }
}
