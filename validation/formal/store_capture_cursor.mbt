///|
// Preserve the source's UInt4 modular equations. Legal bounded cursor support
// is checked separately; it is not silently assumed by these recurrences.
fn store_capture_cursor_source() -> String {
  (
    #|  wire lc_capture_pre_last_column = lc_pre_lc_o_slotted_CaptureColumn + 4'd1 == lc_pre_lc_o_core_Columns;
    #|  always @(posedge lc_clock) begin
    #|    lc_capture_row_update: assert ((!lc_seen_edge || lc_o_slotted_CaptureRow ==
    #|      (lc_previous_reset || lc_pre_lc_e_SlottedAccept ? 4'd0
    #|      : (lc_pre_lc_e_Capture && lc_capture_pre_last_column ? lc_pre_lc_o_slotted_CaptureRow + 4'd1
    #|      : lc_pre_lc_o_slotted_CaptureRow))) === 1'b1);
    #|    lc_capture_column_update: assert ((!lc_seen_edge || lc_o_slotted_CaptureColumn ==
    #|      (lc_previous_reset || lc_pre_lc_e_SlottedAccept ? 4'd0
    #|      : (lc_pre_lc_e_Capture ? (lc_capture_pre_last_column ? 4'd0
    #|      : lc_pre_lc_o_slotted_CaptureColumn + 4'd1) : lc_pre_lc_o_slotted_CaptureColumn))) === 1'b1);
    #|    lc_capture_phase_update: assert ((!lc_seen_edge || lc_previous_reset
    #|      || !lc_pre_lc_e_Capture || lc_o_slotted_State ==
    #|      (lc_pre_lc_e_FinalCapture ? 2'd3 : 2'd2)) === 1'b1);
    #|  end
    #|
  )
}
