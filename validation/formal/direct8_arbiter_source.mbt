///|
fn direct8_arbiter_property_names() -> ReadOnlyArray[String] {
  [
    "d8g_grant_offer", "d8g_snapshot_hold", "d8g_owner_history", "d8g_routes", "d8g_grant_policy",
    "d8g_preference", "d8g_no_poison", "d8g_local_service_t6", "d8g_client_service_2t",
    "d8g_regrant_t6", "d8g_watcher_history", "d8g_head_progress", "d8g_engine_done_release",
    "d8g_collector_commit",
  ]
}

///|
// Proof observers only. No assignment drives an original node or a memory.
// Raw aliases are original production expressions, not free client inputs.
fn direct8_arbiter_source() -> String {
  let out = StringBuilder()
  let body =
    #|  wire [103:0] lc_g_payload = {lc_g_r_write, lc_g_r_address, lc_g_r_bytes,
    #|    lc_g_r_mask, lc_g_r_data, lc_g_r_local_tag};
    #|  wire [103:0] lc_g_reader_payload = {lc_g_i_reader_write, lc_g_i_reader_address,
    #|    lc_g_i_reader_bytes, lc_g_i_reader_mask, lc_g_i_reader_data, lc_g_i_reader_tag};
    #|  wire [103:0] lc_g_engine_payload = {lc_g_i_engine_write, lc_g_i_engine_address,
    #|    lc_g_i_engine_bytes, lc_g_i_engine_mask, lc_g_i_engine_data, lc_g_i_engine_tag};
    #|  logic lc_g_active = 1'b0, lc_g_accepted = 1'b0, lc_g_previous_grant = 1'b0;
    #|  logic lc_g_saved_owner = 1'b0, lc_g_saved_preference = 1'b0;
    #|  logic [103:0] lc_g_saved_payload = 104'd0;
    #|  logic [31:0] lc_g_saved_global_tag = 32'd0;
    #|  logic [2:0] lc_g_service_age = 3'd0;
    #|  wire lc_g_raw_offer = lc_g_r_state == 2'd1;
    #|  wire lc_g_raw_wait = lc_g_r_state == 2'd2;
    #|  wire lc_g_reader_ack = lc_g_e_reader_response_valid && lc_g_i_reader_response_ready;
    #|  wire lc_g_engine_ack = lc_g_e_engine_response_valid && lc_g_i_engine_response_ready;
    #|  wire lc_d8g_grant_offer = lc_g_reset || !lc_g_previous_grant
    #|    || (lc_g_raw_offer && lc_g_r_owner == lc_g_saved_owner
    #|      && lc_g_payload == lc_g_saved_payload);
    #|  wire lc_d8g_snapshot_hold = lc_g_reset || !lc_g_active
    #|    || (lc_g_payload == lc_g_saved_payload && lc_g_r_owner == lc_g_saved_owner);
    #|  wire lc_d8g_owner_history = lc_g_reset
    #|    || (lc_g_active == (lc_g_raw_offer || lc_g_raw_wait)
    #|      && lc_g_accepted == lc_g_raw_wait
    #|      && (!lc_g_accepted || lc_g_r_expected_tag == lc_g_saved_global_tag));
    #|  wire lc_d8g_routes = lc_g_reset
    #|    || ((lc_g_e_reader_request_ready == (lc_g_raw_offer && !lc_g_r_owner && lc_g_i_request_ready))
    #|      && (lc_g_e_engine_request_ready == (lc_g_raw_offer && lc_g_r_owner && lc_g_i_request_ready))
    #|      && (lc_g_e_reader_response_valid == (lc_g_raw_wait && !lc_g_r_owner && lc_g_i_response_valid))
    #|      && (lc_g_e_engine_response_valid == (lc_g_raw_wait && lc_g_r_owner && lc_g_i_response_valid))
    #|      && (lc_g_e_response_accept == (lc_g_reader_ack || lc_g_engine_ack))
    #|      && !(lc_g_reader_ack && lc_g_engine_ack)
    #|      && (!lc_g_e_response_accept || (lc_g_accepted
    #|        && lc_g_i_response_tag == lc_g_saved_global_tag
    #|        && lc_g_e_route_response_fault == 2'd0)));
    #|  wire lc_g_selected = lc_g_i_engine_valid && (!lc_g_i_reader_valid || lc_g_r_preference);
    #|  wire lc_d8g_grant_policy = lc_g_reset
    #|    || ((lc_g_e_grant == (lc_g_r_state == 2'd0 && (lc_g_i_reader_valid || lc_g_i_engine_valid)))
    #|      && lc_g_e_choose_engine == lc_g_selected
    #|      && (!lc_g_e_grant || (lc_g_selected ? lc_g_i_engine_valid : lc_g_i_reader_valid)));
    #|  wire lc_d8g_preference = lc_g_reset || lc_g_r_preference == lc_g_saved_preference;
    #|  wire lc_d8g_no_poison = lc_g_reset || lc_g_r_state != 2'd3;
    #|  wire lc_d8g_local_service_t6 = lc_g_reset
    #|    || ((lc_g_active ? lc_g_service_age != 3'd0 : lc_g_service_age == 3'd0)
    #|      && (!lc_g_active || lc_g_e_response_accept || lc_g_service_age < 3'd6));
    #|  always @(posedge lc_g_clock) begin
    #|    if (lc_g_reset) begin
    #|      lc_g_active <= 1'b0; lc_g_accepted <= 1'b0; lc_g_previous_grant <= 1'b0;
    #|      lc_g_saved_owner <= 1'b0; lc_g_saved_preference <= 1'b0;
    #|      lc_g_saved_payload <= 104'd0; lc_g_saved_global_tag <= 32'd0;
    #|      lc_g_service_age <= 3'd0;
    #|    end else begin
    #|      lc_g_previous_grant <= lc_g_e_grant;
    #|      if (lc_g_e_grant) begin
    #|        lc_g_active <= 1'b1; lc_g_saved_owner <= lc_g_e_choose_engine;
    #|        lc_g_saved_payload <= lc_g_e_choose_engine ? lc_g_engine_payload : lc_g_reader_payload;
    #|        lc_g_saved_global_tag <= lc_g_r_next_tag; lc_g_service_age <= 3'd1;
    #|      end else if (lc_g_e_response_accept) begin
    #|        lc_g_active <= 1'b0; lc_g_service_age <= 3'd0;
    #|      end else if (lc_g_active && lc_g_service_age < 3'd7)
    #|        lc_g_service_age <= lc_g_service_age + 3'd1;
    #|      if (lc_g_e_request_accept) begin
    #|        lc_g_accepted <= 1'b1; lc_g_saved_preference <= !lc_g_r_owner;
    #|      end else if (lc_g_e_response_accept) lc_g_accepted <= 1'b0;
    #|    end
    #|  end
    #|
  out.write_string(body)
  for (index, prefix) in [(0, "reader"), (1, "engine")] {
    out.write_string(direct8_arbiter_client_source(index, prefix))
  }
  out.write_string(
    "  wire lc_d8g_client_service_2t = lc_g_reset || (lc_g_c0_service && lc_g_c1_service);\n",
  )
  out.write_string(
    "  wire lc_d8g_regrant_t6 = lc_g_reset || (lc_g_c0_regrant && lc_g_c1_regrant);\n",
  )
  out.write_string(
    "  wire lc_d8g_watcher_history = lc_g_reset || (lc_g_c0_history && lc_g_c1_history);\n",
  )
  out.write_string(direct8_queue_progress_source())
  out.to_string()
}

