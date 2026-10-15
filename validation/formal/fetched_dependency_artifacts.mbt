///|
#warnings("-unused_value")
fn fetched_dependency_artifacts() -> ReadOnlyArray[FormalBundleArtifact] raise {
  let sequential = fetched_transport_sequential()
  let component = @rtl.emit_design(
    @ir.Design::single(
      "FetchedTransportProofView",
      fetched_transport_proof_view(sequential),
    ),
  )
  let view = fetched_dependency_view(sequential)
  let design = @ir.Design::single("FetchedDependencyCompositionView", view)
  let emitted = @rtl.emit_design(design)
  let (binary, _) = dependency_boolean_helpers(
    view,
    top_emitted_module(emitted).source(),
  )
  let wrapper = fetched_safety_source(
    sequential,
    component,
    emitted,
    owner_only=false,
    observed_view=view,
    extra_support=fetched_retirement_support() +
      fetched_capture_bounds_support() +
      fetched_dma_support() +
      fetched_dependency_support(),
  )
  let artifacts : Array[FormalBundleArtifact] = [
    { path: "fetched-dependency-full.sv", content: binary + wrapper, },
    {
      path: "fetched-dependency-full.sby",
      content: fetched_safety_config("fetched-dependency-full"),
    },
    { path: "proof-view.lcir", content: @ir_codec.serialize(design), },
    {
      path: "proof-view.names",
      content: emitted.manifest().to_canonical_text(),
    },
  ]
  let report = StringBuilder()
  report.write_string(
    "LUNACHIP-FETCHED-DEPENDENCY 1\nPRODUCTION sha256 \{sequential.probe.production_digest}\nSCOPE fixed-fetched1x1-K2-host1024-ring4-q2\nASSUMPTIONS original-five-only\nMEMORY original-ten-unknown-arrays-and-read-states\nADDRESS original-64-13-32-34-bit-stages\nPROVENANCE intended-writers-from-raw-head-snapshots-and-actual-engine-events\n",
  )
  for binding in fetched_dependency_aliases(sequential.probe.source) {
    report.write_string(
      "ACTUAL \{binding.name} node\{binding.node.ordinal()} type\{Repr(binding.signal_type)}\n",
    )
  }
  for artifact in artifacts {
    report.write_string(
      "SOURCE \{artifact.path} sha256 \{sha256_hex(artifact.content)}\n",
    )
  }
  report.write_string("CLAIM generated-inputs-not-engine-evidence\nEND\n")
  artifacts.push({
    path: "composition-inventory.txt",
    content: report.to_string(),
  })
  ReadOnlyArray::from_array(artifacts)
}
