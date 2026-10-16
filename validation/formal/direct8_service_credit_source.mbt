///|
let direct8_latency_credit_id : String = direct8_latency_id + "-service-credit"

///|
// Carry already elapsed service through the competing transaction and regrant.
// These are additional conclusions on existing observers, not new premises.
fn direct8_service_credit_source() -> String {
  let out = StringBuilder()
  out.write_string(
    (
      #|  wire lc_d8l_service_credit4 = lc_g_reset || !lc_g_active
      #|    || (lc_g_service_age <= 3'd4 && (lc_g_e_response_accept || lc_g_service_age < 3'd4));
      #|
    ),
  )
  for index in 0..<2 {
    let owner = if index == 1 { "lc_g_r_owner" } else { "!lc_g_r_owner" }
    out.write_string(
      (
        $|  wire lc_l_credit_\{index} = !lc_g_c\{index}_active
        $|    || (lc_g_c\{index}_granted
        $|      ? (lc_g_active && (\{owner}) && {1'b0,lc_g_c\{index}_age} <= {2'd0,lc_g_service_age} + 5'd5)
        $|      : (lc_g_r_state == 2'd0
        $|        ? (lc_g_c\{index}_grant && lc_g_c\{index}_age <= 4'd5)
        $|        : (lc_g_active && !(\{owner}) && lc_g_c\{index}_age <= {1'b0,lc_g_service_age})));
        $|
      ),
    )
  }
  out.write_string(
    "  wire lc_d8l_client_credit = lc_g_reset || (lc_l_credit_0 && lc_l_credit_1);\n",
  )
  out.to_string()
}
