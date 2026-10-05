///|
// Purpose-specific independent decode, not a generic observation framework.
// No production syntax/ready/dependency predicate is used as a reference.
fn dependency_decode_source() -> String {
  let source =
    #|  wire [7:0] lc_raw_opcode = lc_o_head_lane_0[23:16];
    #|  wire [15:0] lc_raw_rows = lc_o_head_lane_1[15:0];
    #|  wire [15:0] lc_raw_columns = lc_o_head_lane_1[31:16];
    #|  wire [15:0] lc_raw_reduction = lc_o_head_lane_1[47:32];
    #|  wire [31:0] lc_raw_base = lc_o_head_lane_2[31:0];
    #|  wire [31:0] lc_raw_stride = lc_o_head_lane_2[63:32];
    #|  wire lc_raw_a = lc_o_head_lane_3[0];
    #|  wire lc_raw_b = lc_o_head_lane_3[8];
    #|  wire lc_raw_c = lc_o_head_lane_3[16];
    #|  wire lc_raw_version_ok = lc_o_head_lane_0[7:0] == 8'd0
    #|    && lc_o_head_lane_0[15:8] == 8'd2;
    #|  wire lc_raw_reserved_ok = lc_o_head_lane_0[31:24] == 8'd0
    #|    && lc_o_head_lane_1[63:48] == 16'd0
    #|    && (lc_o_head_lane_3 & 64'hffffffffff_fefefe) == 64'd0;
    #|  wire lc_raw_fits = lc_raw_rows <= 16'd8191
    #|    && lc_raw_columns <= 16'd8191 && lc_raw_reduction <= 16'd8191;
    #|  wire [3:0] lc_raw_syntax_fault = !lc_raw_version_ok ? 4'd12
    #|    : !lc_raw_reserved_ok ? 4'd13 : lc_raw_opcode > 8'd4 ? 4'd1
    #|    : !lc_raw_fits ? 4'd14 : 4'd0;
    #|  wire lc_raw_syntax_ok = lc_raw_syntax_fault == 4'd0;
    #|  wire lc_raw_is_load = lc_raw_opcode == 8'd0 || lc_raw_opcode == 8'd1;
    #|  wire lc_raw_is_mat = lc_raw_opcode == 8'd2;
    #|  wire lc_raw_is_store = lc_raw_opcode == 8'd3;
    #|  wire lc_raw_is_writer = lc_raw_is_load || lc_raw_is_mat;
    #|  wire [2:0] lc_raw_writer_slot = lc_raw_opcode == 8'd0 ? {2'd0, lc_raw_a}
    #|    : lc_raw_opcode == 8'd1 ? 3'd2 + {2'd0, lc_raw_b}
    #|    : 3'd4 + {2'd0, lc_raw_c};
    #|  // Snapshot registers have a defined raw projection even for bad syntax.
    #|  // Full-byte syntax rejection above still precedes any authorized issue.
    #|  wire [2:0] lc_raw_source0 = lc_raw_opcode[2:0] == 3'd3
    #|    ? 3'd4 + {2'd0, lc_raw_c} : {2'd0, lc_raw_a};
    #|  wire [2:0] lc_raw_source1 = 3'd2 + {2'd0, lc_raw_b};
    #|  wire lc_raw_unused_ok = lc_raw_opcode == 8'd0
    #|    ? (lc_raw_reduction == 0 && !lc_raw_b && !lc_raw_c)
    #|    : lc_raw_opcode == 8'd1
    #|      ? (lc_raw_reduction == 0 && !lc_raw_a && !lc_raw_c)
    #|    : lc_raw_is_mat ? (lc_raw_base == 0 && lc_raw_stride == 0)
    #|    : lc_raw_is_store ? (lc_raw_reduction == 0 && !lc_raw_a && !lc_raw_b)
    #|    : lc_raw_opcode == 8'd4 && lc_raw_rows == 0 && lc_raw_columns == 0
    #|      && lc_raw_reduction == 0 && lc_raw_base == 0 && lc_raw_stride == 0
    #|      && !lc_raw_a && !lc_raw_b && !lc_raw_c;
    #|  wire lc_raw_result_shape_ok = lc_raw_rows == 16'd1 && lc_raw_columns == 16'd1;
    #|  wire lc_raw_dimensions_ok = lc_raw_opcode == 8'd0
    #|    ? (lc_raw_rows == 16'd1 && lc_raw_columns >= 16'd1 && lc_raw_columns <= 16'd2)
    #|    : lc_raw_opcode == 8'd1
    #|      ? (lc_raw_rows >= 16'd1 && lc_raw_rows <= 16'd2 && lc_raw_columns == 16'd1)
    #|    : lc_raw_is_mat ? (lc_raw_result_shape_ok && lc_raw_reduction >= 16'd1
    #|      && lc_raw_reduction <= 16'd2)
    #|    : lc_raw_is_store ? lc_raw_result_shape_ok : lc_raw_opcode == 8'd4;
    #|  wire lc_dispatch_active = !lc_reset && lc_o_head_state == 2'd3;
    #|  wire lc_reservation = !lc_reset && lc_o_head_reserve;
    #|  wire lc_new_intent = lc_reservation && lc_raw_syntax_ok
    #|    && lc_raw_is_writer && !lc_halted;
    #|  wire lc_inner_accept = !lc_reset && lc_o_inner_command_valid && lc_o_inner_command_ready;
    #|  wire lc_priority_eligible = lc_dispatch_active && !lc_halted
    #|    && lc_raw_syntax_ok && lc_raw_unused_ok && lc_raw_dimensions_ok;
    #|
  source
}
