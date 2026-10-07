///|
// Private input collector only: no public API, family registry, runner or
// result receipt. Complete report/core pins intentionally block initial export.
#warnings("-unused_value")
fn fetched_transport_proof_artifacts() -> ReadOnlyArray[FormalBundleArtifact] raise {
  let sequential = fetched_transport_sequential()
  fetched_transport_proof_require(sequential)
  let view = fetched_transport_proof_view(sequential)
  let design = @ir.Design::single("FetchedTransportProofView", view)
  let emitted = @rtl.emit_design(design)
  let production = top_emitted_module(emitted).source()
  let (boolean_source, _) = dependency_boolean_helpers(view, production)
  let artifacts : Array[FormalBundleArtifact] = [
    { path: "sequential.lcir", content: @ir_codec.serialize(design), },
    { path: "sequential-production.sv", content: production, },
    { path: "sequential-boolean.sv", content: boolean_source, },
    {
      path: "bridge.sv",
      content: fetched_transport_proof_source(sequential, emitted),
    },
    {
      path: "negative-assembled-lane.sv",
      content: fetched_transport_proof_source(
        sequential,
        emitted,
        negative=true,
      ),
    },
  ]
  let inventory = StringBuilder()
  inventory.write_string(
    "SCOPE binary-fetched-reader-three-client-component-inputs-only-not-proof-full-device-Store-or-Phase6-gate\nTOP lc_fetched_transport_bridge\n",
  )
  inventory.write_string(
    "PRODUCTION sha256 \{sequential.probe.production_digest}\nCORE-IR sha256 \{fetched_transport_proof_ir_pin()}\nCOMPLETE-REPORT sha256 \{fetched_transport_proof_report_pin()}\n",
  )
  inventory.write_string(
    "CLOCK original-global-toggle-first-sampled-joint-reset-later-resets-symbolic\nSTATE exact26-original-registers666bits-uninitialized-no-memory-replacement\nVIEW same-original-selected-nodes-five-original-direct-aliases-no-new-operation-or-state\nBOUNDARY actual-reviewed-raw-loader-storer-fields-readiness-downstream-packet-ready-public-host-inputs-all-arbitrary\n",
  )
  inventory.write_string(
    "ASSUMPTION lc_initial_joint_reset\nNO-PREMISE client-stability-ready-progress-response-match-array-zero-owner-or-invariant\nNEGATIVE comparison-only-checked-lane0-bit0-after-currentpacket32-genuine-owned-successful-byte-ACKs-raw-history-and-otherassertions-identical\n",
  )
  inventory.write_string(
    "TASK bmc bound256-global128-DUT timeout600 all12assertions\nTASK cover bound256-global128-DUT timeout600 lc_fetched_packet_three_owners\nTASK negative-bmc bound256-global128-DUT timeout600 only-lc_fetched_reader_assembly-expected-fail\n",
  )
  inventory.write_string(
    "LIMITATION reader-only-aperture-payload-legality-arbitrary-otherclients-not-full-eight-public-conditions-not-numerical-Store-lease-fairness-or-completion\nQUALIFICATION native-report-review-Boolean-helper-equivalence-and-actual-engine-traces-required\n",
  )
  for label in fetched_transport_proof_assertions() {
    inventory.write_string("ASSERTION \{label}\n")
  }
  inventory.write_string("COVER lc_fetched_packet_three_owners\n")
  for view_alias in fetched_transport_proof_view_aliases(sequential) {
    inventory.write_string(
      "VIEW-ALIAS proof_\{view_alias.name} original \{view_alias.node.ordinal()} local \{dependency_generation_mapped(sequential.original_to_local,view_alias.node).ordinal()} type \{Repr(view_alias.signal_type)}\n",
    )
  }
  for artifact in artifacts {
    inventory.write_string(
      "SOURCE \{artifact.path} sha256 \{sha256_hex(artifact.content)}\n",
    )
  }
  inventory.write_string(fetched_transport_probe_report(sequential.probe))
  artifacts.push({ path: "bridge-inputs.txt", content: inventory.to_string(), })
  ReadOnlyArray::from_array(artifacts)
}
