///|
#warnings("-unused_value")
fn fetched_dma_artifacts() -> ReadOnlyArray[FormalBundleArtifact] raise {
  let sequential = fetched_transport_sequential()
  let component = @rtl.emit_design(
    @ir.Design::single(
      "FetchedTransportProofView",
      fetched_transport_proof_view(sequential),
    ),
  )
  let view = fetched_dma_view(sequential)
  let design = @ir.Design::single("FetchedDmaCompositionView", view)
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
      fetched_dma_support(),
  )
  let artifacts : Array[FormalBundleArtifact] = [
    { path: "fetched-dma-full.sv", content: binary + wrapper, },
    {
      path: "fetched-dma-full.sby",
      content: fetched_safety_config("fetched-dma-full"),
    },
    { path: "proof-view.lcir", content: @ir_codec.serialize(design), },
    {
      path: "proof-view.names",
      content: emitted.manifest().to_canonical_text(),
    },
  ]
  let report = StringBuilder()
  report.write_string(
    "LUNACHIP-FETCHED-DMA 1\nPRODUCTION sha256 \{sequential.probe.production_digest}\nSCOPE fixed-fetched1x1-K2-host1024-ring4-q2\nASSUMPTIONS original-five-only\nMEMORY original-ten-unknown-arrays-and-ports\nADDRESS original-UInt64-calculation-UInt13-cursors-UInt32-encoding-UInt34-public-end\nPAYLOAD actual-C-response-to-DMA-snapshot-not-complete-generation-provenance\n",
  )
  for binding in fetched_dma_roots(sequential) {
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
