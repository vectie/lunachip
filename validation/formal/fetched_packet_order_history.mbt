///|
// Independent two-entry queue: only validity/control reset. Payload registers
// are uninitialized and become meaningful only after a genuine accepted push.
// Nonblocking assignments preserve the OLD packet on simultaneous full refill.
fn fetched_packet_order_history() -> String {
  let out = StringBuilder()
  out.write_string(
    (
      #|  logic lc_fp_seen = 1'b0;
      #|  logic lc_fp_read, lc_fp_write;
      #|  logic [1:0] lc_fp_count, lc_fp_phase;
      #|  logic [255:0] lc_fp_word_0, lc_fp_word_1, lc_fp_expected;
      #|  wire lc_fp_live_0 = lc_fp_count == 2'd2 || (lc_fp_count == 2'd1 && !lc_fp_read);
      #|  wire lc_fp_live_1 = lc_fp_count == 2'd2 || (lc_fp_count == 2'd1 && lc_fp_read);
      #|  always @(posedge lc_fp_clock) begin
      #|    lc_fp_seen <= 1'b1;
      #|    if (lc_fp_reset) begin
      #|      lc_fp_read <= 1'b0;
      #|      lc_fp_write <= 1'b0;
      #|      lc_fp_count <= 2'd0;
      #|      lc_fp_phase <= 2'd0;
      #|    end else begin
      #|      if (lc_fp_push) begin
      #|        if (lc_fp_write) lc_fp_word_1 <= lc_fp_input;
      #|        else lc_fp_word_0 <= lc_fp_input;
      #|        lc_fp_write <= ~lc_fp_write;
      #|      end
      #|      if (lc_fp_pop) begin
      #|        lc_fp_expected <= lc_fp_read ? lc_fp_word_1 : lc_fp_word_0;
      #|        lc_fp_read <= ~lc_fp_read;
      #|      end
      #|      if (lc_fp_push != lc_fp_pop)
      #|        lc_fp_count <= lc_fp_push ? lc_fp_count + 2'd1 : lc_fp_count - 2'd1;
      #|      case (lc_fp_phase)
      #|        2'd0: if (lc_fp_pop) lc_fp_phase <= 2'd1;
      #|        2'd1: if (lc_fp_capture) lc_fp_phase <= 2'd2;
      #|        2'd2: if (lc_fp_reserve) lc_fp_phase <= 2'd3;
      #|        2'd3: if (lc_fp_finish) lc_fp_phase <= 2'd0;
      #|      endcase
      #|    end
      #|    lc_fp_capacity: assert ((!lc_fp_seen || (lc_fp_count <= 2'd2
      #|      && (!lc_fp_pop || lc_fp_count != 2'd0)
      #|      && (!lc_fp_push || lc_fp_count < 2'd2 || lc_fp_pop))) === 1'b1);
      #|    lc_fp_pointer_relation: assert ((!lc_fp_seen || lc_fp_write == (lc_fp_read ^ lc_fp_count[0])) === 1'b1);
      #|    lc_fp_head_phase: assert ((!lc_fp_seen || lc_fp_phase == lc_fp_head_state) === 1'b1);
      #|    lc_fp_oldest_cell_0: assert ((!lc_fp_seen || !lc_fp_live_0 || lc_fp_cell_0 == lc_fp_word_0) === 1'b1);
      #|    lc_fp_oldest_cell_1: assert ((!lc_fp_seen || !lc_fp_live_1 || lc_fp_cell_1 == lc_fp_word_1) === 1'b1);
      #|    lc_fp_read_old_response: assert ((!lc_fp_seen || lc_fp_phase != 2'd1 || lc_fp_response == lc_fp_expected) === 1'b1);
      #|    lc_fp_captured_oldest: assert ((!lc_fp_seen || lc_fp_phase < 2'd2 || lc_fp_head_lane == lc_fp_expected) === 1'b1);
      #|    lc_fp_capture_event: assert ((!lc_fp_seen || lc_fp_capture == (!lc_fp_reset && lc_fp_phase == 2'd1)) === 1'b1);
      #|    lc_fp_pop_event: assert ((!lc_fp_seen || lc_fp_reset || lc_fp_pop == (lc_fp_phase == 2'd0 && lc_fp_count != 2'd0)) === 1'b1);
      #|    lc_fp_reserve_order: assert ((!lc_fp_seen || !lc_fp_reserve || (lc_fp_phase == 2'd2 && lc_fp_head_lane == lc_fp_expected)) === 1'b1);
      #|    lc_fp_dispatch_order: assert ((!lc_fp_seen || !lc_fp_finish || (lc_fp_phase == 2'd3 && lc_fp_head_lane == lc_fp_expected)) === 1'b1);
      #|  end
      #|
    ),
  )
  for lane in 0..<4 {
    out.write_string(
      "  always @(posedge lc_fp_clock) begin\n" +
      "    lc_fp_lane_\{lane}: assert ((!lc_fp_seen || (lc_fp_read_pointer_\{lane} == lc_fp_read && lc_fp_write_pointer_\{lane} == lc_fp_write && lc_fp_fifo_occupancy_\{lane} == lc_fp_count && lc_fp_fifo_response_valid_\{lane} == (lc_fp_phase == 2'd1) && lc_fp_read_fire_\{lane} == lc_fp_pop && lc_fp_write_fire_\{lane} == lc_fp_push)) === 1'b1);\n" +
      "  end\n",
    )
  }
  out.to_string()
}
