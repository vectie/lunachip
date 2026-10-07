///|
/// Export the original three queue-monitor predicates over the unchanged
/// local controller projection. These are proof inputs, not proof results.
/// All 35 monitor bits and their wrapping public history remain verbatim.
/// Only startup joint reset is assumed; eight existing data cuts stay free.
/// Engine ownership, packet provenance, memory safety and progress are outside
/// this supporting slice. Ordinary and earlier proof exports are unchanged.
///
/// ```mbt check
/// test {
///   let inputs = @formal.generate_queue_monitor_proof_artifacts()
///   assert_eq(inputs.map(input => input.path()), [
///     "sequential.lcir", "sequential-production.sv", "sequential-boolean.sv", "bridge.sv",
///     "negative-population.sv", "bridge-inputs.txt",
///   ])
/// }
/// ```
pub fn generate_queue_monitor_proof_artifacts() -> ReadOnlyArray[
  FormalBundleArtifact,
] raise {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let sequential = queue_control_sequential(fixture)
  let design = @ir.Design::single("QueueControlSequential", sequential.hardware)
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
      content: queue_monitor_proof_source(fixture, sequential, emitted),
    },
    {
      path: "negative-population.sv",
      content: queue_monitor_proof_source(
        fixture,
        sequential,
        emitted,
        negative=true,
      ),
    },
  ]
  let inventory = StringBuilder()
  inventory.write_string(
    "SCOPE binary-local-original-queue-monitor-proof-inputs-not-proof-or-full-device-gate\n" +
    "TOP lc_queue_monitor_bridge\n" +
    "CLOCK original-rising-domain-global-toggle-first-joint-reset-later-reset-symbolic\n" +
    "STATE DUT-uninitialized-16-registers-37-bits-original-monitor-16-registers-35-bits-total72-excluding-clock\n" +
    "BOUNDARY unchanged-eight-free-nonstate-cuts-8-bits-plus-clock-9-inputs\n" +
    "ASSUMPTIONS original-lc_queue_sampled-startup-reset-only-no-relation-history-event-readiness-or-progress-premise\n" +
    "CONCLUSIONS original-p4-lane-atomicity-response-history-p5-public-and-live-population-p6-retirement-events-history-and-established-raw-relation\n" +
    "LIMITATION arbitrary-terminal-timing-no-engine-identity-packet-provenance-nested-memory-fairness-or-full-device-claim\n" +
    "MUTATION original-R-plus-one-comparison-only-admission-seen-reservation-seen-nonreset-R-positive-raw-population-match-not-current-reserve-XOR\n",
  )
  for root in sequential.plan.roots {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      root.node,
    )
    inventory.write_string(
      "REGISTER \{root.name} original \{root.node.ordinal()} local \{mapped.ordinal()} width \{root.signal_type.width().bits()} type \{Repr(root.signal_type)}\n",
    )
  }
  for (name, width) in queue_monitor_history_fields() {
    inventory.write_string("MONITOR-REGISTER \{name} width \{width}\n")
  }
  for cut in sequential.plan.cuts {
    if !sequential.plan.roots.any(root => root.node == cut.node) {
      let mapped = dependency_generation_mapped(
        sequential.original_to_local,
        cut.node,
      )
      inventory.write_string(
        "CUT node \{cut.node.ordinal()} local \{mapped.ordinal()} width \{cut.signal_type.width().bits()} type \{Repr(cut.signal_type)} roles \{cut.roles.iter().to_array().join(",")}\n",
      )
    }
  }
  for event in sequential.plan.events {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      event.node,
    )
    inventory.write_string(
      "EVENT \{event.name} original \{event.node.ordinal()} local \{mapped.ordinal()} width \{event.signal_type.width().bits()}\n",
    )
  }
  inventory.write_string(
    "ALIAS lc_completion_valid actual-public-driver-equals-retirement_valid\n" +
    "ALIAS lc_descriptor_ready actual-public-driver-equals-descriptor_ready\n" +
    "ALIAS lc_o_entry_terminal_0,1,2 same-existing-terminal-cuts\n" +
    "ALIAS lc_reset,lc_descriptor_valid,lc_completion_ready same-existing-public-cuts\n",
  )
  let (exported, _, _, _) = queue_property_export(Conservation)
  let properties = exported.property_manifest().properties()
  inventory.write_string("ASSUMPTION \{properties[0].stable_name()}\n")
  for property in properties[4:7] {
    inventory.write_string(
      "ASSERTION \{property.stable_name()} original \{property.name()}\n",
    )
  }
  for artifact in artifacts {
    inventory.write_string(
      "SOURCE \{artifact.path} sha256 \{sha256_hex(artifact.content)}\n",
    )
  }
  for fixture_kind in [QueueFormalFixture::Conservation, NegativePopulation] {
    inventory.write_string(
      "MONITOR \{fixture_kind.id()} sha256 \{sha256_hex(queue_monitor_source(fixture_kind))}\n",
    )
  }
  inventory.write_string(
    "PRODUCTION sha256 \{sha256_hex(@ir_codec.serialize(@ir.Design::single("QueuedConcurrentQueueConservationPilot", fixture.hardware())))}\n",
  )
  artifacts.push({ path: "bridge-inputs.txt", content: inventory.to_string(), })
  ReadOnlyArray::from_array(artifacts)
}
