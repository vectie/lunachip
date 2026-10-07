///|
// Eight scalar monitor words avoid a replacement hardware memory. Values are
// sampled only from raw arithmetic producers on actual capture; words remain
// uninitialized until written. Every comparison is a checked conclusion.
fn store_preservation_production_source() -> String {
  let out = StringBuilder()
  let helpers =
    #|  logic lc_seen_edge = 1'b0;
    #|  logic lc_previous_reset = 1'b0;
    #|  always @(posedge lc_clock) begin
    #|    lc_seen_edge <= 1'b1;
    #|    lc_previous_reset <= lc_reset;
    #|  end
    #|  wire lc_startup_reset = lc_seen_edge || lc_reset;
    #|  wire [5:0] lc_capture_address = {2'd0, lc_o_slotted_CaptureRow} * 6'd2
    #|    + {2'd0, lc_o_slotted_CaptureColumn};
    #|  wire [31:0] lc_produced_word = (lc_o_slotted_CaptureRow == 0 && lc_o_slotted_CaptureColumn == 0) ? lc_production_0
    #|    : ((lc_o_slotted_CaptureRow == 0 && lc_o_slotted_CaptureColumn == 1) ? lc_production_1
    #|    : ((lc_o_slotted_CaptureRow == 1 && lc_o_slotted_CaptureColumn == 0) ? lc_production_2 : lc_production_3));
    #|  function automatic [3:0] lc_rectangle_mask(input [3:0] rows, input [3:0] columns);
    #|    case ({rows, columns})
    #|      8'h11: lc_rectangle_mask = 4'b0001;
    #|      8'h12: lc_rectangle_mask = 4'b0011;
    #|      8'h21: lc_rectangle_mask = 4'b0101;
    #|      8'h22: lc_rectangle_mask = 4'b1111;
    #|      default: lc_rectangle_mask = 4'b0000;
    #|    endcase
    #|  endfunction
    #|
  out.write_string(helpers)
  let checks : Array[String] = []
  for slot in 0..<2 {
    out.write_string(
      "  logic [3:0] lc_g_written_\{slot};\n  logic lc_g_valid_\{slot};\n  logic [3:0] lc_g_rows_\{slot}, lc_g_columns_\{slot};\n  logic lc_g_read_tracked_\{slot};\n  logic [31:0] lc_g_read_word_\{slot};\n",
    )
    for cell in 0..<4 {
      out.write_string("  logic [31:0] lc_g_word_\{slot}_\{cell};\n")
    }
    out.write_string(
      "  wire lc_invalidate_\{slot} = lc_e_SlottedLegalAccept && lc_o_compute_C == 1'd\{slot};\n  wire lc_capture_\{slot} = lc_e_Capture && lc_o_slotted_ActiveC == 1'd\{slot};\n  wire lc_publish_\{slot} = lc_e_FinalCapture && lc_o_slotted_ActiveC == 1'd\{slot};\n",
    )
    let choice = "(lc_c_read_address_\{slot} == 0 ? lc_g_word_\{slot}_0 : (lc_c_read_address_\{slot} == 1 ? lc_g_word_\{slot}_1 : (lc_c_read_address_\{slot} == 2 ? lc_g_word_\{slot}_2 : lc_g_word_\{slot}_3)))"
    out.write_string("  wire [31:0] lc_g_selected_read_\{slot} = \{choice};\n")
    out.write_string(
      "  always @(posedge lc_clock) begin\n    if (lc_reset) begin\n      lc_g_written_\{slot} <= 4'd0;\n      lc_g_valid_\{slot} <= 1'b0;\n      lc_g_rows_\{slot} <= 4'd0;\n      lc_g_columns_\{slot} <= 4'd0;\n      lc_g_read_tracked_\{slot} <= 1'b0;\n    end else begin\n      if (lc_invalidate_\{slot}) begin\n        lc_g_written_\{slot} <= 4'd0;\n        lc_g_valid_\{slot} <= 1'b0;\n      end else begin\n        if (lc_capture_\{slot}) lc_g_written_\{slot} <= lc_g_written_\{slot} | (4'b0001 << lc_capture_address);\n        if (lc_publish_\{slot}) lc_g_valid_\{slot} <= 1'b1;\n      end\n      if (lc_publish_\{slot}) begin\n        lc_g_rows_\{slot} <= lc_o_core_Rows;\n        lc_g_columns_\{slot} <= lc_o_core_Columns;\n      end\n",
    )
    for cell in 0..<4 {
      out.write_string(
        "      if (lc_capture_\{slot} && lc_capture_address == 6'd\{cell}) lc_g_word_\{slot}_\{cell} <= lc_produced_word;\n",
      )
      checks.push(
        "(!lc_g_written_\{slot}[\{cell}] || lc_actual_c_\{slot}_\{cell} == lc_g_word_\{slot}_\{cell})",
      )
    }
    out.write_string(
      "      if (lc_c_read_enable_\{slot}) begin\n        lc_g_read_tracked_\{slot} <= lc_g_valid_\{slot} && lc_g_written_\{slot}[lc_c_read_address_\{slot}];\n        lc_g_read_word_\{slot} <= lc_g_selected_read_\{slot};\n      end\n    end\n  end\n",
    )
    checks.push(
      "(lc_o_result_valid_\{slot} == lc_g_valid_\{slot} && lc_o_result_rows_\{slot} == lc_g_rows_\{slot} && lc_o_result_columns_\{slot} == lc_g_columns_\{slot})",
    )
    checks.push(
      "(!lc_g_valid_\{slot} || (lc_rectangle_mask(lc_g_rows_\{slot}, lc_g_columns_\{slot}) != 0 && (lc_g_written_\{slot} & lc_rectangle_mask(lc_g_rows_\{slot}, lc_g_columns_\{slot})) == lc_rectangle_mask(lc_g_rows_\{slot}, lc_g_columns_\{slot})))",
    )
    checks.push("(lc_c_write_enable_\{slot} == lc_capture_\{slot})")
    checks.push(
      "(!lc_capture_\{slot} || (lc_o_slotted_CaptureRow < 4'd2 && lc_o_slotted_CaptureColumn < 4'd2 && {4'd0, lc_c_write_address_\{slot}} == lc_capture_address && lc_c_write_data_\{slot} == lc_produced_word))",
    )
    checks.push(
      "(!lc_c_read_enable_\{slot} || (lc_g_valid_\{slot} && lc_g_written_\{slot}[lc_c_read_address_\{slot}]))",
    )
    checks.push(
      "(!lc_g_read_tracked_\{slot} || lc_o_c_read_\{slot} == lc_g_read_word_\{slot})",
    )
  }
  out.write_string(
    "  wire lc_produced_storage = !lc_seen_edge || (\{checks.join(" && ")});\n",
  )
  out.to_string()
}
