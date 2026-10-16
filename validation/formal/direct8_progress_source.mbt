///|
let direct8_progress_id : String = "phase6-flux-tile-direct8-q3-transport-progress-r2-h2"

///|
fn direct8_progress_definitions() -> Array[
  (String, @formal_core.FormalPropertyKind),
] {
  let definitions = direct_completion_property_definitions(Eventual).filter(item => {
    item.1 is Assumption ||
    item.0 == "dc_request_stable" ||
    item.0 == "dc_transport_serial_owned" ||
    item.0 == "dc_response_readiness"
  })
  for
    name in [
      "d8p_offer_drain_r2", "d8p_reply_drain_h2", "d8p_service_drain", "d8p_owner_history",
      "d8p_age_history",
    ] {
    definitions.push((name, Assertion))
  }
  definitions
}

///|
// Observer-only counters. An offered response never freezes either timer.
// These assertions are proved jointly with DUT persistence/ownership/readiness,
// not turned into assumptions about an abstract or cut transaction engine.
fn direct8_progress_source() -> String {
  let source =
    #|  logic lc_d8p_service_active = 1'b0;
    #|  logic [1:0] lc_d8p_service_age = 2'd0;
    #|  logic [1:0] lc_d8p_reply_age = 2'd0;
    #|  wire lc_d8p_offer_drain_r2 = lc_reset || !lc_dc_request_hold || lc_dc_request_accept;
    #|  wire lc_d8p_reply_drain_h2 = lc_reset || !lc_dc_host_owned
    #|    || lc_dc_response_accept || lc_d8p_reply_age < 2'd2;
    #|  wire lc_d8p_service_drain = lc_reset || !lc_d8p_service_active
    #|    || lc_dc_response_accept || lc_d8p_service_age < 2'd3;
    #|  wire lc_d8p_owner_history = lc_reset
    #|    || (lc_d8p_service_active == (lc_dc_host_owned || lc_dc_request_hold));
    #|  wire lc_d8p_age_history = lc_reset
    #|    || ((lc_dc_host_owned ? (lc_d8p_reply_age >= 2'd1 && lc_d8p_reply_age <= 2'd2)
    #|      : lc_d8p_reply_age == 2'd0)
    #|      && (lc_d8p_service_active ? lc_d8p_service_age != 2'd0 : lc_d8p_service_age == 2'd0));
    #|  always_ff @(posedge lc_clock) begin
    #|    if (lc_reset) begin
    #|      lc_d8p_service_active <= 1'b0;
    #|      lc_d8p_service_age <= 2'd0;
    #|      lc_d8p_reply_age <= 2'd0;
    #|    end else begin
    #|      if (lc_dc_request_accept && !lc_dc_host_owned) lc_d8p_reply_age <= 2'd1;
    #|      else if (lc_dc_response_accept && lc_dc_host_owned) lc_d8p_reply_age <= 2'd0;
    #|      else if (lc_dc_host_owned && lc_d8p_reply_age < 2'd3)
    #|        lc_d8p_reply_age <= lc_d8p_reply_age + 2'd1;
    #|      if (lc_dc_response_accept) begin
    #|        lc_d8p_service_active <= 1'b0;
    #|        lc_d8p_service_age <= 2'd0;
    #|      end else if (!lc_d8p_service_active && lc_memory_request_valid) begin
    #|        lc_d8p_service_active <= 1'b1;
    #|        lc_d8p_service_age <= 2'd1;
    #|      end else if (lc_d8p_service_active && lc_d8p_service_age < 2'd3)
    #|        lc_d8p_service_age <= lc_d8p_service_age + 2'd1;
    #|    end
    #|  end
    #|
  source
}
