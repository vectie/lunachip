///|
fn async_fifo_harness(
  fixture : AsyncFifoFormalFixture,
  design : @ir.Design,
  emitted : @rtl.EmittedDesign,
  dut : AsyncFifoFormalDut,
  property_source : String,
  completion_bound : Int,
) -> String raise FormalGateError {
  guard design.top_module() is Some(hardware_module) else {
    raise MissingTopModule
  }
  guard hardware_module.cdc_primitives() is [AsyncFifo(_)] else {
    raise InvalidAsyncFifoFormalBundle("expected one asynchronous FIFO")
  }
  let port = fn(
    kind : @rtl.SymbolKind,
    name : String,
  ) -> String raise FormalGateError {
    port_identifier(emitted, kind, name)
  }
  let source_clock = port(InputPort, "source_clock")
  let destination_clock = port(InputPort, "destination_clock")
  let source_reset = port(InputPort, "source_reset")
  let destination_reset = port(InputPort, "destination_reset")
  let source_valid = port(InputPort, "source_valid")
  let source_word = port(InputPort, "source_word")
  let destination_ready = port(InputPort, "destination_ready")
  let source_ready = port(OutputPort, "source_ready")
  let destination_valid = port(OutputPort, "destination_valid")
  let destination_word = port(OutputPort, "destination_word")
  let gray_mutant = if fixture is BrokenAsyncFifoGray { " ^ 3'd1" } else { "" }
  let full_mutant = if fixture is BrokenAsyncFifoFull { " ^ 1'b1" } else { "" }
  let address_mutant = if fixture is BrokenAsyncFifoAddress {
    " ^ 2'd1"
  } else {
    ""
  }
  let storage_mutant = if fixture is BrokenAsyncFifoStorageOrder {
    " ^ 8'd1"
  } else {
    ""
  }
  let read_pipeline_mutant = if fixture is BrokenAsyncFifoReadPipeline {
    " ^ 3'd1"
  } else {
    ""
  }
  let write_pipeline_mutant = if fixture is BrokenAsyncFifoWritePipeline {
    " ^ 3'd1"
  } else {
    ""
  }
  let write_bounds_mutant = if fixture is BrokenAsyncFifoWriteAddressBounds {
    " | 3'd4"
  } else {
    ""
  }
  let read_bounds_mutant = if fixture is BrokenAsyncFifoReadAddressBounds {
    " | 3'd4"
  } else {
    ""
  }
  let out = StringBuilder()
  out.write_string("`default_nettype none\nmodule lc_formal_async_fifo_top;\n")
  out.write_string(
    "  logic lc_formal_step_clock = 1'b0;\n  always @($global_clock) lc_formal_step_clock <= ~lc_formal_step_clock;\n",
  )
  out.write_string(
    "  (* anyseq *) logic lc_requested_source_clock;\n  (* anyseq *) logic lc_requested_destination_clock;\n  (* anyseq *) logic lc_requested_source_valid;\n  (* anyseq *) logic [7:0] lc_requested_source_word;\n  (* anyseq *) logic lc_requested_destination_ready;\n  (* anyseq *) logic lc_requested_watch_select;\n",
  )
  out.write_string(
    "  logic lc_scheduled_source_clock = 1'b0;\n  logic lc_scheduled_destination_clock = 1'b0;\n  logic lc_scheduled_source_valid = 1'b0;\n  logic [7:0] lc_scheduled_source_word = 8'd0;\n  logic lc_scheduled_destination_ready = 1'b0;\n  logic lc_scheduled_watch_select = 1'b0;\n",
  )
  out.write_string(
    "  logic lc_source_clock = 1'b0;\n  logic lc_destination_clock = 1'b0;\n  logic lc_source_reset = 1'b1;\n  logic lc_destination_reset = 1'b1;\n  logic [2:0] lc_source_idle = 3'd0;\n  logic [2:0] lc_destination_idle = 3'd0;\n  logic [2:0] lc_source_settle = 3'd0;\n  logic [2:0] lc_destination_settle = 3'd0;\n  logic [2:0] lc_ready_gap = 3'd0;\n",
  )
  out.write_string(
    "  wire lc_source_rise = !lc_source_clock && lc_scheduled_source_clock;\n  wire lc_destination_rise = !lc_destination_clock && lc_scheduled_destination_clock;\n",
  )
  out.write_string(
    "  wire lc_source_clock_transition_legal = !(lc_source_clock && lc_requested_source_clock);\n  wire lc_destination_clock_transition_legal = !(lc_destination_clock && lc_requested_destination_clock);\n  wire lc_source_clock_fair = (lc_source_idle < 3) || (!lc_source_clock && lc_requested_source_clock);\n  wire lc_destination_clock_fair = (lc_destination_idle < 3) || (!lc_destination_clock && lc_requested_destination_clock);\n",
  )
  out.write_string(
    "  wire lc_protocol_active = (lc_source_settle >= 3'd2) && (lc_destination_settle >= 3'd2);\n  wire lc_coordinated_reset_initialization = lc_protocol_active || !lc_scheduled_source_valid;\n",
  )
  out.write_string(
    "  logic lc_source_ready;\n  logic lc_destination_valid;\n  logic [7:0] lc_destination_word;\n",
  )
  out.write_string(
    "  wire lc_source_protocol_hold = !lc_scheduled_source_valid || lc_source_ready || (lc_requested_source_valid && (lc_requested_source_word == lc_scheduled_source_word));\n  wire lc_destination_eventual_ready = !lc_protocol_active || (lc_ready_gap < 3) || lc_requested_destination_ready;\n",
  )
  out.write_string(
    "  always_ff @(posedge lc_formal_step_clock) begin\n    lc_scheduled_source_clock <= lc_requested_source_clock;\n    lc_scheduled_destination_clock <= lc_requested_destination_clock;\n    lc_scheduled_source_valid <= lc_requested_source_valid;\n    lc_scheduled_source_word <= lc_requested_source_word;\n    lc_scheduled_destination_ready <= lc_requested_destination_ready;\n    lc_scheduled_watch_select <= lc_requested_watch_select;\n  end\n",
  )
  out.write_string(
    "  always_ff @(negedge lc_formal_step_clock) begin\n    lc_source_clock <= lc_scheduled_source_clock;\n    lc_destination_clock <= lc_scheduled_destination_clock;\n    if (lc_source_rise) lc_source_idle <= 0; else if (lc_source_idle != 7) lc_source_idle <= lc_source_idle + 1;\n    if (lc_destination_rise) lc_destination_idle <= 0; else if (lc_destination_idle != 7) lc_destination_idle <= lc_destination_idle + 1;\n  end\n",
  )
  out.write_string(
    "  always_ff @(posedge lc_source_clock) begin\n    if (lc_source_reset) begin lc_source_reset <= 1'b0; lc_source_settle <= 0; end\n    else if (lc_source_settle != 7) lc_source_settle <= lc_source_settle + 1;\n  end\n",
  )
  out.write_string(
    "  always_ff @(posedge lc_destination_clock) begin\n    if (lc_destination_reset) begin lc_destination_reset <= 1'b0; lc_destination_settle <= 0; lc_ready_gap <= 0; end\n    else begin\n      if (lc_destination_settle != 7) lc_destination_settle <= lc_destination_settle + 1;\n      if (lc_scheduled_destination_ready) lc_ready_gap <= 0; else if (lc_ready_gap != 7) lc_ready_gap <= lc_ready_gap + 1;\n    end\n  end\n",
  )
  for observation in dut.observations {
    out.write_string(
      "  wire \{if observation.width == 1 { "" } else { "[\{observation.width - 1}:0] " }}lc_\{observation.role};\n",
    )
  }
  out.write_string(
    "  \{dut.identifier} lc_dut (\n    .\{source_clock}(lc_source_clock),\n    .\{destination_clock}(lc_destination_clock),\n    .\{source_reset}(lc_source_reset),\n    .\{destination_reset}(lc_destination_reset),\n    .\{source_valid}(lc_scheduled_source_valid),\n    .\{source_word}(lc_scheduled_source_word),\n    .\{destination_ready}(lc_scheduled_destination_ready),\n    .\{source_ready}(lc_source_ready),\n    .\{destination_valid}(lc_destination_valid),\n    .\{destination_word}(lc_destination_word)",
  )
  for observation in dut.observations {
    out.write_string(",\n    .\{observation.port}(lc_\{observation.role})")
  }
  out.write_string("\n  );\n")
  out.write_string(
    "  wire lc_source_event = lc_protocol_active && lc_source_rise && lc_source_transfer;\n  wire lc_destination_event = lc_protocol_active && lc_destination_rise && lc_destination_transfer;\n",
  )
  out.write_string(
    "  wire [2:0] lc_monitored_write_gray_equation = lc_write_gray_next\{gray_mutant};\n  wire lc_monitored_full_next = lc_full_next\{full_mutant};\n  wire [1:0] lc_monitored_write_address = lc_write_address\{address_mutant};\n  wire [7:0] lc_monitored_destination_word = lc_destination_word\{storage_mutant};\n",
  )
  out.write_string(
    "  wire [2:0] lc_monitored_read_gray_stage0 = lc_read_gray_stage0\{read_pipeline_mutant};\n  wire [2:0] lc_monitored_write_gray_stage0 = lc_write_gray_stage0\{write_pipeline_mutant};\n  wire [2:0] lc_monitored_write_address_wide = {1'b0,lc_write_address}\{write_bounds_mutant};\n  wire [2:0] lc_monitored_read_address_wide = {1'b0,lc_read_address}\{read_bounds_mutant};\n",
  )
  out.write_string(
    "  logic [2:0] lc_reference_read_gray_stage0 = 0;\n  logic [2:0] lc_reference_read_gray_stage1 = 0;\n  logic [2:0] lc_reference_write_gray_stage0 = 0;\n  logic [2:0] lc_reference_write_gray_stage1 = 0;\n",
  )
  out.write_string(
    "  logic [7:0] lc_model_storage [0:3];\n  logic [2:0] lc_model_write = 0;\n  logic [2:0] lc_model_read = 0;\n  logic [2:0] lc_model_occupancy = 0;\n  logic lc_watch_active = 0;\n  logic [2:0] lc_watch_remaining = 0;\n  logic [1:0] lc_watch_address = 0;\n  logic [7:0] lc_watch_word = 0;\n  logic [7:0] lc_watch_age = 0;\n",
  )
  out.write_string(
    "  logic lc_read_pipeline_error = 0;\n  logic lc_write_pipeline_error = 0;\n  logic lc_backpressure_error = 0;\n  logic lc_ordering_error = 0;\n  logic lc_data_error = 0;\n  logic lc_completion_error = 0;\n  logic lc_backpressure_armed = 0;\n  logic [7:0] lc_backpressure_word = 0;\n",
  )
  out.write_string(
    "  logic lc_cover_coincident = 0;\n  logic lc_cover_full = 0;\n  logic lc_cover_write_wrap = 0;\n  logic lc_cover_read_wrap = 0;\n  logic lc_cover_simultaneous = 0;\n  logic lc_cover_watch = 0;\n",
  )
  out.write_string(
    "  always_ff @(negedge lc_formal_step_clock) if (lc_protocol_active) begin\n",
  )
  out.write_string(
    "    if (lc_monitored_read_gray_stage0 != lc_reference_read_gray_stage0 || lc_read_gray_stage1 != lc_reference_read_gray_stage1) lc_read_pipeline_error <= 1'b1;\n    if (lc_monitored_write_gray_stage0 != lc_reference_write_gray_stage0 || lc_write_gray_stage1 != lc_reference_write_gray_stage1) lc_write_pipeline_error <= 1'b1;\n",
  )
  out.write_string(
    "    if (lc_source_rise) begin lc_reference_read_gray_stage1 <= lc_reference_read_gray_stage0; lc_reference_read_gray_stage0 <= lc_read_gray; end\n    if (lc_destination_rise) begin lc_reference_write_gray_stage1 <= lc_reference_write_gray_stage0; lc_reference_write_gray_stage0 <= lc_write_gray; end\n",
  )
  out.write_string(
    "    if (lc_destination_valid && !lc_scheduled_destination_ready) begin\n      if (lc_backpressure_armed && lc_destination_word != lc_backpressure_word) lc_backpressure_error <= 1'b1;\n      lc_backpressure_armed <= 1'b1; lc_backpressure_word <= lc_destination_word;\n    end else lc_backpressure_armed <= 1'b0;\n",
  )
  out.write_string(
    "    if (lc_destination_event) begin\n      if (lc_model_occupancy == 0) lc_ordering_error <= 1'b1;\n      if (lc_monitored_destination_word != lc_model_storage[lc_model_read[1:0]]) lc_data_error <= 1'b1;\n      if (lc_watch_active) begin\n        if (lc_watch_remaining == 0) lc_ordering_error <= 1'b1;\n        else if (lc_watch_remaining == 1) begin if (lc_read_address != lc_watch_address) lc_ordering_error <= 1'b1; if (lc_monitored_destination_word != lc_watch_word) lc_data_error <= 1'b1; lc_watch_active <= 0; lc_cover_watch <= 1; end\n        else begin if (lc_read_address == lc_watch_address) lc_ordering_error <= 1'b1; lc_watch_remaining <= lc_watch_remaining - 1; end\n      end\n      lc_model_read <= lc_model_read + 1;\n    end\n",
  )
  out.write_string(
    "    if (lc_source_event) begin\n      lc_model_storage[lc_model_write[1:0]] <= lc_scheduled_source_word;\n      if (lc_scheduled_watch_select && !lc_watch_active) begin lc_watch_active <= 1; lc_watch_remaining <= lc_model_occupancy + (lc_destination_event ? 0 : 1); lc_watch_address <= lc_model_write[1:0]; lc_watch_word <= lc_scheduled_source_word; lc_watch_age <= 0; end\n      lc_model_write <= lc_model_write + 1;\n    end\n",
  )
  out.write_string(
    "    case ({lc_source_event,lc_destination_event}) 2'b10: lc_model_occupancy <= lc_model_occupancy + 1; 2'b01: lc_model_occupancy <= lc_model_occupancy - 1; default: lc_model_occupancy <= lc_model_occupancy; endcase\n",
  )
  out.write_string(
    "    if (lc_watch_active) begin if (lc_watch_age >= 8'd\{completion_bound}) lc_completion_error <= 1; else lc_watch_age <= lc_watch_age + 1; end\n",
  )
  out.write_string(
    "    if (lc_source_rise && lc_destination_rise) lc_cover_coincident <= 1;\n    if (lc_full) lc_cover_full <= 1;\n    if (lc_source_event && lc_write_binary == 3'd7) lc_cover_write_wrap <= 1;\n    if (lc_destination_event && lc_read_binary == 3'd7) lc_cover_read_wrap <= 1;\n    if (lc_source_event && lc_destination_event) lc_cover_simultaneous <= 1;\n  end\n",
  )
  out.write_string(
    "  wire lc_source_transfer_guard_exact = lc_source_transfer == (lc_scheduled_source_valid && lc_source_ready);\n  wire lc_destination_transfer_guard_exact = lc_destination_transfer == (lc_destination_valid && lc_scheduled_destination_ready);\n",
  )
  out.write_string(
    "  wire lc_write_binary_pointer_hold_or_increment = lc_write_binary_next == (lc_source_transfer ? lc_write_binary + 3'd1 : lc_write_binary);\n  wire lc_read_binary_pointer_hold_or_increment = lc_read_binary_next == (lc_destination_transfer ? lc_read_binary + 3'd1 : lc_read_binary);\n",
  )
  out.write_string(
    "  wire lc_write_gray_equation_exact = lc_monitored_write_gray_equation == (lc_write_binary_next ^ (lc_write_binary_next >> 1));\n  wire lc_write_gray_hold_or_one_bit_transition = lc_source_transfer ? $onehot(lc_write_gray_next ^ lc_write_gray) : (lc_write_gray_next == lc_write_gray);\n  wire lc_read_gray_equation_exact = lc_read_gray_next == (lc_read_binary_next ^ (lc_read_binary_next >> 1));\n  wire lc_read_gray_hold_or_one_bit_transition = lc_destination_transfer ? $onehot(lc_read_gray_next ^ lc_read_gray) : (lc_read_gray_next == lc_read_gray);\n",
  )
  out.write_string(
    "  wire lc_read_gray_source_pipeline_exact = !lc_read_pipeline_error;\n  wire lc_write_gray_destination_pipeline_exact = !lc_write_pipeline_error;\n",
  )
  out.write_string(
    "  wire lc_full_equation_exact = lc_monitored_full_next == (lc_write_gray_next == (lc_read_gray_stage1 ^ 3'b110));\n  wire lc_nonempty_equation_exact = lc_nonempty_next == (lc_read_gray_next != lc_write_gray_stage1);\n",
  )
  out.write_string(
    "  wire lc_write_address_selection_exact = lc_monitored_write_address == lc_write_binary[1:0];\n  wire lc_write_address_in_bounds = lc_monitored_write_address_wide < 4;\n  wire lc_read_address_selection_exact = lc_read_address == lc_read_binary[1:0];\n  wire lc_read_address_in_bounds = lc_monitored_read_address_wide < 4;\n",
  )
  out.write_string(
    "  wire lc_no_write_while_full = !(lc_source_transfer && lc_full);\n  wire lc_no_consume_while_empty = !(lc_destination_transfer && !lc_nonempty);\n  wire lc_destination_payload_stable_under_backpressure = !lc_backpressure_error;\n  wire lc_watched_token_ordering = !lc_ordering_error;\n  wire lc_watched_token_data_integrity = !lc_data_error;\n  wire lc_watched_token_consumed = !lc_completion_error;\n",
  )
  out.write_string(
    "  wire lc_coincident_source_destination_edge = lc_cover_coincident;\n  wire lc_fifo_reaches_full = lc_cover_full;\n  wire lc_write_pointer_wraps = lc_cover_write_wrap;\n  wire lc_read_pointer_wraps = lc_cover_read_wrap;\n  wire lc_simultaneous_enqueue_and_dequeue = lc_cover_simultaneous;\n  wire lc_watched_token_consumed_cover = lc_cover_watch;\n\n",
  )
  out.write_string(property_source)
  out.write_string("endmodule\n`default_nettype wire\n")
  out.to_string()
}
