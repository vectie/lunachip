///|
fn queue_monitor_source(fixture : QueueFormalFixture) -> String {
  let out = StringBuilder()
  let declarations =
    #|  wire lc_queue_admit = lc_descriptor_valid && lc_descriptor_ready;
    #|  wire lc_queue_retire = lc_completion_valid && lc_completion_ready;
    #|  logic lc_queue_sampled = 1'b0;
    #|  logic [3:0] lc_queue_outstanding = 4'd0;
    #|  logic lc_queue_admission_seen = 1'b0;
    #|  logic lc_queue_reservation_seen = 1'b0;
    #|  logic lc_expected_response_valid = 1'b0;
    #|  logic [4:0] lc_expected_read_pointer = 5'd0;
    #|  logic [4:0] lc_expected_write_pointer = 5'd0;
    #|  logic [4:0] lc_expected_retirement_occupancy = 5'd0;
    #|  logic lc_previous_full_refill = 1'b0;
    #|  wire lc_unreserved_head = lc_o_head_state == 2'd1 || lc_o_head_state == 2'd2;
    #|  wire [5:0] lc_physical_population = {4'd0, lc_o_fifo_occupancy_0}
    #|    + {1'b0, lc_o_retirement_occupancy} + {5'd0, lc_unreserved_head};
    #|  wire [4:0] lc_live_entry_population = {4'd0, lc_o_entry_valid_0}
    #|    + {4'd0, lc_o_entry_valid_1} + {4'd0, lc_o_entry_valid_2};
    #|  wire lc_raw_population_relation = {2'd0, lc_queue_outstanding} == lc_physical_population
    #|    && lc_o_retirement_occupancy == lc_live_entry_population
    #|    && lc_queue_outstanding <= 4'd7;
    #|  wire lc_mutate_population = !lc_reset && lc_queue_admission_seen
    #|    && lc_queue_reservation_seen && lc_o_retirement_occupancy != 5'd0
    #|    && lc_raw_population_relation;
    #|
  out.write_string(declarations)
  let checked = if fixture is NegativePopulation {
    "lc_o_retirement_occupancy + (lc_mutate_population ? 5'd1 : 5'd0)"
  } else {
    "lc_o_retirement_occupancy"
  }
  out.write_string(
    "  wire [4:0] lc_checked_retirement_population = \{checked};\n",
  )
  for lane in 0..<4 {
    out.write_string(
      "  logic [1:0] lc_expected_fifo_occupancy_\{lane} = 2'd0;\n",
    )
  }
  for entry in 0..<3 {
    out.write_string("  logic lc_expected_entry_valid_\{entry} = 1'b0;\n")
  }
  let ghost =
    #|  // Independent population history reads only the two public handshakes.
    #|  // Expected transfers below are sampled PRE and compared at the next PRE.
    #|  always_ff @(posedge lc_clock) begin
    #|    lc_queue_sampled <= 1'b1;
    #|    if (lc_reset) begin
    #|      lc_queue_outstanding <= 4'd0;
    #|      lc_queue_admission_seen <= 1'b0;
    #|      lc_queue_reservation_seen <= 1'b0;
    #|      lc_expected_response_valid <= 1'b0;
    #|      lc_expected_read_pointer <= 5'd0;
    #|      lc_expected_write_pointer <= 5'd0;
    #|      lc_expected_retirement_occupancy <= 5'd0;
    #|      lc_previous_full_refill <= 1'b0;
    #|
  out.write_string(ghost)
  for lane in 0..<4 {
    out.write_string("      lc_expected_fifo_occupancy_\{lane} <= 2'd0;\n")
  }
  for entry in 0..<3 {
    out.write_string("      lc_expected_entry_valid_\{entry} <= 1'b0;\n")
  }
  let update =
    #|    end else begin
    #|      case ({lc_queue_admit, lc_queue_retire})
    #|        2'b10: lc_queue_outstanding <= lc_queue_outstanding + 4'd1;
    #|        2'b01: lc_queue_outstanding <= lc_queue_outstanding - 4'd1;
    #|        default: lc_queue_outstanding <= lc_queue_outstanding;
    #|      endcase
    #|      if (lc_queue_admit) lc_queue_admission_seen <= 1'b1;
    #|      if (lc_o_head_reserve) lc_queue_reservation_seen <= 1'b1;
    #|      lc_expected_response_valid <= lc_o_head_pop;
    #|      lc_expected_read_pointer <= !lc_queue_retire ? lc_o_retirement_read_pointer
    #|        : (lc_o_retirement_read_pointer == 5'd2 ? 5'd0 : lc_o_retirement_read_pointer + 5'd1);
    #|      lc_expected_write_pointer <= !lc_o_head_reserve ? lc_o_retirement_write_pointer
    #|        : (lc_o_retirement_write_pointer == 5'd2 ? 5'd0 : lc_o_retirement_write_pointer + 5'd1);
    #|      lc_expected_retirement_occupancy <= lc_o_head_reserve == lc_queue_retire
    #|        ? lc_o_retirement_occupancy : (lc_o_head_reserve
    #|          ? lc_o_retirement_occupancy + 5'd1 : lc_o_retirement_occupancy - 5'd1);
    #|      lc_previous_full_refill <= lc_o_fifo_occupancy_0 == 2'd3
    #|        && lc_queue_admit && lc_o_head_pop;
    #|
  out.write_string(update)
  for lane in 0..<4 {
    out.write_string(
      "      lc_expected_fifo_occupancy_\{lane} <= lc_queue_admit == lc_o_head_pop\n        ? lc_o_fifo_occupancy_\{lane} : (lc_queue_admit\n          ? lc_o_fifo_occupancy_\{lane} + 2'd1 : lc_o_fifo_occupancy_\{lane} - 2'd1);\n",
    )
  }
  for entry in 0..<3 {
    out.write_string(
      "      lc_expected_entry_valid_\{entry} <= lc_o_entry_allocate_\{entry} ? 1'b1\n        : (lc_o_entry_acknowledge_\{entry} ? 1'b0 : lc_o_entry_valid_\{entry});\n",
    )
  }
  out.write_string("    end\n  end\n")
  let lane_checks : Array[String] = []
  for lane in 0..<4 {
    lane_checks.push(
      "((lc_o_fifo_push_valid_\{lane} && lc_o_fifo_push_ready_\{lane}) == lc_queue_admit)",
    )
    lane_checks.push(
      "((lc_o_fifo_pop_request_\{lane} && lc_o_fifo_pop_ready_\{lane}) == lc_o_head_pop)",
    )
    lane_checks.push("lc_o_fifo_occupancy_\{lane} <= 2'd3")
    lane_checks.push("lc_o_fifo_occupancy_\{lane} == lc_o_fifo_occupancy_0")
    lane_checks.push(
      "lc_o_fifo_full_\{lane} == (lc_o_fifo_occupancy_\{lane} == 2'd3)",
    )
    lane_checks.push(
      "lc_o_fifo_empty_\{lane} == (lc_o_fifo_occupancy_\{lane} == 2'd0)",
    )
    lane_checks.push(
      "(!lc_queue_sampled || (lc_o_fifo_response_valid_\{lane} == lc_expected_response_valid\n        && lc_o_fifo_occupancy_\{lane} == lc_expected_fifo_occupancy_\{lane}))",
    )
  }
  let responses = Array::makei(4, lane => "lc_o_fifo_response_valid_\{lane}").join(
    " && ",
  )
  lane_checks.push(
    "lc_o_head_capture == (lc_o_head_state == 2'd1 && \{responses})",
  )
  out.write_string(
    "  wire lc_lane_atomicity_and_response = lc_reset || (\{lane_checks.join("\n    && ")});\n",
  )
  let population =
    #|  wire lc_packet_population_conserved = lc_reset
    #|    || ({2'd0, lc_queue_outstanding} == lc_physical_population
    #|      && lc_checked_retirement_population == lc_live_entry_population
    #|      && lc_queue_outstanding <= 4'd7);
    #|
  out.write_string(population)
  let retirement_checks : Array[String] = [
    "lc_o_retirement_read_pointer < 5'd3", "lc_o_retirement_write_pointer < 5'd3",
    "lc_o_retirement_occupancy <= 5'd3", "lc_o_head_entry < 5'd3", "lc_o_head_reserve == (lc_o_head_state == 2'd2 && lc_o_retirement_occupancy < 5'd3)",
    "lc_o_retirement_valid == lc_completion_valid", "lc_o_retirement_fire == lc_queue_retire",
    "(!lc_queue_sampled || (lc_o_retirement_read_pointer == lc_expected_read_pointer\n      && lc_o_retirement_write_pointer == lc_expected_write_pointer\n      && lc_o_retirement_occupancy == lc_expected_retirement_occupancy))",
  ]
  for entry in 0..<3 {
    retirement_checks.push(
      "lc_o_entry_allocate_\{entry} == (lc_o_head_reserve && lc_o_retirement_write_pointer == 5'd\{entry})",
    )
    retirement_checks.push(
      "lc_o_entry_acknowledge_\{entry} == (lc_queue_retire && lc_o_retirement_read_pointer == 5'd\{entry})",
    )
    retirement_checks.push(
      "(!lc_o_entry_allocate_\{entry} || !lc_o_entry_valid_\{entry})",
    )
    retirement_checks.push(
      "(!lc_o_entry_acknowledge_\{entry} || (lc_o_entry_valid_\{entry} && lc_o_entry_terminal_\{entry}))",
    )
    retirement_checks.push(
      "(!lc_queue_sampled || lc_o_entry_valid_\{entry} == lc_expected_entry_valid_\{entry})",
    )
  }
  out.write_string(
    "  wire lc_retirement_event_ownership = lc_reset || (\{retirement_checks.join("\n    && ")});\n",
  )
  out.write_string(
    "  wire lc_reachable_full_refill_capture = !lc_reset && lc_previous_full_refill\n    && lc_o_head_capture && \{responses};\n",
  )
  out.to_string()
}
