///|
// Extend only the generated public-pin wrapper. The ordinary symbolic safety
// harness and production graph/source are not changed.
fn directed_terminal_harness(
  dut : FluxTileFormalDut,
  property_source : String,
) -> String {
  let directed =
    #|  // Directed legal host profile; no assumption constrains DUT progress.
    #|  logic lc_directed_config_accepted = 1'b0;
    #|  logic lc_directed_publication_accepted = 1'b0;
    #|  logic [31:0] lc_directed_saved_address = 32'd0;
    #|  logic [31:0] lc_directed_saved_tag = 32'd0;
    #|  logic [5:0] lc_directed_requests = 6'd0;
    #|  logic [5:0] lc_directed_acks = 6'd0;
    #|  logic lc_directed_sequence_ok = 1'b1;
    #|  wire lc_directed_config_accept = !lc_reset && lc_config_valid && lc_config_ready;
    #|  wire lc_directed_publication_accept = !lc_reset && lc_publish_valid && lc_publish_ready;
    #|  // The byte image is independent of requested data, decoded packets and
    #|  // DUT ready/fault results. Addresses outside the packet return zero.
    #|  wire [31:0] lc_directed_fence_byte =
    #|    lc_directed_saved_address == 32'd513 ? 32'd2 :
    #|    lc_directed_saved_address == 32'd514 ? 32'd4 :
    #|    lc_directed_saved_address == 32'd516 ? 32'd1 : 32'd0;
    #|  wire lc_directed_request_in_sequence =
    #|    !lc_owned && !lc_response_accept && lc_directed_requests < 6'd32
    #|    && !lc_memory_request_write && lc_memory_request_bytes == 3'd1
    #|    && lc_memory_request_mask == 4'd1 && lc_memory_request_data == 32'd0
    #|    && lc_memory_request_address == (32'd512 + {26'd0, lc_directed_requests})
    #|    && lc_memory_request_tag == {26'd0, lc_directed_requests};
    #|  wire lc_directed_ack_in_sequence =
    #|    lc_owned && !lc_request_accept && lc_directed_acks < 6'd32
    #|    && lc_directed_requests == (lc_directed_acks + 6'd1)
    #|    && lc_directed_saved_address == (32'd512 + {26'd0, lc_directed_acks})
    #|    && lc_directed_saved_tag == {26'd0, lc_directed_acks}
    #|    && lc_memory_response_tag == lc_directed_saved_tag
    #|    && lc_memory_response_fault == 2'd0
    #|    && lc_memory_response_data == lc_directed_fence_byte;
    #|  always_ff @(posedge lc_clock) begin
    #|    if (lc_reset) begin
    #|      lc_directed_config_accepted <= 1'b0;
    #|      lc_directed_publication_accepted <= 1'b0;
    #|      lc_directed_saved_address <= 32'd0;
    #|      lc_directed_saved_tag <= 32'd0;
    #|      lc_directed_requests <= 6'd0;
    #|      lc_directed_acks <= 6'd0;
    #|      lc_directed_sequence_ok <= 1'b1;
    #|    end else begin
    #|      if (lc_directed_config_accept) lc_directed_config_accepted <= 1'b1;
    #|      if (lc_directed_publication_accept) lc_directed_publication_accepted <= 1'b1;
    #|      if (lc_request_accept) begin
    #|        lc_directed_saved_address <= lc_memory_request_address;
    #|        lc_directed_saved_tag <= lc_memory_request_tag;
    #|        // Saturate beyond the target; the sticky flag rejects extra work.
    #|        if (lc_directed_requests < 6'd33)
    #|          lc_directed_requests <= lc_directed_requests + 6'd1;
    #|      end
    #|      if (lc_response_accept && lc_directed_acks < 6'd33)
    #|        lc_directed_acks <= lc_directed_acks + 6'd1;
    #|      if ((lc_request_accept && !lc_directed_request_in_sequence)
    #|          || (lc_response_accept && !lc_directed_ack_in_sequence))
    #|        lc_directed_sequence_ok <= 1'b0;
    #|    end
    #|  end
    #|  wire lc_directed_initial_reset_only = lc_reset == !lc_seen_edge;
    #|  wire lc_directed_single_legal_config =
    #|    lc_config_base == 32'd512 && lc_config_origin == 32'd0
    #|    && lc_config_valid == (!lc_reset && !lc_directed_config_accepted);
    #|  wire lc_directed_single_publication =
    #|    lc_publish_producer == 32'd1
    #|    && lc_publish_valid == (!lc_reset && lc_directed_config_accepted
    #|                           && !lc_directed_publication_accepted);
    #|  wire lc_directed_unstalled_ready = lc_memory_request_ready && lc_completion_ready;
    #|  // Availability follows saved actual ownership, not DUT response-ready.
    #|  wire lc_directed_owned_response_available =
    #|    lc_memory_response_valid == (!lc_reset && lc_owned);
    #|  wire lc_directed_matching_success_response =
    #|    lc_memory_response_fault == 2'd0
    #|    && lc_memory_response_tag == (lc_owned ? lc_directed_saved_tag : 32'd0);
    #|  wire lc_directed_fence_memory_image =
    #|    lc_memory_response_data == (lc_owned ? lc_directed_fence_byte : 32'd0);
    #|  // A real retiring Fence after all 32 ordered reader transactions.
    #|  // No DUT progress, expected ready, or successful terminal is assumed.
    #|  wire lc_directed_successful_first_fence =
    #|    !lc_reset && lc_directed_config_accepted && lc_directed_publication_accepted
    #|    && lc_directed_sequence_ok && lc_directed_requests == 6'd32
    #|    && lc_directed_acks == 6'd32 && !lc_owned
    #|    && !lc_request_accept && !lc_response_accept
    #|    && lc_producer_count == 32'd1 && lc_consumer_count == 32'd1
    #|    && lc_completion_valid && lc_completion_ready
    #|    && lc_completion_id == 32'd1 && lc_completion_fault == 4'd0
    #|    && lc_completion_bytes_completed == 32'd0
    #|    && lc_completion_fault_address == 32'd0
    #|    && !lc_ring_fault_valid && !lc_transport_halted && !lc_halted;
    #|
  flux_tile_harness(PublicTransport, dut, directed + property_source).replace(
    old="  // Tag/status/data otherwise remain symbolic, including malformed responses.",
    new="  // This separate cover profile constrains a matching successful owned host.",
  )
}
