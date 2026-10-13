///|
// Compose both original synchronous read results with saved pending identity.
// A tracked basis denotes a physically captured cell, not an assumed valid
// generation. Publication-to-complete-generation coverage remains separate.
fn store_payload_pending_source() -> String {
  (
    #|  wire lc_payload_read_slot = lc_o_store_Slot;
    #|  wire lc_payload_read_valid = lc_payload_read_slot ? lc_o_result_valid_1 : lc_o_result_valid_0;
    #|  wire [3:0] lc_payload_read_rows = lc_payload_read_slot ? lc_o_result_rows_1 : lc_o_result_rows_0;
    #|  wire [3:0] lc_payload_read_columns = lc_payload_read_slot ? lc_o_result_columns_1 : lc_o_result_columns_0;
    #|  wire lc_payload_read_bounds = lc_o_store_Row[3:0] < lc_payload_read_rows
    #|    && lc_o_store_Column[3:0] < lc_payload_read_columns;
    #|  wire [1:0] lc_payload_read_fault = !lc_payload_read_valid ? 2'd2 : (lc_payload_read_bounds ? 2'd0 : 2'd1);
    #|  wire lc_payload_read_basis = lc_payload_read_fault == 2'd0
    #|    && (lc_payload_read_slot ? lc_payload_written_1[lc_c_read_address_1] : lc_payload_written_0[lc_c_read_address_0]);
    #|  wire [31:0] lc_payload_next_word = lc_payload_read_slot ? lc_payload_selected_1 : lc_payload_selected_0;
    #|  logic lc_payload_pending_active, lc_payload_pending_slot, lc_payload_pending_basis;
    #|  logic [31:0] lc_payload_pending_id, lc_payload_pending_word;
    #|  logic [1:0] lc_payload_pending_fault;
    #|  always @(posedge lc_clock) begin
    #|    if (lc_reset) begin
    #|      lc_payload_pending_active <= 1'b0;
    #|      lc_payload_pending_basis <= 1'b0;
    #|    end else begin
    #|      lc_payload_pending_active <= lc_e_ReadAccept || (lc_payload_pending_active && !lc_lease_core_response_ready);
    #|      if (lc_e_ReadAccept) begin
    #|        lc_payload_pending_slot <= lc_payload_read_slot;
    #|        lc_payload_pending_id <= lc_o_store_Id;
    #|        lc_payload_pending_fault <= lc_payload_read_fault;
    #|        lc_payload_pending_basis <= lc_payload_read_basis;
    #|        lc_payload_pending_word <= lc_payload_next_word;
    #|      end
    #|    end
    #|  end
    #|  always @(posedge lc_clock) begin
    #|    lc_payload_pending_identity: assert ((!lc_seen_edge || (
    #|      lc_o_slotted_Pending == lc_payload_pending_active
    #|      && lc_e_ResponseValid == (!lc_reset && lc_payload_pending_active)
    #|      && (!lc_payload_pending_active || (lc_o_slotted_ResponseSlot == lc_payload_pending_slot
    #|        && lc_o_response_id == lc_payload_pending_id && lc_o_response_fault == lc_payload_pending_fault)))) === 1'b1);
    #|    lc_payload_pending_captured_word: assert ((!lc_seen_edge || lc_reset
    #|      || !lc_payload_pending_active || !lc_payload_pending_basis
    #|      || lc_e_ResponseData == lc_payload_pending_word) === 1'b1);
    #|    lc_payload_pending_read_hold: assert ((!lc_seen_edge || !lc_payload_pending_active
    #|      || !lc_payload_pending_basis || (lc_payload_pending_slot
    #|        ? (lc_payload_read_tracked_1 && lc_payload_read_word_1 == lc_payload_pending_word)
    #|        : (lc_payload_read_tracked_0 && lc_payload_read_word_0 == lc_payload_pending_word))) === 1'b1);
    #|    lc_payload_read_port_selected: assert ((!lc_e_ReadAccept || lc_payload_read_fault != 2'd0
    #|      || (lc_payload_read_slot ? lc_c_read_enable_1 : lc_c_read_enable_0)) === 1'b1);
    #|  end
    #|
  )
}

