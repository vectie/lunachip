///|
// Eight conclusions over exact original state, with one startup-reset premise.
// The sensitivity control changes only saved request data bit0 in the checked
// comparison after a real grant and at least one committed stalled Offer edge.
// Local-tag restoration compares the actual saved local_tag driver with the
// independently captured raw grant tag. Client record tag/data aliases are
// source-reviewed contracts, not named IR ports or separate proven routes;
// no response-data stability or passthrough theorem is asserted here.
fn two_client_arbiter_proof_source(
  fixture : @flux_tile.QueueConservationFixture,
  sequential : TwoClientArbiterSequential,
  emitted : @rtl.EmittedDesign,
  negative? : Bool = false,
) -> String raise {
  let out = StringBuilder()
  out.write_string(
    two_client_arbiter_proof_bindings(fixture, sequential, emitted),
  )
  out.write_string(
    "  logic lc_seen_edge = 1'b0;\n" +
    "  logic lc_previous_rising_reset = 1'b0;\n",
  )
  out.write_string(two_client_arbiter_observer_source())
  out.write_string(two_client_arbiter_relation_source())
  let checked = if negative {
    "(lc_raw_payload ^ (lc_genuine_stalled_offer ? (104'd1 << 32) : 104'd0))"
  } else {
    "lc_raw_payload"
  }
  out.write_string("  wire [103:0] lc_checked_payload = \{checked};\n")
  out.write_string(two_client_arbiter_edge_source(sequential.probe))
  let body =
    #|  always @(posedge lc_clock) begin
    #|    lc_seen_edge <= 1'b1;
    #|    lc_previous_rising_reset <= lc_reset;
    #|    lc_initial_joint_reset: assume ((lc_seen_edge || lc_reset) === 1'b1);
    #|    lc_arbiter_payload: assert ((!lc_seen_edge || lc_reset || !lc_raw_active
    #|      || (lc_snapshot_valid && lc_checked_payload == lc_saved_payload
    #|        && lc_o_owner == lc_saved_owner)) === 1'b1);
    #|    lc_arbiter_history: assert ((!lc_seen_edge
    #|      || (lc_raw_history_ok && lc_history_events_ok)) === 1'b1);
    #|    lc_arbiter_routes: assert ((!lc_seen_edge || lc_routes_ok) === 1'b1);
    #|    lc_arbiter_arbitration: assert ((!lc_seen_edge || lc_arbitration_ok) === 1'b1);
    #|    lc_arbiter_edge_updates: assert ((!lc_seen_edge || lc_previous_rising_reset
    #|      || lc_edge_updates_ok) === 1'b1);
    #|    lc_arbiter_reset_zero: assert ((!lc_previous_rising_reset
    #|      || (lc_all_reset_zero && lc_observers_reset_zero)) === 1'b1);
    #|  end
    #|  // The established raw relation is not bypassed by later PRE reset.
    #|  // Only the original172 retained bits form this nonrising state pair;
    #|  // arbitrary raw peers and combinational events are deliberately absent.
    #|  logic lc_seen_global = 1'b0;
    #|  logic lc_previous_clock = 1'b0;
    #|  logic [171:0] lc_previous_pair;
    #|  always @($global_clock) begin
    #|    lc_seen_global <= 1'b1;
    #|    lc_previous_clock <= lc_clock;
    #|    lc_previous_pair <= lc_current_pair;
    #|    lc_arbiter_established: assert ((!lc_seen_edge || lc_raw_invariant) === 1'b1);
    #|    lc_arbiter_nonrising_hold: assert ((!lc_seen_global
    #|      || (!lc_previous_clock && lc_clock)
    #|      || lc_current_pair == lc_previous_pair) === 1'b1);
    #|  end
    #|endmodule
    #|`default_nettype wire
    #|
  out.write_string(body)
  out.to_string()
}
