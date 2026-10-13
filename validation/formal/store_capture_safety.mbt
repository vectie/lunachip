///|
// Reachability-strengthening conclusions, never internal assumptions. Both
// arithmetic producers and public cuts remain free. State 1/2 is inner owned;
// outer Run alone need not be leased after final capture.
fn store_capture_safety_source() -> String {
  (
    #|  wire lc_capture_inner_owned = lc_o_slotted_State == 2'd1 || lc_o_slotted_State == 2'd2;
    #|  always @(posedge lc_clock) begin
    #|    lc_capture_inner_lease: assert ((!lc_seen_edge || !lc_capture_inner_owned
    #|      || (lc_o_compute_State == 2'd2 && lc_o_compute_Leased)) === 1'b1);
    #|    lc_capture_inner_identity: assert ((!lc_seen_edge || !lc_capture_inner_owned
    #|      || lc_o_slotted_ActiveC == lc_o_compute_C) === 1'b1);
    #|    lc_capture_inner_success: assert ((!lc_seen_edge || !lc_capture_inner_owned
    #|      || (lc_o_core_Fault == 2'd0 && lc_o_core_State != 2'd0)) === 1'b1);
    #|    lc_capture_inner_shape: assert ((!lc_seen_edge || !lc_capture_inner_owned
    #|      || (lc_o_core_Rows >= 4'd1 && lc_o_core_Rows <= 4'd2
    #|      && lc_o_core_Columns >= 4'd1 && lc_o_core_Columns <= 4'd2)) === 1'b1);
    #|    lc_capture_compute_cursor: assert ((!lc_seen_edge || lc_o_slotted_State != 2'd1
    #|      || (lc_o_slotted_CaptureRow == 4'd0 && lc_o_slotted_CaptureColumn == 4'd0)) === 1'b1);
    #|    lc_capture_owned_cursor: assert ((!lc_seen_edge || !lc_capture_inner_owned
    #|      || (lc_o_slotted_CaptureRow < lc_o_core_Rows
    #|      && lc_o_slotted_CaptureColumn < lc_o_core_Columns)) === 1'b1);
    #|    lc_capture_stored_core_done: assert ((!lc_seen_edge || lc_o_slotted_State != 2'd2
    #|      || lc_o_core_State == 2'd3) === 1'b1);
    #|    lc_capture_leased_success_cursor: assert ((!lc_seen_edge || !lc_e_Capture
    #|      || (lc_o_compute_Leased && lc_o_core_Fault == 2'd0
    #|      && lc_o_slotted_ActiveC == lc_o_compute_C
    #|      && lc_o_slotted_CaptureRow < lc_o_core_Rows
    #|      && lc_o_slotted_CaptureColumn < lc_o_core_Columns)) === 1'b1);
    #|    lc_capture_final_widened: assert ((!lc_seen_edge || lc_e_FinalCapture ==
    #|      (lc_e_Capture && ({1'b0, lc_o_slotted_CaptureRow} + 5'd1 == {1'b0, lc_o_core_Rows})
    #|      && ({1'b0, lc_o_slotted_CaptureColumn} + 5'd1 == {1'b0, lc_o_core_Columns}))) === 1'b1);
    #|  end
    #|
  )
}
