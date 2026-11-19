///|
// Global-clock bridge over the unchanged extracted transition system. Only
// first sampled joint reset is assumed; all eight boundaries stay symbolic.
fn queue_control_proof_source(
  sequential : QueueControlSequential,
  emitted : @rtl.EmittedDesign,
  negative~ : Bool = false,
) -> String raise {
  let plan = sequential.plan
  let out = StringBuilder()
  out.write_string(
    "`default_nettype none\nmodule lc_queue_control_bridge;\n  logic lc_clock = 1'b0;\n  always @($global_clock) lc_clock <= ~lc_clock;\n",
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
  let zero : Array[String] = ["(lc_g_public_outstanding == 0)"]
  let pair : Array[String] = ["lc_g_public_outstanding"]
  for root in plan.roots {
    out.write_string(
      "  wire \{toggle_formal_width_range(root.signal_type.width().bits())}lc_o_\{root.name};\n",
    )
    connections.push(
      "    .\{port_identifier(emitted, OutputPort, "current_" + root.name)}(lc_o_\{root.name})",
    )
    zero.push("(lc_o_\{root.name} == 0)")
    pair.push("lc_o_\{root.name}")
  }
  for event in plan.events {
    out.write_string(
      "  wire \{toggle_formal_width_range(event.signal_type.width().bits())}lc_dut_\{event.name};\n",
    )
    connections.push(
      "    .\{port_identifier(emitted, OutputPort, event.name)}(lc_dut_\{event.name})",
    )
  }
  out.write_string(
    "  \{top_emitted_module(emitted).identifier()} lc_dut(\n\{connections.join(",\n")}\n  );\n",
  )
  for role in ["reset", "descriptor_valid"] {
    guard plan.cuts.filter(cut => cut.roles.contains(role)) is [cut] &&
      !plan.roots.any(root => root.node == cut.node) else {
      raise InvalidFormalBundleIdentity("queue control proof: public boundary")
    }
    out.write_string("  wire lc_\{role} = cut_n\{cut.node.ordinal()};\n")
  }
  let public_history =
    #|  wire lc_admit = lc_descriptor_valid && lc_dut_descriptor_ready;
    #|  wire lc_retire = lc_dut_retirement_fire;
    #|  // Independent public history, never repaired from internal population.
    #|  // Illegal updates hold instead of wrapping, and are asserted separately.
    #|  logic [3:0] lc_g_public_outstanding;
    #|  wire lc_public_count_step_ok = (!lc_retire || lc_g_public_outstanding != 4'd0)
    #|    && (!lc_admit || lc_retire || lc_g_public_outstanding < 4'd7);
    #|  always @(posedge lc_clock) begin
    #|    if (lc_reset) lc_g_public_outstanding <= 4'd0;
    #|    else if (lc_admit && !lc_retire && lc_g_public_outstanding < 4'd7)
    #|      lc_g_public_outstanding <= lc_g_public_outstanding + 4'd1;
    #|    else if (lc_retire && !lc_admit && lc_g_public_outstanding != 4'd0)
    #|      lc_g_public_outstanding <= lc_g_public_outstanding - 4'd1;
    #|  end
    #|
  out.write_string(public_history)
  out.write_string(queue_control_invariant_source())
  out.write_string(
    "  wire lc_genuine_reserve = !lc_reset && lc_dut_head_reserve && lc_raw_invariant_ok;\n",
  )
  let checked = if negative {
    "(lc_raw_population ^ (lc_genuine_reserve ? 6'd1 : 6'd0))"
  } else {
    "lc_raw_population"
  }
  out.write_string("  wire [5:0] lc_checked_population = \{checked};\n")
  out.write_string("  wire lc_all_reset_zero = \{zero.join(" && ")};\n")
  out.write_string("  wire [40:0] lc_current_pair = {\{pair.join(", ")}};\n")
  let assertions =
    #|  logic lc_seen_edge = 1'b0;
    #|  logic lc_previous_rising_reset = 1'b0;
    #|  always @(posedge lc_clock) begin
    #|    lc_seen_edge <= 1'b1;
    #|    lc_previous_rising_reset <= lc_reset;
    #|    lc_initial_joint_reset: assume ((lc_seen_edge || lc_reset) === 1'b1);
    #|    lc_queue_structure: assert ((lc_reset || lc_raw_structure_ok) === 1'b1);
    #|    lc_queue_population: assert ((lc_reset
    #|      || lc_checked_population == {2'd0, lc_g_public_outstanding}) === 1'b1);
    #|    lc_queue_public_count_bounds: assert ((lc_reset
    #|      || (lc_g_public_outstanding <= 4'd7 && lc_public_count_step_ok)) === 1'b1);
    #|    lc_queue_reset_zero: assert ((!lc_previous_rising_reset || lc_all_reset_zero) === 1'b1);
    #|  end
    #|  // Establishment is a conclusion after reset, never an induction premise
    #|  // assumed by this source. Previous uninitialized state is flag-guarded.
    #|  logic lc_seen_global = 1'b0;
    #|  logic lc_previous_clock = 1'b0;
    #|  logic [40:0] lc_previous_pair;
    #|  always @($global_clock) begin
    #|    lc_seen_global <= 1'b1;
    #|    lc_previous_clock <= lc_clock;
    #|    lc_previous_pair <= lc_current_pair;
    #|    lc_queue_established: assert ((!lc_seen_edge || lc_raw_invariant_ok) === 1'b1);
    #|    lc_queue_nonrising_hold: assert ((!lc_seen_global
    #|      || (!lc_previous_clock && lc_clock)
    #|      || lc_current_pair == lc_previous_pair) === 1'b1);
    #|  end
    #|endmodule
    #|`default_nettype wire
    #|
  out.write_string(assertions)
  out.to_string()
}
