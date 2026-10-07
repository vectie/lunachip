///|
// Bind only accepted original roots/events and the frozen foreign leaves.
// All foreign data remains anyseq; this source adds no relation/readiness
// premise and does not replace any production controller equation.
fn queue_owner_proof_bindings(
  fixture : @flux_tile.QueueConservationFixture,
  sequential : QueueOwnerSequential,
  emitted : @rtl.EmittedDesign,
) -> String raise {
  let plan = sequential.plan
  let probe = plan.probe
  if probe.roots.length() != 30 ||
    probe.events.length() != 59 ||
    probe.roots
    .iter()
    .fold(init=0, (bits, root) => bits + root.signal_type.width().bits()) !=
    304 ||
    plan.cuts.length() != 82 ||
    sha256_hex(
      @ir_codec.serialize(
        @ir.Design::single(
          "QueuedConcurrentQueueConservationPilot",
          fixture.hardware(),
        ),
      ),
    ) !=
    probe.production_digest {
    raise InvalidFormalBundleIdentity(
      "queue owner proof: source/state inventory",
    )
  }
  let clock = dependency_generation_mapped(
    sequential.original_to_local,
    probe.clock,
  )
  guard sequential.hardware.node(clock) is Some(node) &&
    node.signal_type() is Clock &&
    node.kind() is Input("clock") else {
    raise InvalidFormalBundleIdentity(
      "queue owner proof: original clock binding",
    )
  }
  let out = StringBuilder()
  out.write_string(
    "`default_nettype none\nmodule lc_queue_owner_bridge;\n" +
    "  logic lc_clock = 1'b0;\n" +
    "  always @($global_clock) lc_clock <= ~lc_clock;\n",
  )
  let connections : Array[String] = [
    "    .\{port_identifier(emitted, InputPort, "clock")}(lc_clock)",
  ]
  for cut in plan.cuts {
    if probe.roots.any(root => root.node == cut.node) {
      raise InvalidFormalBundleIdentity(
        "queue owner proof: essential state cut",
      )
    }
    let name = "cut_n\{cut.node.ordinal()}"
    out.write_string(
      "  (* anyseq *) logic \{toggle_formal_width_range(cut.signal_type.width().bits())}\{name};\n",
    )
    connections.push(
      "    .\{port_identifier(emitted, InputPort, name)}(\{name})",
    )
  }
  let zero : Array[String] = []
  let pair : Array[String] = []
  for root in probe.roots {
    let name = "current_" + root.name
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      root.node,
    )
    guard sequential.hardware.outputs().filter(output => output.name() == name)
      is [output] &&
      output.driver() == mapped &&
      output.signal_type() == root.signal_type else {
      raise InvalidFormalBundleIdentity(
        "queue owner proof: original root output",
      )
    }
    out.write_string(
      "  wire \{toggle_formal_width_range(root.signal_type.width().bits())}lc_o_\{root.name};\n",
    )
    connections.push(
      "    .\{port_identifier(emitted, OutputPort, name)}(lc_o_\{root.name})",
    )
    zero.push("(lc_o_\{root.name} == 0)")
    pair.push("lc_o_" + root.name)
  }
  for event in probe.events {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      event.node,
    )
    guard sequential.hardware
      .outputs()
      .filter(output => output.name() == event.name)
      is [output] &&
      output.driver() == mapped &&
      output.signal_type() == event.signal_type else {
      raise InvalidFormalBundleIdentity(
        "queue owner proof: original event output",
      )
    }
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
  for
    (name, original) in [
      ("reset", probe.reset),
      (
        "descriptor_valid",
        dependency_generation_input(
          fixture.hardware(),
          "descriptor_valid",
          queue_public_port_type("descriptor_valid", 1),
        ),
      ),
      (
        "completion_ready",
        dependency_generation_input(
          fixture.hardware(),
          "completion_ready",
          queue_public_port_type("completion_ready", 1),
        ),
      ),
    ] {
    guard plan.cuts.filter(cut => cut.node == original) is [cut] else {
      raise InvalidFormalBundleIdentity(
        "queue owner proof: public boundary alias",
      )
    }
    out.write_string("  wire lc_\{name} = cut_n\{cut.node.ordinal()};\n")
  }
  out.write_string("  wire lc_all_reset_zero = \{zero.join(" && ")};\n")
  out.write_string("  wire [303:0] lc_current_pair = {\{pair.join(", ")}};\n")
  out.to_string()
}

