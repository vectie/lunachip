///|
// Source-grounded old-PRE reservations and exact committed control updates.
// Done owns a retirement record, NOT a C reservation; ACK-edge credit cannot
// overwrite the old rectangle. All relations below are conclusions.
fn store_preservation_control_source() -> String {
  let out = StringBuilder()
  let relations =
    #|  wire lc_reserved = lc_o_store_State == 3'd1 || lc_o_store_State == 3'd2 || lc_o_store_State == 3'd3;
    #|  wire lc_core_response_ready = !lc_reset && (lc_o_store_State == 3'd3 || lc_o_store_State == 3'd4);
    #|  wire lc_final = lc_e_Capture
    #|    && ({1'b0, lc_o_slotted_CaptureRow} + 5'd1 == {1'b0, lc_o_core_Rows})
    #|    && ({1'b0, lc_o_slotted_CaptureColumn} + 5'd1 == {1'b0, lc_o_core_Columns});
    #|  wire lc_release = lc_e_FinalCapture || (!lc_reset && lc_o_compute_State == 2'd2
    #|    && lc_o_slotted_State == 2'd3 && !lc_e_OwnershipActive);
    #|  wire lc_reservation_exclusion = !lc_seen_edge || (
    #|    lc_o_store_State <= 3'd4 && lc_o_compute_State <= 2'd3 && lc_o_slotted_State <= 2'd3
    #|    && lc_e_StoreActive == (!lc_reset && lc_reserved)
    #|    && (lc_reset || !lc_reserved || !lc_e_Capture || lc_o_slotted_ActiveC != lc_o_store_Slot)
    #|    && (lc_reset || !lc_reserved || !lc_e_ComputeAccept || lc_incoming_compute_c != lc_o_store_Slot)
    #|    && (lc_reset || !lc_e_StoreAccept || !lc_o_compute_Leased || lc_incoming_store_slot != lc_o_compute_C)
    #|    && (lc_reset || !lc_e_StoreAccept || !lc_e_ComputeLegalAccept || lc_incoming_store_slot != lc_incoming_compute_c)
    #|    && (lc_reset || !lc_o_slotted_Pending || !lc_e_SlottedAccept || lc_o_compute_C != lc_o_slotted_ResponseSlot));
    #|  wire lc_pre_last_capture_column = {1'b0, lc_pre_lc_o_slotted_CaptureColumn} + 5'd1 == {1'b0, lc_pre_lc_o_core_Columns};
    #|  wire lc_capture_publication_and_lease = !lc_seen_edge || (
    #|    lc_e_FinalCapture == lc_final && lc_e_ComputeRelease == lc_release
    #|    && (!lc_e_Capture || (lc_o_compute_Leased && lc_o_core_Fault == 0
    #|      && lc_o_slotted_CaptureRow < lc_o_core_Rows && lc_o_slotted_CaptureColumn < lc_o_core_Columns))
    #|    && lc_o_compute_Leased == (lc_previous_reset ? 1'b0 : (lc_pre_lc_e_ComputeLegalAccept ? 1'b1
    #|      : (lc_pre_lc_e_ComputeRelease ? 1'b0 : lc_pre_lc_o_compute_Leased)))
    #|    && lc_o_slotted_CaptureRow == (lc_previous_reset || lc_pre_lc_e_SlottedAccept ? 4'd0
    #|      : ((lc_pre_lc_e_Capture && lc_pre_last_capture_column) ? lc_pre_lc_o_slotted_CaptureRow + 4'd1 : lc_pre_lc_o_slotted_CaptureRow))
    #|    && lc_o_slotted_CaptureColumn == (lc_previous_reset || lc_pre_lc_e_SlottedAccept ? 4'd0
    #|      : (lc_pre_lc_e_Capture ? (lc_pre_last_capture_column ? 4'd0 : lc_pre_lc_o_slotted_CaptureColumn + 4'd1) : lc_pre_lc_o_slotted_CaptureColumn))
    #|    && (lc_previous_reset || !lc_pre_lc_e_Capture || lc_o_slotted_State == (lc_pre_lc_e_FinalCapture ? 2'd3 : 2'd2)));
    #|  wire lc_pre_last_store_column = {1'b0, lc_pre_lc_o_store_Column} + 14'd1 == {1'b0, lc_pre_lc_o_store_Columns};
    #|  wire lc_pre_last_store = lc_pre_last_store_column
    #|    && ({1'b0, lc_pre_lc_o_store_Row} + 14'd1 == {1'b0, lc_pre_lc_o_store_Rows});
    #|  wire lc_good_ack_exact = !lc_e_StoreResponseGood || (!lc_reset && lc_o_store_State == 3'd3
    #|    && lc_arb_state == 2'd2 && lc_arb_owner && lc_memory_response_valid && lc_memory_response_ready
    #|    && lc_memory_response_fault == 0 && lc_memory_response_tag == lc_arb_expected_tag
    #|    && lc_arb_local_tag == lc_o_store_ExpectedTag);
    #|
  out.write_string(relations)
  let checks : Array[String] = [
    "lc_good_ack_exact", "(lc_o_store_Progress == (lc_previous_reset || lc_pre_lc_e_StoreAccept ? 32'd0 : (lc_pre_lc_e_StoreResponseGood ? lc_pre_lc_o_store_Progress + 32'd4 : lc_pre_lc_o_store_Progress)))",
    "(lc_o_store_Row == (lc_previous_reset || lc_pre_lc_e_StoreAccept ? 13'd0 : ((lc_pre_lc_e_StoreResponseGood && lc_pre_last_store_column) ? lc_pre_lc_o_store_Row + 13'd1 : lc_pre_lc_o_store_Row)))",
    "(lc_o_store_Column == (lc_previous_reset || lc_pre_lc_e_StoreAccept ? 13'd0 : (lc_pre_lc_e_StoreResponseGood ? (lc_pre_last_store_column ? 13'd0 : lc_pre_lc_o_store_Column + 13'd1) : lc_pre_lc_o_store_Column)))",
    "(lc_o_store_Tag == (lc_previous_reset ? 32'd0 : (lc_pre_lc_e_StoreRequestAccept ? lc_pre_lc_o_store_Tag + 32'd1 : lc_pre_lc_o_store_Tag)))",
    "(lc_o_store_ExpectedTag == (lc_previous_reset ? 32'd0 : (lc_pre_lc_e_StoreRequestAccept ? lc_pre_lc_o_store_Tag : lc_pre_lc_o_store_ExpectedTag)))",
    "(lc_previous_reset || !lc_pre_lc_e_StoreTerminal || lc_o_store_State == 3'd4)",
    "(lc_previous_reset || lc_pre_lc_e_StoreTerminal || !lc_pre_lc_e_StoreResponseGood || lc_o_store_State == (lc_pre_last_store ? 3'd4 : 3'd1))",
    "(lc_previous_reset || lc_pre_lc_e_StoreTerminal || !lc_pre_lc_e_ReadAccept || lc_o_store_State == 3'd2)",
    "(lc_previous_reset || lc_pre_lc_e_StoreTerminal || !lc_pre_lc_e_StoreRequestAccept || lc_o_store_State == 3'd3)",
    "(lc_previous_reset || !lc_pre_lc_e_StoreTerminal || lc_o_store_Fault == (lc_pre_lc_e_StoreResponseProtocol ? 4'd10 : (lc_pre_lc_e_StoreResponseRemote ? 4'd9 : (lc_pre_lc_e_StoreInternalFault ? 4'd11 : 4'd15))))",
  ]
  // A held Done record stays immutable even if an unrelated peer poisons DMA.
  for
    field in [
      "Slot", "Id", "Rows", "Columns", "Base", "Stride", "Row", "Column", "Tag",
      "ExpectedTag", "Progress", "Fault", "FaultAddress",
    ] {
    checks.push(
      "(lc_previous_reset || lc_pre_lc_o_store_State != 3'd4 || lc_o_store_\{field} == lc_pre_lc_o_store_\{field})",
    )
  }
  out.write_string(
    "  wire lc_cursor_progress_and_terminal = !lc_seen_edge || (\{checks.join(" && ")});\n",
  )
  out.to_string()
}
