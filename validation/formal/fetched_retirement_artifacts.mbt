///|
#warnings("-unused_value")
fn fetched_retirement_artifacts() -> ReadOnlyArray[FormalBundleArtifact] raise {
  let sequential = fetched_transport_sequential()
  let component = @rtl.emit_design(
    @ir.Design::single(
      "FetchedTransportProofView",
      fetched_transport_proof_view(sequential),
    ),
  )
  let view = fetched_retirement_view(sequential)
  let design = @ir.Design::single("FetchedRetirementCompositionView", view)
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
    extra_support=fetched_retirement_support(),
  )
  let (_, _, labels, _) = flux_tile_property_export()
  let artifacts : Array[FormalBundleArtifact] = []
  for name in ["fetched-retirement-stability", "fetched-retirement-full"] {
    let selected = wrapper
      .split("\n")
      .filter(line => {
        name == "fetched-retirement-full" ||
        ![labels[0], labels[1]].any(label => line.contains(label + ": assert ("))
      })
      .map(line => line.to_owned())
      .to_array()
      .join("\n")
    artifacts.push({ path: name + ".sv", content: binary + selected, })
    artifacts.push({
      path: name + ".sby",
      content: fetched_safety_config(name),
    })
  }
  artifacts.push({
    path: "proof-view.lcir",
    content: @ir_codec.serialize(design),
  })
  artifacts.push({
    path: "proof-view.names",
    content: emitted.manifest().to_canonical_text(),
  })
  let report = StringBuilder()
  report.write_string(
    "LUNACHIP-FETCHED-RETIREMENT 1\nPRODUCTION sha256 \{sequential.probe.production_digest}\nSCOPE fixed-fetched1x1-K2-host1024-ring4-q2\nASSUMPTIONS original-five-only-no-internal-relation\nMEMORY all-ten-original-unknown-arrays-and-ports\nADDRESS original-full-width-equations-no-high-bit-pins\nSTABILITY-SUBSET excludes-public-aperture-and-payload-only-not-full-safety\n",
  )
  for binding in fetched_retirement_aliases(sequential.probe.source) {
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
