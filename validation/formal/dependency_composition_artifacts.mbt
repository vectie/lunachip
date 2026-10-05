///|
/// Export exact local generation/compute proof inputs, not a proof receipt or
/// an ordinary dependency task. The production slice retains actual registers
/// with arbitrary initial state; its bridge uses the unchanged independent
/// references and original startup-reset sampling. Conflict, preflight, queue
/// and load/core boundaries remain free binary inputs, not proved subsystems.
///
/// ```mbt check
/// test {
///   let inputs = @formal.generate_dependency_compute_generation_artifacts()
///   assert_eq(inputs.map(artifact => artifact.path()), [
///     "sequential.lcir", "sequential-production.sv", "sequential-boolean.sv", "bridge.sv",
///     "negative-inner.sv", "bridge-inputs.txt",
///   ])
///   // Generation returns proof inputs without running an engine.
///   assert_true(
///     inputs.any(artifact => {
///       artifact.path() == "bridge-inputs.txt" &&
///       artifact.content().contains("not-proof-or-full-device-gate")
///     }),
///   )
/// }
/// ```
pub fn generate_dependency_compute_generation_artifacts() -> ReadOnlyArray[
  FormalBundleArtifact,
] raise {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let sequential = dependency_composition_sequential(fixture)
  let design = @ir.Design::single(
    "DependencyCompositionSequential",
    sequential.hardware,
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
      content: dependency_composition_bridge_source(sequential, emitted),
    },
    {
      path: "negative-inner.sv",
      content: dependency_composition_bridge_source(
        sequential,
        emitted,
        negative=true,
      ),
    },
  ]
  let inventory = StringBuilder()
  inventory.write_string(
    "SCOPE binary-local-generation-compute-proof-inputs-not-proof-or-full-device-gate\n",
  )
  inventory.write_string(
    "CLOCK original-rising-domain-global-toggle-first-joint-reset-later-reset-symbolic\n",
  )
  inventory.write_string(
    "STATE DUT-uninitialized-27-registers-416-bits-reference-live-generation-and-compute-444-bits-original-initialization-history-retained-nonfeeding\n",
  )
  inventory.write_string(
    "BOUNDARY eighteen-free-nonstate-cuts-340-bits-plus-clock-19-inputs-341-bits\n",
  )
  inventory.write_string(
    "ASSUMPTIONS original-startup-reset-only-no-relation-authorization-or-event-premise\n",
  )
  inventory.write_string(
    "MUTATION negative-inner-comparison-only-reduction-xor-on-actual-inner-handshake\n",
  )
  for root in sequential.plan.roots {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      root.node,
    )
    inventory.write_string(
      "REGISTER \{root.name} original \{root.node.ordinal()} local \{mapped.ordinal()} width \{root.signal_type.width().bits()} spec \{Repr(root.spec)}\n",
    )
  }
  for cut in sequential.plan.cuts {
    if !sequential.plan.roots.any(root => root.node == cut.node) {
      inventory.write_string(
        "CUT node \{cut.node.ordinal()} width \{cut.signal_type.width().bits()} roles \{cut.roles.iter().to_array().join(",")}\n",
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
  for binding in sequential.plan.generation.decoder_bindings {
    inventory.write_string(
      "DECODER \{binding.name} original \{binding.node.ordinal()} width \{binding.signal_type.width().bits()} type \{Repr(binding.signal_type)}\n",
    )
  }
  for artifact in artifacts {
    inventory.write_string(
      "SOURCE \{artifact.path} sha256 \{sha256_hex(artifact.content)}\n",
    )
  }
  inventory.write_string(
    "REFERENCE decoder sha256 \{sha256_hex(dependency_decode_source())}\n",
  )
  inventory.write_string(
    "REFERENCE generation-compute sha256 \{sha256_hex(dependency_generation_compute_reference_source())}\n",
  )
  inventory.write_string(
    "REFERENCE full-ghost sha256 \{sha256_hex(dependency_ghost_source())}\n",
  )
  inventory.write_string(
    "PRODUCTION sha256 \{sha256_hex(@ir_codec.serialize(@ir.Design::single("QueuedConcurrentDependencyPilot", fixture.hardware())))}\n",
  )
  artifacts.push({ path: "bridge-inputs.txt", content: inventory.to_string(), })
  ReadOnlyArray::from_array(artifacts)
}
