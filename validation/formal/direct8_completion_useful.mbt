///|
// Purpose-specific public Store witness, not internal engine ownership or a
// numerical matrix theorem. Only UsefulStore selects its producer premise.
fn direct8_completion_useful_source() -> String raise FormalGateError {
  let out = StringBuilder()
  for index in 0..<4 {
    out.write_string(
      "  localparam [255:0] LC_DC_SEQUENCE_\{index} = " +
      direct8_completion_packet_literal(index) +
      ";\n",
    )
  }
  let source =
    #|  logic [2:0] lc_dc_sequence_admitted = 3'd0;
    #|  logic [2:0] lc_dc_sequence_retired = 3'd0;
    #|  logic lc_dc_sequence_exact = 1'b1;
    #|  logic lc_dc_sequence_success = 1'b1;
    #|  logic [255:0] lc_dc_useful_read_addresses = 256'd0;
    #|  logic [255:0] lc_dc_useful_read_ack_addresses = 256'd0;
    #|  logic [63:0] lc_dc_useful_write_addresses = 64'd0;
    #|  logic [63:0] lc_dc_useful_write_ack_addresses = 64'd0;
    #|  logic [8:0] lc_dc_useful_read_accepts = 9'd0;
    #|  logic [8:0] lc_dc_useful_read_acks = 9'd0;
    #|  logic [6:0] lc_dc_useful_write_accepts = 7'd0;
    #|  logic [6:0] lc_dc_useful_write_acks = 7'd0;
    #|  logic lc_dc_useful_owned_good_read = 1'b0;
    #|  logic lc_dc_useful_owned_good_write = 1'b0;
    #|  logic [7:0] lc_dc_useful_owned_read_index = 8'd0;
    #|  logic [5:0] lc_dc_useful_owned_write_index = 6'd0;
    #|  wire [255:0] lc_dc_sequence_packet = lc_dc_sequence_admitted == 3'd0 ? LC_DC_SEQUENCE_0
    #|    : (lc_dc_sequence_admitted == 3'd1 ? LC_DC_SEQUENCE_1
    #|      : (lc_dc_sequence_admitted == 3'd2 ? LC_DC_SEQUENCE_2 : LC_DC_SEQUENCE_3));
    #|  wire lc_dc_public_producer_sequence = lc_descriptor_valid == (!lc_reset && lc_dc_sequence_admitted < 3'd4)
    #|    && (!lc_descriptor_valid || lc_dc_packet == lc_dc_sequence_packet);
    #|  wire lc_dc_useful_read_range_a = lc_memory_request_address >= 32'd256
    #|    && lc_memory_request_address < 32'd384;
    #|  wire lc_dc_useful_read_range_b = lc_memory_request_address >= 32'd512
    #|    && lc_memory_request_address < 32'd640;
    #|  wire [7:0] lc_dc_useful_read_index = lc_dc_useful_read_range_a
    #|    ? lc_memory_request_address - 32'd256 : lc_memory_request_address - 32'd384;
    #|  wire [5:0] lc_dc_useful_write_index = (lc_memory_request_address - 32'd1024) >> 2;
    #|  wire lc_dc_useful_read_accept = lc_dc_request_accept && !lc_dc_host_owned
    #|    && !lc_memory_request_write && lc_memory_request_bytes == 3'd1
    #|    && lc_memory_request_mask == 4'd1 && lc_memory_request_data == 32'd0
    #|    && (lc_dc_useful_read_range_a || lc_dc_useful_read_range_b);
    #|  wire lc_dc_useful_write_accept = lc_dc_request_accept && !lc_dc_host_owned
    #|    && lc_memory_request_write && lc_memory_request_bytes == 3'd4
    #|    && lc_memory_request_mask == 4'd15 && lc_memory_request_address[1:0] == 2'd0
    #|    && lc_memory_request_address >= 32'd1024 && lc_memory_request_address < 32'd1280;
    #|  wire lc_dc_useful_read_ack = lc_dc_response_accept && lc_dc_host_owned
    #|    && lc_dc_useful_owned_good_read && !lc_dc_host_write
    #|    && lc_memory_response_tag == lc_dc_host_tag && lc_memory_response_fault == 2'd0;
    #|  wire lc_dc_useful_write_ack = lc_dc_response_accept && lc_dc_host_owned
    #|    && lc_dc_useful_owned_good_write && lc_dc_host_write
    #|    && lc_memory_response_tag == lc_dc_host_tag && lc_memory_response_fault == 2'd0;
    #|  wire lc_dc_useful_store_cover = !lc_reset && lc_dc_ordinal_history
    #|    && lc_dc_ordinal_retire && lc_dc_saved_packet == LC_DC_STORE && lc_dc_age <= 14'd11718
    #|    && lc_dc_sequence_exact && lc_dc_sequence_success
    #|    && lc_dc_sequence_admitted == 3'd4 && lc_dc_sequence_retired == 3'd3
    #|    && (&lc_dc_useful_read_addresses) && (&lc_dc_useful_read_ack_addresses)
    #|    && (&lc_dc_useful_write_addresses) && (&lc_dc_useful_write_ack_addresses)
    #|    && lc_dc_useful_read_accepts == 9'd256 && lc_dc_useful_read_acks == 9'd256
    #|    && lc_dc_useful_write_accepts == 7'd64 && lc_dc_useful_write_acks == 7'd64
    #|    && lc_completion_id == 32'd73 && lc_completion_fault == 4'd0
    #|    && lc_completion_bytes_completed == 32'd256 && lc_completion_fault_address == 32'd0;
    #|  always_ff @(posedge lc_clock) begin
    #|    if (lc_reset) begin
    #|      lc_dc_sequence_admitted <= 3'd0;
    #|      lc_dc_sequence_retired <= 3'd0;
    #|      lc_dc_sequence_exact <= 1'b1;
    #|      lc_dc_sequence_success <= 1'b1;
    #|      lc_dc_useful_read_addresses <= 256'd0;
    #|      lc_dc_useful_read_ack_addresses <= 256'd0;
    #|      lc_dc_useful_write_addresses <= 64'd0;
    #|      lc_dc_useful_write_ack_addresses <= 64'd0;
    #|      lc_dc_useful_read_accepts <= 9'd0;
    #|      lc_dc_useful_read_acks <= 9'd0;
    #|      lc_dc_useful_write_accepts <= 7'd0;
    #|      lc_dc_useful_write_acks <= 7'd0;
    #|      lc_dc_useful_owned_good_read <= 1'b0;
    #|      lc_dc_useful_owned_good_write <= 1'b0;
    #|      lc_dc_useful_owned_read_index <= 8'd0;
    #|      lc_dc_useful_owned_write_index <= 6'd0;
    #|    end else begin
    #|      if (lc_dc_admit) begin
    #|        if (lc_dc_sequence_admitted >= 3'd4 || lc_dc_packet != lc_dc_sequence_packet)
    #|          lc_dc_sequence_exact <= 1'b0;
    #|        if (lc_dc_sequence_admitted < 3'd5)
    #|          lc_dc_sequence_admitted <= lc_dc_sequence_admitted + 3'd1;
    #|      end
    #|      if (lc_dc_retire) begin
    #|        if (lc_dc_sequence_retired >= 3'd4 || lc_completion_id != 32'd73
    #|          || lc_completion_fault != 4'd0 || lc_completion_fault_address != 32'd0
    #|          || lc_completion_bytes_completed != (lc_dc_sequence_retired < 3'd2 ? 32'd128
    #|            : (lc_dc_sequence_retired == 3'd2 ? 32'd0 : 32'd256)))
    #|          lc_dc_sequence_success <= 1'b0;
    #|        if (lc_dc_sequence_retired < 3'd5)
    #|          lc_dc_sequence_retired <= lc_dc_sequence_retired + 3'd1;
    #|      end
    #|      if (lc_dc_request_accept && !lc_dc_host_owned) begin
    #|        lc_dc_useful_owned_good_read <= lc_dc_useful_read_accept;
    #|        lc_dc_useful_owned_good_write <= lc_dc_useful_write_accept;
    #|        lc_dc_useful_owned_read_index <= lc_dc_useful_read_index;
    #|        lc_dc_useful_owned_write_index <= lc_dc_useful_write_index;
    #|        if (!lc_memory_request_write && lc_dc_useful_read_accepts < 9'd257)
    #|          lc_dc_useful_read_accepts <= lc_dc_useful_read_accepts + 9'd1;
    #|        if (lc_memory_request_write && lc_dc_useful_write_accepts < 7'd65)
    #|          lc_dc_useful_write_accepts <= lc_dc_useful_write_accepts + 7'd1;
    #|        if (lc_dc_useful_read_accept)
    #|          lc_dc_useful_read_addresses[lc_dc_useful_read_index] <= 1'b1;
    #|        if (lc_dc_useful_write_accept)
    #|          lc_dc_useful_write_addresses[lc_dc_useful_write_index] <= 1'b1;
    #|      end
    #|      if (lc_dc_response_accept && lc_dc_host_owned) begin
    #|        if (!lc_dc_host_write && lc_dc_useful_read_acks < 9'd257)
    #|          lc_dc_useful_read_acks <= lc_dc_useful_read_acks + 9'd1;
    #|        if (lc_dc_host_write && lc_dc_useful_write_acks < 7'd65)
    #|          lc_dc_useful_write_acks <= lc_dc_useful_write_acks + 7'd1;
    #|        if (lc_dc_useful_read_ack)
    #|          lc_dc_useful_read_ack_addresses[lc_dc_useful_owned_read_index] <= 1'b1;
    #|        if (lc_dc_useful_write_ack)
    #|          lc_dc_useful_write_ack_addresses[lc_dc_useful_owned_write_index] <= 1'b1;
    #|        lc_dc_useful_owned_good_read <= 1'b0;
    #|        lc_dc_useful_owned_good_write <= 1'b0;
    #|      end
    #|    end
    #|  end
    #|
  out.write_string(source)
  out.to_string()
}
