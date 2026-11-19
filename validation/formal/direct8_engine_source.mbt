///|
let direct8_engine_id : String = "phase6-flux-tile-direct8-q3-engine-progress-r2-h2"

///|
let direct8_engine_supported_id : String = direct8_engine_id + "-owner-support"

///|
fn direct8_engine_property_names(
  owner_support~ : Bool = false,
  completed_prefix~ : Bool = false,
) -> ReadOnlyArray[String] {
  let names = [
    "d8e_request_hold", "d8e_wait_progress", "d8e_cursor_step", "d8e_config_hold",
    "d8e_cursor_bounds", "d8e_loader_commit", "d8e_store_read", "d8e_core_shape",
    "d8e_core_rank", "d8e_core_step", "d8e_capture_shape", "d8e_capture_step", "d8e_lease_step",
    "d8e_request_service",
  ]
  if owner_support {
    for
      name in [
        "d8e_lease_phase", "d8e_inner_snapshot", "d8e_loader_lease", "d8e_store_lease",
        "d8e_pending_owner", "d8e_prefix_bounds", "d8e_loader_prefix",
      ] {
      names.push(name)
    }
  }
  if completed_prefix {
    names.push("d8e_completed_prefix")
  }
  ReadOnlyArray::from_array(names)
}

///|
// Observers sample PRE and check the following PRE. All original addresses,
// cursors, payloads and unknown memory equations remain untouched.
fn direct8_engine_source(
  owner_support~ : Bool = false,
  completed_prefix~ : Bool = false,
) -> String {
  let out = StringBuilder()
  for
    (client, engine, request_state, wait_state) in [
      ("reader", 0, 1, 2),
      ("engine", 2, 2, 3),
    ] {
    out.write_string(
      direct8_engine_transfer_source(client, engine, request_state, wait_state),
    )
  }
  for
    name in [
      "request_hold", "wait_progress", "cursor_step", "config_hold", "cursor_bounds",
    ] {
    out.write_string(
      "  wire lc_d8e_\{name} = lc_g_reset || (lc_e_reader_\{name} && lc_e_engine_\{name});\n",
    )
  }
  let body =
    #|  wire lc_d8e_loader_commit = lc_g_reset || lc_g_q_engine_state_0 != 3'd3 || lc_g_t_reader_advance;
    #|  logic lc_e_previous_store_read = 1'b0;
    #|  wire lc_d8e_store_read = lc_g_reset || !lc_e_previous_store_read || lc_g_q_engine_state_2 == 3'd2;
    #|  wire lc_e_core_active = lc_g_composition_shape_core_state == 2'd1 || lc_g_composition_shape_core_state == 2'd2;
    #|  wire lc_d8e_core_shape = lc_g_reset || !lc_e_core_active
    #|    || (lc_g_composition_shape_core_fault == 2'd0
    #|      && lc_g_composition_shape_core_rows > 4'd0 && lc_g_composition_shape_core_rows <= 4'd8
    #|      && lc_g_composition_shape_core_columns > 4'd0 && lc_g_composition_shape_core_columns <= 4'd8
    #|      && lc_g_composition_shape_core_reduction > 13'd0 && lc_g_composition_shape_core_reduction <= 13'd16);
    #|  wire lc_d8e_core_rank = lc_g_reset || !lc_e_core_active
    #|    || (lc_g_x_core_total > 13'd0 && lc_g_x_core_total <= 13'd30
    #|      && lc_g_x_core_total == lc_g_composition_shape_core_reduction
    #|        + {9'd0,lc_g_composition_shape_core_rows} + {9'd0,lc_g_composition_shape_core_columns} - 13'd2
    #|      && lc_g_x_core_steps < lc_g_x_core_total
    #|      && (!lc_g_x_running || lc_g_x_core_advance));
    #|  logic lc_e_seen = 1'b0, lc_e_core_check = 1'b0;
    #|  logic [1:0] lc_e_expected_core_state = 2'd0;
    #|  logic [12:0] lc_e_expected_steps = 13'd0;
    #|  wire lc_d8e_core_step = lc_g_reset || !lc_e_core_check
    #|    || (lc_g_composition_shape_core_state == lc_e_expected_core_state && lc_g_x_core_steps == lc_e_expected_steps);
    #|  wire lc_e_capture_active = lc_g_composition_capture_state == 2'd1 || lc_g_composition_capture_state == 2'd2;
    #|  wire lc_e_capture = lc_g_composition_shape_capture;
    #|  wire lc_e_capture_last_column = lc_g_composition_capture_column + 4'd1 == lc_g_composition_shape_core_columns;
    #|  wire lc_d8e_capture_shape = lc_g_reset
    #|    || ((!lc_e_capture_active || (lc_g_composition_shape_core_fault == 2'd0
    #|        && lc_g_composition_shape_core_rows > 4'd0 && lc_g_composition_shape_core_rows <= 4'd8
    #|        && lc_g_composition_shape_core_columns > 4'd0 && lc_g_composition_shape_core_columns <= 4'd8
    #|        && lc_g_composition_capture_row < lc_g_composition_shape_core_rows
    #|        && lc_g_composition_capture_column < lc_g_composition_shape_core_columns))
    #|      && (!lc_e_capture || lc_e_capture_active)
    #|      && (lc_g_composition_capture_state != 2'd2 || lc_e_capture)
    #|      && (lc_g_x_final_capture == (lc_e_capture && lc_e_capture_last_column
    #|        && lc_g_composition_capture_row + 4'd1 == lc_g_composition_shape_core_rows)));
    #|  logic [3:0] lc_e_expected_capture_row = 4'd0, lc_e_expected_capture_column = 4'd0;
    #|  logic lc_e_capture_check = 1'b0;
    #|  logic [1:0] lc_e_expected_capture_state = 2'd0;
    #|  wire lc_d8e_capture_step = lc_g_reset || !lc_e_seen
    #|    || (lc_g_composition_capture_row == lc_e_expected_capture_row
    #|      && lc_g_composition_capture_column == lc_e_expected_capture_column
    #|      && (!lc_e_capture_check || lc_g_composition_capture_state == lc_e_expected_capture_state));
    #|  logic lc_e_expected_lease = 1'b0;
    #|  wire lc_d8e_lease_step = lc_g_reset
    #|    || ((!lc_e_seen || lc_g_x_lease == lc_e_expected_lease)
    #|      && (!lc_g_x_ownership || lc_g_x_lease)
    #|      && (lc_g_x_release == (lc_g_x_final_capture || (lc_g_x_compute_terminal && !lc_g_x_ownership))));
    #|  wire lc_d8e_request_service = lc_g_reset
    #|    || (!lc_g_c0_cancel && !lc_g_c1_cancel
    #|      && (!lc_g_c0_active || lc_g_reader_ack || lc_g_c0_age < 4'd12)
    #|      && (!lc_g_c1_active || lc_g_engine_ack || lc_g_c1_age < 4'd12));
    #|  always @(posedge lc_g_clock) begin
    #|    if (lc_g_reset) begin
    #|      lc_e_seen <= 1'b0; lc_e_core_check <= 1'b0; lc_e_capture_check <= 1'b0;
    #|      lc_e_previous_store_read <= 1'b0; lc_e_expected_lease <= 1'b0;
    #|      lc_e_expected_core_state <= 2'd0; lc_e_expected_steps <= 13'd0;
    #|      lc_e_expected_capture_row <= 4'd0; lc_e_expected_capture_column <= 4'd0;
    #|      lc_e_expected_capture_state <= 2'd0;
    #|    end else begin
    #|      lc_e_seen <= 1'b1;
    #|      lc_e_previous_store_read <= lc_g_q_engine_state_2 == 3'd1;
    #|      lc_e_core_check <= lc_g_x_clear || lc_g_x_running;
    #|      lc_e_expected_core_state <= lc_g_x_clear ? 2'd2 : (lc_g_x_core_final_step ? 2'd3 : 2'd2);
    #|      lc_e_expected_steps <= lc_g_x_clear ? lc_g_x_core_steps : lc_g_x_core_steps + 13'd1;
    #|      lc_e_expected_capture_row <= lc_g_x_slotted_accept ? 4'd0
    #|        : lc_g_composition_capture_row + ((lc_e_capture && lc_e_capture_last_column) ? 4'd1 : 4'd0);
    #|      lc_e_expected_capture_column <= lc_g_x_slotted_accept ? 4'd0
    #|        : lc_e_capture ? (lc_e_capture_last_column ? 4'd0 : lc_g_composition_capture_column + 4'd1)
    #|        : lc_g_composition_capture_column;
    #|      lc_e_capture_check <= lc_e_capture;
    #|      lc_e_expected_capture_state <= lc_g_x_final_capture ? 2'd3 : 2'd2;
    #|      lc_e_expected_lease <= lc_g_x_compute_legal_accept ? 1'b1 : lc_g_x_release ? 1'b0 : lc_g_x_lease;
    #|    end
    #|  end
    #|
  out.write_string(body)
  if owner_support {
    out.write_string(direct8_engine_owner_source())
  }
  if completed_prefix {
    out.write_string(direct8_engine_completed_prefix_source())
  }
  out.to_string()
}

