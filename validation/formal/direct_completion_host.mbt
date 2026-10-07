///|
// Host-only availability bounds. No equation assumes request persistence,
// response readiness, dependencies, engine progress, leases or terminal state.
fn direct_completion_host_source() -> String {
  let source =
    #|  logic lc_dc_seen_edge = 1'b0;
    #|  assign lc_reset = !lc_dc_seen_edge;
    #|  logic lc_dc_descriptor_hold = 1'b0;
    #|  logic lc_dc_response_hold = 1'b0;
    #|  logic lc_dc_request_hold = 1'b0;
    #|  logic lc_dc_completion_hold = 1'b0;
    #|  logic [255:0] lc_dc_previous_descriptor = 256'd0;
    #|  logic [65:0] lc_dc_previous_response = 66'd0;
    #|  logic [103:0] lc_dc_previous_request = 104'd0;
    #|  logic [99:0] lc_dc_previous_completion = 100'd0;
    #|  logic lc_dc_host_owned = 1'b0;
    #|  logic lc_dc_response_offered = 1'b0;
    #|  logic [1:0] lc_dc_response_age = 2'd0;
    #|  logic [31:0] lc_dc_host_tag = 32'd0;
    #|  logic lc_dc_host_write = 1'b0;
    #|  logic [31:0] lc_dc_host_address = 32'd0;
    #|  wire [255:0] lc_dc_packet = {lc_descriptor_lane_3,
    #|    lc_descriptor_lane_2, lc_descriptor_lane_1, lc_descriptor_lane_0};
    #|  wire [65:0] lc_dc_response_payload = {lc_memory_response_tag,
    #|    lc_memory_response_fault, lc_memory_response_data};
    #|  wire [103:0] lc_dc_request_payload = {lc_memory_request_write,
    #|    lc_memory_request_address, lc_memory_request_bytes, lc_memory_request_mask,
    #|    lc_memory_request_data, lc_memory_request_tag};
    #|  wire [99:0] lc_dc_completion_payload = {lc_completion_id,
    #|    lc_completion_fault, lc_completion_bytes_completed, lc_completion_fault_address};
    #|  wire lc_dc_admit = !lc_reset && lc_descriptor_valid && lc_descriptor_ready;
    #|  wire lc_dc_retire = !lc_reset && lc_completion_valid && lc_completion_ready;
    #|  wire lc_dc_request_accept = !lc_reset && lc_memory_request_valid && lc_memory_request_ready;
    #|  wire lc_dc_response_accept = !lc_reset && lc_memory_response_valid && lc_memory_response_ready;
    #|  wire lc_dc_initial_only_reset = lc_reset == !lc_dc_seen_edge;
    #|  wire lc_dc_host_descriptor_stable = lc_reset || !lc_dc_descriptor_hold
    #|    || (lc_descriptor_valid && lc_dc_packet == lc_dc_previous_descriptor);
    #|  wire lc_dc_host_owned_success_response = !lc_memory_response_valid
    #|    || (!lc_reset && lc_dc_host_owned && lc_memory_response_tag == lc_dc_host_tag
    #|      && lc_memory_response_fault == 2'd0);
    #|  wire lc_dc_host_response_stable = lc_reset || !lc_dc_response_hold
    #|    || (lc_memory_response_valid && lc_dc_response_payload == lc_dc_previous_response);
    #|  // R=2 and C=2: first offer may stall; the next opportunity must be ready.
    #|  wire lc_dc_host_request_ready_r2 = lc_reset || !lc_dc_request_hold || lc_memory_request_ready;
    #|  wire lc_dc_host_completion_ready_c2 = lc_reset || !lc_dc_completion_hold || lc_completion_ready;
    #|  // H=2 constrains OFFER, even when the DUT wrongly keeps response_ready low.
    #|  wire lc_dc_host_response_offer_h2 = lc_reset || !lc_dc_host_owned
    #|    || lc_dc_response_offered || lc_dc_response_age < 2'd2 || lc_memory_response_valid;
    #|  wire lc_dc_request_stable = lc_reset || !lc_dc_request_hold
    #|    || (lc_memory_request_valid && lc_dc_request_payload == lc_dc_previous_request);
    #|  wire lc_dc_completion_stable = lc_reset || !lc_dc_completion_hold
    #|    || (lc_completion_valid && lc_dc_completion_payload == lc_dc_previous_completion);
    #|  wire lc_dc_transport_serial_owned = lc_reset
    #|    || ((!lc_dc_request_accept || !lc_dc_host_owned)
    #|      && (!lc_memory_response_ready || lc_dc_host_owned)
    #|      && !(lc_dc_request_accept && lc_dc_response_accept));
    #|  // This is a DUT conclusion, never a host response-acceptance assumption.
    #|  wire lc_dc_response_readiness = lc_reset || !lc_dc_host_owned || lc_memory_response_ready;
    #|  always_ff @(posedge lc_clock) begin
    #|    lc_dc_seen_edge <= 1'b1;
    #|    if (lc_reset) begin
    #|      lc_dc_descriptor_hold <= 1'b0;
    #|      lc_dc_response_hold <= 1'b0;
    #|      lc_dc_request_hold <= 1'b0;
    #|      lc_dc_completion_hold <= 1'b0;
    #|      lc_dc_previous_descriptor <= 256'd0;
    #|      lc_dc_previous_response <= 66'd0;
    #|      lc_dc_previous_request <= 104'd0;
    #|      lc_dc_previous_completion <= 100'd0;
    #|      lc_dc_host_owned <= 1'b0;
    #|      lc_dc_response_offered <= 1'b0;
    #|      lc_dc_response_age <= 2'd0;
    #|      lc_dc_host_tag <= 32'd0;
    #|      lc_dc_host_write <= 1'b0;
    #|      lc_dc_host_address <= 32'd0;
    #|    end else begin
    #|      lc_dc_descriptor_hold <= lc_descriptor_valid && !lc_descriptor_ready;
    #|      lc_dc_response_hold <= lc_memory_response_valid && !lc_memory_response_ready;
    #|      lc_dc_request_hold <= lc_memory_request_valid && !lc_memory_request_ready;
    #|      lc_dc_completion_hold <= lc_completion_valid && !lc_completion_ready;
    #|      lc_dc_previous_descriptor <= lc_dc_packet;
    #|      lc_dc_previous_response <= lc_dc_response_payload;
    #|      lc_dc_previous_request <= lc_dc_request_payload;
    #|      lc_dc_previous_completion <= lc_dc_completion_payload;
    #|      // Never overwrite the genuine saved owner after an illegal second request.
    #|      if (lc_dc_request_accept && !lc_dc_host_owned) begin
    #|        lc_dc_host_owned <= 1'b1;
    #|        lc_dc_host_tag <= lc_memory_request_tag;
    #|        lc_dc_host_write <= lc_memory_request_write;
    #|        lc_dc_host_address <= lc_memory_request_address;
    #|        lc_dc_response_age <= 2'd1;
    #|        lc_dc_response_offered <= 1'b0;
    #|      end else if (lc_dc_host_owned) begin
    #|        if (lc_memory_response_valid) lc_dc_response_offered <= 1'b1;
    #|        if (!lc_dc_response_offered && lc_dc_response_age < 2'd2)
    #|          lc_dc_response_age <= lc_dc_response_age + 2'd1;
    #|        if (lc_dc_response_accept) begin
    #|          lc_dc_host_owned <= 1'b0;
    #|          lc_dc_response_offered <= 1'b0;
    #|          lc_dc_response_age <= 2'd0;
    #|        end
    #|      end
    #|    end
    #|  end
    #|
  source
}
