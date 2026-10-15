///|
fn fetched_safety_config(name : String) -> String {
  "[options]\nmode prove\ndepth 20\ntimeout 600\nmulticlock on\nexpect pass\n[engines]\nsmtbmc bitwuzla\n[script]\nlogger -werror .*\nread_verilog -formal -sv -noautowire \{name}.sv\nprep -top lc_fetched_transport_bridge -flatten\nwrite_rtlil /out/\{name}-prepared.rtlil\n[files]\n\{name}.sv /work/\{name}.sv\n"
}

///|
#warnings("-unused_value")
fn fetched_safety_artifacts() -> ReadOnlyArray[FormalBundleArtifact] raise {
  let sequential = fetched_transport_sequential()
  let component = @rtl.emit_design(
    @ir.Design::single(
      "FetchedTransportProofView",
      fetched_transport_proof_view(sequential),
    ),
  )
  let view = fetched_safety_view(sequential)
  let design = @ir.Design::single("FetchedSafetyCompositionView", view)
  let emitted = @rtl.emit_design(design)
  let production = top_emitted_module(emitted).source()
  let (binary, _) = dependency_boolean_helpers(view, production)
  let artifacts : Array[FormalBundleArtifact] = []
  for
    (name, owner_only) in [
      ("fetched-safety-owner", true),
      ("fetched-safety-full", false),
    ] {
    let wrapper = fetched_safety_source(
      sequential,
      component,
      emitted,
      owner_only~,
    )
    artifacts.push({ path: name + ".sv", content: binary + wrapper, })
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
    "LUNACHIP-FETCHED-SAFETY-COMPOSITION 1\nSCOPE whole-fetched1x1-K2-host1024-ring4-q2-symbolic\nPRODUCTION sha256 \{sequential.probe.production_digest}\n",
  )
  report.write_string(
    "STATE all-original-nodes-domains-registers-memories-ports-metadata-unchanged\nBOUNDARY actual-public-inputs-only-no-component-cut-anyseq\nASSUMPTIONS original-five-public-peers-later-reset-symbolic-no-fairness-or-directed-image\nADDRESS original-full-width-end-exclusive-no-zero-or-truncation-premise\nDEPENDENCY-FRONTIER actual-reader-packet-accept-to-four-original-FIFO-write-ports-not-later-dispatch-proof\n",
  )
  for root in sequential.probe.roots {
    report.write_string(
      "COMPONENT-ROOT \{root.name} actual \{root.node.ordinal()} type \{Repr(root.signal_type)}\n",
    )
  }
  for cut in sequential.probe.candidates {
    report.write_string(
      "BOUNDARY-BACKED actual \{cut.original.id().ordinal()} type \{Repr(cut.original.signal_type())} roles \{cut.roles.iter().to_array().join(",")}\n",
    )
  }
  for memory in view.memories() {
    report.write_string(
      "MEMORY \{memory.id().ordinal()} \{memory.name()} depth \{memory.depth().elements()} type \{Repr(memory.element_type())}\n",
    )
  }
  for output in view.outputs() {
    report.write_string(
      "OUTPUT \{output.name()} actual \{output.driver().ordinal()} type \{Repr(output.signal_type())}\n",
    )
  }
  let (_, premises, conclusions, _) = flux_tile_property_export()
  for premise in premises {
    report.write_string("ORIGINAL-PREMISE \{premise}\n")
  }
  for conclusion in conclusions {
    report.write_string("ORIGINAL-PUBLIC-CONCLUSION \{conclusion}\n")
  }
  for artifact in artifacts {
    report.write_string(
      "SOURCE \{artifact.path} sha256 \{sha256_hex(artifact.content)}\n",
    )
  }
  report.write_string(
    "CLAIM generated-inputs-only-prepared-model-and-actual-engine-qualification-required\nEND\n",
  )
  artifacts.push({
    path: "composition-inventory.txt",
    content: report.to_string(),
  })
  ReadOnlyArray::from_array(artifacts)
}
