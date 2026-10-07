///|
/// Export binary supporting inputs for the original two-client DMA arbiter.
/// Eleven original registers/172 bits retain their equations; fifteen reviewed
/// raw boundaries remain symbolic and seven constant boundaries remain exact.
/// Only first sampled joint reset is assumed. Export is not a proof, helper
/// qualification, DMA bounds result or completion of the full-device gate.
/// No runner family or proof receipt is created.
///
/// ```mbt check
/// test {
///   let inputs = @formal.generate_two_client_arbiter_proof_artifacts()
///   assert_eq(inputs.map(input => input.path()), [
///     "sequential.lcir", "sequential-production.sv", "sequential-boolean.sv", "bridge.sv",
///     "negative-stalled-payload.sv", "bridge-inputs.txt",
///   ])
/// }
/// ```
pub fn generate_two_client_arbiter_proof_artifacts() -> ReadOnlyArray[
  FormalBundleArtifact,
] raise {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let sequential = two_client_arbiter_sequential(fixture)
  let probe = sequential.probe
  let design = @ir.Design::single(
    "TwoClientArbiterSequential",
    two_client_arbiter_proof_view(sequential),
  )
  let emitted = @rtl.emit_design(design)
  let production = top_emitted_module(emitted).source()
  let (boolean_source, _) = dependency_boolean_helpers(
    sequential.hardware,
    production,
  )
  let artifacts : Array[FormalBundleArtifact] = [
    { path: "sequential.lcir", content: @ir_codec.serialize(design), },
    { path: "sequential-production.sv", content: production, },
    { path: "sequential-boolean.sv", content: boolean_source, },
    {
      path: "bridge.sv",
      content: two_client_arbiter_proof_source(fixture, sequential, emitted),
    },
    {
      path: "negative-stalled-payload.sv",
      content: two_client_arbiter_proof_source(
        fixture,
        sequential,
        emitted,
        negative=true,
      ),
    },
  ]
  let inventory = StringBuilder()
  inventory.write_string(
    "SCOPE binary-local-original-two-client-DMA-arbiter-inputs-not-proof-or-full-device-gate\n" +
    "TOP lc_two_client_arbiter_bridge\n" +
    "CLOCK original-rising-domain-global-toggle-first-sampled-joint-reset-later-reset-symbolic\n" +
    "STATE DUT-uninitialized-11-registers-172-bits-no-replacement-controller\n" +
    "EMISSION-VIEW exact-108-original-nodes-and-28-core-aliases-plus-one-raw_response_data_observation-direct-boundary-alias-29-outputs-no-new-node-state-or-theorem\n" +
    "BOUNDARY reviewed-15-raw-symbolic-cuts-seven-original-constant-boundaries-derived-grant-acceptance-routing-retained\n" +
    "ASSUMPTIONS startup-reset-only-no-client-stability-readiness-response-match-history-fairness-or-payload-premise\n" +
    "CONCLUSIONS grant-snapshot-held-Offer-public-history-owner-tag-restoration-fault-routing-poison-arbitration-edge-updates-reset-establishment-nonrising-hold\n" +
    "TAG-RESTORATION original-saved-local_tag-versus-independent-raw-grant-tag; client-record-tag-and-data-mapping-source-reviewed-alias-contract-not-named-IR-ports-or-separate-passthrough-theorem\n" +
    "MUTATION comparison-only-stalled-Offer-data-bit0-mask-bit32-of-104-bit-tuple-after-real-grant-committed-stall-and-raw-payload-equality\n" +
    "LIMITATION direct-1x1-two-client-component-not-fetched-arbiter-no-response-data-stability-DMA-cursor-bounds-Store-lease-memory-fairness-or-full-device-claim\n" +
    "QUALIFICATION Boolean-helper-equivalence-and-engine-execution-not-established-by-export\n" +
    "REVIEWED-INVENTORY sha256 \{sha256_hex(two_client_arbiter_probe_report(probe))}\n" +
    "PRODUCTION sha256 \{probe.production_digest}\n",
  )
  for root in probe.roots {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      root.node,
    )
    inventory.write_string(
      "REGISTER \{root.name} original \{root.node.ordinal()} local \{mapped.ordinal()} width \{root.signal_type.width().bits()} type \{Repr(root.signal_type)}\n",
    )
  }
  for candidate in probe.candidates {
    let original = candidate.original
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      original.id(),
    )
    inventory.write_string(
      "CUT node \{original.id().ordinal()} local \{mapped.ordinal()} width \{original.signal_type().width().bits()} type \{Repr(original.signal_type())} roles \{candidate.roles.iter().to_array().join(",")}\n",
    )
  }
  for boundary in probe.boundaries {
    if boundary.original.kind() is Constant(value) {
      let original = boundary.original
      let mapped = dependency_generation_mapped(
        sequential.original_to_local,
        original.id(),
      )
      inventory.write_string(
        "CONSTANT node \{original.id().ordinal()} local \{mapped.ordinal()} width \{original.signal_type().width().bits()} value \{value} roles \{boundary.roles.iter().to_array().join(",")}\n",
      )
    }
  }
  for event in probe.events {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      event.node,
    )
    inventory.write_string(
      "EVENT \{event.name} original \{event.node.ordinal()} local \{mapped.ordinal()} width \{event.signal_type.width().bits()}\n",
    )
  }
  inventory.write_string("ASSUMPTION lc_initial_joint_reset\n")
  for
    label in [
      "lc_arbiter_payload", "lc_arbiter_history", "lc_arbiter_routes", "lc_arbiter_arbitration",
      "lc_arbiter_edge_updates", "lc_arbiter_reset_zero", "lc_arbiter_established",
      "lc_arbiter_nonrising_hold",
    ] {
    inventory.write_string("ASSERTION \{label}\n")
  }
  for artifact in artifacts {
    inventory.write_string(
      "SOURCE \{artifact.path} sha256 \{sha256_hex(artifact.content)}\n",
    )
  }
  inventory.write_string(two_client_arbiter_probe_report(probe))
  artifacts.push({ path: "bridge-inputs.txt", content: inventory.to_string(), })
  ReadOnlyArray::from_array(artifacts)
}
