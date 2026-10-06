///|
/// Export exact local queue-control induction inputs, not proof results.
/// Original binary register/clock/reset transitions are retained. Eight free
/// boundaries abstract data/terminal timing; engine ownership, packet contents,
/// memory safety, fairness and whole-device composition are outside this slice.
///
/// ```mbt check
/// test {
///   let inputs = @formal.generate_queue_control_proof_artifacts()
///   assert_eq(inputs.map(artifact => artifact.path()), [
///     "sequential.lcir", "sequential-production.sv", "sequential-boolean.sv", "bridge.sv",
///     "negative-reserve.sv", "bridge-inputs.txt",
///   ])
///   assert_true(
///     inputs.any(artifact => {
///       artifact.path() == "bridge-inputs.txt" &&
///       artifact.content().contains("not-proof-or-full-device-gate")
///     }),
///   )
/// }
/// ```
pub fn generate_queue_control_proof_artifacts() -> ReadOnlyArray[
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
      content: queue_control_proof_source(sequential, emitted),
    },
    {
      path: "negative-reserve.sv",
      content: queue_control_proof_source(sequential, emitted, negative=true),
    },
  ]
  let inventory = StringBuilder()
  inventory.write_string(
    "SCOPE binary-local-queue-control-proof-inputs-not-proof-or-full-device-gate\n" +
    "CLOCK original-rising-domain-global-toggle-first-joint-reset-later-reset-symbolic\n" +
    "STATE DUT-uninitialized-16-registers-37-bits-independent-public-outstanding-4-bits\n" +
    "BOUNDARY eight-free-nonstate-cuts-8-bits-plus-clock-9-inputs-9-bits\n" +
    "ASSUMPTIONS original-startup-reset-only-no-relation-event-readiness-or-progress-premise\n" +
    "CONCLUSIONS lane-equality-bounds-response-gap-headentry-range-contiguous-ring-public-population-bound-reset-establishment-nonrising-hold\n" +
    "LIMITATION arbitrary-terminal-timing-no-State3-live-entry-no-engine-packet-memory-or-whole-device-claim\n" +
    "MUTATION negative-reserve-comparison-only-6-bit-population-xor-on-genuine-original-PRE-reserve-event-not-post-reservation-transition\n",
  )
  for root in sequential.plan.roots {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      root.node,
    )
    inventory.write_string(
      "REGISTER \{root.name} original \{root.node.ordinal()} local \{mapped.ordinal()} type \{Repr(root.signal_type)} spec \{Repr(root.spec)}\n",
    )
  }
  for cut in sequential.plan.cuts {
    if !sequential.plan.roots.any(root => root.node == cut.node) {
      inventory.write_string(
        "CUT node \{cut.node.ordinal()} type \{Repr(cut.signal_type)} width \{cut.signal_type.width().bits()} roles \{cut.roles.iter().to_array().join(",")}\n",
      )
    }
  }
  for node in sequential.hardware.nodes() {
    if node.kind() is Input(name) {
      inventory.write_string(
        "INPUT \{name} local \{node.id().ordinal()} width \{node.signal_type().width().bits()} emitted \{port_identifier(emitted, InputPort, name)}\n",
      )
    }
  }
  for output in sequential.hardware.outputs() {
    inventory.write_string(
      "OUTPUT \{output.name()} local \{output.driver().ordinal()} width \{output.signal_type().width().bits()} emitted \{port_identifier(emitted, OutputPort, output.name())}\n",
    )
  }
  for
    label in [
      "lc_queue_structure", "lc_queue_population", "lc_queue_public_count_bounds",
      "lc_queue_reset_zero", "lc_queue_established", "lc_queue_nonrising_hold",
    ] {
    inventory.write_string("ASSERTION \{label}\n")
  }
  inventory.write_string("ASSUMPTION lc_initial_joint_reset\n")
  for artifact in artifacts {
    inventory.write_string(
      "SOURCE \{artifact.path} sha256 \{sha256_hex(artifact.content)}\n",
    )
  }
  inventory.write_string(
    "INVARIANT sha256 \{sha256_hex(queue_control_invariant_source())}\n",
  )
  inventory.write_string(
    "PRODUCTION sha256 \{sha256_hex(@ir_codec.serialize(@ir.Design::single("QueuedConcurrentQueueConservationPilot", fixture.hardware())))}\n",
  )
  artifacts.push({ path: "bridge-inputs.txt", content: inventory.to_string(), })
  ReadOnlyArray::from_array(artifacts)
}
