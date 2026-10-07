///|
// Nonfeeding PRE observers over the actual emitted original-storage module.
// A public admission, not an ID/ticket/packet predicate, selects one watch.
fn queue_storage_prefix_observer(
  sequential : QueueStorageSequential,
  emitted : @rtl.EmittedDesign,
  negative : Bool,
) -> String raise FormalGateError {
  let probe = sequential.probe
  let out = StringBuilder()
  let actual_pair : Array[String] = []
  let zero : Array[String] = []
  for root in probe.roots {
    let port = port_identifier(emitted, OutputPort, "current_" + root.name)
    out.write_string(
      "  wire \{toggle_formal_width_range(root.signal_type.width().bits())}lc_o_\{root.name};\n  assign lc_o_\{root.name} = \{port};\n",
    )
    actual_pair.push("lc_o_" + root.name)
    zero.push("(lc_o_\{root.name} == 0)")
  }
  for event in probe.events {
    let port = port_identifier(emitted, OutputPort, event.name)
    out.write_string(
      "  wire \{toggle_formal_width_range(event.signal_type.width().bits())}lc_dut_\{event.name};\n  assign lc_dut_\{event.name} = \{port};\n",
    )
  }
  for cut in sequential.cuts {
    guard cut.roles is [role] else {
      raise InvalidFormalBundleIdentity("queue storage prefix: shared cut role")
    }
    if role == "reset" ||
      role == "descriptor_valid" ||
      role.has_prefix("descriptor_lane_") {
      let port = port_identifier(
        emitted,
        InputPort,
        "cut_n\{cut.node.ordinal()}",
      )
      out.write_string(
        "  wire \{toggle_formal_width_range(cut.signal_type.width().bits())}lc_\{role};\n  assign lc_\{role} = \{port};\n",
      )
    }
  }
  let memories = queue_storage_prefix_memory_identifiers(sequential, emitted)
  for lane in 0..<4 {
    let response = port_identifier(
      emitted,
      OutputPort,
      "fifo_response_data_\{lane}",
    )
    out.write_string(
      "  wire [63:0] lc_response_\{lane};\n  assign lc_response_\{lane} = \{response};\n",
    )
    actual_pair.push("lc_response_\{lane}")
    for slot in 0..<3 {
      out.write_string(
        "  wire [63:0] lc_cell_\{lane}_\{slot};\n  assign lc_cell_\{lane}_\{slot} = \{memories[lane]}[\{slot}];\n",
      )
      actual_pair.push("lc_cell_\{lane}_\{slot}")
    }
    // Variable indexing is a real observer read of the retained array, never
    // anyseq data, a substitute ghost SRAM, or declaration initialization.
    out.write_string(
      "  wire [63:0] lc_watched_cell_\{lane};\n  assign lc_watched_cell_\{lane} = \{memories[lane]}[lc_watch_slot];\n",
    )
  }
  let base =
    #|  (* anyseq *) logic lc_watch_select;
    #|  logic lc_seen_edge = 1'b0;
    #|  logic lc_previous_rising_reset = 1'b0;
    #|  logic [2:0] lc_public_count;
    #|  logic lc_watch_chosen, lc_watch_queued, lc_response_due;
    #|  logic lc_head_due, lc_head_held, lc_response_seen, lc_capture_seen;
    #|  logic [2:0] lc_watch_rank;
    #|  logic [1:0] lc_watch_slot;
    #|  logic [255:0] lc_saved_packet;
    #|  wire [255:0] lc_public_packet = {lc_descriptor_lane_3,
    #|    lc_descriptor_lane_2, lc_descriptor_lane_1, lc_descriptor_lane_0};
    #|  wire [255:0] lc_raw_response = {lc_response_3, lc_response_2,
    #|    lc_response_1, lc_response_0};
    #|  wire [255:0] lc_raw_head = {lc_o_head_lane_3, lc_o_head_lane_2,
    #|    lc_o_head_lane_1, lc_o_head_lane_0};
    #|  wire lc_admit = lc_descriptor_valid && lc_dut_descriptor_ready;
    #|  wire lc_pop = lc_dut_head_pop;
    #|  wire lc_effective_finish = lc_o_head_state == 2'd3 && lc_dut_head_finish;
    #|  wire lc_take_watch = !lc_reset && lc_admit && !lc_watch_chosen && lc_watch_select;
    #|  // PRE queued flag excludes a newly admitted packet from this edge's pop.
    #|  wire lc_watched_pop = !lc_reset && lc_watch_queued && lc_pop && lc_watch_rank == 0;
    #|  wire lc_count_step_ok = (!lc_pop || lc_public_count != 0)
    #|    && (!lc_admit || lc_pop || lc_public_count < 3'd3);
    #|  function automatic [1:0] lc_wrap3(input [2:0] value);
    #|    case (value)
    #|      3'd3: lc_wrap3 = 2'd0;
    #|      3'd4: lc_wrap3 = 2'd1;
    #|      3'd5: lc_wrap3 = 2'd2;
    #|      default: lc_wrap3 = value[1:0];
    #|    endcase
    #|  endfunction
    #|  always @(posedge lc_clock) begin
    #|    lc_seen_edge <= 1'b1;
    #|    lc_previous_rising_reset <= lc_reset;
    #|    if (lc_reset) begin
    #|      lc_public_count <= 3'd0;
    #|      lc_watch_chosen <= 1'b0;
    #|      lc_watch_queued <= 1'b0;
    #|      lc_response_due <= 1'b0;
    #|      lc_head_due <= 1'b0;
    #|      lc_head_held <= 1'b0;
    #|      lc_response_seen <= 1'b0;
    #|      lc_capture_seen <= 1'b0;
    #|      lc_watch_rank <= 3'd0;
    #|      lc_watch_slot <= 2'd0;
    #|      // Saved packet and real SRAM/read states are NOT reset or initialized.
    #|    end else begin
    #|      if (lc_admit && !lc_pop && lc_public_count < 3'd3)
    #|        lc_public_count <= lc_public_count + 3'd1;
    #|      else if (lc_pop && !lc_admit && lc_public_count != 0)
    #|        lc_public_count <= lc_public_count - 3'd1;
    #|      lc_response_due <= lc_watched_pop;
    #|      lc_head_due <= lc_response_due && lc_dut_head_capture;
    #|      if (lc_take_watch) begin
    #|        lc_watch_chosen <= 1'b1;
    #|        lc_watch_queued <= 1'b1;
    #|        lc_saved_packet <= lc_public_packet;
    #|        lc_watch_slot <= lc_o_fifo_write_pointer_0;
    #|        lc_watch_rank <= lc_public_count - (lc_pop ? 3'd1 : 3'd0);
    #|      end else if (lc_watch_queued && lc_pop) begin
    #|        if (lc_watch_rank != 0) lc_watch_rank <= lc_watch_rank - 3'd1;
    #|        else lc_watch_queued <= 1'b0;
    #|      end
    #|      if (lc_response_due) lc_response_seen <= 1'b1;
    #|      if (lc_response_due && lc_dut_head_capture) begin
    #|        lc_capture_seen <= 1'b1;
    #|        lc_head_held <= 1'b1;
    #|      end else if (lc_effective_finish) lc_head_held <= 1'b0;
    #|    end
    #|  end
    #|
  out.write_string(base)
  let structure : Array[String] = [
    "(lc_o_head_state <= 2'd3)", "(lc_o_fifo_response_valid_0 == (lc_o_head_state == 2'd1))",
  ]
  for lane in 0..<4 {
    for name in ["occupancy", "read_pointer", "write_pointer", "response_valid"] {
      structure.push("(lc_o_fifo_\{name}_\{lane} == lc_o_fifo_\{name}_0)")
    }
    structure.push("(lc_o_fifo_occupancy_\{lane} <= 2'd3)")
    structure.push(
      "(lc_o_fifo_read_pointer_\{lane} < 2'd3 && lc_o_fifo_write_pointer_\{lane} < 2'd3)",
    )
    structure.push(
      "(lc_o_fifo_write_pointer_\{lane} == lc_wrap3({1'b0, lc_o_fifo_read_pointer_\{lane}} + {1'b0, lc_o_fifo_occupancy_\{lane}}))",
    )
    structure.push(
      "(lc_dut_fifo_push_fire_\{lane} == lc_admit && lc_dut_fifo_pop_fire_\{lane} == lc_pop)",
    )
  }
  out.write_string(
    "  wire lc_raw_structure = \{structure.join(" && ")};\n  wire lc_fifo_structure = !lc_seen_edge || lc_raw_structure;\n",
  )
  let predicates =
    #|  wire lc_startup_reset = lc_seen_edge || lc_reset;
    #|  // Later PRE reset does not excuse an already established raw invariant.
    #|  wire lc_fifo_public_count = !lc_seen_edge || (lc_public_count <= 3'd3
    #|    && lc_public_count == {1'b0, lc_o_fifo_occupancy_0} && lc_count_step_ok);
    #|  wire lc_watch_location = lc_watch_slot < 2'd3 && lc_watch_rank < lc_public_count
    #|    && lc_watch_slot == lc_wrap3({1'b0, lc_o_fifo_read_pointer_0} + lc_watch_rank);
    #|  wire lc_raw_cells_match = {lc_watched_cell_3, lc_watched_cell_2,
    #|    lc_watched_cell_1, lc_watched_cell_0} == lc_saved_packet;
    #|  // Stop cell equality at pop COMMIT: full pop/refill may replace that
    #|  // physical word, while the actual ReadOld response preserves old bits.
    #|  wire lc_watched_slot_and_cells = !lc_seen_edge || !lc_watch_queued
    #|    || (lc_watch_location && lc_raw_cells_match);
    #|  wire lc_raw_response_match = lc_raw_response == lc_saved_packet;
    #|  wire lc_genuine_response = lc_seen_edge && !lc_reset && lc_watch_chosen
    #|    && lc_response_due && lc_o_fifo_response_valid_0 && lc_dut_head_capture
    #|    && lc_raw_response_match;
    #|
  out.write_string(predicates)
  let checked = if negative {
    "(lc_raw_response ^ (lc_genuine_response ? 256'h100000000000000000000000000000000 : 256'd0))"
  } else {
    "lc_raw_response"
  }
  out.write_string("  wire [255:0] lc_checked_response = \{checked};\n")
  let checked_predicates =
    #|  // The single negative expression changes lane2 bit0 only after the
    #|  // same watch's real ordinal response matches; no DUT/history feeds it.
    #|  wire lc_watched_response = !lc_seen_edge || lc_reset || !lc_response_due
    #|    || (lc_o_fifo_response_valid_0 && lc_dut_head_capture
    #|      && lc_o_head_state == 2'd1 && lc_checked_response == lc_saved_packet);
    #|  wire lc_watched_head = !lc_seen_edge || !(lc_head_due || lc_head_held)
    #|    || lc_raw_head == lc_saved_packet;
    #|  wire lc_raw_watch_structure = (!lc_watch_queued || (lc_watch_chosen
    #|    && !lc_response_due && !lc_head_due && !lc_head_held))
    #|    && (!lc_response_due || (lc_watch_chosen && !lc_watch_queued
    #|      && !lc_head_due && !lc_head_held && lc_o_head_state == 2'd1))
    #|    && (!lc_head_held || (lc_watch_chosen && lc_response_seen && lc_capture_seen
    #|      && !lc_watch_queued && !lc_response_due
    #|      && (lc_o_head_state == 2'd2 || lc_o_head_state == 2'd3)))
    #|    && (!lc_head_due || lc_head_held);
    #|  wire lc_watch_structure = !lc_seen_edge || lc_raw_watch_structure;
    #|  wire lc_watched_transfer = lc_seen_edge && !lc_reset && lc_head_due
    #|    && lc_watch_chosen && lc_response_seen && lc_capture_seen
    #|    && lc_raw_structure && lc_raw_watch_structure && lc_raw_head == lc_saved_packet;
    #|
  out.write_string(checked_predicates)
  out.write_string(
    "  wire lc_reset_establishment = !lc_previous_rising_reset || (\{zero.join(" && ")} && lc_public_count == 0 && !lc_watch_chosen && !lc_watch_queued && !lc_response_due && !lc_head_due && !lc_head_held && !lc_response_seen && !lc_capture_seen && lc_watch_rank == 0 && lc_watch_slot == 0);\n",
  )
  // Explicit raw global hold covers original309bits+12cells768bits+4read256bits.
  out.write_string(
    "  wire [1332:0] lc_actual_storage_pair = {\{actual_pair.join(", ")}};\n",
  )
  let hold =
    #|  wire [272:0] lc_observer_pair = {lc_seen_edge, lc_previous_rising_reset,
    #|    lc_public_count, lc_watch_chosen,
    #|    lc_watch_queued, lc_response_due, lc_head_due, lc_head_held,
    #|    lc_response_seen, lc_capture_seen, lc_watch_rank, lc_watch_slot, lc_saved_packet};
    #|  logic lc_seen_global = 1'b0;
    #|  logic lc_previous_clock = 1'b0;
    #|  logic [1332:0] lc_previous_actual_storage_pair;
    #|  logic [272:0] lc_previous_observer_pair;
    #|  always @($global_clock) begin
    #|    lc_seen_global <= 1'b1;
    #|    lc_previous_clock <= lc_clock;
    #|    lc_previous_actual_storage_pair <= lc_actual_storage_pair;
    #|    lc_previous_observer_pair <= lc_observer_pair;
    #|    lc_storage_nonrising_hold: assert ((!lc_seen_global
    #|      || (!lc_previous_clock && lc_clock)
    #|      || ((lc_actual_storage_pair === lc_previous_actual_storage_pair)
    #|        && (lc_observer_pair === lc_previous_observer_pair))) === 1'b1);
    #|  end
    #|
  out.write_string(hold)
  out.to_string()
}
