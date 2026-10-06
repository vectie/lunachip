///|
// Conclusions over actual retained state. There is no free-state premise,
// ready/finish fairness, terminal identity, or State3/live-entry implication.
fn queue_control_invariant_source() -> String {
  let out = StringBuilder()
  let lanes : Array[String] = []
  for lane in 0..<4 {
    lanes.push("(lc_o_fifo_occupancy_\{lane} == lc_o_fifo_occupancy_0)")
    lanes.push(
      "(lc_o_fifo_response_valid_\{lane} == lc_o_fifo_response_valid_0)",
    )
    lanes.push("(lc_o_fifo_occupancy_\{lane} <= 2'd3)")
  }
  out.write_string(
    "  wire lc_lanes_equal_and_bounded = \{lanes.join(" && ")};\n",
  )
  let response_and_bounds =
    #|  wire lc_response_gap_matches = lc_o_fifo_response_valid_0
    #|    == (lc_o_head_state == 2'd1);
    #|  wire [2:0] lc_entry_valid_mask = {lc_o_entry_valid_2,
    #|    lc_o_entry_valid_1, lc_o_entry_valid_0};
    #|  wire lc_ring_bounds = lc_o_retirement_read_pointer < 5'd3
    #|    && lc_o_retirement_write_pointer < 5'd3
    #|    && lc_o_retirement_occupancy <= 5'd3;
    #|
  out.write_string(response_and_bounds)
  let ring : Array[String] = []
  // Twelve exact cyclic intervals; population equality alone is insufficient.
  for read in 0..<3 {
    for occupancy in 0..<4 {
      let mut mask = 0
      for offset in 0..<occupancy {
        mask = mask | (1 << ((read + offset) % 3))
      }
      let write = (read + occupancy) % 3
      ring.push(
        "(lc_o_retirement_read_pointer == 5'd\{read} && lc_o_retirement_occupancy == 5'd\{occupancy} && lc_o_retirement_write_pointer == 5'd\{write} && lc_entry_valid_mask == 3'd\{mask})",
      )
    }
  }
  out.write_string("  wire lc_ring_contiguous = \{ring.join(" || ")};\n")
  let population =
    #|  wire lc_raw_structure_ok = lc_lanes_equal_and_bounded
    #|    && lc_response_gap_matches && lc_o_head_state <= 2'd3
    #|    && lc_o_head_entry < 5'd3 && lc_ring_bounds && lc_ring_contiguous;
    #|  // Widen BEFORE addition: arbitrary UInt5 R can reach31 before proof.
    #|  wire [5:0] lc_raw_population = {4'd0, lc_o_fifo_occupancy_0}
    #|    + {1'd0, lc_o_retirement_occupancy}
    #|    + ((lc_o_head_state == 2'd1 || lc_o_head_state == 2'd2) ? 6'd1 : 6'd0);
    #|  wire lc_raw_population_matches = lc_raw_population
    #|    == {2'd0, lc_g_public_outstanding};
    #|  wire lc_raw_invariant_ok = lc_raw_structure_ok
    #|    && lc_raw_population_matches && lc_g_public_outstanding <= 4'd7;
    #|
  out.write_string(population)
  out.to_string()
}
