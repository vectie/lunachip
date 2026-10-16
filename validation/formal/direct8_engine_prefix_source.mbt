///|
let direct8_engine_prefix_id : String = direct8_engine_id +
  "-owner-prefix-support"

///|
// A carries completed ROWS. B carries earlier COLUMNS within the current row.
// Prefixes may exceed the minimum after reloads; no memory value is constrained.
fn direct8_engine_completed_prefix_source() -> String {
  let terms : Array[String] = []
  for slot in 0..<2 {
    for bank in 0..<8 {
      terms.push(
        "(!(lc_g_o_load_operand == 1'd0 && lc_g_o_load_slot == 1'd\{slot} && 13'd\{bank} < lc_g_t_reader_row) || lc_g_p_a_\{slot}_\{bank} >= lc_g_t_reader_columns)",
      )
      terms.push(
        "(!(lc_g_o_load_operand == 1'd1 && lc_g_o_load_slot == 1'd\{slot} && 13'd\{bank} < lc_g_t_reader_columns) || lc_g_p_b_\{slot}_\{bank} >= lc_g_t_reader_row + ((13'd\{bank} < lc_g_t_reader_column) ? 13'd1 : 13'd0))",
      )
    }
  }
  "  wire lc_d8e_completed_prefix = lc_g_reset || !lc_e_reader_active || (\{terms.join(" && ")});\n"
}
