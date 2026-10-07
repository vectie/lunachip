///|
fn fetched_transport_proof_arbiter_source() -> String {
  (
    #|  wire lc_raw_offer = lc_o_arbiter_state == 2'd1;
    #|  wire lc_raw_wait = lc_o_arbiter_state == 2'd2;
    #|  wire lc_raw_active = lc_raw_offer || lc_raw_wait;
    #|  wire lc_reader_active = !lc_reset && lc_o_arbiter_state != 2'd3;
    #|  wire [1:0] lc_selected_owner = lc_o_arbiter_preference == 2'd0
    #|    ? (lc_i_reader_valid ? 2'd0 : (lc_i_loader_valid ? 2'd1 : 2'd2))
    #|    : lc_o_arbiter_preference == 2'd1
    #|      ? (lc_i_loader_valid ? 2'd1 : (lc_i_storer_valid ? 2'd2 : 2'd0))
    #|      : (lc_i_storer_valid ? 2'd2 : (lc_i_reader_valid ? 2'd0 : 2'd1));
    #|  wire [103:0] lc_reader_payload = {lc_i_reader_write,lc_i_reader_address,
    #|    lc_i_reader_bytes,lc_i_reader_mask,lc_i_reader_data,lc_i_reader_tag};
    #|  wire [103:0] lc_loader_payload = {lc_i_loader_write,lc_i_loader_address,
    #|    lc_i_loader_bytes,lc_i_loader_mask,lc_i_loader_data,lc_i_loader_tag};
    #|  wire [103:0] lc_storer_payload = {lc_i_storer_write,lc_i_storer_address,
    #|    lc_i_storer_bytes,lc_i_storer_mask,lc_i_storer_data,lc_i_storer_tag};
    #|  wire [103:0] lc_selected_payload = lc_selected_owner == 2'd0 ? lc_reader_payload :
    #|    lc_selected_owner == 2'd1 ? lc_loader_payload : lc_storer_payload;
    #|  wire [103:0] lc_raw_payload = {lc_o_arbiter_write,lc_o_arbiter_address,
    #|    lc_o_arbiter_bytes,lc_o_arbiter_mask,lc_o_arbiter_data,lc_o_arbiter_local_tag};
    #|  logic lc_snapshot_valid, lc_outstanding;
    #|  logic [103:0] lc_saved_payload;
    #|  logic [1:0] lc_saved_owner, lc_accepted_owner;
    #|  logic [31:0] lc_saved_global_tag, lc_accepted_global_tag, lc_accepted_local_tag;
    #|  logic [31:0] lc_public_request_count;
    #|  logic lc_seen_reader_owner,lc_seen_loader_owner,lc_seen_storer_owner;
    #|  wire lc_owned_response = lc_dut_arbiter_response_accept && lc_outstanding;
    #|  wire lc_good_response = lc_owned_response && lc_i_response_tag == lc_accepted_global_tag
    #|    && lc_i_response_fault == 2'd0;
    #|  wire lc_good_reader_byte = lc_good_response && lc_accepted_owner == 2'd0;
    #|  always @(posedge lc_clock) begin
    #|    if (lc_reset) begin
    #|      lc_snapshot_valid <= 1'b0; lc_outstanding <= 1'b0; lc_saved_payload <= 104'd0;
    #|      lc_saved_owner <= 2'd0; lc_accepted_owner <= 2'd0; lc_saved_global_tag <= 32'd0;
    #|      lc_accepted_global_tag <= 32'd0; lc_accepted_local_tag <= 32'd0; lc_public_request_count <= 32'd0;
    #|      lc_seen_reader_owner <= 1'b0; lc_seen_loader_owner <= 1'b0; lc_seen_storer_owner <= 1'b0;
    #|    end else begin
    #|      if (lc_dut_arbiter_grant) begin
    #|        lc_snapshot_valid <= 1'b1; lc_saved_payload <= lc_selected_payload;
    #|        lc_saved_owner <= lc_selected_owner; lc_saved_global_tag <= lc_o_arbiter_next_tag;
    #|      end else if (lc_dut_arbiter_response_accept) lc_snapshot_valid <= 1'b0;
    #|      // Illegal events are conclusions, never premises or history repair.
    #|      if (lc_dut_arbiter_request_accept && !lc_outstanding) begin
    #|        lc_outstanding <= 1'b1; lc_accepted_owner <= lc_saved_owner;
    #|        lc_accepted_global_tag <= lc_o_arbiter_next_tag; lc_accepted_local_tag <= lc_saved_payload[31:0];
    #|        lc_public_request_count <= lc_public_request_count + 32'd1;
    #|      end else if (lc_owned_response) lc_outstanding <= 1'b0;
    #|      if (lc_good_response) begin
    #|        if (lc_accepted_owner == 2'd0) lc_seen_reader_owner <= 1'b1;
    #|        if (lc_accepted_owner == 2'd1) lc_seen_loader_owner <= 1'b1;
    #|        if (lc_accepted_owner == 2'd2) lc_seen_storer_owner <= 1'b1;
    #|      end
    #|    end
    #|  end
    #|  wire lc_arbiter_history_ok = (lc_snapshot_valid == lc_raw_active) && (lc_outstanding == lc_raw_wait)
    #|    && lc_o_arbiter_owner < 2'd3 && lc_o_arbiter_preference < 2'd3
    #|    && lc_o_arbiter_next_tag == lc_public_request_count
    #|    && (!lc_raw_offer || lc_o_arbiter_next_tag == lc_saved_global_tag)
    #|    && (!lc_raw_wait || (lc_o_arbiter_expected_tag == lc_accepted_global_tag
    #|      && lc_accepted_global_tag == lc_saved_global_tag
    #|      && lc_o_arbiter_next_tag == lc_saved_global_tag + 32'd1
    #|      && lc_o_arbiter_owner == lc_accepted_owner && lc_o_arbiter_local_tag == lc_accepted_local_tag));
    #|  wire lc_arbiter_payload_ok = !lc_raw_active || (lc_snapshot_valid
    #|    && lc_raw_payload == lc_saved_payload && lc_o_arbiter_owner == lc_saved_owner);
    #|  wire lc_arbiter_events_ok = (!lc_dut_arbiter_request_accept || !lc_outstanding)
    #|    && (!lc_dut_arbiter_response_accept || lc_outstanding)
    #|    && !(lc_dut_arbiter_request_accept && lc_dut_arbiter_response_accept);
    #|  wire lc_malformed = lc_i_response_tag != lc_o_arbiter_expected_tag || lc_i_response_fault >= 2'd2;
    #|  wire lc_selected_ready = lc_o_arbiter_owner == 2'd0 ? lc_i_reader_response_ready :
    #|    lc_o_arbiter_owner == 2'd1 ? lc_i_loader_response_ready : lc_i_storer_response_ready;
    #|  wire lc_routes_ok = lc_dut_arbiter_offer == (!lc_reset && lc_raw_offer)
    #|    && lc_dut_arbiter_response_ready == (!lc_reset && lc_raw_wait && lc_selected_ready)
    #|    && lc_dut_arbiter_request_accept == (lc_dut_arbiter_offer && lc_i_request_ready)
    #|    && lc_dut_arbiter_response_accept == (lc_dut_arbiter_response_ready && lc_i_response_valid)
    #|    && lc_dut_reader_request_ready == (!lc_reset && lc_raw_offer && lc_o_arbiter_owner == 2'd0 && lc_i_request_ready)
    #|    && lc_dut_loader_request_ready == (!lc_reset && lc_raw_offer && lc_o_arbiter_owner == 2'd1 && lc_i_request_ready)
    #|    && lc_dut_storer_request_ready == (!lc_reset && lc_raw_offer && lc_o_arbiter_owner == 2'd2 && lc_i_request_ready)
    #|    && lc_dut_reader_response_valid == (!lc_reset && lc_raw_wait && lc_o_arbiter_owner == 2'd0 && lc_i_response_valid)
    #|    && lc_dut_loader_response_valid == (!lc_reset && lc_raw_wait && lc_o_arbiter_owner == 2'd1 && lc_i_response_valid)
    #|    && lc_dut_storer_response_valid == (!lc_reset && lc_raw_wait && lc_o_arbiter_owner == 2'd2 && lc_i_response_valid)
    #|    && lc_dut_arbiter_malformed == lc_malformed
    #|    && lc_dut_reader_response_fault == (lc_malformed ? 2'd2 : lc_i_response_fault)
    #|    && lc_dut_arbiter_poison == (!lc_reset && lc_o_arbiter_state == 2'd3);
    #|  wire lc_selection_ok = lc_dut_arbiter_grant == (!lc_reset && lc_o_arbiter_state == 2'd0
    #|      && (lc_i_reader_valid || lc_i_loader_valid || lc_i_storer_valid))
    #|    && (!lc_dut_arbiter_grant || (lc_dut_arbiter_choice == lc_selected_owner
    #|      && (lc_selected_owner == 2'd0 ? lc_i_reader_valid : lc_selected_owner == 2'd1 ? lc_i_loader_valid : lc_i_storer_valid)));
    #|
  )
}
