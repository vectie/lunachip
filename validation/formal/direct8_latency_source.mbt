///|
let direct8_latency_id : String = "phase6-flux-tile-direct8-q3-engine-latency-r2-h2"

///|
fn direct8_latency_property_names(
  service_credit? : Bool = false,
) -> ReadOnlyArray[String] {
  let names = [
    "d8l_phase_link", "d8l_issue_progress", "d8l_client_phase", "d8l_client_service11",
    "d8l_potential_bounds", "d8l_potential_step", "d8l_age_history", "d8l_age_potential",
    "d8l_command_latency",
  ]
  if service_credit {
    names.push("d8l_service_credit4")
    names.push("d8l_client_credit")
  }
  ReadOnlyArray::from_array(names)
}

///|
// All arithmetic extends original cursors; no address or memory is rewritten.
fn direct8_latency_source() -> String {
  let out = StringBuilder()
  out.write_string(
    (
      #|  wire lc_l_outer_run = lc_g_q_engine_state_1 == 2'd2;
      #|  wire lc_l_inner_compute = lc_g_composition_capture_state == 2'd1;
      #|  wire lc_l_inner_capture = lc_g_composition_capture_state == 2'd2;
      #|  wire lc_l_inner_done = lc_g_composition_capture_state == 2'd3;
      #|  wire lc_d8l_phase_link = lc_g_reset || (
      #|    (!lc_l_outer_run ? (lc_g_composition_capture_state == 2'd0 && lc_g_composition_shape_core_state == 2'd0)
      #|      : (lc_l_inner_compute || lc_l_inner_capture || lc_l_inner_done))
      #|    && (!lc_l_inner_compute || (lc_g_composition_shape_core_state != 2'd0
      #|      && lc_g_composition_capture_row == 4'd0 && lc_g_composition_capture_column == 4'd0))
      #|    && (!lc_l_inner_capture || lc_g_composition_shape_core_state == 2'd3)
      #|    && (!lc_l_inner_done || lc_g_composition_shape_core_state == 2'd0 || lc_g_composition_shape_core_state == 2'd3)
      #|    && (lc_g_composition_shape_core_state != 2'd1 || lc_g_x_core_steps == 13'd0)
      #|    && (lc_g_x_compute_terminal == (lc_l_outer_run && lc_l_inner_done)));
      #|  wire lc_d8l_issue_progress = lc_g_reset || lc_g_q_engine_state_1 != 2'd1
      #|    || (lc_g_x_issue_accept && lc_g_x_slotted_accept && lc_g_x_core_accept);
      #|  wire lc_l_reader_bus = lc_g_q_engine_state_0 == 3'd1 || lc_g_q_engine_state_0 == 3'd2;
      #|  wire lc_l_engine_bus = lc_g_q_engine_state_2 == 3'd2 || lc_g_q_engine_state_2 == 3'd3;
      #|  wire lc_d8l_client_phase = lc_g_reset || (
      #|    (!lc_g_c0_active || lc_l_reader_bus) && (!lc_g_c1_active || lc_l_engine_bus)
      #|    && (lc_g_q_engine_state_0 != 3'd2 || lc_g_c0_active)
      #|    && (lc_g_q_engine_state_2 != 3'd3 || lc_g_c1_active)
      #|    && (lc_g_i_reader_valid == (lc_g_q_engine_state_0 == 3'd1))
      #|    && (lc_g_i_engine_valid == (lc_g_q_engine_state_2 == 3'd2)));
      #|  wire lc_d8l_client_service11 = lc_g_reset || (
      #|    (!lc_g_c0_active || (lc_g_c0_age <= 4'd11 && (lc_g_reader_ack || lc_g_c0_age < 4'd11)))
      #|    && (!lc_g_c1_active || (lc_g_c1_age <= 4'd11 && (lc_g_engine_ack || lc_g_c1_age < 4'd11))));
      #|  wire [31:0] lc_l_load_ordinal = ({19'd0,lc_g_t_reader_row} << (lc_g_o_load_operand ? 3 : 4)) + {19'd0,lc_g_t_reader_column};
      #|  wire [31:0] lc_l_store_ordinal = ({19'd0,lc_g_t_engine_row} << 3) + {19'd0,lc_g_t_engine_column};
      #|  wire [31:0] lc_l_capture_ordinal = ({28'd0,lc_g_composition_capture_row} << 3) + {28'd0,lc_g_composition_capture_column};
      #|  wire [31:0] lc_l_rank_0 = !lc_e_reader_active ? 32'd0
      #|    : lc_g_q_engine_state_0 == 3'd3 ? 32'd13 * (32'd127 - lc_l_load_ordinal) + 32'd1
      #|    : 32'd13 * (32'd128 - lc_l_load_ordinal) - {28'd0,lc_g_c0_age};
      #|  wire [31:0] lc_l_rank_2 = !lc_e_engine_active ? 32'd0
      #|    : 32'd14 * (32'd64 - lc_l_store_ordinal)
      #|      - (lc_g_q_engine_state_2 == 3'd1 ? 32'd0 : 32'd1 + {28'd0,lc_g_c1_age});
      #|  wire [31:0] lc_l_rank_1 = lc_g_q_engine_state_1 == 2'd1 ? 32'd97 : !lc_l_outer_run ? 32'd0
      #|    : lc_l_inner_done ? 32'd1
      #|    : lc_g_composition_shape_core_state == 2'd1 ? 32'd96
      #|    : lc_g_composition_shape_core_state == 2'd2 ? 32'd95 - {19'd0,lc_g_x_core_steps}
      #|    : 32'd65 - lc_l_capture_ordinal;
      #|
    ),
  )
  let groups : Array[Array[String]] = Array::makei(5, _ => [])
  for (engine, done, bound) in [(0, 4, 1666), (1, 3, 99), (2, 4, 898)] {
    let text =
      $|  wire lc_l_busy_\{engine} = lc_g_q_engine_state_\{engine} != 0;
      $|  wire lc_l_done_\{engine} = lc_g_q_engine_state_\{engine} == \{done};
      $|  logic lc_l_active_\{engine} = 1'b0, lc_l_check_\{engine} = 1'b0;
      $|  logic [10:0] lc_l_age_\{engine} = 11'd0;
      $|  logic [31:0] lc_l_previous_rank_\{engine} = 32'd0;
      $|  wire lc_l_bounds_\{engine} = lc_l_done_\{engine} || !lc_l_busy_\{engine}
      $|    ? lc_l_rank_\{engine} == 32'd0 : lc_l_rank_\{engine} > 32'd0 && lc_l_rank_\{engine} <= 32'd\{bound};
      $|  wire lc_l_step_\{engine} = !lc_l_check_\{engine} || lc_l_rank_\{engine} + 32'd1 <= lc_l_previous_rank_\{engine};
      $|  wire lc_l_history_\{engine} = lc_l_active_\{engine} == lc_l_busy_\{engine}
      $|    && (lc_l_active_\{engine} ? lc_l_age_\{engine} > 11'd0 : lc_l_age_\{engine} == 11'd0);
      $|  wire lc_l_potential_\{engine} = !lc_l_active_\{engine}
      $|    || {21'd0,lc_l_age_\{engine}} + lc_l_rank_\{engine} <= 32'd\{bound};
      $|  wire lc_l_latency_\{engine} = !lc_l_active_\{engine}
      $|    || (lc_l_age_\{engine} <= 11'd\{bound} && (lc_l_age_\{engine} < 11'd\{bound} || lc_l_done_\{engine}));
      $|  always @(posedge lc_g_clock) begin
      $|    if (lc_g_reset) begin
      $|      lc_l_active_\{engine} <= 1'b0; lc_l_check_\{engine} <= 1'b0;
      $|      lc_l_age_\{engine} <= 11'd0; lc_l_previous_rank_\{engine} <= 32'd0;
      $|    end else begin
      $|      lc_l_check_\{engine} <= lc_l_active_\{engine} && !lc_l_done_\{engine} && !lc_g_q_engine_accept_\{engine};
      $|      lc_l_previous_rank_\{engine} <= lc_l_rank_\{engine};
      $|      if (lc_g_q_engine_accept_\{engine}) begin
      $|        lc_l_active_\{engine} <= 1'b1; lc_l_age_\{engine} <= 11'd1;
      $|      end else if (lc_l_done_\{engine}) begin
      $|        lc_l_active_\{engine} <= 1'b0; lc_l_age_\{engine} <= 11'd0;
      $|      end else if (lc_l_active_\{engine} && lc_l_age_\{engine} < 11'd2047)
      $|        lc_l_age_\{engine} <= lc_l_age_\{engine} + 11'd1;
      $|    end
      $|  end
      $|
    out.write_string(text)
    for index, suffix in ["bounds", "step", "history", "potential", "latency"] {
      groups[index].push("lc_l_\{suffix}_\{engine}")
    }
  }
  for
    index, name in [
      "potential_bounds", "potential_step", "age_history", "age_potential", "command_latency",
    ] {
    out.write_string(
      "  wire lc_d8l_\{name} = lc_g_reset || (\{groups[index].join(" && ")});\n",
    )
  }
  out.to_string()
}
