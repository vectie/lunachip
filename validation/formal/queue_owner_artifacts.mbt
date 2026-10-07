///|
/// Export binary supporting proof inputs for actual engine/live-entry identity.
/// The exact 30-register/304-bit production slice keeps 82 reviewed foreign
/// boundaries symbolic; shared decode and derived events are not free inputs.
/// Only first sampled joint reset is assumed. These files do not establish
/// ownership, helper equivalence, payload correctness or the full-device gate.
/// No task family, runner profile or typed proof receipt is created.
///
/// ```mbt check
/// test {
///   let inputs = @formal.generate_queue_owner_proof_artifacts()
///   assert_eq(inputs.map(input => input.path()), [
///     "sequential.lcir", "sequential-production.sv", "sequential-boolean.sv", "bridge.sv",
///     "negative-engine-ticket.sv", "bridge-inputs.txt",
///   ])
/// }
/// ```
pub fn generate_queue_owner_proof_artifacts() -> ReadOnlyArray[
  FormalBundleArtifact,
] raise {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let sequential = queue_owner_sequential(fixture)
  let plan = sequential.plan
  let probe = plan.probe
  let design = @ir.Design::single("QueueOwnerSequential", sequential.hardware)
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
      content: queue_owner_proof_source(fixture, sequential, emitted),
    },
    {
      path: "negative-engine-ticket.sv",
      content: queue_owner_proof_source(
        fixture,
        sequential,
        emitted,
        negative=true,
      ),
    },
  ]
  let inventory = StringBuilder()
  inventory.write_string(
    "SCOPE binary-local-engine-live-entry-ownership-proof-inputs-not-proof-or-full-device-gate\n" +
    "TOP lc_queue_owner_bridge\n" +
    "CLOCK original-rising-domain-global-toggle-first-sampled-joint-reset-later-reset-symbolic\n" +
    "STATE DUT-uninitialized-30-registers-304-bits-no-replacement-controller\n" +
    "BOUNDARY reviewed-82-foreign-leaves-shared-decode-and-original-derived-events-retained\n" +
    "ASSUMPTIONS startup-reset-only-no-ownership-readiness-history-fairness-or-payload-premise\n" +
    "CONCLUSIONS structure-cyclic-ticket-order-pending-head-forward-reverse-bijection-exact-events-edge-updates-reset-establishment-nonrising-hold\n" +
    "MUTATION checked-loader-ticket-plus-one-only-after-real-admission-reservation-acceptance-nonreset-busy-history-raw-owner-mask-equality\n" +
    "LIMITATION no-packet-provenance-generation-lease-DMA-memory-payload-fairness-or-full-device-claim\n" +
    "QUALIFICATION Boolean-helper-equivalence-and-engine-execution-not-established-by-export\n" +
    "REVIEWED-INVENTORY sha256 \{plan.inventory_digest}\n" +
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
  for cut in plan.cuts {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      cut.node,
    )
    inventory.write_string(
      "CUT node \{cut.node.ordinal()} local \{mapped.ordinal()} width \{cut.signal_type.width().bits()} type \{Repr(cut.signal_type)} roles \{cut.roles.iter().to_array().join(",")}\n",
    )
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
      "lc_owner_structure", "lc_owner_ticket_order", "lc_owner_bijection", "lc_owner_engine_identity",
      "lc_owner_events", "lc_owner_edge_updates", "lc_owner_reset_zero", "lc_owner_established",
      "lc_owner_nonrising_hold",
    ] {
    inventory.write_string("ASSERTION \{label}\n")
  }
  for artifact in artifacts {
    inventory.write_string(
      "SOURCE \{artifact.path} sha256 \{sha256_hex(artifact.content)}\n",
    )
  }
  inventory.write_string(
    "REVIEWED-DISCOVERY-SNAPSHOT same-complete-signatures-before-acceptance\n",
  )
  inventory.write_string(queue_owner_probe_report(probe))
  artifacts.push({ path: "bridge-inputs.txt", content: inventory.to_string(), })
  ReadOnlyArray::from_array(artifacts)
}
