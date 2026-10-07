///|
// Raw contenders are sampled only on an actual grant. Public history is
// updated only by the actual external request/response handshakes. None of
// these registers feeds the original component or repairs itself from state.
fn two_client_arbiter_observer_source() -> String {
  let out = StringBuilder()
  let body =
    #|  wire lc_raw_offer = lc_o_state == 2'd1;
    #|  wire lc_raw_wait = lc_o_state == 2'd2;
    #|  wire lc_raw_active = lc_raw_offer || lc_raw_wait;
    #|  wire lc_selected_engine = lc_i_engine_valid
    #|    && (!lc_i_reader_valid || lc_o_preference);
    #|  wire [103:0] lc_reader_payload = {lc_i_reader_write, lc_i_reader_address,
    #|    lc_i_reader_bytes, lc_i_reader_mask, lc_i_reader_data, lc_i_reader_tag};
    #|  wire [103:0] lc_engine_payload = {lc_i_engine_write, lc_i_engine_address,
    #|    lc_i_engine_bytes, lc_i_engine_mask, lc_i_engine_data, lc_i_engine_tag};
    #|  wire [103:0] lc_selected_payload = lc_selected_engine
    #|    ? lc_engine_payload : lc_reader_payload;
    #|  wire [103:0] lc_raw_payload = {lc_o_write, lc_o_address, lc_o_bytes,
    #|    lc_o_mask, lc_o_data, lc_o_local_tag};
    #|  logic lc_snapshot_valid;
    #|  logic [103:0] lc_saved_payload;
    #|  logic lc_saved_owner;
    #|  logic [31:0] lc_saved_global_tag;
    #|  logic lc_outstanding;
    #|  logic lc_accepted_owner;
    #|  logic [31:0] lc_accepted_global_tag;
    #|  logic [31:0] lc_accepted_local_tag;
    #|  logic [31:0] lc_public_request_count;
    #|  logic lc_stall_seen;
    #|  always @(posedge lc_clock) begin
    #|    if (lc_reset) begin
    #|      lc_snapshot_valid <= 1'b0;
    #|      lc_saved_payload <= 104'd0;
    #|      lc_saved_owner <= 1'b0;
    #|      lc_saved_global_tag <= 32'd0;
    #|      lc_outstanding <= 1'b0;
    #|      lc_accepted_owner <= 1'b0;
    #|      lc_accepted_global_tag <= 32'd0;
    #|      lc_accepted_local_tag <= 32'd0;
    #|      lc_public_request_count <= 32'd0;
    #|      lc_stall_seen <= 1'b0;
    #|    end else begin
    #|      if (lc_dut_grant) begin
    #|        lc_snapshot_valid <= 1'b1;
    #|        lc_saved_payload <= lc_selected_payload;
    #|        lc_saved_owner <= lc_selected_engine;
    #|        lc_saved_global_tag <= lc_o_next_tag;
    #|      end else if (lc_dut_response_accept) lc_snapshot_valid <= 1'b0;
    #|      if (lc_dut_request_accept) begin
    #|        lc_outstanding <= 1'b1;
    #|        lc_accepted_owner <= lc_saved_owner;
    #|        lc_accepted_global_tag <= lc_o_next_tag;
    #|        lc_accepted_local_tag <= lc_saved_payload[31:0];
    #|        lc_public_request_count <= lc_public_request_count + 32'd1;
    #|      end else if (lc_dut_response_accept) lc_outstanding <= 1'b0;
    #|      if (lc_dut_grant || lc_dut_response_accept) lc_stall_seen <= 1'b0;
    #|      else if (lc_dut_offer && !lc_i_request_ready) lc_stall_seen <= 1'b1;
    #|    end
    #|  end
    #|  wire lc_observers_reset_zero = !lc_snapshot_valid
    #|    && lc_saved_payload == 104'd0 && !lc_saved_owner
    #|    && lc_saved_global_tag == 32'd0 && !lc_outstanding
    #|    && !lc_accepted_owner && lc_accepted_global_tag == 32'd0
    #|    && lc_accepted_local_tag == 32'd0 && lc_public_request_count == 32'd0
    #|    && !lc_stall_seen;
    #|
  out.write_string(body)
  out.to_string()
}

///|
// The following PRE compares the simultaneous commit against the previous
// sampled PRE, not against freshly changed arbitrary external observations.
fn two_client_arbiter_edge_source(probe : TwoClientArbiterProbe) -> String {
  let out = StringBuilder()
  let samples : Array[String] = []
  for root in probe.roots {
    out.write_string(
      "  logic \{toggle_formal_width_range(root.signal_type.width().bits())}lc_pre_\{root.name};\n",
    )
    samples.push("    lc_pre_\{root.name} <= lc_o_\{root.name};")
  }
  for
    name in [
      "grant", "request_accept", "response_accept", "malformed_controller",
    ] {
    out.write_string("  logic lc_pre_\{name};\n")
    samples.push("    lc_pre_\{name} <= lc_dut_\{name};")
  }
  out.write_string(
    "  logic lc_pre_selected_engine;\n  logic [103:0] lc_pre_selected_payload;\n",
  )
  samples.push("    lc_pre_selected_engine <= lc_selected_engine;")
  samples.push("    lc_pre_selected_payload <= lc_selected_payload;")
  let updates : Array[String] = [
    "(lc_o_state == (lc_pre_response_accept ? (lc_pre_malformed_controller ? 2'd3 : 2'd0) : (lc_pre_request_accept ? 2'd2 : (lc_pre_grant ? 2'd1 : lc_pre_state))))",
    "(lc_o_owner == (lc_pre_grant ? lc_pre_selected_engine : lc_pre_owner))", "(lc_o_preference == (lc_pre_request_accept ? !lc_pre_owner : lc_pre_preference))",
    "(lc_o_next_tag == (lc_pre_next_tag + (lc_pre_request_accept ? 32'd1 : 32'd0)))",
    "(lc_o_expected_tag == (lc_pre_request_accept ? lc_pre_next_tag : lc_pre_expected_tag))",
    "(lc_raw_payload == (lc_pre_grant ? lc_pre_selected_payload : {lc_pre_write, lc_pre_address, lc_pre_bytes, lc_pre_mask, lc_pre_data, lc_pre_local_tag}))",
    "(lc_pre_state != 2'd3 || lc_o_state == 2'd3)",
  ]
  out.write_string("  wire lc_edge_updates_ok = \{updates.join(" && ")};\n")
  out.write_string(
    "  always @(posedge lc_clock) begin\n\{samples.join("\n")}\n  end\n",
  )
  out.to_string()
}
