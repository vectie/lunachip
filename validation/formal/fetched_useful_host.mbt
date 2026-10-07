///|
fn fetched_useful_host_source() -> String raise FormalGateError {
  let packets : Array[String] = []
  for index in 0..<4 {
    packets.push(fetched_useful_packet_literal(index))
  }
  let out = StringBuilder()
  out.write_string(
    "  localparam [255:0] lc_fu_packet0 = \{packets[0]};\n" +
    "  localparam [255:0] lc_fu_packet1 = \{packets[1]};\n" +
    "  localparam [255:0] lc_fu_packet2 = \{packets[2]};\n" +
    "  localparam [255:0] lc_fu_packet3 = \{packets[3]};\n",
  )
  let body =
    #|  // One common byte-addressed host image, independent of arbiter owner.
    #|  // Data depends only on the address saved at the actual public request.
    #|  function automatic [31:0] lc_fu_host_data(input [31:0] address);
    #|    reg [255:0] packet;
    #|    begin
    #|      packet = 256'd0;
    #|      case (address[6:5])
    #|        2'd0: packet = lc_fu_packet0;
    #|        2'd1: packet = lc_fu_packet1;
    #|        2'd2: packet = lc_fu_packet2;
    #|        2'd3: packet = lc_fu_packet3;
    #|      endcase
    #|      if (address < 32'd128)
    #|        lc_fu_host_data = (packet >> (address[4:0] * 8)) & 32'd255;
    #|      else case (address)
    #|        32'd256: lc_fu_host_data = 32'd253; // signed A=-3
    #|        32'd257: lc_fu_host_data = 32'd7;
    #|        32'd512: lc_fu_host_data = 32'd5;
    #|        32'd513: lc_fu_host_data = 32'd254; // signed B=-2
    #|        default: lc_fu_host_data = 32'd0;
    #|      endcase
    #|    end
    #|  endfunction
    #|  logic lc_fu_config_seen = 1'b0, lc_fu_publish_seen = 1'b0;
    #|  logic lc_fu_owned = 1'b0;
    #|  logic [31:0] lc_fu_owned_tag = 32'd0;
    #|  logic [31:0] lc_fu_owned_address = 32'd0;
    #|  logic lc_fu_owned_write = 1'b0;
    #|  logic [2:0] lc_fu_owned_bytes = 3'd0;
    #|  logic [3:0] lc_fu_owned_mask = 4'd0;
    #|  logic [31:0] lc_fu_owned_data = 32'd0;
    #|  wire lc_fu_config_accept = !lc_reset && lc_config_valid && lc_config_ready;
    #|  wire lc_fu_publish_accept = !lc_reset && lc_publish_valid && lc_publish_ready;
    #|  // R1/H1/C1 are host availability only. H1 offers the saved successful
    #|  // response at the next PRE and holds it, irrespective of DUT readiness.
    #|  wire lc_fu_initial_only_reset = (lc_reset == !lc_seen_edge);
    #|  wire lc_fu_public_producer_r1_c1 =
    #|    (lc_config_valid == (!lc_reset && !lc_fu_config_seen)) &&
    #|    lc_config_base == 32'd0 && lc_config_origin == 32'd0 &&
    #|    (lc_publish_valid == (!lc_reset && lc_fu_config_seen && !lc_fu_publish_seen)) &&
    #|    lc_publish_producer == 32'd4 && lc_memory_request_ready && lc_completion_ready;
    #|  wire lc_fu_owned_response_offer_h1 =
    #|    (lc_memory_response_valid == (!lc_reset && lc_fu_owned)) &&
    #|    (!lc_memory_response_valid || (lc_memory_response_tag == lc_fu_owned_tag &&
    #|      lc_memory_response_fault == 2'd0 && lc_memory_response_data ==
    #|      (lc_fu_owned_write ? 32'd0 : lc_fu_host_data(lc_fu_owned_address))));
    #|  always_ff @(posedge lc_clock) begin
    #|    if (lc_reset) begin
    #|      lc_fu_config_seen <= 1'b0;
    #|      lc_fu_publish_seen <= 1'b0;
    #|      lc_fu_owned <= 1'b0;
    #|      lc_fu_owned_tag <= 32'd0;
    #|      lc_fu_owned_address <= 32'd0;
    #|      lc_fu_owned_write <= 1'b0;
    #|      lc_fu_owned_bytes <= 3'd0;
    #|      lc_fu_owned_mask <= 4'd0;
    #|      lc_fu_owned_data <= 32'd0;
    #|    end else begin
    #|      if (lc_fu_config_accept) lc_fu_config_seen <= 1'b1;
    #|      if (lc_fu_publish_accept) lc_fu_publish_seen <= 1'b1;
    #|      // An illegal second request must not overwrite the genuine owner.
    #|      if (lc_request_accept && !lc_fu_owned) begin
    #|        lc_fu_owned <= 1'b1;
    #|        lc_fu_owned_tag <= lc_memory_request_tag;
    #|        lc_fu_owned_address <= lc_memory_request_address;
    #|        lc_fu_owned_write <= lc_memory_request_write;
    #|        lc_fu_owned_bytes <= lc_memory_request_bytes;
    #|        lc_fu_owned_mask <= lc_memory_request_mask;
    #|        lc_fu_owned_data <= lc_memory_request_data;
    #|      end else if (lc_response_accept && lc_fu_owned) lc_fu_owned <= 1'b0;
    #|    end
    #|  end
    #|
  out.write_string(body)
  out.to_string()
}
