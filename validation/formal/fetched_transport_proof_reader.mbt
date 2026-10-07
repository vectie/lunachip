///|
fn fetched_transport_proof_reader_source() -> String {
  (
    #|  logic [31:0] lc_saved_base,lc_saved_origin,lc_producer_history,lc_consumer_history;
    #|  logic lc_configured_history;
    #|  logic [31:0] lc_reader_request_count,lc_reader_expected_local_tag;
    #|  logic [5:0] lc_byte_count;
    #|  logic [255:0] lc_byte_shadow;
    #|  logic lc_byte_overflow;
    #|  wire lc_config_capture = lc_v_config_ready && lc_i_config_valid;
    #|  wire lc_publish_capture = lc_v_publish_ready && lc_i_publish_valid;
    #|  wire lc_base_aligned = lc_saved_base[4:0] == 5'd0;
    #|  wire lc_base_in_aperture = {32'd0,lc_saved_base} + 64'd128 <= 64'd1024;
    #|  wire lc_config_good = lc_reader_active && lc_o_reader_state == 3'd1
    #|    && lc_base_aligned && lc_base_in_aperture;
    #|  wire lc_config_bad = lc_reader_active && lc_o_reader_state == 3'd1
    #|    && !(lc_base_aligned && lc_base_in_aperture);
    #|  wire [31:0] lc_ring_population = lc_producer_history - lc_consumer_history;
    #|  wire lc_publication_good = lc_i_publish_producer - lc_producer_history <= 32'd4 - lc_ring_population;
    #|  wire lc_publication_bad = lc_publish_capture && !lc_publication_good;
    #|  wire lc_reader_start_expected = lc_reader_active && lc_o_reader_state == 3'd2
    #|    && lc_producer_history != lc_consumer_history && !lc_publication_bad;
    #|  wire lc_reader_request = lc_dut_arbiter_request_accept && lc_saved_owner == 2'd0;
    #|  wire lc_reader_ack = lc_dut_arbiter_response_accept && lc_accepted_owner == 2'd0;
    #|  wire lc_reader_bad_ack = lc_reader_ack && !lc_good_reader_byte;
    #|  wire lc_reader_protocol = lc_i_response_tag != lc_accepted_global_tag || lc_i_response_fault >= 2'd2;
    #|  wire lc_reader_terminal_expected = lc_config_bad || lc_publication_bad || lc_reader_bad_ack;
    #|  wire [2:0] lc_reader_fault_expected = lc_config_bad ? (lc_base_aligned ? 3'd2 : 3'd1) :
    #|    lc_publication_bad ? 3'd3 : (lc_reader_protocol ? 3'd5 : 3'd4);
    #|  wire [31:0] lc_reader_fault_address_expected = lc_config_bad ? lc_saved_base :
    #|    lc_publication_bad ? 32'd0 : lc_i_reader_address;
    #|  wire [255:0] lc_raw_lanes = {lc_o_reader_lane_3,lc_o_reader_lane_2,lc_o_reader_lane_1,lc_o_reader_lane_0};
    #|  // Assembly ordinal advances only on a genuine owned successful bus ACK.
    #|  // It is never repaired from cursor, lane contents or DUT response_good.
    #|  always @(posedge lc_clock) begin
    #|    if (lc_reset) begin
    #|      lc_saved_base <= 32'd0; lc_saved_origin <= 32'd0;
    #|      lc_producer_history <= 32'd0; lc_consumer_history <= 32'd0; lc_configured_history <= 1'b0;
    #|      lc_reader_request_count <= 32'd0; lc_reader_expected_local_tag <= 32'd0;
    #|      lc_byte_count <= 6'd0; lc_byte_shadow <= 256'd0; lc_byte_overflow <= 1'b0;
    #|    end else begin
    #|      if (lc_config_capture) begin lc_saved_base <= lc_i_config_base; lc_saved_origin <= lc_i_config_origin; end
    #|      if (lc_config_good) begin
    #|        lc_configured_history <= 1'b1; lc_producer_history <= lc_saved_origin; lc_consumer_history <= lc_saved_origin;
    #|      end else begin
    #|        if (lc_publish_capture && lc_publication_good) lc_producer_history <= lc_i_publish_producer;
    #|        if (lc_dut_reader_packet_accept) lc_consumer_history <= lc_consumer_history + 32'd1;
    #|      end
    #|      if (lc_reader_request) begin
    #|        lc_reader_expected_local_tag <= lc_reader_request_count;
    #|        lc_reader_request_count <= lc_reader_request_count + 32'd1;
    #|      end
    #|      if (lc_reader_start_expected) begin
    #|        lc_byte_count <= 6'd0; lc_byte_shadow <= 256'd0;
    #|      end else if (lc_good_reader_byte) begin
    #|        if (lc_byte_count < 6'd32) begin
    #|          lc_byte_shadow[lc_byte_count * 8 +: 8] <= lc_i_response_data[7:0];
    #|          lc_byte_count <= lc_byte_count + 6'd1;
    #|        end else lc_byte_overflow <= 1'b1;
    #|      end
    #|    end
    #|  end
    #|  wire lc_reader_history_ok = lc_o_reader_base == lc_saved_base && lc_o_reader_origin == lc_saved_origin
    #|    && lc_o_reader_producer == lc_producer_history && lc_o_reader_consumer == lc_consumer_history
    #|    && lc_o_reader_configured == lc_configured_history && lc_ring_population <= 32'd4
    #|    && lc_o_reader_tag == lc_reader_request_count && lc_o_reader_expected_tag == lc_reader_expected_local_tag;
    #|  wire lc_reader_structure_ok = lc_o_reader_state <= 3'd6 && lc_byte_count <= 6'd32 && !lc_byte_overflow
    #|    && lc_o_reader_cursor == lc_byte_count[4:0]
    #|    && (!(lc_o_reader_state >= 3'd2 && lc_o_reader_state <= 3'd5) || lc_configured_history)
    #|    && (lc_o_reader_state != 3'd5 || lc_byte_count == 6'd32)
    #|    && (!(lc_o_reader_state == 3'd3 || lc_o_reader_state == 3'd4) || lc_byte_count < 6'd32)
    #|    && (lc_o_reader_state != 3'd4 || (lc_raw_wait && lc_o_arbiter_owner == 2'd0))
    #|    && (!(lc_raw_wait && lc_o_arbiter_owner == 2'd0) || lc_o_reader_state == 3'd4)
    #|    && (!(lc_raw_offer && lc_o_arbiter_owner == 2'd0) || lc_o_reader_state == 3'd3)
    #|    && (!(lc_raw_wait && lc_o_arbiter_owner == 2'd0) || lc_o_arbiter_local_tag == lc_reader_expected_local_tag);
    #|  wire lc_reader_publication_ok =
    #|    lc_v_config_ready == (lc_reader_active && lc_o_reader_state == 3'd0)
    #|    && lc_v_publish_ready == ((lc_reader_active && lc_o_reader_state == 3'd2) || lc_dut_reader_packet_accept)
    #|    && lc_dut_reader_config_accept == lc_config_capture && lc_dut_reader_config_ok == lc_config_good
    #|    && lc_dut_reader_publish_accept == lc_publish_capture && lc_dut_reader_publication_ok == lc_publication_good
    #|    && lc_dut_reader_start == lc_reader_start_expected
    #|    && lc_dut_reader_packet_valid == (lc_reader_active && lc_o_reader_state == 3'd5)
    #|    && lc_dut_reader_packet_accept == (lc_dut_reader_packet_valid && lc_i_queue_packet_ready)
    #|    && lc_dut_reader_request_accept == lc_reader_request
    #|    && lc_dut_reader_response_accept == lc_reader_ack
    #|    && lc_dut_reader_response_good == lc_good_reader_byte
    #|    && lc_dut_reader_terminal == lc_reader_terminal_expected
    #|    && lc_i_reader_valid == (lc_reader_active && lc_o_reader_state == 3'd3)
    #|    && lc_i_reader_response_ready == (lc_reader_active && lc_o_reader_state == 3'd4);
    #|  wire [63:0] lc_reader_address_expected = {32'd0,lc_saved_base}
    #|    + ({32'd0,lc_consumer_history & 32'd3} * 64'd32) + {59'd0,lc_o_reader_cursor};
    #|  wire lc_reader_address_ok = lc_dut_reader_wide_address == lc_reader_address_expected
    #|    && lc_i_reader_address == lc_reader_address_expected[31:0]
    #|    && (!lc_i_reader_valid || (lc_configured_history && lc_base_aligned && lc_base_in_aperture
    #|      && lc_reader_address_expected + 64'd1 <= 64'd1024));
    #|  wire lc_raw_assembly_ok = lc_raw_lanes == lc_byte_shadow;
    #|  wire lc_genuine_complete_packet = !lc_reset && lc_seen_edge && lc_dut_reader_packet_valid
    #|    && lc_byte_count == 6'd32 && !lc_byte_overflow && lc_raw_assembly_ok
    #|    && lc_arbiter_payload_ok && lc_arbiter_history_ok && lc_reader_history_ok && lc_reader_structure_ok;
    #|  wire lc_observers_reset_zero = !lc_snapshot_valid && !lc_outstanding && lc_saved_payload == 104'd0
    #|    && lc_saved_owner == 2'd0 && lc_accepted_owner == 2'd0 && lc_saved_global_tag == 32'd0
    #|    && lc_accepted_global_tag == 32'd0 && lc_accepted_local_tag == 32'd0 && lc_public_request_count == 32'd0
    #|    && !lc_seen_reader_owner && !lc_seen_loader_owner && !lc_seen_storer_owner
    #|    && lc_saved_base == 32'd0 && lc_saved_origin == 32'd0 && lc_producer_history == 32'd0
    #|    && lc_consumer_history == 32'd0 && !lc_configured_history && lc_reader_request_count == 32'd0
    #|    && lc_reader_expected_local_tag == 32'd0 && lc_byte_count == 6'd0 && lc_byte_shadow == 256'd0 && !lc_byte_overflow;
    #|
  )
}