///|
fn direct8_engine_transfer_source(
  client : String,
  engine : Int32,
  request_state : Int32,
  wait_state : Int32,
) -> String {
  let ack_next = if engine == 0 {
    "3'd3"
  } else {
    "((lc_g_t_engine_last_column && lc_g_t_engine_row + 13'd1 == lc_g_t_engine_rows) ? 3'd4 : 3'd1)"
  }
  let maximum = if engine == 0 { "16" } else { "8" }
  let shape = if engine == 0 {
    "(lc_g_t_reader_rows <= 13'd8 || lc_g_t_reader_columns <= 13'd8)"
  } else {
    "1'b1"
  }
  let text =
    $|  logic lc_e_\{client}_hold = 1'b0, lc_e_\{client}_seen = 1'b0;
    $|  logic [103:0] lc_e_\{client}_payload = 104'd0;
    $|  logic lc_e_\{client}_wait_check = 1'b0, lc_e_\{client}_config_check = 1'b0;
    $|  logic [2:0] lc_e_\{client}_expected_state = 3'd0;
    $|  logic [12:0] lc_e_\{client}_row = 13'd0, lc_e_\{client}_column = 13'd0;
    $|  logic [89:0] lc_e_\{client}_configuration = 90'd0;
    $|  wire [89:0] lc_e_\{client}_current_configuration = {lc_g_t_\{client}_base, lc_g_t_\{client}_stride, lc_g_t_\{client}_rows, lc_g_t_\{client}_columns};
    $|  wire lc_e_\{client}_request_hold = (!lc_g_i_\{client}_valid || lc_g_q_engine_state_\{engine} == 3'd\{request_state})
    $|    && (!lc_e_\{client}_hold || (lc_g_i_\{client}_valid && lc_g_\{client}_payload == lc_e_\{client}_payload));
    $|  wire lc_e_\{client}_wait_progress = !lc_e_\{client}_wait_check || lc_g_q_engine_state_\{engine} == lc_e_\{client}_expected_state;
    $|  wire lc_e_\{client}_cursor_step = !lc_e_\{client}_seen
    $|    || (lc_g_t_\{client}_row == lc_e_\{client}_row && lc_g_t_\{client}_column == lc_e_\{client}_column);
    $|  wire lc_e_\{client}_config_hold = !lc_e_\{client}_config_check || lc_e_\{client}_current_configuration == lc_e_\{client}_configuration;
    $|  wire lc_e_\{client}_active = lc_g_q_engine_state_\{engine} >= 3'd1 && lc_g_q_engine_state_\{engine} <= 3'd3;
    $|  wire lc_e_\{client}_cursor_bounds = !lc_e_\{client}_active
    $|    || (lc_g_t_\{client}_rows > 13'd0 && lc_g_t_\{client}_rows <= 13'd\{maximum}
    $|      && lc_g_t_\{client}_columns > 13'd0 && lc_g_t_\{client}_columns <= 13'd\{maximum}
    $|      && \{shape}
    $|      && lc_g_t_\{client}_row < lc_g_t_\{client}_rows && lc_g_t_\{client}_column < lc_g_t_\{client}_columns);
    $|  always @(posedge lc_g_clock) begin
    $|    if (lc_g_reset) begin
    $|      lc_e_\{client}_hold <= 1'b0; lc_e_\{client}_seen <= 1'b0;
    $|      lc_e_\{client}_wait_check <= 1'b0; lc_e_\{client}_config_check <= 1'b0;
    $|      lc_e_\{client}_payload <= 104'd0; lc_e_\{client}_configuration <= 90'd0;
    $|      lc_e_\{client}_row <= 13'd0; lc_e_\{client}_column <= 13'd0;
    $|      lc_e_\{client}_expected_state <= 3'd0;
    $|    end else begin
    $|      lc_e_\{client}_seen <= 1'b1;
    $|      lc_e_\{client}_hold <= lc_g_i_\{client}_valid && !lc_g_e_\{client}_request_ready;
    $|      lc_e_\{client}_payload <= lc_g_\{client}_payload;
    $|      lc_e_\{client}_config_check <= !lc_g_t_\{client}_accept;
    $|      lc_e_\{client}_configuration <= lc_e_\{client}_current_configuration;
    $|      lc_e_\{client}_wait_check <= (lc_g_i_\{client}_valid && lc_g_e_\{client}_request_ready) || lc_g_\{client}_ack;
    $|      lc_e_\{client}_expected_state <= lc_g_\{client}_ack ? \{ack_next} : 3'd\{wait_state};
    $|      lc_e_\{client}_row <= lc_g_t_\{client}_accept ? 13'd0
    $|        : lc_g_t_\{client}_row + ((lc_g_t_\{client}_advance && lc_g_t_\{client}_last_column) ? 13'd1 : 13'd0);
    $|      lc_e_\{client}_column <= lc_g_t_\{client}_accept ? 13'd0
    $|        : lc_g_t_\{client}_advance ? (lc_g_t_\{client}_last_column ? 13'd0 : lc_g_t_\{client}_column + 13'd1)
    $|        : lc_g_t_\{client}_column;
    $|    end
    $|  end
    $|
  text
}
