///|
// Full-width Store support over the original registers. The source increments
// UInt13 modulo 8192; only the checked active-rectangle bounds justify replacing
// its last-cell comparison with a widened UInt14 comparison. Done is excluded:
// a successful final ACK advances Row to Rows, and rejected commands may latch
// arbitrary invalid shapes. Reservations still apply on PRE terminal edges.
fn store_p4_cursor_source() -> String {
  let out = StringBuilder()
  out.write_string(
    (
      #|  wire lc_p4_cursor_reserved = lc_o_store_State == 3'd1
      #|    || lc_o_store_State == 3'd2 || lc_o_store_State == 3'd3;
      #|  wire lc_p4_last_column_modular = lc_o_store_Column + 13'd1 == lc_o_store_Columns;
      #|  wire lc_p4_last_modular = lc_p4_last_column_modular
      #|    && (lc_o_store_Row + 13'd1 == lc_o_store_Rows);
      #|  wire lc_p4_pre_last_column_modular = lc_pre_lc_o_store_Column + 13'd1 == lc_pre_lc_o_store_Columns;
      #|  wire lc_p4_selected_valid = lc_o_store_Slot ? lc_o_result_valid_1 : lc_o_result_valid_0;
      #|  wire [3:0] lc_p4_selected_rows = lc_o_store_Slot ? lc_o_result_rows_1 : lc_o_result_rows_0;
      #|  wire [3:0] lc_p4_selected_columns = lc_o_store_Slot ? lc_o_result_columns_1 : lc_o_result_columns_0;
      #|  wire lc_p4_actual_read_bounds = lc_o_store_Row[3:0] < lc_p4_selected_rows
      #|    && lc_o_store_Column[3:0] < lc_p4_selected_columns;
      #|  wire [1:0] lc_p4_actual_read_fault = !lc_p4_selected_valid ? 2'd2
      #|    : (lc_p4_actual_read_bounds ? 2'd0 : 2'd1);
      #|  wire [25:0] lc_p4_full_read_address = {13'd0, lc_o_store_Row} * 26'd2
      #|    + {13'd0, lc_o_store_Column};
      #|  always @(posedge lc_clock) begin
      #|    lc_p4_cursor_row_update: assert ((!lc_seen_edge || lc_o_store_Row ==
      #|      (lc_previous_reset || lc_pre_lc_e_StoreAccept ? 13'd0
      #|      : (lc_pre_lc_e_StoreResponseGood && lc_p4_pre_last_column_modular
      #|        ? lc_pre_lc_o_store_Row + 13'd1 : lc_pre_lc_o_store_Row))) === 1'b1);
      #|    lc_p4_cursor_column_update: assert ((!lc_seen_edge || lc_o_store_Column ==
      #|      (lc_previous_reset || lc_pre_lc_e_StoreAccept ? 13'd0
      #|      : (lc_pre_lc_e_StoreResponseGood ? (lc_p4_pre_last_column_modular ? 13'd0
      #|        : lc_pre_lc_o_store_Column + 13'd1) : lc_pre_lc_o_store_Column))) === 1'b1);
      #|    lc_p4_cursor_progress_update: assert ((!lc_seen_edge || lc_o_store_Progress ==
      #|      (lc_previous_reset || lc_pre_lc_e_StoreAccept ? 32'd0
      #|      : (lc_pre_lc_e_StoreResponseGood ? lc_pre_lc_o_store_Progress + 32'd4
      #|        : lc_pre_lc_o_store_Progress))) === 1'b1);
      #|    lc_p4_cursor_active_shape: assert ((!lc_seen_edge || !lc_p4_cursor_reserved
      #|      || (lc_o_store_Rows >= 13'd1 && lc_o_store_Rows <= 13'd2
      #|        && lc_o_store_Columns >= 13'd1 && lc_o_store_Columns <= 13'd2)) === 1'b1);
      #|    lc_p4_cursor_selected_rectangle: assert ((!lc_seen_edge || !lc_p4_cursor_reserved
      #|      || (lc_p4_selected_valid && lc_o_store_Rows == {9'd0, lc_p4_selected_rows}
      #|        && lc_o_store_Columns == {9'd0, lc_p4_selected_columns})) === 1'b1);
      #|    lc_p4_cursor_full_width_bounds: assert ((!lc_seen_edge || !lc_p4_cursor_reserved
      #|      || (lc_o_store_Row < lc_o_store_Rows && lc_o_store_Column < lc_o_store_Columns)) === 1'b1);
      #|    lc_p4_cursor_active_fault: assert ((!lc_seen_edge || !lc_p4_cursor_reserved
      #|      || lc_o_store_Fault == 4'd0) === 1'b1);
      #|    lc_p4_cursor_good_ack: assert ((!lc_seen_edge || !lc_e_StoreResponseGood
      #|      || (!lc_reset && lc_o_store_State == 3'd3 && lc_o_store_Fault == 4'd0)) === 1'b1);
      #|    lc_p4_cursor_last_widened: assert ((!lc_seen_edge || !lc_p4_cursor_reserved
      #|      || (lc_p4_last_column_modular == ({1'b0, lc_o_store_Column} + 14'd1 == {1'b0, lc_o_store_Columns})
      #|        && lc_p4_last_modular == (({1'b0, lc_o_store_Column} + 14'd1 == {1'b0, lc_o_store_Columns})
      #|          && ({1'b0, lc_o_store_Row} + 14'd1 == {1'b0, lc_o_store_Rows})))) === 1'b1);
      #|    lc_p4_cursor_read_fault: assert ((!lc_seen_edge || !lc_e_ReadAccept
      #|      || (lc_o_store_State == 3'd1 && !lc_core_response_ready
      #|        && lc_expected_read_fault == 2'd0 && lc_p4_actual_read_fault == lc_expected_read_fault)) === 1'b1);
      #|    lc_p4_cursor_read_address: assert ((!lc_seen_edge || !lc_e_ReadAccept
      #|      || (lc_p4_full_read_address < 26'd4
      #|        && {20'd0, lc_indexed_read_address} == lc_p4_full_read_address
      #|        && (lc_o_store_Slot ? (lc_c_read_enable_1
      #|          && {24'd0, lc_c_read_address_1} == lc_p4_full_read_address)
      #|          : (lc_c_read_enable_0 && {24'd0, lc_c_read_address_0} == lc_p4_full_read_address)))) === 1'b1);
      #|
    ),
  )
  // Input envelopes may vary while the old accepted rectangle is active. The
  // actual registers, not a copied request envelope, provide these conclusions.
  for field in ["Slot", "Id", "Rows", "Columns", "Base", "Stride"] {
    out.write_string(
      "    lc_p4_cursor_latched_\{field}: assert ((!lc_seen_edge || lc_previous_reset\n" +
      "      || lc_pre_lc_e_StoreAccept || lc_o_store_\{field} == lc_pre_lc_o_store_\{field}) === 1'b1);\n",
    )
  }
  out.write_string("  end\n")
  out.to_string()
}
