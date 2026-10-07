///|
fn fetched_transport_proof_edge_source(probe : FetchedTransportProbe) -> String {
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
      "arbiter_grant", "arbiter_request_accept", "arbiter_response_accept", "arbiter_malformed",
    ] {
    out.write_string("  logic lc_pre_\{name};\n")
    samples.push("    lc_pre_\{name} <= lc_dut_\{name};")
  }
  for
    name in [
      "reader_active", "config_capture", "config_good", "publication_bad", "reader_start_expected",
      "reader_request", "reader_bad_ack", "good_reader_byte", "reader_terminal_expected",
    ] {
    out.write_string("  logic lc_pre_\{name};\n")
    samples.push("    lc_pre_\{name} <= lc_\{name};")
  }
  out.write_string(
    "  logic [1:0] lc_pre_selected_owner;\n  logic [103:0] lc_pre_selected_payload;\n  logic [2:0] lc_pre_fault_expected;\n  logic [31:0] lc_pre_fault_address_expected;\n  logic lc_pre_packet_accept;\n",
  )
  samples.push("    lc_pre_selected_owner <= lc_selected_owner;")
  samples.push("    lc_pre_selected_payload <= lc_selected_payload;")
  samples.push("    lc_pre_fault_expected <= lc_reader_fault_expected;")
  samples.push(
    "    lc_pre_fault_address_expected <= lc_reader_fault_address_expected;",
  )
  samples.push("    lc_pre_packet_accept <= lc_dut_reader_packet_accept;")
  let body =
    #|  wire [2:0] lc_reader_next_state_expected = !lc_pre_reader_active ? lc_pre_reader_state :
    #|    lc_pre_reader_state == 3'd0 ? (lc_pre_config_capture ? 3'd1 : 3'd0) :
    #|    lc_pre_reader_state == 3'd1 ? (lc_pre_config_good ? 3'd2 : 3'd6) :
    #|    lc_pre_reader_state == 3'd2 ? (lc_pre_publication_bad ? 3'd6 : (lc_pre_reader_start_expected ? 3'd3 : 3'd2)) :
    #|    lc_pre_reader_state == 3'd3 ? (lc_pre_reader_request ? 3'd4 : 3'd3) :
    #|    lc_pre_reader_state == 3'd4 ? (lc_pre_reader_bad_ack ? 3'd6 :
    #|      (lc_pre_good_reader_byte ? (lc_pre_reader_cursor == 5'd31 ? 3'd5 : 3'd3) : 3'd4)) :
    #|    lc_pre_reader_state == 3'd5 ? (lc_pre_publication_bad ? 3'd6 : (lc_pre_packet_accept ? 3'd2 : 3'd5)) : lc_pre_reader_state;
    #|  wire lc_edge_updates_ok =
    #|    lc_o_arbiter_state == (lc_pre_arbiter_response_accept ? (lc_pre_arbiter_malformed ? 2'd3 : 2'd0) :
    #|      lc_pre_arbiter_request_accept ? 2'd2 : lc_pre_arbiter_grant ? 2'd1 : lc_pre_arbiter_state)
    #|    && lc_o_arbiter_owner == (lc_pre_arbiter_grant ? lc_pre_selected_owner : lc_pre_arbiter_owner)
    #|    && lc_o_arbiter_preference == (lc_pre_arbiter_request_accept ?
    #|      (lc_pre_arbiter_owner == 2'd2 ? 2'd0 : lc_pre_arbiter_owner + 2'd1) : lc_pre_arbiter_preference)
    #|    && lc_o_arbiter_next_tag == lc_pre_arbiter_next_tag + (lc_pre_arbiter_request_accept ? 32'd1 : 32'd0)
    #|    && lc_o_arbiter_expected_tag == (lc_pre_arbiter_request_accept ? lc_pre_arbiter_next_tag : lc_pre_arbiter_expected_tag)
    #|    && lc_raw_payload == (lc_pre_arbiter_grant ? lc_pre_selected_payload :
    #|      {lc_pre_arbiter_write,lc_pre_arbiter_address,lc_pre_arbiter_bytes,lc_pre_arbiter_mask,lc_pre_arbiter_data,lc_pre_arbiter_local_tag})
    #|    && lc_o_reader_state == lc_reader_next_state_expected
    #|    && lc_o_reader_cursor == (lc_pre_reader_start_expected ? 5'd0 :
    #|      lc_pre_good_reader_byte ? lc_pre_reader_cursor + 5'd1 : lc_pre_reader_cursor)
    #|    && lc_o_reader_tag == lc_pre_reader_tag + (lc_pre_reader_request ? 32'd1 : 32'd0)
    #|    && lc_o_reader_expected_tag == (lc_pre_reader_request ? lc_pre_reader_tag : lc_pre_reader_expected_tag)
    #|    && lc_o_reader_fault == (lc_pre_reader_terminal_expected ? lc_pre_fault_expected : lc_pre_reader_fault)
    #|    && lc_o_reader_fault_address == (lc_pre_reader_terminal_expected ? lc_pre_fault_address_expected : lc_pre_reader_fault_address)
    #|    && (lc_pre_arbiter_state != 2'd3 || lc_o_arbiter_state == 2'd3);
    #|
  out.write_string(body)
  out.write_string(
    "  always @(posedge lc_clock) begin\n\{samples.join("\n")}\n  end\n",
  )
  out.to_string()
}
