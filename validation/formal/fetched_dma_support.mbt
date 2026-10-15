///|
// These conclusions constrain no input. Done is excluded because the final
// acknowledged element advances the original modular cursor past the rectangle.
fn fetched_dma_support() -> String {
  let out = StringBuilder()
  for (client, bytes, limit) in [("loader", 1, 2), ("storer", 4, 1)] {
    let p = "lc_dut_composition_dma_" + client + "_"
    let n = "lc_dma_" + client
    let alignment = if bytes == 4 {
      " && \{p}base[1:0] == 2'd0 && \{p}stride[1:0] == 2'd0"
    } else {
      ""
    }
    out.write_string(
      "  wire \{n}_active = \{p}state >= 3'd1 && \{p}state <= 3'd3;\n" +
      "  wire [63:0] \{n}_rows = {51'd0,\{p}rows};\n" +
      "  wire [63:0] \{n}_columns = {51'd0,\{p}columns};\n" +
      "  wire [63:0] \{n}_base = {32'd0,\{p}base};\n" +
      "  wire [63:0] \{n}_stride = {32'd0,\{p}stride};\n" +
      "  wire [63:0] \{n}_row_bytes = \{n}_columns * 64'd\{bytes};\n" +
      "  wire [63:0] \{n}_end = \{n}_base + (\{n}_rows - 64'd1) * \{n}_stride + \{n}_row_bytes;\n" +
      "  always @($global_clock) begin\n" +
      "    \{n}_shape: assert ((!lc_seen_edge || !\{n}_active || (\{p}rows >= 13'd1 && \{p}rows <= 13'd\{limit} && \{p}columns >= 13'd1 && \{p}columns <= 13'd\{limit})) === 1'b1);\n" +
      "    \{n}_rectangle: assert ((!lc_seen_edge || !\{n}_active || (\{n}_end <= 64'd1024 && \{n}_stride >= \{n}_row_bytes\{alignment})) === 1'b1);\n" +
      "    \{n}_cursor: assert ((!lc_seen_edge || !\{n}_active || (\{p}row < \{p}rows && \{p}column < \{p}columns)) === 1'b1);\n" +
      "    \{n}_element: assert ((!lc_seen_edge || !\{n}_active || \{p}address_full + 64'd\{bytes} <= 64'd1024) === 1'b1);\n" +
      "    \{n}_encoding: assert ((!lc_seen_edge || !lc_i_\{client}_valid || (\{n}_active && {32'd0,lc_i_\{client}_address} == \{p}address_full)) === 1'b1);\n" +
      "  end\n",
    )
  }
  out.write_string(
    (
      #|  wire lc_dma_store_grant = lc_dut_arbiter_grant && lc_dut_arbiter_choice == 2'd2;
      #|  logic lc_dma_saved_store;
      #|  logic [31:0] lc_dma_saved_word;
      #|  logic [63:0] lc_dma_saved_address;
      #|  always @(posedge lc_clock) begin
      #|    if (lc_reset) lc_dma_saved_store <= 1'b0;
      #|    else if (lc_dut_arbiter_grant) begin
      #|      lc_dma_saved_store <= lc_dut_arbiter_choice == 2'd2;
      #|      if (lc_dma_store_grant) begin
      #|        lc_dma_saved_word <= lc_dut_composition_dma_store_word;
      #|        lc_dma_saved_address <= lc_dut_composition_dma_storer_address_full;
      #|      end
      #|    end
      #|  end
      #|  wire [33:0] lc_dma_saved_end = {2'd0,lc_saved_payload[102:71]} + {31'd0,lc_saved_payload[70:68]};
      #|  wire lc_dma_saved_legal = lc_saved_payload[103]
      #|    ? (lc_saved_payload[70:68] == 3'd4 && lc_saved_payload[67:64] == 4'd15 && lc_saved_payload[72:71] == 2'd0)
      #|    : (lc_saved_payload[70:68] == 3'd1 && lc_saved_payload[67:64] == 4'd1 && lc_saved_payload[63:32] == 32'd0);
      #|  always @($global_clock) begin
      #|    lc_dma_snapshot_aperture: assert ((!lc_seen_edge || !lc_snapshot_valid || lc_dma_saved_end <= 34'd1024) === 1'b1);
      #|    lc_dma_snapshot_payload: assert ((!lc_seen_edge || !lc_snapshot_valid || lc_dma_saved_legal) === 1'b1);
      #|    lc_dma_store_source: assert ((!lc_i_storer_valid || lc_i_storer_data == lc_dut_composition_dma_store_word) === 1'b1);
      #|    lc_dma_store_snapshot: assert ((!lc_seen_edge || !lc_raw_active || lc_o_arbiter_owner != 2'd2 || (lc_dma_saved_store && lc_o_arbiter_write && lc_o_arbiter_data == lc_dma_saved_word && {32'd0,lc_o_arbiter_address} == lc_dma_saved_address)) === 1'b1);
      #|    lc_dma_store_public: assert ((!lc_seen_edge || !lc_memory_request_valid || lc_o_arbiter_owner != 2'd2 || (lc_memory_request_write && lc_memory_request_data == lc_dma_saved_word && {32'd0,lc_memory_request_address} == lc_dma_saved_address)) === 1'b1);
      #|  end
      #|
    ),
  )
  out.to_string()
}
