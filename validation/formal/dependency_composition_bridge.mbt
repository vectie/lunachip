///|
// Fixed local binary clock/reset relation over exact copied production state.
// Boundary cuts stay free; this source does not assume legality, equality,
// readiness or ownership, and is proof input rather than a proof receipt.
fn dependency_composition_bridge_source(
  sequential : DependencyCompositionSequential,
  emitted : @rtl.EmittedDesign,
  negative~ : Bool = false,
) -> String raise {
  let plan = sequential.plan
  let out = StringBuilder()
  out.write_string(
    "`default_nettype none\nmodule lc_composition_bridge;\n" +
    "  logic lc_clock = 1'b0;\n" +
    "  always @($global_clock) lc_clock <= ~lc_clock;\n",
  )
  let connections : Array[String] = [
    "    .\{port_identifier(emitted, InputPort, "clock")}(lc_clock)",
  ]
  for cut in plan.cuts {
    if plan.roots.any(root => root.node == cut.node) {
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
    let width = root.signal_type.width().bits()
    out.write_string(
      "  wire \{toggle_formal_width_range(width)}lc_o_\{root.name};\n",
    )
    connections.push(
      "    .\{port_identifier(emitted, OutputPort, "current_" + root.name)}(lc_o_\{root.name})",
    )
    zero.push("(lc_o_\{root.name} == 0)")
    pair.push("lc_o_\{root.name}")
  }
  for root in plan.generation.roots {
    let role = dependency_role_name(root.binding.role)
    let width = root.binding.signal_type.width().bits()
    // Keep original reference aliases while exposing unambiguous joint roots.
    out.write_string(
      "  wire \{toggle_formal_width_range(width)}lc_o_\{role} = lc_o_generation_\{role};\n",
    )
    let reference = dependency_generation_reference_field(
      root.binding.role,
      post=false,
    )
    relation.push("(lc_o_generation_\{role} == \{reference})")
    zero.push("(\{reference} == 0)")
    pair.push(reference)
  }
  // Existing owner and saved-authorization fields: 108 bits, no modeled FSM.
  for
    field in [
      "lc_g_compute_owned", "lc_g_compute_ticket", "lc_g_authorized", "lc_g_authorized_ticket",
      "lc_g_authorized_a", "lc_g_authorized_b", "lc_g_authorized_c", "lc_g_authorized_rows",
      "lc_g_authorized_columns", "lc_g_authorized_reduction",
    ] {
    zero.push("(\{field} == 0)")
    pair.push(field)
  }
  relation.push("(lc_o_compute_ticket == lc_g_compute_ticket)")
  relation.push("(lc_o_compute_ticket == lc_g_authorized_ticket)")
  for field in ["a", "b", "c", "rows", "columns", "reduction"] {
    relation.push("(lc_o_compute_\{field} == lc_g_authorized_\{field})")
  }
  relation.push("(lc_g_compute_owned == (lc_o_compute_state != 2'd0))")
  relation.push("(lc_g_authorized == (lc_o_compute_state == 2'd1))")
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
  // Match the existing sequential reference's public reset-gated alias.
  // Both actual and independent reset updates dominate arbitrary raw poison.
  out.write_string("  wire lc_halted = lc_dut_public_halted;\n")
  for
    role in [
      "head_lane_0", "head_lane_1", "head_lane_2", "head_lane_3", "head_state", "head_reserve",
      "load_terminal", "load_terminal_ticket", "load_terminal_fault",
    ] {
    guard plan.cuts.filter(cut => cut.roles.contains(role)) is [cut] &&
      !plan.roots.any(root => root.node == cut.node) else {
      raise InvalidFormalBundleIdentity("composition bridge: missing boundary")
    }
    out.write_string(
      "  wire \{toggle_formal_width_range(cut.signal_type.width().bits())}lc_o_\{role} = cut_n\{cut.node.ordinal()};\n",
    )
  }
  let aliases =
    #|  // Acceptance, Issue and Done are actual retained-cone observations.
    #|  wire lc_o_compute_accept = lc_dut_accept;
    #|  wire [3:0] lc_o_compute_preflight = lc_dut_preflight;
    #|  wire lc_o_inner_command_valid = lc_dut_inner_valid;
    #|  wire lc_o_inner_command_ready = lc_dut_inner_ready;
    #|  wire lc_o_compute_terminal = lc_dut_terminal;
    #|  wire [31:0] lc_o_compute_terminal_ticket = lc_o_compute_ticket;
    #|  wire [3:0] lc_o_compute_terminal_fault = lc_o_compute_fault;
    #|  wire [31:0] lc_o_compute_latched_ticket = lc_o_compute_ticket;
    #|  wire lc_o_compute_latched_a = lc_o_compute_a;
    #|  wire lc_o_compute_latched_b = lc_o_compute_b;
    #|  wire lc_o_compute_latched_c = lc_o_compute_c;
    #|  wire [12:0] lc_o_compute_latched_rows = lc_o_compute_rows;
    #|  wire [12:0] lc_o_compute_latched_columns = lc_o_compute_columns;
    #|  wire [12:0] lc_o_compute_latched_reduction = lc_o_compute_reduction;
    #|
  out.write_string(aliases)
  out.write_string(dependency_decode_source())
  out.write_string(dependency_generation_compute_reference_source())
  out.write_string("  wire lc_all_fields_equal = \{relation.join(" && ")};\n")
  out.write_string("  wire lc_all_reset_zero = \{zero.join(" && ")};\n")
  // All 416 DUT state bits plus all 444 functional reference state bits.
  // Nonfeeding generation cover history is not a relation-state component.
  out.write_string("  wire [859:0] lc_current_pair = {\{pair.join(", ")}};\n")
  let checked_reduction = if negative {
    "(lc_o_compute_latched_reduction ^ (lc_inner_accept ? 13'd1 : 13'd0))"
  } else {
    "lc_o_compute_latched_reduction"
  }
  out.write_string(
    "  wire [12:0] lc_checked_inner_reduction = \{checked_reduction};\n",
  )
  let predicates =
    #|  wire lc_inner_identity_matches = lc_o_compute_latched_ticket == lc_g_authorized_ticket
    #|    && lc_o_compute_latched_a == lc_g_authorized_a
    #|    && lc_o_compute_latched_b == lc_g_authorized_b
    #|    && lc_o_compute_latched_c == lc_g_authorized_c
    #|    && lc_o_compute_latched_rows == lc_g_authorized_rows
    #|    && lc_o_compute_latched_columns == lc_g_authorized_columns
    #|    && lc_checked_inner_reduction == lc_g_authorized_reduction;
    #|  // Original saved-authorization component: current latest writers may
    #|  // legitimately change after acceptance during the registered Issue gap.
    #|  wire lc_inner_saved_authorization_holds = lc_reset || !lc_o_inner_command_valid
    #|    || (lc_g_authorized && lc_inner_identity_matches);
    #|  // Only the original compute ownership component is in this local slice.
    #|  wire lc_compute_terminal_owner_holds = lc_reset || !lc_o_compute_terminal
    #|    || (lc_g_compute_owned && lc_o_compute_terminal_ticket == lc_g_compute_ticket);
    #|  logic lc_seen_edge = 1'b0;
    #|  logic lc_previous_rising_reset = 1'b0;
    #|  wire lc_composition_matches = lc_reset || lc_all_fields_equal;
    #|  always @(posedge lc_clock) begin
    #|    lc_seen_edge <= 1'b1;
    #|    lc_previous_rising_reset <= lc_reset;
    #|    lc_initial_joint_reset: assume ((lc_seen_edge || lc_reset) === 1'b1);
    #|    lc_composition_relation: assert ((lc_composition_matches) === 1'b1);
    #|    lc_composition_reset_zero: assert ((!lc_previous_rising_reset || lc_all_reset_zero) === 1'b1);
    #|    lc_inner_compute_preserves_saved_authorization: assert ((lc_inner_saved_authorization_holds) === 1'b1);
    #|    lc_compute_terminal_ticket_matches_accepted_owner: assert ((lc_compute_terminal_owner_holds) === 1'b1);
    #|  end
    #|  // Uninitialized previous data is ignored until the observation flag.
    #|  logic lc_seen_global = 1'b0;
    #|  logic lc_previous_clock = 1'b0;
    #|  logic [859:0] lc_previous_pair;
    #|  always @($global_clock) begin
    #|    lc_seen_global <= 1'b1;
    #|    lc_previous_clock <= lc_clock;
    #|    lc_previous_pair <= lc_current_pair;
    #|    // Assert establishment after first reset; never assume the relation.
    #|    lc_composition_established: assert ((!lc_seen_edge || lc_all_fields_equal) === 1'b1);
    #|    lc_composition_nonrising_hold: assert ((!lc_seen_global
    #|      || (!lc_previous_clock && lc_clock)
    #|      || lc_current_pair == lc_previous_pair) === 1'b1);
    #|  end
    #|endmodule
    #|`default_nettype wire
    #|
  out.write_string(predicates)
  out.to_string()
}
