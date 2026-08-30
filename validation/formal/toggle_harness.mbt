///|
fn toggle_harness(
  fixture : ToggleFormalFixture,
  emitted : @rtl.EmittedDesign,
  dut : ToggleFormalDut,
  property_source : String,
  completion_bound : Int,
) -> String raise FormalGateError {
  let source_clock = port_identifier(emitted, InputPort, "source_clock")
  let destination_clock = port_identifier(
    emitted,
    InputPort,
    "destination_clock",
  )
  let source_reset = port_identifier(emitted, InputPort, "source_reset")
  let destination_reset = port_identifier(
    emitted,
    InputPort,
    "destination_reset",
  )
  let source_valid = port_identifier(emitted, InputPort, "source_valid")
  let source_word = port_identifier(emitted, InputPort, "source_word")
  let destination_ready = port_identifier(
    emitted,
    InputPort,
    "destination_ready",
  )
  let source_ready = port_identifier(emitted, OutputPort, "source_ready")
  let destination_valid = port_identifier(
    emitted,
    OutputPort,
    "destination_valid",
  )
  let destination_word = port_identifier(
    emitted,
    OutputPort,
    "destination_word",
  )
  let source_tag = if fixture.has_record_payload() {
    Some(port_identifier(emitted, InputPort, "source_tag"))
  } else {
    None
  }
  let destination_tag = if fixture.has_record_payload() {
    Some(port_identifier(emitted, OutputPort, "destination_tag"))
  } else {
    None
  }
  toggle_validate_formal_observations(fixture, dut.observations)
  let capacity_mutation = if fixture is BrokenToggleCapacity {
    " || (lc_transport_outstanding && lc_source_rise_now && lc_scheduled_source_valid)"
  } else {
    ""
  }
  let held_mutation = if fixture is BrokenToggleSourcePayload {
    " ^ 8'd1"
  } else {
    ""
  }
  let backpressure_mutation = if fixture is BrokenToggleBackpressure {
    " ^ 8'd1"
  } else {
    ""
  }
  let duplicate_mutation = if fixture is BrokenToggleDuplicate {
    " || (lc_seen_destination_capture && !lc_model_response_valid && lc_destination_rise_now)"
  } else {
    ""
  }
  let integrity_mutation = if fixture is BrokenToggleDataIntegrity {
    " ^ 8'd1"
  } else {
    ""
  }
  let watched_consume = if fixture is BrokenToggleCompletion {
    "1'b0"
  } else {
    "lc_destination_consume_event"
  }
  let out = StringBuilder()
  out.write_string("`default_nettype none\n")
  out.write_string("// Generated Phase 5 toggle-handshake formal harness.\n")
  out.write_string("module lc_formal_toggle_top;\n")
  out.write_string("  logic lc_formal_step_clock = 1'b0;\n")
  out.write_string(
    "  always @($global_clock) lc_formal_step_clock <= ~lc_formal_step_clock;\n",
  )
  out.write_string("  (* anyseq *) logic lc_requested_source_clock;\n")
  out.write_string("  (* anyseq *) logic lc_requested_destination_clock;\n")
  out.write_string("  (* anyseq *) logic lc_requested_source_valid;\n")
  out.write_string("  (* anyseq *) logic [7:0] lc_requested_source_word;\n")
  if fixture.has_record_payload() {
    out.write_string("  (* anyseq *) logic [2:0] lc_requested_source_tag;\n")
  }
  out.write_string("  (* anyseq *) logic lc_requested_destination_ready;\n")
  out.write_string("  (* anyseq *) logic lc_requested_watch_select;\n")
  out.write_string("  logic lc_scheduled_source_clock = 1'b0;\n")
  out.write_string("  logic lc_scheduled_destination_clock = 1'b0;\n")
  out.write_string("  logic lc_scheduled_source_valid = 1'b0;\n")
  out.write_string("  logic [7:0] lc_scheduled_source_word = 8'd0;\n")
  if fixture.has_record_payload() {
    out.write_string("  logic [2:0] lc_scheduled_source_tag = 3'd0;\n")
  }
  out.write_string("  logic lc_scheduled_destination_ready = 1'b0;\n")
  out.write_string("  logic lc_scheduled_watch_select = 1'b0;\n")
  out.write_string("  logic lc_source_clock = 1'b0;\n")
  out.write_string("  logic lc_destination_clock = 1'b0;\n")
  out.write_string("  logic lc_source_reset = 1'b1;\n")
  out.write_string("  logic lc_destination_reset = 1'b1;\n")
  out.write_string("  logic [2:0] lc_source_idle_steps = 3'd0;\n")
  out.write_string("  logic [2:0] lc_destination_idle_steps = 3'd0;\n")
  out.write_string("  logic [3:0] lc_source_settle_edges = 4'd0;\n")
  out.write_string("  logic [3:0] lc_destination_settle_edges = 4'd0;\n")
  out.write_string("  logic [2:0] lc_ready_gap_edges = 3'd0;\n")
  out.write_string("  logic lc_last_source_rise = 1'b0;\n")
  out.write_string("  logic lc_last_destination_rise = 1'b0;\n")
  out.write_string(
    "  wire lc_source_rise_now = !lc_source_clock && lc_scheduled_source_clock;\n",
  )
  out.write_string(
    "  wire lc_destination_rise_now = !lc_destination_clock && lc_scheduled_destination_clock;\n",
  )
  out.write_string(
    "  wire lc_source_clock_transition_legal = !(lc_source_clock && lc_requested_source_clock);\n",
  )
  out.write_string(
    "  wire lc_destination_clock_transition_legal = !(lc_destination_clock && lc_requested_destination_clock);\n",
  )
  out.write_string(
    "  wire lc_source_clock_fair = (lc_source_idle_steps < 3) || (!lc_source_clock && lc_requested_source_clock);\n",
  )
  out.write_string(
    "  wire lc_destination_clock_fair = (lc_destination_idle_steps < 3) || (!lc_destination_clock && lc_requested_destination_clock);\n",
  )
  out.write_string(
    "  wire lc_protocol_active = (lc_source_settle_edges >= 4'd\{fixture.stage_count()}) && (lc_destination_settle_edges >= 4'd\{fixture.stage_count()});\n",
  )
  out.write_string(
    "  wire lc_coordinated_reset_initialization = lc_protocol_active || (!lc_scheduled_source_valid && !lc_requested_source_valid);\n",
  )
  let protocol_tag = if fixture.has_record_payload() {
    " && (lc_requested_source_tag == lc_scheduled_source_tag)"
  } else {
    ""
  }
  out.write_string(
    "  wire lc_source_protocol_hold = !lc_scheduled_source_valid || lc_source_ready || (lc_requested_source_valid && (lc_requested_source_word == lc_scheduled_source_word)\{protocol_tag});\n",
  )
  out.write_string(
    "  wire lc_destination_eventual_ready = !lc_protocol_active || (lc_ready_gap_edges < 3) || lc_requested_destination_ready;\n",
  )
  out.write_string("  always_ff @(posedge lc_formal_step_clock) begin\n")
  out.write_string(
    "    lc_scheduled_source_clock <= lc_requested_source_clock;\n",
  )
  out.write_string(
    "    lc_scheduled_destination_clock <= lc_requested_destination_clock;\n",
  )
  out.write_string(
    "    lc_scheduled_source_valid <= lc_requested_source_valid;\n",
  )
  out.write_string(
    "    lc_scheduled_source_word <= lc_requested_source_word;\n",
  )
  if fixture.has_record_payload() {
    out.write_string(
      "    lc_scheduled_source_tag <= lc_requested_source_tag;\n",
    )
  }
  out.write_string(
    "    lc_scheduled_destination_ready <= lc_requested_destination_ready;\n",
  )
  out.write_string(
    "    lc_scheduled_watch_select <= lc_requested_watch_select;\n",
  )
  out.write_string("  end\n")
  out.write_string("  always_ff @(negedge lc_formal_step_clock) begin\n")
  out.write_string("    lc_last_source_rise <= lc_source_rise_now;\n")
  out.write_string("    lc_last_destination_rise <= lc_destination_rise_now;\n")
  out.write_string("    lc_source_clock <= lc_scheduled_source_clock;\n")
  out.write_string(
    "    lc_destination_clock <= lc_scheduled_destination_clock;\n",
  )
  out.write_string(
    "    if (lc_source_rise_now) lc_source_idle_steps <= 3'd0; else if (lc_source_idle_steps != 3'd7) lc_source_idle_steps <= lc_source_idle_steps + 3'd1;\n",
  )
  out.write_string(
    "    if (lc_destination_rise_now) lc_destination_idle_steps <= 3'd0; else if (lc_destination_idle_steps != 3'd7) lc_destination_idle_steps <= lc_destination_idle_steps + 3'd1;\n",
  )
  out.write_string("  end\n")
  out.write_string("  always_ff @(posedge lc_source_clock) begin\n")
  out.write_string("    if (lc_source_reset) begin\n")
  out.write_string("      lc_source_reset <= 1'b0;\n")
  out.write_string("      lc_source_settle_edges <= 4'd0;\n")
  out.write_string("    end else if (lc_source_settle_edges != 4'd15) begin\n")
  out.write_string(
    "      lc_source_settle_edges <= lc_source_settle_edges + 4'd1;\n",
  )
  out.write_string("    end\n")
  out.write_string("  end\n")
  out.write_string("  always_ff @(posedge lc_destination_clock) begin\n")
  out.write_string("    if (lc_destination_reset) begin\n")
  out.write_string("      lc_destination_reset <= 1'b0;\n")
  out.write_string("      lc_destination_settle_edges <= 4'd0;\n")
  out.write_string("      lc_ready_gap_edges <= 3'd0;\n")
  out.write_string("    end else begin\n")
  out.write_string(
    "      if (lc_destination_settle_edges != 4'd15) lc_destination_settle_edges <= lc_destination_settle_edges + 4'd1;\n",
  )
  out.write_string(
    "      if (lc_scheduled_destination_ready) lc_ready_gap_edges <= 3'd0; else if (lc_ready_gap_edges != 3'd7) lc_ready_gap_edges <= lc_ready_gap_edges + 3'd1;\n",
  )
  out.write_string("    end\n")
  out.write_string("  end\n\n")
  out.write_string("  logic lc_source_ready;\n")
  out.write_string("  logic lc_destination_valid;\n")
  out.write_string("  logic [7:0] lc_destination_word;\n")
  if fixture.has_record_payload() {
    out.write_string("  logic [2:0] lc_destination_tag;\n")
  }
  for observation in dut.observations {
    out.write_string(
      "  wire \{toggle_formal_width_range(observation.width)}lc_\{observation.role};\n",
    )
  }
  out.write_string("  \{dut.identifier()} lc_dut (\n")
  out.write_string("    .\{source_clock}(lc_source_clock),\n")
  out.write_string("    .\{destination_clock}(lc_destination_clock),\n")
  out.write_string("    .\{source_reset}(lc_source_reset),\n")
  out.write_string("    .\{destination_reset}(lc_destination_reset),\n")
  out.write_string("    .\{source_valid}(lc_scheduled_source_valid),\n")
  out.write_string("    .\{source_word}(lc_scheduled_source_word),\n")
  match source_tag {
    Some(tag) => out.write_string("    .\{tag}(lc_scheduled_source_tag),\n")
    None => ()
  }
  out.write_string(
    "    .\{destination_ready}(lc_scheduled_destination_ready),\n",
  )
  out.write_string("    .\{source_ready}(lc_source_ready),\n")
  out.write_string("    .\{destination_valid}(lc_destination_valid),\n")
  out.write_string("    .\{destination_word}(lc_destination_word),\n")
  match destination_tag {
    Some(tag) => out.write_string("    .\{tag}(lc_destination_tag),\n")
    None => ()
  }
  for index, observation in dut.observations {
    out.write_string(
      "    .\{observation.port}(lc_\{observation.role})\{if index + 1 == dut.observations.length() { "\n" } else { ",\n" }}",
    )
  }
  out.write_string("  );\n")
  out.write_string(
    "  wire lc_source_accept_event = lc_protocol_active && lc_source_rise_now && lc_source_accept;\n",
  )
  out.write_string(
    "  wire lc_destination_capture_event = lc_protocol_active && lc_destination_rise_now && lc_destination_capture;\n",
  )
  out.write_string(
    "  wire lc_destination_consume_event = lc_protocol_active && lc_destination_rise_now && lc_destination_consume;\n",
  )
  out.write_string("  logic lc_transport_outstanding = 1'b0;\n")
  out.write_string("  logic [7:0] lc_transport_word = 8'd0;\n")
  out.write_string("  logic [2:0] lc_transport_tag = 3'd0;\n")
  out.write_string("  logic lc_model_response_valid = 1'b0;\n")
  out.write_string("  logic [7:0] lc_model_response_word = 8'd0;\n")
  out.write_string("  logic [2:0] lc_model_response_tag = 3'd0;\n")
  out.write_string("  logic lc_watched_transport = 1'b0;\n")
  out.write_string("  logic lc_watched_response = 1'b0;\n")
  out.write_string("  logic lc_watched_complete = 1'b0;\n")
  out.write_string("  logic [7:0] lc_watched_word = 8'd0;\n")
  out.write_string("  logic [2:0] lc_watched_tag = 3'd0;\n")
  out.write_string("  logic [7:0] lc_watched_age = 8'd0;\n")
  out.write_string(
    "  wire lc_watched_active = lc_watched_transport || lc_watched_response;\n",
  )
  out.write_string("  logic lc_previous_acknowledge = 1'b0;\n")
  out.write_string("  logic lc_previous_capture = 1'b0;\n")
  out.write_string("  logic lc_observation_armed = 1'b0;\n")
  out.write_string("  logic lc_seen_source_accept = 1'b0;\n")
  out.write_string("  logic lc_seen_destination_capture = 1'b0;\n")
  out.write_string("  logic lc_capacity_error = 1'b0;\n")
  out.write_string("  logic lc_source_payload_error = 1'b0;\n")
  out.write_string("  logic lc_backpressure_error = 1'b0;\n")
  out.write_string("  logic lc_duplicate_error = 1'b0;\n")
  out.write_string("  logic lc_integrity_error = 1'b0;\n")
  out.write_string("  logic lc_completion_error = 1'b0;\n")
  out.write_string("  logic lc_cover_coincident = 1'b0;\n")
  out.write_string("  logic lc_cover_consume_refill = 1'b0;\n")
  out.write_string("  logic lc_cover_watched_complete = 1'b0;\n")
  out.write_string(
    "  wire lc_capacity_source_accept_event = lc_source_accept_event\{capacity_mutation};\n",
  )
  out.write_string(
    "  wire [7:0] lc_monitored_held_word = lc_held_word\{held_mutation};\n",
  )
  out.write_string(
    "  wire [7:0] lc_monitored_backpressure_word = lc_destination_word\{backpressure_mutation};\n",
  )
  out.write_string(
    "  wire lc_monitored_consume_event = lc_destination_consume_event\{duplicate_mutation};\n",
  )
  out.write_string(
    "  wire [7:0] lc_monitored_integrity_word = lc_destination_word\{integrity_mutation};\n",
  )
  out.write_string("  wire lc_watched_consume_event = \{watched_consume};\n")
  let tag_held_equal = if fixture.has_record_payload() {
    " && (lc_held_tag == lc_transport_tag)"
  } else {
    ""
  }
  let tag_response_equal = if fixture.has_record_payload() {
    " && (lc_destination_tag == lc_model_response_tag)"
  } else {
    ""
  }
  let tag_watched_equal = if fixture.has_record_payload() {
    " && (lc_destination_tag == lc_watched_tag)"
  } else {
    ""
  }
  out.write_string("  always_ff @(negedge lc_formal_step_clock) begin\n")
  out.write_string("    if (lc_protocol_active) begin\n")
  out.write_string("      lc_observation_armed <= 1'b1;\n")
  out.write_string(
    "      if (lc_source_rise_now && lc_destination_rise_now) lc_cover_coincident <= 1'b1;\n",
  )
  out.write_string(
    "      if (lc_destination_capture_event && lc_destination_consume_event) lc_cover_consume_refill <= 1'b1;\n",
  )
  out.write_string(
    "      if (lc_capacity_source_accept_event && lc_transport_outstanding) lc_capacity_error <= 1'b1;\n",
  )
  out.write_string(
    "      if (lc_destination_capture_event && (!lc_transport_outstanding || (lc_model_response_valid && !lc_destination_consume_event))) lc_capacity_error <= 1'b1;\n",
  )
  out.write_string(
    "      if (lc_transport_outstanding && !((lc_monitored_held_word == lc_transport_word)\{tag_held_equal})) lc_source_payload_error <= 1'b1;\n",
  )
  out.write_string(
    "      if (lc_model_response_valid && !((lc_destination_word == lc_model_response_word)\{tag_response_equal})) lc_integrity_error <= 1'b1;\n",
  )
  out.write_string(
    "      if (lc_destination_rise_now && lc_destination_valid && !lc_scheduled_destination_ready && !((lc_monitored_backpressure_word == lc_model_response_word)\{tag_response_equal})) lc_backpressure_error <= 1'b1;\n",
  )
  out.write_string(
    "      if (lc_monitored_consume_event && !lc_model_response_valid) lc_duplicate_error <= 1'b1;\n",
  )
  out.write_string(
    "      if (lc_observation_armed && ((lc_acknowledge_toggle != lc_previous_acknowledge) != lc_previous_capture)) lc_duplicate_error <= 1'b1;\n",
  )
  out.write_string("      lc_previous_acknowledge <= lc_acknowledge_toggle;\n")
  out.write_string(
    "      lc_previous_capture <= lc_destination_capture_event;\n",
  )
  out.write_string(
    "      if (lc_source_accept_event) begin lc_seen_source_accept <= 1'b1; lc_transport_word <= lc_scheduled_source_word;",
  )
  if fixture.has_record_payload() {
    out.write_string(" lc_transport_tag <= lc_scheduled_source_tag;")
  }
  out.write_string(" end\n")
  out.write_string(
    "      case ({lc_source_accept_event, lc_destination_capture_event})\n",
  )
  out.write_string("        2'b10: lc_transport_outstanding <= 1'b1;\n")
  out.write_string("        2'b01: lc_transport_outstanding <= 1'b0;\n")
  out.write_string(
    "        default: lc_transport_outstanding <= lc_transport_outstanding;\n",
  )
  out.write_string("      endcase\n")
  out.write_string("      if (lc_destination_capture_event) begin\n")
  out.write_string("        lc_seen_destination_capture <= 1'b1;\n")
  out.write_string("        lc_model_response_valid <= 1'b1;\n")
  out.write_string("        lc_model_response_word <= lc_transport_word;\n")
  if fixture.has_record_payload() {
    out.write_string("        lc_model_response_tag <= lc_transport_tag;\n")
  }
  out.write_string("      end else if (lc_destination_consume_event) begin\n")
  out.write_string("        lc_model_response_valid <= 1'b0;\n")
  out.write_string("      end\n")
  out.write_string(
    "      if (lc_source_accept_event && lc_scheduled_watch_select && !lc_watched_active && !lc_watched_complete) begin\n",
  )
  out.write_string("        lc_watched_transport <= 1'b1;\n")
  out.write_string("        lc_watched_word <= lc_scheduled_source_word;\n")
  if fixture.has_record_payload() {
    out.write_string("        lc_watched_tag <= lc_scheduled_source_tag;\n")
  }
  out.write_string("        lc_watched_age <= 8'd0;\n")
  out.write_string("      end\n")
  out.write_string(
    "      if (lc_destination_capture_event && lc_watched_transport) begin\n",
  )
  out.write_string("        lc_watched_transport <= 1'b0;\n")
  out.write_string("        lc_watched_response <= 1'b1;\n")
  out.write_string(
    "        if (!((lc_transport_word == lc_watched_word)\{if fixture.has_record_payload() { " && (lc_transport_tag == lc_watched_tag)" } else { "" }})) lc_integrity_error <= 1'b1;\n",
  )
  out.write_string("      end\n")
  out.write_string(
    "      if (lc_watched_consume_event && lc_watched_response) begin\n",
  )
  out.write_string(
    "        if (!((lc_monitored_integrity_word == lc_watched_word)\{tag_watched_equal})) lc_integrity_error <= 1'b1;\n",
  )
  out.write_string("        lc_watched_response <= 1'b0;\n")
  out.write_string("        lc_watched_complete <= 1'b1;\n")
  out.write_string("        lc_cover_watched_complete <= 1'b1;\n")
  out.write_string("      end\n")
  out.write_string(
    "      if (lc_watched_active && !lc_watched_complete) begin\n",
  )
  out.write_string(
    "        if (lc_watched_age >= 8'd\{completion_bound}) lc_completion_error <= 1'b1; else lc_watched_age <= lc_watched_age + 8'd1;\n",
  )
  out.write_string("      end\n")
  out.write_string("    end\n")
  out.write_string("  end\n")
  out.write_string("  wire lc_capacity_base = !lc_capacity_error;\n")
  out.write_string(
    "  wire lc_source_payload_base = !lc_source_payload_error;\n",
  )
  out.write_string("  wire lc_backpressure_base = !lc_backpressure_error;\n")
  out.write_string("  wire lc_duplicate_base = !lc_duplicate_error;\n")
  out.write_string("  wire lc_integrity_base = !lc_integrity_error;\n")
  out.write_string("  wire lc_completion_base = !lc_completion_error;\n")
  out.write_string(
    "  wire lc_one_item_in_flight_capacity = lc_capacity_base;\n",
  )
  out.write_string(
    "  wire lc_source_payload_stable_while_outstanding = lc_source_payload_base;\n",
  )
  out.write_string(
    "  wire lc_destination_response_stable_under_backpressure = lc_backpressure_base;\n",
  )
  out.write_string(
    "  wire lc_no_duplicate_acknowledge_or_consume = lc_duplicate_base;\n",
  )
  out.write_string(
    "  wire lc_watched_transaction_data_integrity = lc_integrity_base;\n",
  )
  out.write_string(
    "  wire lc_watched_transaction_completes = lc_completion_base;\n",
  )
  out.write_string(
    "  wire lc_coincident_source_destination_edge = lc_cover_coincident;\n",
  )
  out.write_string(
    "  wire lc_simultaneous_destination_consume_and_refill = lc_cover_consume_refill;\n",
  )
  out.write_string(
    "  wire lc_watched_transaction_accept_capture_consume = lc_cover_watched_complete;\n\n",
  )
  out.write_string(property_source)
  out.write_string("endmodule\n`default_nettype wire\n")
  out.to_string()
}
