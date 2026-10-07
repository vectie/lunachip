///|
// Conclusions on the SAME original public watch. This adds only a two-bit
// physical FIFO location; packet, ranks, entry and ticket stay original ghosts.
fn queue_packet_composition_strengthening_source(
  sequential : QueuePacketCompositionSequential,
  emitted : @rtl.EmittedDesign,
) -> String raise FormalGateError {
  let out = StringBuilder()
  let names = queue_packet_composition_memory_identifiers(sequential, emitted)
  let witness =
    #|  logic [1:0] lc_pp_saved_fifo_slot;
    #|  always @(posedge lc_clock) begin
    #|    if (lc_reset) lc_pp_saved_fifo_slot <= 2'd0;
    #|    else if (lc_pp_watch && lc_pp_counts_ok)
    #|      lc_pp_saved_fifo_slot <= lc_s_fifo_write_pointer_0;
    #|  end
    #|  // Widen first. Invalid induction states cannot truncate into slot 0..2.
    #|  function automatic [5:0] lc_pp_wrap3(input [5:0] value);
    #|    case (value)
    #|      6'd3: lc_pp_wrap3 = 6'd0;
    #|      6'd4: lc_pp_wrap3 = 6'd1;
    #|      6'd5: lc_pp_wrap3 = 6'd2;
    #|      default: lc_pp_wrap3 = value;
    #|    endcase
    #|  endfunction
    #|
  out.write_string(witness)
  for lane in 0..<4 {
    out.write_string(
      "  wire [63:0] lc_pp_saved_cell_\{lane} = \{names[lane]}[lc_pp_saved_fifo_slot];\n",
    )
  }
  let structure : Array[String] = [
    "(lc_pp_fifo_count == {2'd0, lc_o_fifo_occupancy_0})", "(lc_pp_outstanding == lc_queue_outstanding)",
  ]
  for lane in 0..<4 {
    structure.push(
      "(lc_s_fifo_read_pointer_\{lane} < 2'd3 && lc_s_fifo_write_pointer_\{lane} < 2'd3)",
    )
    structure.push(
      "(lc_s_fifo_read_pointer_\{lane} == lc_s_fifo_read_pointer_0 && lc_s_fifo_write_pointer_\{lane} == lc_s_fifo_write_pointer_0)",
    )
    structure.push(
      "({4'd0, lc_s_fifo_write_pointer_\{lane}} == lc_pp_wrap3({4'd0, lc_s_fifo_read_pointer_\{lane}} + {4'd0, lc_o_fifo_occupancy_\{lane}}))",
    )
  }
  out.write_string("  wire lc_pp_fifo_structure = \{structure.join(" && ")};\n")
  let relations =
    #|  wire [5:0] lc_pp_queued_older = {1'd0, lc_o_retirement_occupancy}
    #|    + {5'd0, lc_unreserved_head} + {2'd0, lc_pp_fifo_older};
    #|  wire lc_pp_queued_location = lc_pp_saved_fifo_slot < 2'd3
    #|    && {2'd0, lc_pp_fifo_older} < {4'd0, lc_o_fifo_occupancy_0}
    #|    && {4'd0, lc_pp_saved_fifo_slot} == lc_pp_wrap3(
    #|      {4'd0, lc_s_fifo_read_pointer_0} + {2'd0, lc_pp_fifo_older});
    #|  wire lc_pp_queued_cells = {lc_pp_saved_cell_3, lc_pp_saved_cell_2,
    #|    lc_pp_saved_cell_1, lc_pp_saved_cell_0} == lc_pp_saved_packet;
    #|  // Only stage1 observes the cell. A full pop/refill can overwrite it at
    #|  // COMMIT; stage2 instead observes the actual ReadOld read-result state.
    #|  wire lc_pp_queued_relation = lc_pp_stage != 3'd1
    #|    || ({2'd0, lc_pp_retire_older} == lc_pp_queued_older
    #|      && lc_pp_queued_location && lc_pp_queued_cells);
    #|  wire lc_pp_response_relation = lc_pp_stage != 3'd2
    #|    || ({1'd0, lc_pp_retire_older} == lc_o_retirement_occupancy
    #|      && lc_o_head_state == 2'd1 && lc_pp_all_response
    #|      && lc_o_head_capture && lc_pp_response_packet == lc_pp_saved_packet);
    #|  wire lc_pp_head_relation = lc_pp_stage != 3'd3
    #|    || ({1'd0, lc_pp_retire_older} == lc_o_retirement_occupancy
    #|      && lc_o_head_state == 2'd2 && lc_pp_head_packet == lc_pp_saved_packet);
    #|  // R-rank is bounded before subtraction. UInt32 subtraction is the
    #|  // original ticket arithmetic modulo 2^32, including wrap-around.
    #|  wire [31:0] lc_pp_record_distance = {27'd0, lc_o_retirement_occupancy}
    #|    - {28'd0, lc_pp_retire_older};
    #|  wire lc_pp_record_relation = lc_pp_stage != 3'd4
    #|    || (lc_pp_saved_entry < 5'd3
    #|      && {1'd0, lc_pp_retire_older} < lc_o_retirement_occupancy
    #|      && {1'd0, lc_pp_saved_entry} == lc_pp_wrap3(
    #|        {1'd0, lc_o_retirement_read_pointer} + {2'd0, lc_pp_retire_older})
    #|      && lc_pp_saved_ticket == lc_o_next_ticket - lc_pp_record_distance
    #|      && lc_pp_entry_valid && lc_pp_entry_ticket == lc_pp_saved_ticket
    #|      && lc_pp_entry_id == lc_pp_saved_packet[63:32]);
    #|  // Check the original watch's predecessor history, not a new premise.
    #|  // Entering stage3 records the raw response; capture_seen is set only
    #|  // at the following stage3 PRE, so it is required at stage4, not stage3.
    #|  // Stage5 has no live-history claim: ordinal retirement is checked by p12.
    #|  wire lc_pp_history_relation = lc_pp_stage <= 3'd5
    #|    && (!lc_pp_active || lc_pp_taken)
    #|    && (lc_pp_stage != 3'd3 || lc_pp_response_seen)
    #|    && (lc_pp_stage != 3'd4 || (lc_pp_response_seen
    #|      && lc_pp_capture_seen && lc_pp_reservation_seen));
    #|  // Includes the watched ACK PRE. Stage5 stops live-slot checks because
    #|  // the original record is released at that edge, not kept as a ghost DUT.
    #|  wire lc_pp_strengthening = !lc_seen_edge || lc_reset
    #|    || (lc_pp_history_relation && lc_pp_fifo_structure && lc_pp_queued_relation
    #|      && lc_pp_response_relation && lc_pp_head_relation && lc_pp_record_relation);
    #|`ifdef FORMAL
    #|  always @(posedge lc_clock) begin
    #|    lc_packet_strengthening: assert ((lc_pp_strengthening) === 1'b1);
    #|  end
    #|`endif
    #|
  out.write_string(relations)
  out.to_string()
}
