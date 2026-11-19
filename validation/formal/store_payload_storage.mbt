///|
// Nonfeeding capture history, independent of SRAM/readback and generation
// validity. Track only actual captures since reset; unknown old SRAM is never
// compared until that exact physical cell has been captured. The producer mux
// deliberately includes the original default zero for out-of-shape cursors.
fn store_payload_producer_source() -> String {
  (
    #|  wire [31:0] lc_payload_produced_word =
    #|    (lc_o_slotted_CaptureRow == 4'd0 && lc_o_slotted_CaptureColumn == 4'd0) ? lc_production_0 :
    #|    ((lc_o_slotted_CaptureRow == 4'd0 && lc_o_slotted_CaptureColumn == 4'd1) ? lc_production_1 :
    #|    ((lc_o_slotted_CaptureRow == 4'd1 && lc_o_slotted_CaptureColumn == 4'd0) ? lc_production_2 :
    #|    ((lc_o_slotted_CaptureRow == 4'd1 && lc_o_slotted_CaptureColumn == 4'd1) ? lc_production_3 : 32'd0)));
    #|
  )
}

///|
fn store_payload_slot_source(slot : Int32, reads : Bool) -> String {
  let out = StringBuilder()
  out.write_string(
    "  wire lc_payload_capture_\{slot} = lc_e_Capture && lc_o_slotted_ActiveC == 1'd\{slot};\n" +
    "  logic [3:0] lc_payload_written_\{slot};\n",
  )
  for cell in 0..<4 {
    out.write_string("  logic [31:0] lc_payload_word_\{slot}_\{cell};\n")
  }
  out.write_string(
    "  always @(posedge lc_clock) begin\n" +
    "    if (lc_reset) lc_payload_written_\{slot} <= 4'd0;\n" +
    "    else begin\n" +
    "      if (lc_payload_capture_\{slot}) lc_payload_written_\{slot} <= lc_payload_written_\{slot} | (4'b0001 << lc_c_write_address_\{slot});\n",
  )
  for cell in 0..<4 {
    out.write_string(
      "      if (lc_payload_capture_\{slot} && lc_c_write_address_\{slot} == 2'd\{cell}) lc_payload_word_\{slot}_\{cell} <= lc_payload_produced_word;\n",
    )
  }
  out.write_string("    end\n  end\n")
  out.write_string(
    "  always @(posedge lc_clock) begin\n" +
    "    lc_payload_write_binding_\{slot}: assert ((lc_c_write_enable_\{slot} == lc_payload_capture_\{slot}\n" +
    "      && (!lc_payload_capture_\{slot} || lc_c_write_data_\{slot} == lc_payload_produced_word)) === 1'b1);\n" +
    "    lc_payload_reset_ports_\{slot}: assert ((!lc_reset || (!lc_c_write_enable_\{slot} && !lc_c_read_enable_\{slot})) === 1'b1);\n",
  )
  for cell in 0..<4 {
    out.write_string(
      "    lc_payload_cell_\{slot}_\{cell}: assert ((!lc_seen_edge || !lc_payload_written_\{slot}[\{cell}]\n" +
      "      || lc_actual_c_\{slot}_\{cell} == lc_payload_word_\{slot}_\{cell}) === 1'b1);\n",
    )
  }
  out.write_string("  end\n")
  if reads {
    out.write_string(
      "  wire [31:0] lc_payload_selected_\{slot} = (lc_c_read_address_\{slot} == 2'd0) ? lc_payload_word_\{slot}_0\n" +
      "    : ((lc_c_read_address_\{slot} == 2'd1) ? lc_payload_word_\{slot}_1\n" +
      "    : ((lc_c_read_address_\{slot} == 2'd2) ? lc_payload_word_\{slot}_2 : lc_payload_word_\{slot}_3));\n" +
      "  logic lc_payload_read_tracked_\{slot};\n" +
      "  logic [31:0] lc_payload_read_word_\{slot};\n" +
      "  always @(posedge lc_clock) begin\n" +
      "    if (lc_reset) lc_payload_read_tracked_\{slot} <= 1'b0;\n" +
      "    else if (lc_c_read_enable_\{slot}) begin\n" +
      "      lc_payload_read_tracked_\{slot} <= lc_payload_written_\{slot}[lc_c_read_address_\{slot}];\n" +
      "      lc_payload_read_word_\{slot} <= lc_payload_selected_\{slot};\n" +
      "    end\n" +
      "  end\n" +
      "  always @(posedge lc_clock) begin\n" +
      "    lc_payload_readold_hold_\{slot}: assert ((!lc_seen_edge || !lc_payload_read_tracked_\{slot}\n" +
      "      || lc_o_c_read_\{slot} == lc_payload_read_word_\{slot}) === 1'b1);\n" +
      "  end\n",
    )
  }
  out.to_string()
}
