///|
/// Prepare the predefined fetched concurrent device for the existing pinned
/// Yosys runner. Its checked configuration and design identity match the
/// independently replayed 1x1/K512 fixture. This function emits inputs only;
/// it does not execute tools or claim synthesis, memory inference or timing.
pub fn generate_flux_tile_bundle() -> ReadOnlyArray[BundleArtifact] raise {
  let configuration = @capabilities.Capabilities::new(
    rows=1,
    columns=1,
    max_reduction=512,
    host_bytes=4096UL,
    ring_depth=4,
    queue_depth=3,
  )
  let hardware = @flux_tile.ring_concurrent_from_capabilities(configuration)
  let design = @ir.Design::single(
    "phase6-fetched-concurrent-1x1-k512-overlap", hardware,
  )
  let emitted = @systemverilog.emit_design(design)
  let artifacts : Array[BundleArtifact] = [
    { path: "design.lcir", content: @ir_codec.serialize(design), },
    { path: "capabilities.json", content: configuration.manifest(), },
  ]
  for source in emitted.modules() {
    artifacts.push({ path: source.filename(), content: source.source(), })
  }
  artifacts.push({
    path: "names.lcnm",
    content: emitted.manifest().to_canonical_text(),
  })
  artifacts.push({ path: "job.json", content: job_json(emitted), })
  ReadOnlyArray::from_array(artifacts)
}
