///|
let direct8_done_core_id : String = "phase6-flux-tile-direct8-q3-done-core-link-r2-h2"

///|
let direct8_latency_done_id : String = direct8_latency_credit_id + "-done-core"

///|
fn direct8_done_core_source() -> String {
  (
    #|  wire lc_d8d_done_core = lc_g_reset || lc_g_composition_capture_state != 2'd3
    #|    || lc_g_composition_shape_core_state == (lc_g_composition_shape_core_fault == 2'd0 ? 2'd0 : 2'd3);
    #|
  )
}
