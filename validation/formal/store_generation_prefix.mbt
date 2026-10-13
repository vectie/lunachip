///|
// Checked history support for original per-generation written masks. The
// current cell is excluded from its PRE prefix and included at the commit.
fn store_capture_generation_prefix_source() -> String {
  let out = StringBuilder()
  out.write_string(
    (
      #|  function automatic [3:0] lc_generation_prefix(input [3:0] row, input [3:0] column, input [3:0] columns);
      #|    case ({columns, row, column})
      #|      12'h100: lc_generation_prefix = 4'b0000;
      #|      12'h110: lc_generation_prefix = 4'b0001;
      #|      12'h200: lc_generation_prefix = 4'b0000;
      #|      12'h201: lc_generation_prefix = 4'b0001;
      #|      12'h210: lc_generation_prefix = 4'b0011;
      #|      12'h211: lc_generation_prefix = 4'b0111;
      #|      default: lc_generation_prefix = 4'b0000;
      #|    endcase
      #|  endfunction
      #|  wire [3:0] lc_generation_owned_prefix = lc_generation_prefix(
      #|    lc_o_slotted_CaptureRow, lc_o_slotted_CaptureColumn, lc_o_core_Columns);
      #|  always @(posedge lc_clock) begin
      #|
    ),
  )
  for slot in 0..<2 {
    out.write_string(
      "    lc_generation_prefix_\{slot}: assert ((!lc_seen_edge || !lc_capture_inner_owned\n" +
      "      || lc_o_slotted_ActiveC != 1'd\{slot}\n" +
      "      || lc_g_written_\{slot} == lc_generation_owned_prefix) === 1'b1);\n" +
      "    lc_generation_complete_\{slot}: assert ((!lc_seen_edge || !lc_g_valid_\{slot}\n" +
      "      || (lc_g_rows_\{slot} >= 4'd1 && lc_g_rows_\{slot} <= 4'd2\n" +
      "      && lc_g_columns_\{slot} >= 4'd1 && lc_g_columns_\{slot} <= 4'd2\n" +
      "      && (lc_g_written_\{slot} & lc_rectangle_mask(lc_g_rows_\{slot}, lc_g_columns_\{slot}))\n" +
      "        == lc_rectangle_mask(lc_g_rows_\{slot}, lc_g_columns_\{slot}))) === 1'b1);\n",
    )
  }
  out.write_string("  end\n")
  out.to_string()
}
