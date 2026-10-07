///|
// Read expectations come from per-generation PRODUCED words, not SRAM or the
// response under test. The actual read/identity snapshot persists only until
// core response-ready: Store Wait OR Done, not the later host ACK.
// Overlap history belongs to one indexed read and one real opposite inner
// compute acceptance. A qualified grant seals that read's history until its
// good ACK; only the completed witness survives subsequent rectangle reads.
fn store_preservation_transfer_source(negative : Bool) -> String {
  let out = StringBuilder()
  let observer =
    #|  wire lc_read_valid_fact = lc_o_store_Slot ? lc_g_valid_1 : lc_g_valid_0;
    #|  wire [3:0] lc_read_rows = lc_o_store_Slot ? lc_g_rows_1 : lc_g_rows_0;
    #|  wire [3:0] lc_read_columns = lc_o_store_Slot ? lc_g_columns_1 : lc_g_columns_0;
    #|  wire [5:0] lc_indexed_read_address = {2'd0, lc_o_store_Row[3:0]} * 6'd2 + {2'd0, lc_o_store_Column[3:0]};
    #|  wire lc_read_in_bounds = lc_o_store_Row < {9'd0, lc_read_rows} && lc_o_store_Column < {9'd0, lc_read_columns};
    #|  wire [1:0] lc_expected_read_fault = !lc_read_valid_fact ? 2'd2 : (lc_read_in_bounds ? 2'd0 : 2'd1);
    #|  wire [3:0] lc_read_written = lc_o_store_Slot ? lc_g_written_1 : lc_g_written_0;
    #|  wire [31:0] lc_selected_word_0 = (lc_indexed_read_address == 0) ? lc_g_word_0_0 : ((lc_indexed_read_address == 1) ? lc_g_word_0_1 : ((lc_indexed_read_address == 2) ? lc_g_word_0_2 : lc_g_word_0_3));
    #|  wire [31:0] lc_selected_word_1 = (lc_indexed_read_address == 0) ? lc_g_word_1_0 : ((lc_indexed_read_address == 1) ? lc_g_word_1_1 : ((lc_indexed_read_address == 2) ? lc_g_word_1_2 : lc_g_word_1_3));
    #|  wire [31:0] lc_expected_read_word = lc_expected_read_fault != 0 ? 32'd0 : (lc_o_store_Slot ? lc_selected_word_1 : lc_selected_word_0);
    #|  logic lc_g_read_active, lc_g_read_due, lc_g_read_slot, lc_g_read_basis;
    #|  logic [31:0] lc_g_read_id, lc_g_read_word;
    #|  logic [1:0] lc_g_read_fault;
    #|  logic [5:0] lc_g_read_address;
    #|  logic lc_g_store_seen, lc_g_read_seen, lc_g_pregrant_seen;
    #|  logic lc_g_opposite_intermediate, lc_g_opposite_final, lc_g_grant_seen;
    #|  logic lc_g_write_seen, lc_g_ack_seen;
    #|  logic lc_g_opposite_generation_live, lc_g_completed_overlap;
    #|  logic lc_g_dma_store;
    #|  logic [31:0] lc_g_dma_word, lc_g_dma_address, lc_g_dma_local_tag;
    #|  wire lc_store_grant = lc_arb_grant && lc_arb_choose_store;
    #|  wire lc_read_episode_identity = !lc_reset && lc_g_read_active && lc_g_read_basis
    #|    && lc_o_store_Id == lc_g_read_id && lc_o_store_Slot == lc_g_read_slot
    #|    && lc_indexed_read_address == lc_g_read_address
    #|    && lc_e_ResponseValid && lc_o_response_id == lc_g_read_id
    #|    && lc_o_slotted_ResponseSlot == lc_g_read_slot;
    #|  wire lc_pregrant_hold = !lc_reset && lc_g_read_active && lc_g_read_basis
    #|    && lc_read_episode_identity && !lc_core_response_ready
    #|    && lc_o_store_State == 3'd2 && lc_e_StoreRequestValid
    #|    && lc_arb_state == 2'd2 && !lc_arb_owner && !lc_store_grant;
    #|  wire lc_opposite_capture = lc_pregrant_hold && lc_g_opposite_generation_live
    #|    && !lc_e_SlottedLegalAccept && lc_e_Capture && lc_o_slotted_ActiveC != lc_g_read_slot;
    #|  wire lc_public_store_write = !lc_reset && lc_memory_request_valid
    #|    && lc_memory_request_ready && lc_arb_owner && lc_memory_request_write;
    #|  wire [31:0] lc_store_address = lc_o_store_Base
    #|    + {19'd0, lc_o_store_Row} * lc_o_store_Stride + {19'd0, lc_o_store_Column} * 32'd4;
    #|  always @(posedge lc_clock) begin
    #|    if (lc_reset) begin
    #|      lc_g_read_active <= 1'b0;
    #|      lc_g_read_due <= 1'b0;
    #|      lc_g_read_basis <= 1'b0;
    #|      lc_g_store_seen <= 1'b0;
    #|      lc_g_read_seen <= 1'b0;
    #|      lc_g_pregrant_seen <= 1'b0;
    #|      lc_g_opposite_intermediate <= 1'b0;
    #|      lc_g_opposite_final <= 1'b0;
    #|      lc_g_grant_seen <= 1'b0;
    #|      lc_g_write_seen <= 1'b0;
    #|      lc_g_ack_seen <= 1'b0;
    #|      lc_g_opposite_generation_live <= 1'b0;
    #|      lc_g_completed_overlap <= 1'b0;
    #|      lc_g_dma_store <= 1'b0;
    #|      // Uninitialized read/DMA/produced data snapshots stay uninitialized.
    #|    end else begin
    #|      lc_g_read_due <= lc_e_ReadAccept;
    #|      lc_g_read_active <= lc_e_ReadAccept || (lc_g_read_active && !lc_core_response_ready);
    #|      if (lc_e_ReadAccept) begin
    #|        lc_g_read_slot <= lc_o_store_Slot;
    #|        lc_g_read_id <= lc_o_store_Id;
    #|        lc_g_read_address <= lc_indexed_read_address;
    #|        lc_g_read_fault <= lc_expected_read_fault;
    #|        lc_g_read_word <= lc_expected_read_word;
    #|        lc_g_read_basis <= lc_expected_read_fault == 0
    #|          && lc_indexed_read_address < 6'd4 && lc_read_written[lc_indexed_read_address[1:0]];
    #|      end
    #|      if (lc_arb_grant) lc_g_dma_store <= lc_arb_choose_store;
    #|      if (lc_store_grant) begin
    #|        lc_g_dma_word <= lc_g_read_word;
    #|        lc_g_dma_address <= lc_store_address;
    #|        lc_g_dma_local_tag <= lc_o_store_Tag;
    #|      end
    #|      if (lc_e_StoreAccept) begin
    #|        lc_g_store_seen <= 1'b1;
    #|        lc_g_read_seen <= 1'b0;
    #|        lc_g_pregrant_seen <= 1'b0;
    #|        lc_g_opposite_intermediate <= 1'b0;
    #|        lc_g_opposite_final <= 1'b0;
    #|        lc_g_grant_seen <= 1'b0;
    #|        lc_g_write_seen <= 1'b0;
    #|        lc_g_ack_seen <= 1'b0;
    #|        lc_g_opposite_generation_live <= 1'b0;
    #|        lc_g_completed_overlap <= 1'b0;
    #|      end else if (lc_e_ReadAccept) begin
    #|        // A new word cannot inherit an earlier read's hold/capture history.
    #|        lc_g_read_seen <= lc_g_store_seen;
    #|        lc_g_pregrant_seen <= 1'b0;
    #|        lc_g_opposite_intermediate <= 1'b0;
    #|        lc_g_opposite_final <= 1'b0;
    #|        lc_g_grant_seen <= 1'b0;
    #|        lc_g_write_seen <= 1'b0;
    #|        lc_g_ack_seen <= 1'b0;
    #|        lc_g_opposite_generation_live <= lc_e_SlottedLegalAccept
    #|          && lc_o_compute_C != lc_o_store_Slot;
    #|        // The Store-epoch completed witness intentionally survives here.
    #|      end else begin
    #|        if (lc_g_store_seen && lc_g_read_seen && lc_pregrant_hold) lc_g_pregrant_seen <= 1'b1;
    #|        if (lc_e_SlottedLegalAccept) begin
    #|          // Restart unfinished overlap at ONE actual accepted generation.
    #|          lc_g_opposite_generation_live <= lc_g_read_active && !lc_core_response_ready
    #|            && !lc_g_grant_seen && lc_o_compute_C != lc_g_read_slot;
    #|          if (!lc_g_grant_seen) begin
    #|            lc_g_opposite_intermediate <= 1'b0;
    #|            lc_g_opposite_final <= 1'b0;
    #|          end
    #|        end else begin
    #|          if (lc_g_pregrant_seen && lc_opposite_capture && !lc_e_FinalCapture) lc_g_opposite_intermediate <= 1'b1;
    #|          if (lc_g_opposite_intermediate && lc_opposite_capture && lc_e_FinalCapture) lc_g_opposite_final <= 1'b1;
    #|          if (lc_g_opposite_generation_live && lc_g_opposite_final
    #|            && lc_read_episode_identity && lc_store_grant) lc_g_grant_seen <= 1'b1;
    #|        end
    #|        if (lc_g_grant_seen && lc_public_store_write) lc_g_write_seen <= 1'b1;
    #|        if (lc_g_grant_seen && lc_g_write_seen && lc_e_StoreResponseGood) begin
    #|          lc_g_ack_seen <= 1'b1;
    #|          lc_g_completed_overlap <= 1'b1;
    #|        end
    #|      end
    #|    end
    #|  end
    #|  wire lc_genuine_held_overlap = lc_seen_edge && lc_pregrant_hold
    #|    && lc_g_read_seen && lc_g_pregrant_seen && lc_g_opposite_generation_live
    #|    && lc_g_opposite_intermediate && lc_g_opposite_final && !lc_e_SlottedLegalAccept
    #|    && lc_o_slotted_Pending && lc_o_store_Id == lc_g_read_id
    #|    && lc_o_store_Slot == lc_g_read_slot && lc_indexed_read_address == lc_g_read_address
    #|    && lc_o_slotted_ResponseSlot == lc_g_read_slot
    #|    && lc_e_ResponseValid && lc_o_response_id == lc_g_read_id
    #|    && lc_o_response_fault == 0 && lc_e_ResponseData == lc_g_read_word;
    #|
  out.write_string(observer)
  let checked = if negative {
    "(lc_e_ResponseData ^ (lc_genuine_held_overlap ? 32'd1 : 32'd0))"
  } else {
    "lc_e_ResponseData"
  }
  out.write_string("  wire [31:0] lc_checked_pending_word = \{checked};\n")
  let predicates =
    #|  wire lc_pending_and_dma_payload = !lc_seen_edge || (
    #|    lc_o_slotted_Pending == lc_g_read_active
    #|    && lc_e_ResponseValid == (!lc_reset && lc_g_read_active)
    #|    && (!lc_g_read_active || (lc_o_slotted_ResponseSlot == lc_g_read_slot
    #|      && lc_o_response_id == lc_g_read_id && lc_o_response_fault == lc_g_read_fault))
    #|    && (lc_reset || !lc_g_read_active || lc_checked_pending_word == lc_g_read_word)
    #|    && (!lc_e_ReadAccept || (lc_o_store_State == 3'd1 && !lc_core_response_ready
    #|      && (lc_expected_read_fault != 0 || (lc_indexed_read_address < 6'd4 && lc_read_written[lc_indexed_read_address[1:0]]))))
    #|    && (!lc_e_ReadAccept || lc_expected_read_fault != 0
    #|      || (lc_o_store_Slot ? (lc_c_read_enable_1 && {4'd0, lc_c_read_address_1} == lc_indexed_read_address)
    #|        : (lc_c_read_enable_0 && {4'd0, lc_c_read_address_0} == lc_indexed_read_address)))
    #|    && (!lc_store_grant || (lc_g_read_active && lc_g_read_basis
    #|      && lc_e_StoreRequestValid && lc_e_ResponseData == lc_g_read_word))
    #|    && (!lc_g_dma_store || (lc_arb_owner && lc_arb_write && lc_arb_bytes == 3'd4
    #|      && lc_arb_mask == 4'hf && lc_arb_data == lc_g_dma_word
    #|      && lc_arb_address == lc_g_dma_address && lc_arb_local_tag == lc_g_dma_local_tag))
    #|    && (lc_reset || !lc_memory_request_valid || !lc_arb_owner || (lc_g_dma_store
    #|      && lc_memory_request_write && lc_memory_request_bytes == 3'd4 && lc_memory_request_mask == 4'hf
    #|      && lc_memory_request_data == lc_g_dma_word && lc_memory_request_address == lc_g_dma_address)));
    #|  wire lc_coherent_store_overlap = lc_seen_edge && !lc_reset && lc_g_store_seen
    #|    && lc_g_completed_overlap
    #|    && lc_o_store_State == 3'd4 && lc_o_store_Fault == 0
    #|    && lc_o_store_Rows == 13'd2 && lc_o_store_Columns == 13'd2 && lc_o_store_Progress == 32'd16;
    #|
  out.write_string(predicates)
  out.to_string()
}
