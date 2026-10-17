///|
fn direct8_payload_property_names() -> ReadOnlyArray[String] {
  ["d8p_store_shape", "d8p_pending_identity", "d8p_pending_status"]
}

///|
// Original metadata only: SRAM words and their read INIT remain unknown.
fn direct8_payload_source() -> String {
  (
    #|  // BEGIN direct8 original pending payload support
    #|  wire lc_d8p_store_shape = lc_g_reset || !lc_e_engine_active
    #|    || ((lc_g_o_store_slot ? lc_g_p_c_valid_1 : lc_g_p_c_valid_0)
    #|      && {9'd0,(lc_g_o_store_slot ? lc_g_p_c_rows_1 : lc_g_p_c_rows_0)} == lc_g_t_engine_rows
    #|      && {9'd0,(lc_g_o_store_slot ? lc_g_p_c_columns_1 : lc_g_p_c_columns_0)} == lc_g_t_engine_columns);
    #|  wire lc_d8p_pending_identity = lc_g_reset || !lc_g_o_pending
    #|    || lc_g_p_response_id == lc_g_p_store_id;
    #|  wire lc_d8p_pending_status = lc_g_reset
    #|    || ((!lc_g_o_read_accept || lc_g_p_read_fault == 2'd0)
    #|      && (!lc_g_o_pending || lc_g_p_response_fault == 2'd0));
    #|  // END direct8 original pending payload support
    #|
  )
}
