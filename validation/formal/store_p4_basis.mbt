///|
// Checked generation-to-pending-to-DMA support for the unchanged original p4.
// The original production observer owns generation eligibility and samples raw
// arithmetic words; its masks clear on accepted overwrite, not just reset.
// No physical last-capture observer, arbitrary read payload or internal premise
// substitutes for those generation words. Full-width cursor and reservation
// support must be asserted alongside these relations, as must original p3.
fn store_p4_basis_source() -> String {
  (
    #|  wire lc_p4_saved_read_tracked = lc_g_read_slot ? lc_g_read_tracked_1 : lc_g_read_tracked_0;
    #|  wire [31:0] lc_p4_saved_read_word = lc_g_read_slot ? lc_g_read_word_1 : lc_g_read_word_0;
    #|  always @(posedge lc_clock) begin
    #|    lc_p4_read_accept_phase: assert ((!lc_seen_edge || !lc_e_ReadAccept
    #|      || (lc_o_store_State == 3'd1 && !lc_core_response_ready)) === 1'b1);
    #|    lc_p4_read_fault_full_width: assert ((!lc_seen_edge || !lc_e_ReadAccept
    #|      || lc_expected_read_fault == lc_p4_actual_read_fault) === 1'b1);
    #|    lc_p4_read_generation_eligible: assert ((!lc_seen_edge || !lc_e_ReadAccept
    #|      || lc_expected_read_fault != 2'd0
    #|      || (lc_indexed_read_address < 6'd4 && lc_read_written[lc_indexed_read_address[1:0]]
    #|        && (lc_o_store_Slot
    #|          ? (lc_c_read_enable_1 && {4'd0, lc_c_read_address_1} == lc_indexed_read_address)
    #|          : (lc_c_read_enable_0 && {4'd0, lc_c_read_address_0} == lc_indexed_read_address)))) === 1'b1);
    #|    lc_p4_pending_generation_identity: assert ((!lc_seen_edge || (
    #|      lc_o_slotted_Pending == lc_g_read_active
    #|      && lc_e_ResponseValid == (!lc_reset && lc_g_read_active)
    #|      && (!lc_g_read_active || (lc_o_slotted_ResponseSlot == lc_g_read_slot
    #|        && lc_o_response_id == lc_g_read_id && lc_o_response_fault == lc_g_read_fault)))) === 1'b1);
    #|    lc_p4_pending_generation_basis: assert ((!lc_seen_edge || !lc_g_read_active
    #|      || lc_g_read_basis == (lc_g_read_fault == 2'd0)) === 1'b1);
    #|    lc_p4_pending_sampled_read: assert ((!lc_seen_edge || !lc_g_read_active
    #|      || lc_g_read_fault != 2'd0
    #|      || (lc_p4_saved_read_tracked && lc_p4_saved_read_word == lc_g_read_word)) === 1'b1);
    #|    lc_p4_pending_failure_zero: assert ((!lc_seen_edge || lc_reset
    #|      || !lc_g_read_active || lc_g_read_fault == 2'd0
    #|      || (lc_g_read_word == 32'd0 && lc_e_ResponseData == 32'd0)) === 1'b1);
    #|    lc_p4_pending_success_read_mux: assert ((!lc_seen_edge || lc_reset
    #|      || !lc_g_read_active || lc_g_read_fault != 2'd0
    #|      || lc_e_ResponseData == lc_p4_saved_read_word) === 1'b1);
    #|    lc_p4_grant_generation_basis: assert ((!lc_seen_edge || !lc_store_grant
    #|      || (lc_g_read_active && lc_g_read_basis && lc_e_StoreRequestValid
    #|        && lc_e_ResponseData == lc_g_read_word)) === 1'b1);
    #|    lc_p4_dma_generation_snapshot: assert ((!lc_seen_edge || !lc_g_dma_store
    #|      || (lc_arb_owner && lc_arb_write && lc_arb_bytes == 3'd4 && lc_arb_mask == 4'hf
    #|        && lc_arb_data == lc_g_dma_word && lc_arb_address == lc_g_dma_address
    #|        && lc_arb_local_tag == lc_g_dma_local_tag)) === 1'b1);
    #|    lc_p4_dma_generation_owner: assert ((!lc_seen_edge || lc_reset
    #|      || !lc_memory_request_valid || !lc_arb_owner || lc_g_dma_store) === 1'b1);
    #|    lc_p4_dma_generation_public_offer: assert ((!lc_seen_edge || lc_reset
    #|      || !lc_memory_request_valid || !lc_arb_owner
    #|      || (lc_g_dma_store && lc_memory_request_write && lc_memory_request_bytes == 3'd4
    #|        && lc_memory_request_mask == 4'hf && lc_memory_request_data == lc_g_dma_word
    #|        && lc_memory_request_address == lc_g_dma_address)) === 1'b1);
    #|  end
    #|
  )
}