///|
// The DMA snapshot samples the actual core response only on a genuine Store
// grant. It does not replace the read result or supply a free read payload.
// This local transfer lemma is not itself capture-origin preservation.
fn store_payload_dma_source() -> String {
  (
    #|  wire lc_payload_store_grant = lc_arb_grant && lc_arb_choose_store;
    #|  wire [31:0] lc_payload_store_address = lc_o_store_Base
    #|    + {19'd0, lc_o_store_Row} * lc_o_store_Stride + {19'd0, lc_o_store_Column} * 32'd4;
    #|  logic lc_payload_dma_store;
    #|  logic [31:0] lc_payload_dma_word, lc_payload_dma_address, lc_payload_dma_local_tag;
    #|  always @(posedge lc_clock) begin
    #|    if (lc_reset) lc_payload_dma_store <= 1'b0;
    #|    else begin
    #|      if (lc_arb_grant) lc_payload_dma_store <= lc_arb_choose_store;
    #|      if (lc_payload_store_grant) begin
    #|        lc_payload_dma_word <= lc_e_ResponseData;
    #|        lc_payload_dma_address <= lc_payload_store_address;
    #|        lc_payload_dma_local_tag <= lc_o_store_Tag;
    #|      end
    #|    end
    #|  end
    #|  always @(posedge lc_clock) begin
    #|    lc_payload_dma_genuine_grant: assert ((!lc_payload_store_grant || (
    #|      lc_e_StoreRequestValid && lc_e_ResponseValid && lc_o_response_fault == 2'd0
    #|      && lc_o_response_id == lc_o_store_Id)) === 1'b1);
    #|    lc_payload_dma_snapshot: assert ((!lc_seen_edge || !lc_payload_dma_store || (
    #|      lc_arb_owner && lc_arb_write && lc_arb_bytes == 3'd4 && lc_arb_mask == 4'hf
    #|      && lc_arb_data == lc_payload_dma_word && lc_arb_address == lc_payload_dma_address
    #|      && lc_arb_local_tag == lc_payload_dma_local_tag)) === 1'b1);
    #|    lc_payload_dma_owner_history: assert ((!lc_seen_edge || lc_reset
    #|      || !lc_memory_request_valid || !lc_arb_owner || lc_payload_dma_store) === 1'b1);
    #|    lc_payload_dma_public_offer: assert ((!lc_seen_edge || lc_reset
    #|      || !lc_memory_request_valid || !lc_arb_owner || (
    #|      lc_memory_request_write && lc_memory_request_bytes == 3'd4 && lc_memory_request_mask == 4'hf
    #|      && lc_memory_request_data == lc_payload_dma_word
    #|      && lc_memory_request_address == lc_payload_dma_address)) === 1'b1);
    #|  end
    #|
  )
}

///|
// The end-to-end expectation is sampled from the independent raw-producer
// capture/read observer, NOT ResponseData or arbiter data under test. A genuine
// successful captured-read basis is retained through grant and public writes.
// No conclusion assumes every published rectangle already supplies that basis.
fn store_payload_composition_source() -> String {
  (
    #|  logic lc_payload_origin_basis;
    #|  logic [31:0] lc_payload_origin_word;
    #|  always @(posedge lc_clock) begin
    #|    if (lc_reset) lc_payload_origin_basis <= 1'b0;
    #|    else begin
    #|      if (lc_arb_grant) lc_payload_origin_basis <= lc_arb_choose_store
    #|        && lc_payload_pending_active && lc_payload_pending_basis;
    #|      if (lc_payload_store_grant) lc_payload_origin_word <= lc_payload_pending_word;
    #|    end
    #|  end
    #|  always @(posedge lc_clock) begin
    #|    lc_payload_origin_grant: assert ((!lc_seen_edge || !lc_payload_store_grant
    #|      || !lc_payload_pending_basis || (lc_payload_pending_active
    #|      && lc_e_ResponseData == lc_payload_pending_word)) === 1'b1);
    #|    lc_payload_origin_arbiter: assert ((!lc_seen_edge || !lc_payload_origin_basis
    #|      || (lc_payload_dma_store && lc_arb_owner && lc_arb_data == lc_payload_origin_word)) === 1'b1);
    #|    lc_payload_origin_public_write: assert ((!lc_seen_edge || lc_reset
    #|      || !lc_memory_request_valid || !lc_arb_owner || !lc_payload_origin_basis
    #|      || (lc_memory_request_write && lc_memory_request_data == lc_payload_origin_word)) === 1'b1);
    #|  end
    #|
  )
}
