///|
fn fetched_transport_proof_assertions() -> ReadOnlyArray[String] {
  [
    "lc_fetched_arbiter_payload", "lc_fetched_arbiter_history", "lc_fetched_routes",
    "lc_fetched_selection", "lc_fetched_reader_structure", "lc_fetched_publication",
    "lc_fetched_reader_address", "lc_fetched_reader_assembly", "lc_fetched_edge_updates",
    "lc_fetched_reset_zero", "lc_fetched_established", "lc_fetched_nonrising_hold",
  ]
}

///|
fn fetched_transport_proof_source(
  sequential : FetchedTransportSequential,
  emitted : @rtl.EmittedDesign,
  negative~ : Bool = false,
) -> String raise {
  let out = StringBuilder()
  out.write_string(fetched_transport_proof_bindings(sequential, emitted))
  out.write_string(
    "  logic lc_seen_edge = 1'b0;\n  logic lc_previous_rising_reset = 1'b0;\n",
  )
  out.write_string(fetched_transport_proof_arbiter_source())
  out.write_string(fetched_transport_proof_reader_source())
  let checked = if negative {
    "(lc_raw_lanes ^ (lc_genuine_complete_packet ? 256'd1 : 256'd0))"
  } else {
    "lc_raw_lanes"
  }
  // Sole comparison-only mutation: lane0 bit0 after all32 genuine successful
  // byte ACKs. Original state, raw relations, shadows and other assertions agree.
  out.write_string("  wire [255:0] lc_checked_lanes = \{checked};\n")
  out.write_string(fetched_transport_proof_edge_source(sequential.probe))
  let body =
    #|  wire lc_raw_established = lc_arbiter_payload_ok && lc_arbiter_history_ok
    #|    && lc_reader_history_ok && lc_reader_structure_ok && lc_raw_assembly_ok;
    #|  always @(posedge lc_clock) begin
    #|    lc_seen_edge <= 1'b1;
    #|    lc_previous_rising_reset <= lc_reset;
    #|    lc_initial_joint_reset: assume ((lc_seen_edge || lc_reset) === 1'b1);
    #|    lc_fetched_arbiter_payload: assert ((!lc_seen_edge || lc_arbiter_payload_ok) === 1'b1);
    #|    lc_fetched_arbiter_history: assert ((!lc_seen_edge || (lc_arbiter_history_ok && lc_arbiter_events_ok)) === 1'b1);
    #|    lc_fetched_routes: assert ((!lc_seen_edge || lc_routes_ok) === 1'b1);
    #|    lc_fetched_selection: assert ((!lc_seen_edge || lc_selection_ok) === 1'b1);
    #|    lc_fetched_reader_structure: assert ((!lc_seen_edge || (lc_reader_structure_ok && lc_reader_history_ok)) === 1'b1);
    #|    lc_fetched_publication: assert ((!lc_seen_edge || lc_reader_publication_ok) === 1'b1);
    #|    lc_fetched_reader_address: assert ((!lc_seen_edge || lc_reader_address_ok) === 1'b1);
    #|    lc_fetched_reader_assembly: assert ((!lc_seen_edge || lc_checked_lanes == lc_byte_shadow) === 1'b1);
    #|    lc_fetched_edge_updates: assert ((!lc_seen_edge || lc_previous_rising_reset || lc_edge_updates_ok) === 1'b1);
    #|    lc_fetched_reset_zero: assert ((!lc_previous_rising_reset || (lc_all_reset_zero && lc_observers_reset_zero)) === 1'b1);
    #|    lc_fetched_packet_three_owners: cover (lc_genuine_complete_packet && lc_dut_reader_packet_accept
    #|      && lc_seen_reader_owner && lc_seen_loader_owner && lc_seen_storer_owner && lc_raw_established);
    #|  end
    #|  // Only actual retained registers form the666-bit hold pair. Raw peers
    #|  // may change on every global step. Later reset cannot mask raw ownership.
    #|  logic lc_seen_global = 1'b0,lc_previous_clock = 1'b0;
    #|  logic [665:0] lc_previous_actual_pair;
    #|  always @($global_clock) begin
    #|    lc_seen_global <= 1'b1; lc_previous_clock <= lc_clock;
    #|    lc_previous_actual_pair <= lc_actual_pair;
    #|    lc_fetched_established: assert ((!lc_seen_edge || lc_raw_established) === 1'b1);
    #|    lc_fetched_nonrising_hold: assert ((!lc_seen_global || (!lc_previous_clock && lc_clock)
    #|      || lc_actual_pair == lc_previous_actual_pair) === 1'b1);
    #|  end
    #|endmodule
    #|`default_nettype wire
    #|
  out.write_string(body)
  out.to_string()
}
