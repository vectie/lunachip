///|
// Fixed sequential composition input. The DUT retains actual copied register
// specifications; only agreed non-state observations are free boundary inputs.
fn dependency_generation_bridge_source(
  sequential : DependencyGenerationSequential,
  emitted : @rtl.EmittedDesign,
) -> String raise {
  let plan = sequential.plan
  let out = StringBuilder()
  out.write_string(
    "`default_nettype none\nmodule lc_generation_bridge;\n" +
    "  logic lc_clock = 1'b0;\n" +
    "  always @($global_clock) lc_clock <= ~lc_clock;\n",
  )
  let connections : Array[String] = [
    "    .\{port_identifier(emitted, InputPort, "clock")}(lc_clock)",
  ]
  for cut in plan.cuts {
    if plan.roots.any(root => root.binding.node == cut.node) {
      continue
    }
    let name = "cut_n\{cut.node.ordinal()}"
    out.write_string(
      "  (* anyseq *) logic \{toggle_formal_width_range(cut.signal_type.width().bits())}\{name};\n",
    )
    connections.push(
      "    .\{port_identifier(emitted, InputPort, name)}(\{name})",
    )
  }
  let relation : Array[String] = []
  let zero : Array[String] = []
  let pair : Array[String] = []
  for root in plan.roots {
    let role = dependency_role_name(root.binding.role)
    let width = root.binding.signal_type.width().bits()
    out.write_string(
      "  wire \{toggle_formal_width_range(width)}lc_o_\{role};\n",
    )
    connections.push(
      "    .\{port_identifier(emitted, OutputPort, "current_" + role)}(lc_o_\{role})",
    )
    let reference = dependency_generation_reference_field(
      root.binding.role,
      post=false,
    )
    relation.push("(lc_o_\{role} == \{reference})")
    zero.push("(lc_o_\{role} == 0 && \{reference} == 0)")
    pair.push("lc_o_\{role}")
    pair.push(reference)
  }
  for output in sequential.hardware.outputs() {
    if output.name().has_prefix("current_") {
      continue
    }
    let name = "lc_dut_" + output.name()
    out.write_string(
      "  wire \{toggle_formal_width_range(output.signal_type().width().bits())}\{name};\n",
    )
    connections.push(
      "    .\{port_identifier(emitted, OutputPort, output.name())}(\{name})",
    )
  }
  out.write_string(
    "  \{top_emitted_module(emitted).identifier()} lc_dut(\n\{connections.join(",\n")}\n  );\n",
  )
  out.write_string("  wire lc_reset = cut_n\{plan.reset.ordinal()};\n")
  // This is the same public halted input used by the sequential full ghost.
  // Under reset it need not equal raw poison; both reset updates dominate it.
  out.write_string("  wire lc_halted = lc_dut_public_halted;\n")
  for role in dependency_generation_boundary_roles() {
    let name = dependency_role_name(role)
    guard plan.cuts.filter(cut => cut.roles.contains(name)) is [cut] else {
      raise InvalidFormalBundleIdentity("generation bridge: missing boundary")
    }
    out.write_string(
      "  wire \{toggle_formal_width_range(cut.signal_type.width().bits())}lc_o_\{name} = cut_n\{cut.node.ordinal()};\n",
    )
  }
  out.write_string(
    "  wire lc_o_inner_command_valid = 1'b0;\n  wire lc_o_inner_command_ready = 1'b0;\n",
  )
  out.write_string(dependency_decode_source())
  out.write_string(dependency_generation_reference_source())
  out.write_string("  wire lc_all_fields_equal = \{relation.join(" && ")};\n")
  out.write_string("  wire lc_all_reset_zero = \{zero.join(" && ")};\n")
  out.write_string("  wire [671:0] lc_current_pair = {\{pair.join(", ")}};\n")
  let properties =
    #|  logic lc_seen_edge = 1'b0;
    #|  logic lc_previous_rising_reset = 1'b0;
    #|  wire lc_generation_matches = lc_reset || lc_all_fields_equal;
    #|  always @(posedge lc_clock) begin
    #|    lc_seen_edge <= 1'b1;
    #|    lc_previous_rising_reset <= lc_reset;
    #|    lc_initial_joint_reset: assume ((lc_seen_edge || lc_reset) === 1'b1);
    #|    lc_generation_relation: assert ((lc_generation_matches) === 1'b1);
    #|    lc_generation_reset_zero: assert ((!lc_previous_rising_reset || lc_all_reset_zero) === 1'b1);
    #|  end
    #|  // Previous data is deliberately uninitialized. Its first comparison
    #|  // is disabled by the initialized observation flag, not state equality.
    #|  logic lc_seen_global = 1'b0;
    #|  logic lc_previous_clock = 1'b0;
    #|  logic [671:0] lc_previous_pair;
    #|  always @($global_clock) begin
    #|    lc_seen_global <= 1'b1;
    #|    lc_previous_clock <= lc_clock;
    #|    lc_previous_pair <= lc_current_pair;
    #|    // An asserted strengthening, not a relation assumption. Once the first
    #|    // reset edge has committed, equality must hold at every global phase.
    #|    lc_generation_established: assert ((!lc_seen_edge || lc_all_fields_equal) === 1'b1);
    #|    lc_generation_nonrising_hold: assert ((!lc_seen_global
    #|      || (!lc_previous_clock && lc_clock)
    #|      || lc_current_pair == lc_previous_pair) === 1'b1);
    #|  end
    #|endmodule
    #|`default_nettype wire
    #|
  out.write_string(properties)
  out.to_string()
}

