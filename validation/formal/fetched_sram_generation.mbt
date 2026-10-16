///|
// Per-generation validity resets/invalidation never initialize SRAM or words.
// A logical failed/pending writer may leave physically old data present, so
// only logical Success is required to name the current captured generation.
fn fetched_sram_generation_support() -> String {
  let out = StringBuilder()
  out.write_string(
    (
      #|  logic lc_seen = 1'b0;
      #|  always @(posedge lc_clock) lc_seen <= 1'b1;
      #|  wire lc_inner_owned = lc_o_slotted_State == 2'd1 || lc_o_slotted_State == 2'd2;
      #|  wire lc_store_active = lc_o_store_State >= 3'd1 && lc_o_store_State <= 3'd3;
      #|  wire lc_head_mat_syntax = lc_head_lane_0[31:0] == 32'h00020200
      #|    && lc_head_lane_1[63:48] == 16'd0 && (lc_head_lane_3 & 64'hffffffffff_fefefe) == 64'd0
      #|    && lc_head_lane_1[15:0] <= 16'd8191 && lc_head_lane_1[31:16] <= 16'd8191 && lc_head_lane_1[47:32] <= 16'd8191;
      #|  logic [31:0] lc_store_basis_ticket;
      #|  always @(posedge lc_clock) if (!lc_reset && lc_e_StoreAccept) lc_store_basis_ticket <= lc_dependency_ticket;
      #|  always @(posedge lc_clock) begin
      #|    lc_compute_lease_phase: assert ((!lc_seen || !lc_o_compute_Leased || lc_o_compute_State == 2'd1 || lc_o_compute_State == 2'd2) === 1'b1);
      #|    lc_compute_issue_lease: assert ((!lc_seen || lc_o_compute_State != 2'd1 || lc_o_compute_Leased) === 1'b1);
      #|    lc_reserved_mat_intent: assert ((!lc_seen || lc_arb_state == 2'd3 || lc_head_state != 2'd3 || !lc_head_mat_syntax || (lc_head_lane_3[16] ? (lc_latest_status_1 == 2'd1 && lc_latest_ticket_1 == lc_head_ticket) : (lc_latest_status_0 == 2'd1 && lc_latest_ticket_0 == lc_head_ticket))) === 1'b1);
      #|    lc_inner_lease: assert ((!lc_seen || !lc_inner_owned || (lc_o_compute_State == 2'd2
      #|      && lc_o_compute_Leased && lc_o_slotted_ActiveC == lc_o_compute_C
      #|      && lc_o_core_Id == lc_o_compute_Id && lc_o_core_Fault == 2'd0)) === 1'b1);
      #|    lc_capture_final: assert ((!lc_seen || lc_e_Capture == lc_e_FinalCapture) === 1'b1);
      #|    lc_capture_coordinates: assert ((!lc_seen || !lc_e_Capture || (lc_inner_owned
      #|      && lc_o_slotted_CaptureRow == 4'd0 && lc_o_slotted_CaptureColumn == 4'd0
      #|      && lc_o_core_Rows == 4'd1 && lc_o_core_Columns == 4'd1)) === 1'b1);
      #|  end
      #|
    ),
  )
  for slot in 0..<2 {
    out.write_string(
      "  wire lc_invalidate_\{slot} = lc_e_SlottedLegalAccept && lc_o_compute_C == 1'd\{slot};\n" +
      "  wire lc_capture_\{slot} = lc_e_Capture && lc_o_slotted_ActiveC == 1'd\{slot};\n" +
      "  wire lc_publish_\{slot} = lc_e_FinalCapture && lc_o_slotted_ActiveC == 1'd\{slot};\n" +
      "  logic lc_written_\{slot}, lc_valid_\{slot}, lc_read_tracked_\{slot};\n" +
      "  logic [3:0] lc_rows_\{slot}, lc_columns_\{slot};\n" +
      "  logic [31:0] lc_word_\{slot}, lc_ticket_\{slot}, lc_read_word_\{slot};\n" +
      "  always @(posedge lc_clock) begin\n" +
      "    if (lc_reset) begin\n      lc_written_\{slot} <= 1'b0; lc_valid_\{slot} <= 1'b0;\n" +
      "      lc_rows_\{slot} <= 4'd0; lc_columns_\{slot} <= 4'd0; lc_read_tracked_\{slot} <= 1'b0;\n" +
      "    end else begin\n" +
      "      if (lc_invalidate_\{slot}) begin\n        lc_written_\{slot} <= 1'b0; lc_valid_\{slot} <= 1'b0; lc_ticket_\{slot} <= lc_o_compute_Id;\n" +
      "      end else begin\n        if (lc_capture_\{slot}) lc_written_\{slot} <= 1'b1;\n        if (lc_publish_\{slot}) lc_valid_\{slot} <= 1'b1;\n      end\n" +
      "      if (lc_publish_\{slot}) begin lc_rows_\{slot} <= lc_o_core_Rows; lc_columns_\{slot} <= lc_o_core_Columns; end\n" +
      "      if (lc_capture_\{slot}) lc_word_\{slot} <= lc_producer;\n" +
      "      if (lc_c_read_enable_\{slot}) begin\n        lc_read_tracked_\{slot} <= lc_written_\{slot} && lc_valid_\{slot}; lc_read_word_\{slot} <= lc_word_\{slot};\n      end\n" +
      "    end\n" +
      "    lc_publication_\{slot}: assert ((!lc_seen || (lc_o_result_valid_\{slot} == lc_valid_\{slot} && lc_o_result_rows_\{slot} == lc_rows_\{slot} && lc_o_result_columns_\{slot} == lc_columns_\{slot})) === 1'b1);\n" +
      "    lc_complete_\{slot}: assert ((!lc_seen || !lc_valid_\{slot} || (lc_written_\{slot} && lc_rows_\{slot} == 4'd1 && lc_columns_\{slot} == 4'd1)) === 1'b1);\n" +
      "    lc_cell_origin_\{slot}: assert ((!lc_seen || !lc_written_\{slot} || lc_cell_\{slot} == lc_word_\{slot}) === 1'b1);\n" +
      "    lc_write_binding_\{slot}: assert ((!lc_seen || (lc_c_write_enable_\{slot} == lc_capture_\{slot} && (!lc_capture_\{slot} || (lc_c_write_address_\{slot} == 1'd0 && lc_c_write_data_\{slot} == lc_producer)))) === 1'b1);\n" +
      "    lc_capture_ticket_\{slot}: assert ((!lc_seen || !lc_inner_owned || lc_o_slotted_ActiveC != 1'd\{slot} || lc_ticket_\{slot} == lc_o_compute_Id) === 1'b1);\n" +
      "    lc_owned_unpublished_\{slot}: assert ((!lc_seen || !lc_inner_owned || lc_o_slotted_ActiveC != 1'd\{slot} || (!lc_valid_\{slot} && !lc_written_\{slot})) === 1'b1);\n" +
      "    lc_busy_not_latest_success_\{slot}: assert ((!lc_seen || !(lc_o_compute_State == 2'd1 || lc_o_compute_State == 2'd2) || lc_o_compute_C != 1'd\{slot} || lc_latest_status_\{slot} != 2'd2) === 1'b1);\n" +
      "    lc_done_generation_\{slot}: assert ((!lc_seen || lc_o_compute_State != 2'd3 || lc_o_compute_Fault != 4'd0 || lc_o_compute_C != 1'd\{slot} || (lc_valid_\{slot} && lc_written_\{slot} && lc_ticket_\{slot} == lc_o_compute_Id)) === 1'b1);\n" +
      "    lc_latest_generation_\{slot}: assert ((!lc_seen || lc_latest_status_\{slot} != 2'd2 || (lc_valid_\{slot} && lc_written_\{slot} && lc_ticket_\{slot} == lc_latest_ticket_\{slot})) === 1'b1);\n" +
      "    lc_pending_generation_owner_\{slot}: assert ((!lc_seen || lc_latest_status_\{slot} != 2'd1 || ((lc_head_state == 2'd3 && lc_head_mat_syntax && lc_head_lane_3[16] == 1'd\{slot} && lc_head_ticket == lc_latest_ticket_\{slot}) || (lc_o_compute_State != 2'd0 && lc_o_compute_C == 1'd\{slot} && lc_o_compute_Id == lc_latest_ticket_\{slot}))) === 1'b1);\n" +
      "    lc_store_lease_\{slot}: assert ((!lc_seen || !lc_store_active || lc_o_store_Slot != 1'd\{slot} || (lc_valid_\{slot} && lc_written_\{slot} && lc_ticket_\{slot} == lc_store_basis_ticket && !(lc_o_compute_Leased && lc_o_compute_C == 1'd\{slot}))) === 1'b1);\n" +
      "    lc_read_basis_\{slot}: assert ((!lc_seen || !lc_c_read_enable_\{slot} || (lc_valid_\{slot} && lc_written_\{slot} && lc_c_read_address_\{slot} == 1'd0)) === 1'b1);\n" +
      "    lc_read_old_hold_\{slot}: assert ((!lc_seen || !lc_read_tracked_\{slot} || lc_o_c_read_\{slot} == lc_read_word_\{slot}) === 1'b1);\n" +
      "    lc_reset_ports_\{slot}: assert ((!lc_reset || (!lc_c_write_enable_\{slot} && !lc_c_read_enable_\{slot})) === 1'b1);\n" +
      "  end\n",
    )
  }
  out.to_string()
}