///|
fn direct8_arbiter_client_source(index : Int, prefix : String) -> String {
  let owner = if index == 1 { "lc_g_r_owner" } else { "!lc_g_r_owner" }
  let choice = if index == 1 {
    "lc_g_e_choose_engine"
  } else {
    "!lc_g_e_choose_engine"
  }
  let text =
    $|  logic lc_g_c\{index}_active = 1'b0, lc_g_c\{index}_accepted = 1'b0, lc_g_c\{index}_granted = 1'b0;
    $|  logic [3:0] lc_g_c\{index}_age = 4'd0;
    $|  wire lc_g_c\{index}_valid = lc_g_i_\{prefix}_valid;
    $|  wire lc_g_c\{index}_grant = lc_g_e_grant && (\{choice});
    $|  wire lc_g_c\{index}_request = lc_g_c\{index}_valid && lc_g_e_\{prefix}_request_ready;
    $|  wire lc_g_c\{index}_ack = lc_g_\{prefix}_ack;
    $|  wire lc_g_c\{index}_cancel = lc_g_c\{index}_active && !lc_g_c\{index}_accepted && !lc_g_c\{index}_valid;
    $|  wire lc_g_c\{index}_service = !lc_g_c\{index}_active || lc_g_c\{index}_cancel
    $|    || lc_g_c\{index}_ack || lc_g_c\{index}_age < 4'd12;
    $|  wire lc_g_c\{index}_regrant = !lc_g_c\{index}_active || lc_g_c\{index}_cancel
    $|    || lc_g_c\{index}_granted || lc_g_c\{index}_grant || lc_g_c\{index}_age < 4'd6;
    $|  wire lc_g_c\{index}_history = (!lc_g_c\{index}_active
    $|      ? (!lc_g_c\{index}_accepted && !lc_g_c\{index}_granted && lc_g_c\{index}_age == 4'd0)
    $|      : lc_g_c\{index}_age != 4'd0)
    $|    && (!lc_g_c\{index}_accepted || (lc_g_c\{index}_granted && lc_g_raw_wait && (\{owner})))
    $|    && (!lc_g_c\{index}_granted || (lc_g_c\{index}_active
    $|      && (lc_g_c\{index}_accepted || lc_g_raw_offer) && (\{owner})));
    $|  always @(posedge lc_g_clock) begin
    $|    if (lc_g_reset || lc_g_c\{index}_ack || lc_g_c\{index}_cancel) begin
    $|      lc_g_c\{index}_active <= 1'b0; lc_g_c\{index}_accepted <= 1'b0;
    $|      lc_g_c\{index}_granted <= 1'b0; lc_g_c\{index}_age <= 4'd0;
    $|    end else if (!lc_g_c\{index}_active && lc_g_c\{index}_valid) begin
    $|      lc_g_c\{index}_active <= 1'b1; lc_g_c\{index}_age <= 4'd1;
    $|      lc_g_c\{index}_granted <= lc_g_c\{index}_grant || lc_g_c\{index}_request;
    $|      lc_g_c\{index}_accepted <= lc_g_c\{index}_request;
    $|    end else if (lc_g_c\{index}_active) begin
    $|      if (lc_g_c\{index}_grant) lc_g_c\{index}_granted <= 1'b1;
    $|      if (lc_g_c\{index}_request) lc_g_c\{index}_accepted <= 1'b1;
    $|      if (lc_g_c\{index}_age < 4'd15) lc_g_c\{index}_age <= lc_g_c\{index}_age + 4'd1;
    $|    end
    $|  end
    $|
  text
}
