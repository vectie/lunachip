///|
fn feedback_unit(root : String) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh feedback unit root") }
  @fs.create_dir(root)
  let hardware = @fp.feedback_accumulator()
  let design = @ir.Design::single("qwen-fp32-feedback-accumulator/v1", hardware)
  let emitted = @sv.emit_design(design)
  save(root, "unit.lcir", @codec.serialize(design))
  save(root, "unit.sv", normalize(optimized(emitted.source())))
  save(root, "unit.names", emitted.manifest().to_canonical_text())
  let ports : Map[String, Json] = Map([])
  for name in ["clock", "reset", "valid", "value"] {
    ports[name] = Json(mapped(emitted, name, InputPort))
  }
  ports["sum"] = Json(mapped(emitted, "sum", OutputPort))
  save(
    root,
    "ports.json",
    ({ "top": emitted.modules()[0].identifier(), "ports": ports } : Json).stringify(
      indent=2,
    ),
  )
}