///|
// PRE samples are nonfeeding observers. The next PRE sees the previous
// simultaneous commit, so a fresh combinational event cannot masquerade as
// the event committed on that edge. Uninitialized samples are flag-guarded.
fn queue_owner_edge_source(probe : QueueOwnerProbe) -> String {
  let out = StringBuilder()
  let samples : Array[String] = []
  for root in probe.roots {
    out.write_string(
      "  logic \{toggle_formal_width_range(root.signal_type.width().bits())}lc_pre_\{root.name};\n",
    )
    samples.push("    lc_pre_\{root.name} <= lc_o_\{root.name};")
  }
  for
    name in [
      "head_pop", "head_capture", "head_reserve", "head_finish", "retirement_fire",
    ] {
    out.write_string("  logic lc_pre_\{name};\n")
    samples.push("    lc_pre_\{name} <= lc_dut_\{name};")
  }
  for engine in 0..<3 {
    for name in ["accept", "terminal"] {
      out.write_string("  logic lc_pre_engine_\{name}_\{engine};\n")
      samples.push(
        "    lc_pre_engine_\{name}_\{engine} <= lc_dut_engine_\{name}_\{engine};",
      )
    }
  }
  for entry in 0..<3 {
    for name in ["allocate", "acknowledge"] {
      out.write_string("  logic lc_pre_entry_\{name}_\{entry};\n")
      samples.push(
        "    lc_pre_entry_\{name}_\{entry} <= lc_dut_entry_\{name}_\{entry};",
      )
    }
    out.write_string("  logic lc_pre_terminal_event_\{entry};\n")
    samples.push(
      "    lc_pre_terminal_event_\{entry} <= lc_terminal_event_\{entry};",
    )
  }
  let updates : Array[String] = [
    "(lc_o_next_ticket == (lc_pre_next_ticket + (lc_pre_head_reserve ? 32'd1 : 32'd0)))",
    "(lc_o_head_ticket == (lc_pre_head_reserve ? lc_pre_next_ticket : lc_pre_head_ticket))",
    "(lc_o_head_entry == (lc_pre_head_reserve ? lc_pre_retirement_write_pointer : lc_pre_head_entry))",
    "(lc_o_retirement_read_pointer == (lc_pre_retirement_fire ? ((lc_pre_retirement_read_pointer == 5'd2) ? 5'd0 : (lc_pre_retirement_read_pointer + 5'd1)) : lc_pre_retirement_read_pointer))",
    "(lc_o_retirement_write_pointer == (lc_pre_head_reserve ? ((lc_pre_retirement_write_pointer == 5'd2) ? 5'd0 : (lc_pre_retirement_write_pointer + 5'd1)) : lc_pre_retirement_write_pointer))",
    "(lc_o_retirement_occupancy == ((lc_pre_head_reserve == lc_pre_retirement_fire) ? lc_pre_retirement_occupancy : (lc_pre_head_reserve ? (lc_pre_retirement_occupancy + 5'd1) : (lc_pre_retirement_occupancy - 5'd1))))",
    "(lc_o_head_state == ((lc_pre_head_state == 2'd0 && lc_pre_head_pop) ? 2'd1 : ((lc_pre_head_state == 2'd1 && lc_pre_head_capture) ? 2'd2 : ((lc_pre_head_state == 2'd2 && lc_pre_head_reserve) ? 2'd3 : ((lc_pre_head_state == 2'd3 && lc_pre_head_finish) ? 2'd0 : lc_pre_head_state)))))",
  ]
  for engine in 0..<3 {
    let width = if engine == 1 { 2 } else { 3 }
    updates.push(
      "(lc_o_engine_ticket_\{engine} == (lc_pre_engine_accept_\{engine} ? lc_pre_head_ticket : lc_pre_engine_ticket_\{engine}))",
    )
    updates.push(
      "(!lc_pre_engine_accept_\{engine} || lc_o_engine_state_\{engine} != \{width}'d0)",
    )
    updates.push(
      "(!lc_pre_engine_terminal_\{engine} || lc_o_engine_state_\{engine} == \{width}'d0)",
    )
    updates.push(
      "(lc_pre_engine_state_\{engine} == \{width}'d0 || lc_pre_engine_terminal_\{engine} || lc_o_engine_state_\{engine} != \{width}'d0)",
    )
  }
  for entry in 0..<3 {
    updates.push(
      "(lc_o_entry_valid_\{entry} == (lc_pre_entry_allocate_\{entry} ? 1'b1 : (lc_pre_entry_acknowledge_\{entry} ? 1'b0 : lc_pre_entry_valid_\{entry})))",
    )
    updates.push(
      "(lc_o_entry_terminal_\{entry} == (lc_pre_entry_allocate_\{entry} ? 1'b0 : (lc_pre_terminal_event_\{entry} ? 1'b1 : lc_pre_entry_terminal_\{entry})))",
    )
    updates.push(
      "(lc_o_entry_ticket_\{entry} == (lc_pre_entry_allocate_\{entry} ? lc_pre_next_ticket : lc_pre_entry_ticket_\{entry}))",
    )
  }
  out.write_string(
    "  wire lc_owner_edge_updates_ok = \{updates.join(" && ")};\n",
  )
  out.write_string(
    "  always @(posedge lc_clock) begin\n\{samples.join("\n")}\n  end\n",
  )
  out.to_string()
}

