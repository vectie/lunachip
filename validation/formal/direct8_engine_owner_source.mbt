///|
// Joint induction supports on ORIGINAL pending, prefixes and selectors.
// These are conclusions, never premises and never initialized SRAM shadows.
fn direct8_engine_owner_source() -> String {
  let out = StringBuilder()
  out.write_string(
    (
      #|  wire lc_d8e_lease_phase = lc_g_reset
      #|    || ((!lc_g_x_lease || lc_g_q_engine_state_1 == 2'd1 || lc_g_q_engine_state_1 == 2'd2)
      #|      && (lc_g_q_engine_state_1 != 2'd1 || lc_g_x_lease));
      #|  wire lc_d8e_inner_snapshot = lc_g_reset || !lc_g_x_ownership
      #|    || (lc_g_q_engine_state_1 == 2'd2 && lc_g_x_lease
      #|      && lc_g_o_active_a == lc_g_o_compute_a && lc_g_o_active_b == lc_g_o_compute_b
      #|      && lc_g_o_active_c == lc_g_o_compute_c);
      #|  wire lc_d8e_loader_lease = lc_g_reset || !lc_e_reader_active
      #|    || !(lc_g_x_lease && lc_g_o_load_slot == (lc_g_o_load_operand ? lc_g_o_compute_b : lc_g_o_compute_a));
      #|  wire lc_d8e_store_lease = lc_g_reset || !lc_e_engine_active
      #|    || !(lc_g_x_lease && lc_g_o_store_slot == lc_g_o_compute_c);
      #|  wire lc_d8e_pending_owner = lc_g_reset
      #|    || ((!lc_g_o_pending || lc_g_q_engine_state_2 == 3'd2 || lc_g_q_engine_state_2 == 3'd3 || lc_g_q_engine_state_2 == 3'd4)
      #|      && (lc_g_q_engine_state_2 != 3'd2 || lc_g_o_pending));
      #|
    ),
  )
  let bounds : Array[String] = []
  let prefixes : Array[String] = []
  for
    (operand, selected_bank, selected_index) in [
      ("a", "row", "column"),
      ("b", "column", "row"),
    ] {
    for slot in 0..<2 {
      for bank in 0..<8 {
        bounds.push("lc_g_p_\{operand}_\{slot}_\{bank} <= 13'd16")
        prefixes.push(
          "(!(lc_g_o_load_operand == 1'd\{if operand == "a" { 0 } else { 1 }} && lc_g_o_load_slot == 1'd\{slot} && lc_g_t_reader_\{selected_bank} == 13'd\{bank}) || lc_g_t_reader_\{selected_index} <= lc_g_p_\{operand}_\{slot}_\{bank})",
        )
      }
    }
  }
  out.write_string(
    "  wire lc_d8e_prefix_bounds = lc_g_reset || (\{bounds.join(" && ")});\n",
  )
  out.write_string(
    "  wire lc_d8e_loader_prefix = lc_g_reset || !lc_e_reader_active\n    || ((lc_g_o_load_operand ? lc_g_t_reader_columns <= 13'd8 : lc_g_t_reader_rows <= 13'd8) && \{prefixes.join(" && ")});\n",
  )
  out.to_string()
}