///|
fn dependency_generation_bridge_artifacts(
  fixture : @flux_tile.QueuedConcurrentFormalFixture,
  transfer : DependencyGenerationTransfer,
) -> Array[FormalBundleArtifact] raise {
  let sequential = dependency_generation_sequential(fixture)
  if sequential.plan != transfer.plan {
    raise InvalidFormalBundleIdentity("generation bridge: source-plan drift")
  }
  let design = @ir.Design::single(
    "DependencyGenerationSequential",
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
      content: dependency_generation_bridge_source(sequential, emitted),
    },
  ]
  let inventory = StringBuilder()
  inventory.write_string(
    "SCOPE exact-register-sequential-generation-bridge-inputs-only-no-receipt\n",
  )
  inventory.write_string(
    "CLOCK original-rising-domain-global-toggle-first-joint-reset-later-reset-symbolic\n",
  )
  inventory.write_string(
    "STATE DUT-uninitialized-336-bits-reference-original-initialization-no-equality-assumption\n",
  )
  inventory.write_string(
    "BOUNDARY fourteen-free-nonstate-cuts-335-bits-plus-clock-no-event-assumptions\n",
  )
  for root in sequential.plan.roots {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      root.binding.node,
    )
    inventory.write_string(
      "REGISTER \{dependency_role_name(root.binding.role)} original \{root.binding.node.ordinal()} local \{mapped.ordinal()} width \{root.binding.signal_type.width().bits()} spec \{Repr(root.spec)}\n",
    )
  }
  for cut in sequential.plan.cuts {
    if !sequential.plan.roots.any(root => root.binding.node == cut.node) {
      inventory.write_string(
        "CUT node \{cut.node.ordinal()} width \{cut.signal_type.width().bits()} roles \{cut.roles.iter().to_array().join(",")}\n",
      )
    }
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
    "REFERENCE sequential-prefix sha256 \{sha256_hex(dependency_generation_reference_source())}\n",
  )
  inventory.write_string(
    "PRODUCTION sha256 \{sha256_hex(@ir_codec.serialize(@ir.Design::single("QueuedConcurrentDependencyPilot", fixture.hardware())))}\n",
  )
  artifacts.push({ path: "bridge-inputs.txt", content: inventory.to_string(), })
  artifacts
}
