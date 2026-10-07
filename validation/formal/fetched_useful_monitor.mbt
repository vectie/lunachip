///|
fn fetched_useful_monitor_source() -> String {
  (
    #|  logic [7:0] lc_fu_read_accepts = 8'd0, lc_fu_read_acks = 8'd0;
    #|  logic [1:0] lc_fu_write_accepts = 2'd0, lc_fu_write_acks = 2'd0;
    #|  logic [2:0] lc_fu_retirements = 3'd0;
    #|  logic [127:0] lc_fu_descriptor_acks = 128'd0;
    #|  logic [3:0] lc_fu_operand_acks = 4'd0;
    #|  logic lc_fu_history_bad = 1'b0, lc_fu_retirement_bad = 1'b0;
    #|  logic lc_fu_numeric_write_ack = 1'b0;
    #|  wire lc_fu_retire = !lc_reset && lc_completion_valid && lc_completion_ready;
    #|  wire lc_fu_read_address = lc_memory_request_address < 32'd128 ||
    #|    lc_memory_request_address == 32'd256 || lc_memory_request_address == 32'd257 ||
    #|    lc_memory_request_address == 32'd512 || lc_memory_request_address == 32'd513;
    #|  wire lc_fu_good_read = !lc_memory_request_write && lc_fu_read_address &&
    #|    lc_memory_request_bytes == 3'd1 && lc_memory_request_mask == 4'd1 &&
    #|    lc_memory_request_data == 32'd0;
    #|  wire lc_fu_good_write = lc_memory_request_write && lc_memory_request_address == 32'd768 &&
    #|    lc_memory_request_bytes == 3'd4 && lc_memory_request_mask == 4'd15;
    #|  wire lc_fu_owned_descriptor = !lc_fu_owned_write && lc_fu_owned_address < 32'd128;
    #|  wire lc_fu_owned_operand = !lc_fu_owned_write &&
    #|    (lc_fu_owned_address == 32'd256 || lc_fu_owned_address == 32'd257 ||
    #|     lc_fu_owned_address == 32'd512 || lc_fu_owned_address == 32'd513);
    #|  wire [1:0] lc_fu_operand_index = lc_fu_owned_address == 32'd256 ? 2'd0 :
    #|    lc_fu_owned_address == 32'd257 ? 2'd1 : lc_fu_owned_address == 32'd512 ? 2'd2 : 2'd3;
    #|  wire lc_fu_owned_good_write = lc_fu_owned_write && lc_fu_owned_address == 32'd768 &&
    #|    lc_fu_owned_bytes == 3'd4 && lc_fu_owned_mask == 4'd15;
    #|  wire lc_fu_owned_good_read = (lc_fu_owned_descriptor || lc_fu_owned_operand) &&
    #|    lc_fu_owned_bytes == 3'd1 && lc_fu_owned_mask == 4'd1 && lc_fu_owned_data == 32'd0;
    #|  wire lc_fu_current_history_ok =
    #|    (!lc_request_accept || (!lc_fu_owned && !lc_response_accept &&
    #|      (lc_memory_request_write ? (lc_fu_good_write && lc_fu_write_accepts < 2'd1)
    #|       : (lc_fu_good_read && lc_fu_read_accepts < 8'd132)))) &&
    #|    (!lc_response_accept || (lc_fu_owned &&
    #|      (lc_fu_owned_write ? (lc_fu_owned_good_write && lc_fu_write_acks < lc_fu_write_accepts)
    #|       : (lc_fu_owned_good_read && lc_fu_read_acks < lc_fu_read_accepts &&
    #|         (lc_fu_owned_descriptor ? !lc_fu_descriptor_acks[lc_fu_owned_address[6:0]]
    #|          : !lc_fu_operand_acks[lc_fu_operand_index])))));
    #|  wire [31:0] lc_fu_expected_progress = lc_fu_retirements < 3'd2 ? 32'd2 :
    #|    lc_fu_retirements == 3'd2 ? 32'd0 : 32'd4;
    #|  wire lc_fu_current_retirement_ok = !lc_completion_valid ||
    #|    (lc_fu_retirements < 3'd4 && lc_completion_id == 32'd73 && lc_completion_fault == 4'd0 &&
    #|     lc_completion_bytes_completed == lc_fu_expected_progress && lc_completion_fault_address == 32'd0);
    #|  // No numeric DUT assertion: -29 is one useful finite witness only.
    #|  wire lc_fu_public_history = lc_reset || (!lc_fu_history_bad && lc_fu_current_history_ok &&
    #|    lc_fu_read_acks <= lc_fu_read_accepts && lc_fu_write_acks <= lc_fu_write_accepts);
    #|  wire lc_fu_write_identity = lc_reset || !lc_memory_request_valid ||
    #|    !lc_memory_request_write || lc_fu_good_write;
    #|  wire lc_fu_retirement_identity = lc_reset || (!lc_fu_retirement_bad && lc_fu_current_retirement_ok);
    #|  always_ff @(posedge lc_clock) begin
    #|    if (lc_reset) begin
    #|      lc_fu_read_accepts <= 8'd0; lc_fu_read_acks <= 8'd0;
    #|      lc_fu_write_accepts <= 2'd0; lc_fu_write_acks <= 2'd0;
    #|      lc_fu_retirements <= 3'd0; lc_fu_descriptor_acks <= 128'd0; lc_fu_operand_acks <= 4'd0;
    #|      lc_fu_history_bad <= 1'b0; lc_fu_retirement_bad <= 1'b0; lc_fu_numeric_write_ack <= 1'b0;
    #|    end else begin
    #|      if (!lc_fu_current_history_ok) lc_fu_history_bad <= 1'b1;
    #|      if (!lc_fu_current_retirement_ok) lc_fu_retirement_bad <= 1'b1;
    #|      if (lc_request_accept && !lc_fu_owned) begin
    #|        if (lc_memory_request_write && lc_fu_write_accepts < 2'd1)
    #|          lc_fu_write_accepts <= lc_fu_write_accepts + 2'd1;
    #|        if (!lc_memory_request_write && lc_fu_read_accepts < 8'd132)
    #|          lc_fu_read_accepts <= lc_fu_read_accepts + 8'd1;
    #|      end
    #|      if (lc_response_accept && lc_fu_owned) begin
    #|        if (lc_fu_owned_write && lc_fu_write_acks < 2'd1) begin
    #|          lc_fu_write_acks <= lc_fu_write_acks + 2'd1;
    #|          if (lc_fu_owned_good_write && lc_fu_owned_data == 32'hffffffe3)
    #|            lc_fu_numeric_write_ack <= 1'b1;
    #|        end
    #|        if (!lc_fu_owned_write && lc_fu_read_acks < 8'd132) begin
    #|          lc_fu_read_acks <= lc_fu_read_acks + 8'd1;
    #|          if (lc_fu_owned_descriptor) lc_fu_descriptor_acks[lc_fu_owned_address[6:0]] <= 1'b1;
    #|          if (lc_fu_owned_operand) lc_fu_operand_acks[lc_fu_operand_index] <= 1'b1;
    #|        end
    #|      end
    #|      if (lc_fu_retire && lc_fu_retirements < 3'd4) lc_fu_retirements <= lc_fu_retirements + 3'd1;
    #|    end
    #|  end
    #|  wire lc_fu_useful_store_cover = !lc_reset && lc_fu_config_seen && lc_fu_publish_seen &&
    #|    lc_configured && lc_producer_count == 32'd4 && lc_consumer_count == 32'd4 &&
    #|    !lc_ring_fault_valid && !lc_transport_halted && !lc_halted &&
    #|    !lc_fu_history_bad && !lc_fu_retirement_bad && lc_fu_current_history_ok && lc_fu_current_retirement_ok &&
    #|    lc_fu_read_accepts == 8'd132 && lc_fu_read_acks == 8'd132 &&
    #|    (&lc_fu_descriptor_acks) && (&lc_fu_operand_acks) && lc_fu_numeric_write_ack &&
    #|    lc_fu_write_accepts == 2'd1 && lc_fu_write_acks == 2'd1 && lc_fu_retirements == 3'd4;
    #|
  )
}
