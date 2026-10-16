///|
// Pending/arbiter expectations come from independently saved capture words,
// never ResponseData or public data under test. Full UInt64 address is saved.
fn fetched_sram_read_support() -> String {
  (
    #|  wire lc_selected_valid = lc_o_store_Slot ? lc_valid_1 : lc_valid_0;
    #|  wire lc_selected_written = lc_o_store_Slot ? lc_written_1 : lc_written_0;
    #|  wire [31:0] lc_selected_word = lc_o_store_Slot ? lc_word_1 : lc_word_0;
    #|  wire [31:0] lc_selected_ticket = lc_o_store_Slot ? lc_ticket_1 : lc_ticket_0;
    #|  wire lc_head_c = lc_head_lane_3[16];
    #|  wire [1:0] lc_head_latest_status = lc_head_c ? lc_latest_status_1 : lc_latest_status_0;
    #|  wire [31:0] lc_head_latest_ticket = lc_head_c ? lc_latest_ticket_1 : lc_latest_ticket_0;
    #|  wire lc_head_source_success = lc_dependency_status == 2'd2 || (lc_dependency_status == 2'd1 && lc_head_latest_status == 2'd2 && lc_head_latest_ticket == lc_dependency_ticket);
    #|  logic lc_pending, lc_pending_basis, lc_pending_slot;
    #|  logic [31:0] lc_pending_word, lc_pending_ticket, lc_pending_id;
    #|  wire lc_response_ready = !lc_reset && (lc_o_store_State == 3'd3 || lc_o_store_State == 3'd4);
    #|  wire lc_store_snapshot = lc_arb_grant && lc_arb_choice == 2'd2;
    #|  logic lc_origin;
    #|  logic [31:0] lc_origin_word;
    #|  logic [63:0] lc_origin_address;
    #|  always @(posedge lc_clock) begin
    #|    if (lc_reset) begin lc_pending <= 1'b0; lc_pending_basis <= 1'b0; lc_origin <= 1'b0; end
    #|    else begin
    #|      lc_pending <= lc_e_ReadAccept || (lc_pending && !lc_response_ready);
    #|      if (lc_e_ReadAccept) begin
    #|        lc_pending_basis <= lc_selected_valid && lc_selected_written;
    #|        lc_pending_slot <= lc_o_store_Slot;
    #|        lc_pending_id <= lc_o_store_Id;
    #|        lc_pending_word <= lc_selected_word;
    #|        lc_pending_ticket <= lc_selected_ticket;
    #|      end
    #|      if (lc_arb_grant) lc_origin <= lc_arb_choice == 2'd2;
    #|      if (lc_store_snapshot) begin lc_origin_word <= lc_pending_word; lc_origin_address <= lc_address_full; end
    #|    end
    #|    lc_pending_history: assert ((!lc_seen || lc_pending == lc_o_slotted_Pending) === 1'b1);
    #|    lc_held_request_owner: assert ((!lc_seen || lc_o_store_State != 3'd2 || (lc_pending && lc_pending_basis && lc_pending_ticket == lc_store_basis_ticket && lc_pending_id == lc_o_store_Id && lc_pending_slot == lc_o_store_Slot)) === 1'b1);
    #|    lc_reserved_store_basis: assert ((!lc_seen || lc_head_state != 2'd3 || lc_head_lane_0[23:16] != 8'd3 || !lc_head_source_success || (!(lc_o_compute_Leased && lc_o_compute_C == lc_head_c) && (lc_head_c ? (lc_valid_1 && lc_written_1 && lc_ticket_1 == lc_dependency_ticket) : (lc_valid_0 && lc_written_0 && lc_ticket_0 == lc_dependency_ticket)))) === 1'b1);
    #|    lc_read_authorized: assert ((!lc_seen || !lc_e_ReadAccept || (lc_store_active && lc_selected_valid && lc_selected_written && lc_selected_ticket == lc_store_basis_ticket && lc_o_store_Row == 13'd0 && lc_o_store_Column == 13'd0)) === 1'b1);
    #|    lc_pending_identity: assert ((!lc_seen || !lc_pending || (lc_pending_basis && lc_o_slotted_ResponseSlot == lc_pending_slot && lc_o_response_id == lc_pending_id && lc_o_response_fault == 2'd0)) === 1'b1);
    #|    lc_pending_read_basis: assert ((!lc_seen || !lc_pending || (lc_pending_slot ? (lc_read_tracked_1 && lc_read_word_1 == lc_pending_word) : (lc_read_tracked_0 && lc_read_word_0 == lc_pending_word))) === 1'b1);
    #|    lc_response_origin: assert ((!lc_seen || lc_reset || !lc_pending || lc_e_ResponseData == lc_pending_word) === 1'b1);
    #|    lc_store_grant_identity: assert ((!lc_seen || !lc_store_snapshot || (lc_e_StoreRequestValid && lc_pending && lc_pending_basis && lc_pending_ticket == lc_store_basis_ticket && lc_pending_id == lc_o_store_Id && lc_e_ResponseData == lc_pending_word)) === 1'b1);
    #|    lc_store_public_accept: assert ((!lc_seen || !lc_e_StoreRequestAccept || (lc_public_valid && lc_public_ready && lc_arb_state == 2'd1 && lc_arb_owner == 2'd2 && lc_origin && lc_public_data == lc_origin_word)) === 1'b1);
    #|    lc_arbiter_origin: assert ((!lc_seen || !(lc_arb_state == 2'd1 || lc_arb_state == 2'd2) || lc_arb_owner != 2'd2 || (lc_origin && lc_arb_data == lc_origin_word && {32'd0,lc_arb_address} == lc_origin_address)) === 1'b1);
    #|    lc_public_origin: assert ((!lc_seen || !lc_public_valid || lc_arb_owner != 2'd2 || (lc_origin && lc_public_write && lc_public_data == lc_origin_word && {32'd0,lc_public_address} == lc_origin_address)) === 1'b1);
    #|  end
    #|
  )
}
