///|
// A separate public producer profile. Success is observed, never assumed.
// The duplicate-ID sequence supplies actual load/compute/Store reachability,
// but it cannot stand in for arbitrary-admission eventual-completion safety.
fn direct_completion_useful_source() -> String raise FormalGateError {
  let out = StringBuilder()
  for index in 0..<4 {
    out.write_string(
      "  localparam [255:0] LC_DC_SEQUENCE_\{index} = " +
      direct_completion_packet_literal(index) +
      ";\n",
    )
  }
  let engine_counts : Array[String] = []
  for engine in 0..<3 {
    let accept = "lc_o_" + queue_role_name(EngineAccept(engine))
    let collectors : Array[String] = []
    for entry in 0..<3 {
      collectors.push("lc_o_" + queue_role_name(EntryCollector(entry, engine)))
    }
    let count = if engine == 0 { 2 } else { 1 }
    out.write_string(
      "  logic [2:0] lc_dc_engine_accept_count_\{engine} = 3'd0;\n  logic [2:0] lc_dc_engine_collect_count_\{engine} = 3'd0;\n",
    )
    out.write_string(
      "  wire lc_dc_engine_collect_\{engine} = " +
      collectors.join(" || ") +
      ";\n",
    )
    out.write_string(
      "  always_ff @(posedge lc_clock) begin\n    if (lc_reset) begin\n      lc_dc_engine_accept_count_\{engine} <= 3'd0;\n      lc_dc_engine_collect_count_\{engine} <= 3'd0;\n    end else begin\n      if (\{accept} && lc_dc_engine_accept_count_\{engine} < 3'd5)\n        lc_dc_engine_accept_count_\{engine} <= lc_dc_engine_accept_count_\{engine} + 3'd1;\n      if (lc_dc_engine_collect_\{engine} && lc_dc_engine_collect_count_\{engine} < 3'd5)\n        lc_dc_engine_collect_count_\{engine} <= lc_dc_engine_collect_count_\{engine} + 3'd1;\n    end\n  end\n",
    )
    engine_counts.push(
      "(lc_dc_engine_accept_count_\{engine} == 3'd\{count} && lc_dc_engine_collect_count_\{engine} == 3'd\{count})",
    )
  }
  out.write_string(
    "  wire lc_dc_useful_engines = " + engine_counts.join(" && ") + ";\n",
  )
  let source =
    #|  logic [2:0] lc_dc_sequence_admitted = 3'd0;
    #|  logic [2:0] lc_dc_sequence_retired = 3'd0;
    #|  logic lc_dc_sequence_exact = 1'b1;
    #|  logic lc_dc_sequence_success = 1'b1;
    #|  logic [3:0] lc_dc_useful_read_addresses = 4'd0;
    #|  logic [2:0] lc_dc_useful_read_accepts = 3'd0;
    #|  logic [2:0] lc_dc_useful_read_acks = 3'd0;
    #|  logic lc_dc_useful_owned_good_read = 1'b0;
    #|  logic lc_dc_useful_owned_good_write = 1'b0;
    #|  logic lc_dc_useful_write_seen = 1'b0;
    #|  logic lc_dc_useful_write_ack_seen = 1'b0;
    #|  wire [255:0] lc_dc_sequence_packet = lc_dc_sequence_admitted == 3'd0 ? LC_DC_SEQUENCE_0
    #|    : (lc_dc_sequence_admitted == 3'd1 ? LC_DC_SEQUENCE_1
    #|      : (lc_dc_sequence_admitted == 3'd2 ? LC_DC_SEQUENCE_2 : LC_DC_SEQUENCE_3));
    #|  wire lc_dc_public_producer_sequence = lc_descriptor_valid == (!lc_reset && lc_dc_sequence_admitted < 3'd4)
    #|    && (!lc_descriptor_valid || lc_dc_packet == lc_dc_sequence_packet);
    #|  wire lc_dc_useful_write_accept = lc_dc_request_accept && !lc_dc_host_owned
    #|    && lc_memory_request_write && lc_memory_request_address == 32'd128
    #|    && lc_memory_request_bytes == 3'd4 && lc_memory_request_mask == 4'd15;
    #|  wire lc_dc_useful_read_accept = lc_dc_request_accept && !lc_dc_host_owned
    #|    && !lc_memory_request_write && lc_memory_request_bytes == 3'd1
    #|    && lc_memory_request_mask == 4'd1 && lc_memory_request_data == 32'd0
    #|    && (lc_memory_request_address == 32'd32 || lc_memory_request_address == 32'd33
    #|      || lc_memory_request_address == 32'd64 || lc_memory_request_address == 32'd65);
    #|  wire lc_dc_useful_read_ack = lc_dc_response_accept && lc_dc_host_owned
    #|    && lc_dc_useful_owned_good_read && !lc_dc_host_write
    #|    && lc_memory_response_tag == lc_dc_host_tag && lc_memory_response_fault == 2'd0;
    #|  wire lc_dc_useful_write_ack = lc_dc_response_accept && lc_dc_host_owned
    #|    && lc_dc_useful_owned_good_write && lc_dc_host_write && lc_dc_host_address == 32'd128
    #|    && lc_memory_response_tag == lc_dc_host_tag && lc_memory_response_fault == 2'd0;
    #|  wire lc_dc_useful_store_cover = !lc_reset && lc_dc_ordinal_history
    #|    && lc_dc_ordinal_retire && lc_dc_saved_packet == LC_DC_STORE && lc_dc_age <= 8'd252
    #|    && lc_dc_sequence_exact && lc_dc_sequence_success
    #|    && lc_dc_useful_engines
    #|    && lc_dc_sequence_admitted == 3'd4 && lc_dc_sequence_retired == 3'd3
    #|    && lc_dc_useful_read_addresses == 4'd15
    #|    && lc_dc_useful_read_accepts == 3'd4 && lc_dc_useful_read_acks == 3'd4
    #|    && lc_dc_useful_write_seen && lc_dc_useful_write_ack_seen
    #|    && lc_completion_id == 32'd73 && lc_completion_fault == 4'd0
    #|    && lc_completion_bytes_completed == 32'd4 && lc_completion_fault_address == 32'd0;
    #|  always_ff @(posedge lc_clock) begin
    #|    if (lc_reset) begin
    #|      lc_dc_sequence_admitted <= 3'd0;
    #|      lc_dc_sequence_retired <= 3'd0;
    #|      lc_dc_sequence_exact <= 1'b1;
    #|      lc_dc_sequence_success <= 1'b1;
    #|      lc_dc_useful_read_addresses <= 4'd0;
    #|      lc_dc_useful_read_accepts <= 3'd0;
    #|      lc_dc_useful_read_acks <= 3'd0;
    #|      lc_dc_useful_owned_good_read <= 1'b0;
    #|      lc_dc_useful_owned_good_write <= 1'b0;
    #|      lc_dc_useful_write_seen <= 1'b0;
    #|      lc_dc_useful_write_ack_seen <= 1'b0;
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
    #|          || lc_completion_bytes_completed != (lc_dc_sequence_retired < 3'd2 ? 32'd2
    #|            : (lc_dc_sequence_retired == 3'd2 ? 32'd0 : 32'd4)))
    #|          lc_dc_sequence_success <= 1'b0;
    #|        if (lc_dc_sequence_retired < 3'd5)
    #|          lc_dc_sequence_retired <= lc_dc_sequence_retired + 3'd1;
    #|      end
    #|      if (lc_dc_request_accept && !lc_dc_host_owned) begin
    #|        lc_dc_useful_owned_good_read <= lc_dc_useful_read_accept;
    #|        lc_dc_useful_owned_good_write <= lc_dc_useful_write_accept;
    #|        if (lc_dc_useful_write_accept) lc_dc_useful_write_seen <= 1'b1;
    #|        if (lc_dc_useful_read_accept) begin
    #|          if (lc_dc_useful_read_accepts < 3'd5)
    #|            lc_dc_useful_read_accepts <= lc_dc_useful_read_accepts + 3'd1;
    #|          case (lc_memory_request_address)
    #|            32'd32: lc_dc_useful_read_addresses[0] <= 1'b1;
    #|            32'd33: lc_dc_useful_read_addresses[1] <= 1'b1;
    #|            32'd64: lc_dc_useful_read_addresses[2] <= 1'b1;
    #|            32'd65: lc_dc_useful_read_addresses[3] <= 1'b1;
    #|            default: lc_dc_useful_read_addresses <= lc_dc_useful_read_addresses;
    #|          endcase
    #|        end
    #|      end
    #|      if (lc_dc_response_accept && lc_dc_host_owned) begin
    #|        if (lc_dc_useful_read_ack && lc_dc_useful_read_acks < 3'd5)
    #|          lc_dc_useful_read_acks <= lc_dc_useful_read_acks + 3'd1;
    #|        if (lc_dc_useful_write_ack) lc_dc_useful_write_ack_seen <= 1'b1;
    #|        lc_dc_useful_owned_good_read <= 1'b0;
    #|        lc_dc_useful_owned_good_write <= 1'b0;
    #|      end
    #|    end
    #|  end
    #|
  out.write_string(source)
  out.to_string()
}