///|
// Both sources retain all nine assertions. Only one comparison-only checked
// ticket differs; actual ownership masks, collectors, state and histories do
// not consume it. These are proof inputs, never a proof result.
fn queue_owner_proof_source(
  fixture : @flux_tile.QueueConservationFixture,
  sequential : QueueOwnerSequential,
  emitted : @rtl.EmittedDesign,
  negative? : Bool = false,
) -> String raise {
  let out = StringBuilder()
  out.write_string(queue_owner_proof_bindings(fixture, sequential, emitted))
  out.write_string(
    "  logic lc_seen_edge = 1'b0;\n" +
    "  logic lc_previous_rising_reset = 1'b0;\n",
  )
  out.write_string(queue_owner_invariant_source())
  let history =
    #|  wire lc_admit = lc_descriptor_valid && lc_dut_descriptor_ready;
    #|  logic lc_admission_seen = 1'b0;
    #|  logic lc_reservation_seen = 1'b0;
    #|  logic lc_loader_accept_seen = 1'b0;
    #|  always @(posedge lc_clock) begin
    #|    if (lc_reset) begin
    #|      lc_admission_seen <= 1'b0;
    #|      lc_reservation_seen <= 1'b0;
    #|      lc_loader_accept_seen <= 1'b0;
    #|    end else begin
    #|      if (lc_admit) lc_admission_seen <= 1'b1;
    #|      if (lc_dut_head_reserve) lc_reservation_seen <= 1'b1;
    #|      if (lc_dut_engine_accept_0) lc_loader_accept_seen <= 1'b1;
    #|    end
    #|  end
    #|  wire lc_genuine_busy_loader = !lc_reset && lc_seen_edge
    #|    && lc_admission_seen && lc_reservation_seen && lc_loader_accept_seen
    #|    && lc_raw_owner_invariant && lc_busy_0;
    #|
  out.write_string(history)
  let checked = if negative {
    "(lc_o_engine_ticket_0 + (lc_genuine_busy_loader ? 32'd1 : 32'd0))"
  } else {
    "lc_o_engine_ticket_0"
  }
  out.write_string("  wire [31:0] lc_checked_loader_ticket = \{checked};\n")
  let mask : Array[String] = []
  for offset in 0..<3 {
    let entry = 2 - offset
    mask.push(
      "(lc_busy_0 && lc_o_entry_valid_\{entry} && !lc_o_entry_terminal_\{entry} && lc_o_entry_ticket_\{entry} == lc_checked_loader_ticket)",
    )
  }
  out.write_string(
    "  wire [2:0] lc_checked_loader_owner_mask = {\{mask.join(", ")}};\n",
  )
  out.write_string(
    "  wire lc_engine_identity_ok = (!lc_busy_0 || (lc_engine_owned_0 && lc_checked_loader_owner_mask == lc_owner_mask_0)) && lc_engine_owned_1 && lc_engine_owned_2;\n",
  )
  out.write_string(queue_owner_edge_source(sequential.plan.probe))
  let assertions =
    #|  always @(posedge lc_clock) begin
    #|    lc_seen_edge <= 1'b1;
    #|    lc_previous_rising_reset <= lc_reset;
    #|    lc_initial_joint_reset: assume ((lc_seen_edge || lc_reset) === 1'b1);
    #|    lc_owner_structure: assert ((lc_reset || lc_owner_structure_ok) === 1'b1);
    #|    lc_owner_ticket_order: assert ((lc_reset || lc_owner_ticket_order_ok) === 1'b1);
    #|    lc_owner_bijection: assert ((lc_reset || lc_owner_bijection_ok) === 1'b1);
    #|    lc_owner_engine_identity: assert ((lc_reset || lc_engine_identity_ok) === 1'b1);
    #|    lc_owner_events: assert ((lc_owner_events_ok) === 1'b1);
    #|    lc_owner_edge_updates: assert ((!lc_seen_edge || lc_previous_rising_reset || lc_owner_edge_updates_ok) === 1'b1);
    #|    lc_owner_reset_zero: assert ((!lc_previous_rising_reset || lc_all_reset_zero) === 1'b1);
    #|  end
    #|  // Raw establishment is not bypassed by PRE later reset. Only the
    #|  // first uninitialized observation is ignored; no invariant is assumed.
    #|  logic lc_seen_global = 1'b0;
    #|  logic lc_previous_clock = 1'b0;
    #|  logic [303:0] lc_previous_pair;
    #|  always @($global_clock) begin
    #|    lc_seen_global <= 1'b1;
    #|    lc_previous_clock <= lc_clock;
    #|    lc_previous_pair <= lc_current_pair;
    #|    lc_owner_established: assert ((!lc_seen_edge || lc_raw_owner_invariant) === 1'b1);
    #|    lc_owner_nonrising_hold: assert ((!lc_seen_global
    #|      || (!lc_previous_clock && lc_clock)
    #|      || lc_current_pair == lc_previous_pair) === 1'b1);
    #|  end
    #|endmodule
    #|`default_nettype wire
    #|
  out.write_string(assertions)
  out.to_string()
}
