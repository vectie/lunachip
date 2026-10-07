///|
// Raw establishment is reset-independent: a later reset input suppresses
// events, but cannot erase saved ownership before the synchronous edge.
fn two_client_arbiter_relation_source() -> String {
  let out = StringBuilder()
  let body =
    #|  wire lc_raw_payload_match = lc_raw_payload == lc_saved_payload;
    #|  wire lc_raw_payload_ok = !lc_raw_active || (lc_snapshot_valid
    #|    && lc_raw_payload_match && lc_o_owner == lc_saved_owner);
    #|  wire lc_raw_history_ok = (lc_snapshot_valid == lc_raw_active)
    #|    && (lc_outstanding == lc_raw_wait)
    #|    && lc_o_next_tag == lc_public_request_count
    #|    && (!lc_raw_offer || lc_o_next_tag == lc_saved_global_tag)
    #|    && (!lc_raw_wait || (lc_o_expected_tag == lc_accepted_global_tag
    #|      && lc_accepted_global_tag == lc_saved_global_tag
    #|      && lc_o_next_tag == lc_saved_global_tag + 32'd1
    #|      && lc_o_owner == lc_accepted_owner
    #|      && lc_o_local_tag == lc_accepted_local_tag));
    #|  wire lc_raw_invariant = lc_raw_payload_ok && lc_raw_history_ok;
    #|  wire lc_history_events_ok = (!lc_dut_request_accept || !lc_outstanding)
    #|    && (!lc_dut_response_accept || lc_outstanding)
    #|    && !(lc_dut_request_accept && lc_dut_response_accept)
    #|    && (!lc_dut_request_accept || (lc_snapshot_valid && lc_raw_offer))
    #|    && (!lc_dut_response_accept || lc_raw_wait);
    #|  wire lc_malformed = lc_i_response_tag != lc_o_expected_tag
    #|    || lc_i_response_fault >= 2'd2;
    #|  wire lc_routes_ok = (lc_dut_offer == (!lc_reset && lc_raw_offer))
    #|    && (lc_dut_wait_controller == (!lc_reset && lc_raw_wait))
    #|    && (lc_dut_wait_route == (!lc_reset && lc_raw_wait))
    #|    && (lc_dut_response_ready == (!lc_reset && lc_raw_wait
    #|      && (lc_o_owner ? lc_i_engine_response_ready : lc_i_reader_response_ready)))
    #|    && (lc_dut_request_accept == (lc_dut_offer && lc_i_request_ready))
    #|    && (lc_dut_response_accept == (lc_dut_response_ready && lc_i_response_valid))
    #|    && (lc_dut_reader_request_ready == (!lc_reset && lc_raw_offer
    #|      && !lc_o_owner && lc_i_request_ready))
    #|    && (lc_dut_engine_request_ready == (!lc_reset && lc_raw_offer
    #|      && lc_o_owner && lc_i_request_ready))
    #|    && !(lc_dut_reader_request_ready && lc_dut_engine_request_ready)
    #|    && (lc_dut_reader_response_valid == (!lc_reset && lc_raw_wait
    #|      && !lc_o_owner && lc_i_response_valid))
    #|    && (lc_dut_engine_response_valid == (!lc_reset && lc_raw_wait
    #|      && lc_o_owner && lc_i_response_valid))
    #|    && !(lc_dut_reader_response_valid && lc_dut_engine_response_valid)
    #|    && (lc_dut_malformed_controller == lc_malformed)
    #|    && (lc_dut_malformed_route == lc_malformed)
    #|    && (lc_dut_route_response_fault == (lc_malformed ? 2'd2 : lc_i_response_fault))
    #|    && (!lc_raw_wait || (lc_o_local_tag == lc_accepted_local_tag
    #|      && lc_o_owner == lc_accepted_owner))
    #|    && (lc_dut_poisoned == (!lc_reset && lc_o_state == 2'd3));
    #|  wire lc_arbitration_ok = (lc_dut_idle == (!lc_reset && lc_o_state == 2'd0))
    #|    && (lc_dut_grant == (!lc_reset && lc_o_state == 2'd0
    #|      && (lc_i_reader_valid || lc_i_engine_valid)))
    #|    && (lc_dut_choose_engine == lc_selected_engine)
    #|    && (!(lc_i_reader_valid && !lc_i_engine_valid) || !lc_selected_engine)
    #|    && (!(!lc_i_reader_valid && lc_i_engine_valid) || lc_selected_engine)
    #|    && (!(lc_i_reader_valid && lc_i_engine_valid)
    #|      || lc_selected_engine == lc_o_preference)
    #|    && (!lc_dut_grant || (lc_selected_engine ? lc_i_engine_valid : lc_i_reader_valid))
    #|    && (!lc_reset || (!lc_dut_grant && !lc_dut_request_accept
    #|      && !lc_dut_response_accept && !lc_dut_offer && !lc_dut_response_ready
    #|      && !lc_dut_reader_request_ready && !lc_dut_engine_request_ready
    #|      && !lc_dut_reader_response_valid && !lc_dut_engine_response_valid));
    #|  wire lc_genuine_stalled_offer = !lc_reset && lc_seen_edge
    #|    && lc_snapshot_valid && lc_stall_seen && lc_dut_offer
    #|    && lc_raw_payload_match && lc_raw_invariant;
    #|
  out.write_string(body)
  out.to_string()
}
