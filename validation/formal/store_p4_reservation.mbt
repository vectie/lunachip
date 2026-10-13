///|
// Assertion-only strengthening over the original Store projection. Read,
// Request, and Wait reserve the selected C rectangle on old PRE state,
// including cancellation, terminal, and good-ACK edges. Done does not reserve
// C. A later reset remains arbitrary; no release-edge admission credit is used.
// The original production observer owns startup history. These extra snapshots
// remember selectors at their real admission edge; they are not hardware cuts.
fn store_p4_reservation_source() -> String {
  let out = StringBuilder()
  out.write_string(
    (
      #|  wire lc_p4_reserved = lc_o_store_State == 3'd1
      #|    || lc_o_store_State == 3'd2 || lc_o_store_State == 3'd3;
      #|  wire lc_p4_pre_reserved = lc_pre_lc_o_store_State == 3'd1
      #|    || lc_pre_lc_o_store_State == 3'd2 || lc_pre_lc_o_store_State == 3'd3;
      #|  logic lc_p4_pre_incoming_compute_c, lc_p4_pre_incoming_store_slot;
      #|  always @(posedge lc_clock) begin
      #|    lc_p4_pre_incoming_compute_c <= lc_incoming_compute_c;
      #|    lc_p4_pre_incoming_store_slot <= lc_incoming_store_slot;
      #|  end
      #|  always @(posedge lc_clock) begin
      #|    lc_p4_reservation_store_state: assert ((!lc_seen_edge
      #|      || lc_o_store_State <= 3'd4) === 1'b1);
      #|    lc_p4_reservation_store_accept_idle: assert ((!lc_e_StoreAccept
      #|      || (!lc_reset && lc_o_store_State == 3'd0)) === 1'b1);
      #|    lc_p4_reservation_compute_accept_idle: assert ((!lc_e_ComputeAccept
      #|      || (!lc_reset && lc_o_compute_State == 2'd0)) === 1'b1);
      #|    lc_p4_reservation_inner_accept_issue: assert ((!lc_e_SlottedAccept
      #|      || (!lc_reset && lc_o_compute_State == 2'd1
      #|      && lc_o_slotted_State == 2'd0)) === 1'b1);
      #|    lc_p4_reservation_lease_phase: assert ((!lc_seen_edge || !lc_o_compute_Leased
      #|      || (lc_o_compute_State == 2'd1 || lc_o_compute_State == 2'd2)) === 1'b1);
      #|    lc_p4_reservation_store_selector: assert ((!lc_seen_edge || lc_o_store_Slot ==
      #|      (lc_previous_reset ? 1'b0 : (lc_pre_lc_e_StoreAccept
      #|      ? lc_p4_pre_incoming_store_slot : lc_pre_lc_o_store_Slot))) === 1'b1);
      #|    lc_p4_reservation_compute_selector: assert ((!lc_seen_edge || lc_o_compute_C ==
      #|      (lc_previous_reset ? 1'b0 : (lc_pre_lc_e_ComputeAccept
      #|      ? lc_p4_pre_incoming_compute_c : lc_pre_lc_o_compute_C))) === 1'b1);
      #|    lc_p4_reservation_active_exact: assert ((lc_e_StoreActive
      #|      == (!lc_reset && lc_p4_reserved)) === 1'b1);
      #|    lc_p4_reservation_blocks_compute_admission: assert ((!lc_p4_reserved
      #|      || !lc_e_ComputeAccept || lc_incoming_compute_c != lc_o_store_Slot) === 1'b1);
      #|    lc_p4_reservation_blocks_store_admission: assert ((!lc_o_compute_Leased
      #|      || !lc_e_StoreAccept || lc_incoming_store_slot != lc_o_compute_C) === 1'b1);
      #|    lc_p4_reservation_same_edge_admission: assert ((!lc_e_ComputeLegalAccept
      #|      || !lc_e_StoreAccept || lc_incoming_store_slot != lc_incoming_compute_c) === 1'b1);
      #|    lc_p4_reservation_selected_lease_disjoint: assert ((!lc_seen_edge
      #|      || !lc_p4_reserved || !lc_o_compute_Leased
      #|      || lc_o_store_Slot != lc_o_compute_C) === 1'b1);
      #|    lc_p4_reservation_pending_blocks_inner: assert ((!lc_o_slotted_Pending
      #|      || !lc_e_SlottedAccept || lc_o_compute_C != lc_o_slotted_ResponseSlot) === 1'b1);
      #|    lc_p4_reservation_selected_invalidate_excluded: assert ((!lc_seen_edge
      #|      || !lc_p4_reserved || !lc_e_SlottedLegalAccept
      #|      || lc_o_compute_C != lc_o_store_Slot) === 1'b1);
      #|    lc_p4_reservation_selected_capture_excluded: assert ((!lc_seen_edge
      #|      || !lc_p4_reserved || !lc_e_Capture
      #|      || lc_o_slotted_ActiveC != lc_o_store_Slot) === 1'b1);
      #|    lc_p4_reservation_selected_publish_excluded: assert ((!lc_seen_edge
      #|      || !lc_p4_reserved || !lc_e_FinalCapture
      #|      || lc_o_slotted_ActiveC != lc_o_store_Slot) === 1'b1);
      #|  end
      #|
    ),
  )
  for slot in 0..<2 {
    out.write_string(
      "  always @(posedge lc_clock) begin\n" +
      "    lc_p4_reservation_selected_write_excluded_\{slot}: assert ((!lc_seen_edge || !lc_p4_reserved\n" +
      "      || lc_o_store_Slot != 1'd\{slot} || !lc_c_write_enable_\{slot}) === 1'b1);\n" +
      "    lc_p4_reservation_selected_metadata_hold_\{slot}: assert ((!lc_seen_edge || lc_previous_reset\n" +
      "      || !lc_p4_pre_reserved || lc_pre_lc_o_store_Slot != 1'd\{slot}\n" +
      "      || (lc_o_result_valid_\{slot} == lc_pre_lc_o_result_valid_\{slot}\n" +
      "      && lc_o_result_rows_\{slot} == lc_pre_lc_o_result_rows_\{slot}\n" +
      "      && lc_o_result_columns_\{slot} == lc_pre_lc_o_result_columns_\{slot})) === 1'b1);\n" +
      "  end\n",
    )
  }
  out.to_string()
}
