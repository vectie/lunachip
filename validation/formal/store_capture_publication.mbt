///|
// Invalidation wins the same-edge mux; it clears validity but does not erase
// prior shape or SRAM. Publication samples original PRE shape at final capture.
fn store_capture_publication_source() -> String {
  let out = StringBuilder()
  out.write_string("  always @(posedge lc_clock) begin\n")
  for slot in 0..<2 {
    let invalidate = "(lc_pre_lc_e_SlottedLegalAccept && lc_pre_lc_o_compute_C == 1'd\{slot})"
    let finish = "(lc_pre_lc_e_FinalCapture && lc_pre_lc_o_slotted_ActiveC == 1'd\{slot})"
    out.write_string(
      "    lc_capture_valid_update_\{slot}: assert ((!lc_seen_edge || lc_o_result_valid_\{slot} == " +
      "(lc_previous_reset ? 1'b0 : (\{invalidate} ? 1'b0 : (\{finish} ? 1'b1 : lc_pre_lc_o_result_valid_\{slot})))) === 1'b1);\n",
    )
    for (field, core) in [("rows", "Rows"), ("columns", "Columns")] {
      out.write_string(
        "    lc_capture_\{field}_update_\{slot}: assert ((!lc_seen_edge || lc_o_result_\{field}_\{slot} == " +
        "(lc_previous_reset ? 4'd0 : (\{finish} ? lc_pre_lc_o_core_\{core} : lc_pre_lc_o_result_\{field}_\{slot}))) === 1'b1);\n",
      )
    }
    out.write_string(
      "    lc_capture_write_selected_\{slot}: assert ((lc_c_write_enable_\{slot} == " +
      "(lc_e_Capture && lc_o_slotted_ActiveC == 1'd\{slot})) === 1'b1);\n",
    )
  }
  out.write_string("  end\n")
  out.to_string()
}
