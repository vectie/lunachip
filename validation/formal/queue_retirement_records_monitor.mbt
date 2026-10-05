///|
// Only sampled records live here; the production entry bank remains the DUT.
// Payload order is caller ID, fault, progress, address (100 bits), with a
// separate ticket in each 132-bit entry record. Caller IDs need not be unique.
fn queue_retirement_records_source(negative : Bool) -> String {
  let out = StringBuilder()
  let selectors =
    #|  // Explicit three-entry selector, not the DUT's selected output aliases.
    #|  wire lc_rr_pointer_in_range = lc_o_retirement_read_pointer < 5'd3;
    #|  wire lc_rr_oldest_valid = lc_o_retirement_read_pointer == 5'd0 ? lc_o_entry_valid_0
    #|    : (lc_o_retirement_read_pointer == 5'd1 ? lc_o_entry_valid_1
    #|      : (lc_o_retirement_read_pointer == 5'd2 ? lc_o_entry_valid_2 : 1'b0));
    #|  wire lc_rr_oldest_terminal = lc_o_retirement_read_pointer == 5'd0 ? lc_o_entry_terminal_0
    #|    : (lc_o_retirement_read_pointer == 5'd1 ? lc_o_entry_terminal_1
    #|      : (lc_o_retirement_read_pointer == 5'd2 ? lc_o_entry_terminal_2 : 1'b0));
    #|  wire [31:0] lc_rr_oldest_ticket = lc_o_retirement_read_pointer == 5'd0 ? lc_o_entry_ticket_0
    #|    : (lc_o_retirement_read_pointer == 5'd1 ? lc_o_entry_ticket_1
    #|      : (lc_o_retirement_read_pointer == 5'd2 ? lc_o_entry_ticket_2 : 32'd0));
    #|  wire [99:0] lc_rr_public_payload = {lc_completion_id, lc_completion_fault,
    #|    lc_completion_bytes_completed, lc_completion_fault_address};
    #|  wire [99:0] lc_rr_oldest_payload = lc_o_retirement_read_pointer == 5'd0
    #|    ? {lc_o_entry_id_0, lc_o_entry_fault_0, lc_o_entry_progress_0, lc_o_entry_address_0}
    #|    : (lc_o_retirement_read_pointer == 5'd1
    #|      ? {lc_o_entry_id_1, lc_o_entry_fault_1, lc_o_entry_progress_1, lc_o_entry_address_1}
    #|      : (lc_o_retirement_read_pointer == 5'd2
    #|        ? {lc_o_entry_id_2, lc_o_entry_fault_2, lc_o_entry_progress_2, lc_o_entry_address_2}
    #|        : 100'd0));
    #|  logic lc_rr_previous_hold = 1'b0;
    #|  logic [99:0] lc_rr_previous_payload = 100'd0;
    #|  logic [4:0] lc_rr_previous_pointer = 5'd0;
    #|  logic [31:0] lc_rr_previous_ticket = 32'd0;
    #|  wire lc_rr_raw_stable_hold = !lc_reset && lc_rr_previous_hold
    #|    && lc_completion_valid && lc_o_retirement_read_pointer == lc_rr_previous_pointer
    #|    && lc_rr_oldest_ticket == lc_rr_previous_ticket
    #|    && lc_rr_public_payload == lc_rr_previous_payload;
    #|
  out.write_string(selectors)
  let checked_id = if negative {
    "(lc_rr_previous_payload[99:68] ^ (lc_rr_raw_stable_hold ? 32'd1 : 32'd0))"
  } else {
    "lc_rr_previous_payload[99:68]"
  }
  out.write_string("  wire [31:0] lc_rr_checked_saved_id = \{checked_id};\n")
  for entry in 0..<3 {
    out.write_string(
      "  wire [131:0] lc_rr_entry_record_\{entry} = {lc_o_entry_ticket_\{entry}, lc_o_entry_id_\{entry},\n    lc_o_entry_fault_\{entry}, lc_o_entry_progress_\{entry}, lc_o_entry_address_\{entry}};\n",
    )
    out.write_string("  logic lc_rr_previous_entry_watch_\{entry} = 1'b0;\n")
    out.write_string(
      "  logic [131:0] lc_rr_previous_entry_record_\{entry} = 132'd0;\n",
    )
    out.write_string(
      "  logic lc_rr_previous_younger_collect_\{entry} = 1'b0;\n",
    )
    out.write_string(
      "  logic [31:0] lc_rr_previous_younger_ticket_\{entry} = 32'd0;\n",
    )
    out.write_string(
      "  wire lc_rr_younger_collect_\{entry} = lc_completion_valid && !lc_completion_ready\n    && lc_rr_pointer_in_range && lc_rr_oldest_valid && lc_rr_oldest_terminal\n    && lc_o_retirement_read_pointer != 5'd\{entry}\n    && lc_o_entry_valid_\{entry} && !lc_o_entry_terminal_\{entry}\n    && (lc_o_entry_collector_\{entry}_0 || lc_o_entry_collector_\{entry}_1 || lc_o_entry_collector_\{entry}_2);\n",
    )
  }
  let watch_reset =
    #|  // PRE watches are overwritten every edge, never sticky cover milestones.
    #|  always_ff @(posedge lc_clock) begin
    #|    if (lc_reset) begin
    #|      lc_rr_previous_hold <= 1'b0;
    #|      lc_rr_previous_payload <= 100'd0;
    #|      lc_rr_previous_pointer <= 5'd0;
    #|      lc_rr_previous_ticket <= 32'd0;
    #|
  out.write_string(watch_reset)
  for entry in 0..<3 {
    out.write_string("      lc_rr_previous_entry_watch_\{entry} <= 1'b0;\n")
    out.write_string("      lc_rr_previous_entry_record_\{entry} <= 132'd0;\n")
    out.write_string("      lc_rr_previous_younger_collect_\{entry} <= 1'b0;\n")
    out.write_string("      lc_rr_previous_younger_ticket_\{entry} <= 32'd0;\n")
  }
  let watch_update =
    #|    end else begin
    #|      lc_rr_previous_hold <= lc_completion_valid && !lc_completion_ready;
    #|      lc_rr_previous_payload <= lc_rr_public_payload;
    #|      lc_rr_previous_pointer <= lc_o_retirement_read_pointer;
    #|      lc_rr_previous_ticket <= lc_rr_oldest_ticket;
    #|
  out.write_string(watch_update)
  for entry in 0..<3 {
    out.write_string(
      "      lc_rr_previous_entry_watch_\{entry} <= lc_o_entry_valid_\{entry}\n        && lc_o_entry_terminal_\{entry} && !lc_o_entry_acknowledge_\{entry};\n",
    )
    out.write_string(
      "      lc_rr_previous_entry_record_\{entry} <= lc_rr_entry_record_\{entry};\n",
    )
    out.write_string(
      "      lc_rr_previous_younger_collect_\{entry} <= lc_rr_younger_collect_\{entry};\n",
    )
    out.write_string(
      "      lc_rr_previous_younger_ticket_\{entry} <= lc_o_entry_ticket_\{entry};\n",
    )
  }
  out.write_string("    end\n  end\n")
  let entry_checks : Array[String] = []
  let collector_witnesses : Array[String] = []
  for entry in 0..<3 {
    entry_checks.push(
      "(!lc_rr_previous_entry_watch_\{entry} || (lc_o_entry_valid_\{entry}\n      && lc_o_entry_terminal_\{entry} && lc_rr_entry_record_\{entry} == lc_rr_previous_entry_record_\{entry}))",
    )
    collector_witnesses.push(
      "(lc_rr_previous_younger_collect_\{entry} && lc_o_entry_valid_\{entry}\n      && lc_o_entry_terminal_\{entry} && lc_o_entry_ticket_\{entry} == lc_rr_previous_younger_ticket_\{entry})",
    )
  }
  out.write_string(
    "  wire lc_terminal_entry_immutable = lc_reset || (\{entry_checks.join("\n    && ")});\n",
  )
  let predicates =
    #|  // Acknowledge/release at this PRE does not disable the previous watch.
    #|  wire lc_oldest_terminal_selected = lc_reset || (lc_rr_pointer_in_range
    #|    && lc_completion_valid == (lc_rr_oldest_valid && lc_rr_oldest_terminal)
    #|    && (!lc_completion_valid || lc_rr_public_payload == lc_rr_oldest_payload));
    #|  wire lc_held_completion_immutable = lc_reset || !lc_rr_previous_hold
    #|    || (lc_completion_valid && lc_o_retirement_read_pointer == lc_rr_previous_pointer
    #|      && lc_rr_oldest_ticket == lc_rr_previous_ticket
    #|      && lc_completion_id == lc_rr_checked_saved_id
    #|      && lc_rr_public_payload[67:0] == lc_rr_previous_payload[67:0]);
    #|
  out.write_string(predicates)
  out.write_string(
    "  wire lc_reachable_held_oldest_younger_collector = lc_rr_raw_stable_hold\n    && lc_rr_pointer_in_range && lc_rr_oldest_valid && lc_rr_oldest_terminal\n    && !lc_completion_ready && (\{collector_witnesses.join("\n    || ")});\n",
  )
  out.to_string()
}
