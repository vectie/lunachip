///|
#warnings("-unused_value")
fn fetched_packet_order_artifacts() -> ReadOnlyArray[FormalBundleArtifact] raise {
  let sequential = fetched_transport_sequential()
  let view = fetched_dependency_view(sequential)
  let design = @ir.Design::single("FetchedPacketOrderView", view)
  let emitted = @rtl.emit_design(design)
  let (binary, _) = dependency_boolean_helpers(
    view,
    top_emitted_module(emitted).source(),
  )
  let observer = fetched_packet_order_observer(sequential.probe.source, emitted)
  let component = @rtl.emit_design(
    @ir.Design::single(
      "FetchedTransportProofView",
      fetched_transport_proof_view(sequential),
    ),
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
    {
      path: "fetched-packet-order-full.sv",
      content: fetched_packet_order_insert(binary, observer) + wrapper,
    },
    {
      path: "fetched-packet-order-full.sby",
      content: fetched_safety_config("fetched-packet-order-full"),
    },
    { path: "proof-view.lcir", content: @ir_codec.serialize(design), },
    {
      path: "proof-view.names",
      content: emitted.manifest().to_canonical_text(),
    },
  ]
  let report = StringBuilder()
  report.write_string(
    "LUNACHIP-FETCHED-PACKET-ORDER 1\nPRODUCTION sha256 \{sequential.probe.production_digest}\nSCOPE fixed-fetched1x1-K2-host1024-ring4-q2\nASSUMPTIONS original-five-only\nMEMORY original-ten-unknown-arrays-and-read-states\nADDRESS original-64-13-32-34-bit-stages-and-exact-UInt1-FIFO-addresses\nPACKET full256-independent-two-entry-history-ReadOld-through-reserve-and-dispatch\n",
  )
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
