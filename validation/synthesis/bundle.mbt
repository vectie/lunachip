///|
fn job_json(emitted : @systemverilog.EmittedDesign) -> String raise {
  guard emitted.modules().get(emitted.manifest().top_module_ordinal())
    is Some(top) else {
    raise MissingEmittedTopModule
  }
  let output = StringBuilder()
  output.write_string("{\n")
  output.write_string(
    "  \"$schema\": \"https://lunachip.dev/schema/yosys-job-v1.json\",\n",
  )
  output.write_string("  \"schema_version\": \"lunachip.yosys-job/v1\",\n")
  output.write_string("  \"top_module\": \"")
  output.write_string(top.identifier())
  output.write_string("\",\n  \"sources\": [\n")
  for index, source in emitted.modules() {
    output.write_string("    { \"path\": \"")
    output.write_string(source.filename())
    output.write_string("\", \"sha256\": \"")
    output.write_string(sha256_hex(source.source()))
    output.write_string(
      if index + 1 == emitted.modules().length() {
        "\" }\n"
      } else {
        "\" },\n"
      },
    )
  }
  output.write_string("  ],\n  \"formal_tasks\": []\n}\n")
  output.to_string()
}

///|
pub fn generate_bundle(kind : SynthesisKind) -> SynthesisBundle raise {
  let design = synthesis_design(kind)
  guard design.top_module() is Some(_) else { raise MissingTopModule }
  let emitted = @systemverilog.emit_design(design)
  let job = job_json(emitted)
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
  artifacts.push({ path: "job.json", content: job })
  {
    kind,
    design,
    emitted,
    job_json: job,
    artifacts: ReadOnlyArray::from_array(artifacts),
  }
}
