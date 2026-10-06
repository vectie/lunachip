///|
// Public packet history is independent of FIFO storage, caller-ID uniqueness,
// and private ticket identity. Every comparison is sampled at a PRE boundary.
fn queue_packet_provenance_source(negative : Bool) -> String {
  let out = StringBuilder()
  let declarations =
    #|  (* anyseq *) logic lc_pp_select;
    #|  logic lc_pp_taken = 1'b0;
    #|  logic lc_pp_failed = 1'b0;
    #|  // 0 idle, 1 queued, 2 response due, 3 captured head, 4 reserved, 5 retired.
    #|  logic [2:0] lc_pp_stage = 3'd0;
    #|  logic [3:0] lc_pp_outstanding = 4'd0;
    #|  logic [3:0] lc_pp_fifo_count = 4'd0;
    #|  logic [3:0] lc_pp_fifo_older = 4'd0;
    #|  logic [3:0] lc_pp_retire_older = 4'd0;
    #|  logic [255:0] lc_pp_saved_packet = 256'd0;
    #|  logic [4:0] lc_pp_saved_entry = 5'd0;
    #|  logic [31:0] lc_pp_saved_ticket = 32'd0;
    #|  logic lc_pp_head_owned = 1'b0;
    #|  logic lc_pp_response_seen = 1'b0;
    #|  logic lc_pp_capture_seen = 1'b0;
    #|  logic lc_pp_reservation_seen = 1'b0;
    #|  wire lc_pp_watch = !lc_pp_taken && lc_pp_select && lc_queue_admit;
    #|  wire lc_pp_active = lc_pp_stage >= 3'd1 && lc_pp_stage <= 3'd4;
    #|  wire [255:0] lc_pp_response_packet = {lc_o_fifo_response_data_3,
    #|    lc_o_fifo_response_data_2, lc_o_fifo_response_data_1, lc_o_fifo_response_data_0};
    #|  wire [255:0] lc_pp_head_packet = {lc_o_head_lane_3, lc_o_head_lane_2,
    #|    lc_o_head_lane_1, lc_o_head_lane_0};
    #|  wire lc_pp_all_response = lc_o_fifo_response_valid_0 && lc_o_fifo_response_valid_1
    #|    && lc_o_fifo_response_valid_2 && lc_o_fifo_response_valid_3;
    #|  wire lc_pp_raw_response = lc_pp_response_packet == lc_pp_saved_packet;
    #|  wire lc_pp_genuine_response = !lc_reset && lc_pp_stage == 3'd2
    #|    && lc_pp_all_response && lc_o_head_capture && lc_pp_raw_response;
    #|
  out.write_string(declarations)
  // Only this comparison expression differs between the two profiles. Bit 128
  // is bit zero of saved lane 2; saved data and raw transfer history never change.
  let checked = if negative {
    "(lc_pp_saved_packet ^ (lc_pp_genuine_response ? (256'd1 << 128) : 256'd0))"
  } else {
    "lc_pp_saved_packet"
  }
  out.write_string(
    "  wire [255:0] lc_pp_checked_response_packet = \{checked};\n",
  )
  let selectors =
    #|  wire lc_pp_entry_in_range = lc_pp_saved_entry < 5'd3;
    #|  wire lc_pp_entry_valid = lc_pp_saved_entry == 5'd0 ? lc_o_entry_valid_0
    #|    : (lc_pp_saved_entry == 5'd1 ? lc_o_entry_valid_1
    #|      : (lc_pp_saved_entry == 5'd2 ? lc_o_entry_valid_2 : 1'b0));
    #|  wire lc_pp_entry_terminal = lc_pp_saved_entry == 5'd0 ? lc_o_entry_terminal_0
    #|    : (lc_pp_saved_entry == 5'd1 ? lc_o_entry_terminal_1
    #|      : (lc_pp_saved_entry == 5'd2 ? lc_o_entry_terminal_2 : 1'b0));
    #|  wire [31:0] lc_pp_entry_ticket = lc_pp_saved_entry == 5'd0 ? lc_o_entry_ticket_0
    #|    : (lc_pp_saved_entry == 5'd1 ? lc_o_entry_ticket_1
    #|      : (lc_pp_saved_entry == 5'd2 ? lc_o_entry_ticket_2 : 32'd0));
    #|  wire [31:0] lc_pp_entry_id = lc_pp_saved_entry == 5'd0 ? lc_o_entry_id_0
    #|    : (lc_pp_saved_entry == 5'd1 ? lc_o_entry_id_1
    #|      : (lc_pp_saved_entry == 5'd2 ? lc_o_entry_id_2 : 32'd0));
    #|  wire lc_pp_entry_ack = lc_pp_saved_entry == 5'd0 ? lc_o_entry_acknowledge_0
    #|    : (lc_pp_saved_entry == 5'd1 ? lc_o_entry_acknowledge_1
    #|      : (lc_pp_saved_entry == 5'd2 ? lc_o_entry_acknowledge_2 : 1'b0));
    #|  wire lc_pp_entry_allocate = lc_pp_saved_entry == 5'd0 ? lc_o_entry_allocate_0
    #|    : (lc_pp_saved_entry == 5'd1 ? lc_o_entry_allocate_1
    #|      : (lc_pp_saved_entry == 5'd2 ? lc_o_entry_allocate_2 : 1'b0));
    #|  wire lc_pp_reserve_allocate = lc_o_retirement_write_pointer == 5'd0
    #|    ? (lc_o_entry_allocate_0 && !lc_o_entry_allocate_1 && !lc_o_entry_allocate_2)
    #|    : (lc_o_retirement_write_pointer == 5'd1
    #|      ? (!lc_o_entry_allocate_0 && lc_o_entry_allocate_1 && !lc_o_entry_allocate_2)
    #|      : (lc_o_retirement_write_pointer == 5'd2
    #|        && !lc_o_entry_allocate_0 && !lc_o_entry_allocate_1 && lc_o_entry_allocate_2));
    #|  wire lc_pp_entry_matches = lc_pp_entry_in_range && lc_pp_entry_valid
    #|    && lc_pp_entry_ticket == lc_pp_saved_ticket
    #|    && lc_pp_entry_id == lc_pp_saved_packet[63:32];
    #|  wire lc_pp_ordinal_retire = lc_pp_active && lc_pp_retire_older == 4'd0
    #|    && lc_queue_retire;
    #|  // A same-edge admission is never eligible for a pop or retirement.
    #|  wire lc_pp_counts_ok = lc_pp_outstanding <= 4'd7 && lc_pp_fifo_count <= 4'd3
    #|    && (!lc_queue_retire || lc_pp_outstanding != 4'd0)
    #|    && (!lc_queue_admit || lc_queue_retire || lc_pp_outstanding < 4'd7)
    #|    && (!lc_o_head_pop || lc_pp_fifo_count != 4'd0)
    #|    && (!lc_queue_admit || lc_o_head_pop || lc_pp_fifo_count < 4'd3);
    #|  wire lc_pp_response_ok = lc_pp_stage != 3'd2
    #|    || (lc_pp_all_response && lc_o_head_capture && lc_o_head_state == 2'd1
    #|      && lc_pp_response_packet == lc_pp_checked_response_packet);
    #|  // Head data are checked after capture, including the reserve and finish PREs.
    #|  wire lc_pp_head_ok = !lc_pp_head_owned
    #|    || (lc_pp_head_packet == lc_pp_saved_packet
    #|      && (lc_pp_stage == 3'd3 ? lc_o_head_state == 2'd2
    #|        : (lc_pp_stage == 3'd4 && lc_o_head_state == 2'd3
    #|          && lc_o_head_entry == lc_pp_saved_entry
    #|          && lc_o_head_ticket == lc_pp_saved_ticket)));
    #|  wire lc_pp_reservation_ok = lc_pp_stage != 3'd3 || !lc_o_head_reserve
    #|    || (lc_o_retirement_write_pointer < 5'd3 && lc_pp_reserve_allocate);
    #|  wire lc_pp_live_record_ok = lc_pp_stage != 3'd4
    #|    || (lc_pp_entry_matches && !lc_pp_entry_allocate
    #|      && (!lc_pp_entry_ack || lc_pp_ordinal_retire)
    #|      && (!lc_completion_valid || lc_o_retirement_read_pointer != lc_pp_saved_entry
    #|        || lc_pp_retire_older == 4'd0)
    #|      && (lc_pp_retire_older != 4'd0 || !lc_completion_valid
    #|        || (lc_o_retirement_read_pointer == lc_pp_saved_entry
    #|          && lc_completion_id == lc_pp_saved_packet[63:32])));
    #|  wire lc_pp_retire_ok = !lc_pp_ordinal_retire
    #|    || (lc_pp_stage == 3'd4 && lc_pp_response_seen && lc_pp_capture_seen
    #|      && lc_pp_reservation_seen && lc_pp_entry_matches && lc_pp_entry_terminal
    #|      && lc_o_retirement_read_pointer == lc_pp_saved_entry && lc_pp_entry_ack
    #|      && lc_completion_id == lc_pp_saved_packet[63:32]);
    #|  wire lc_pp_rank_ok = !lc_pp_active
    #|    || (lc_pp_retire_older < lc_pp_outstanding
    #|      && (lc_pp_stage != 3'd1 || lc_pp_fifo_older < lc_pp_fifo_count));
    #|  wire lc_pp_current_ok = lc_pp_counts_ok && lc_pp_response_ok && lc_pp_head_ok
    #|    && lc_pp_reservation_ok && lc_pp_live_record_ok && lc_pp_retire_ok && lc_pp_rank_ok;
    #|  wire lc_packet_provenance_ok = lc_reset || (!lc_pp_failed && lc_pp_current_ok);
    #|  wire lc_packet_provenance_transfer_cover = !lc_reset && !lc_pp_failed
    #|    && lc_pp_current_ok && lc_pp_ordinal_retire && lc_pp_stage == 3'd4
    #|    && lc_pp_response_seen && lc_pp_capture_seen && lc_pp_reservation_seen;
    #|
  out.write_string(selectors)
  let history =
    #|  always_ff @(posedge lc_clock) begin
    #|    if (lc_reset) begin
    #|      lc_pp_taken <= 1'b0;
    #|      lc_pp_failed <= 1'b0;
    #|      lc_pp_stage <= 3'd0;
    #|      lc_pp_outstanding <= 4'd0;
    #|      lc_pp_fifo_count <= 4'd0;
    #|      lc_pp_fifo_older <= 4'd0;
    #|      lc_pp_retire_older <= 4'd0;
    #|      lc_pp_saved_packet <= 256'd0;
    #|      lc_pp_saved_entry <= 5'd0;
    #|      lc_pp_saved_ticket <= 32'd0;
    #|      lc_pp_head_owned <= 1'b0;
    #|      lc_pp_response_seen <= 1'b0;
    #|      lc_pp_capture_seen <= 1'b0;
    #|      lc_pp_reservation_seen <= 1'b0;
    #|    end else begin
    #|      if (!lc_pp_current_ok) lc_pp_failed <= 1'b1;
    #|      // Illegal arithmetic holds its value and fails; it never wraps.
    #|      if (lc_pp_counts_ok) begin
    #|        case ({lc_queue_admit, lc_queue_retire})
    #|          2'b10: lc_pp_outstanding <= lc_pp_outstanding + 4'd1;
    #|          2'b01: lc_pp_outstanding <= lc_pp_outstanding - 4'd1;
    #|          default: lc_pp_outstanding <= lc_pp_outstanding;
    #|        endcase
    #|        case ({lc_queue_admit, lc_o_head_pop})
    #|          2'b10: lc_pp_fifo_count <= lc_pp_fifo_count + 4'd1;
    #|          2'b01: lc_pp_fifo_count <= lc_pp_fifo_count - 4'd1;
    #|          default: lc_pp_fifo_count <= lc_pp_fifo_count;
    #|        endcase
    #|      end
    #|      if (lc_pp_watch && lc_pp_counts_ok) begin
    #|        lc_pp_taken <= 1'b1;
    #|        lc_pp_stage <= 3'd1;
    #|        lc_pp_saved_packet <= lc_descriptor_payload;
    #|        lc_pp_fifo_older <= lc_pp_fifo_count - (lc_o_head_pop ? 4'd1 : 4'd0);
    #|        lc_pp_retire_older <= lc_pp_outstanding - (lc_queue_retire ? 4'd1 : 4'd0);
    #|      end
    #|      if (lc_pp_active && lc_queue_retire && lc_pp_retire_older != 4'd0)
    #|        lc_pp_retire_older <= lc_pp_retire_older - 4'd1;
    #|      if (lc_pp_stage == 3'd1 && lc_o_head_pop && lc_pp_counts_ok) begin
    #|        if (lc_pp_fifo_older != 4'd0)
    #|          lc_pp_fifo_older <= lc_pp_fifo_older - 4'd1;
    #|        else lc_pp_stage <= 3'd2;
    #|      end
    #|      // Response history uses the raw payload, not the sensitivity expression.
    #|      if (lc_pp_stage == 3'd2 && lc_pp_genuine_response) begin
    #|        lc_pp_response_seen <= 1'b1;
    #|        lc_pp_head_owned <= 1'b1;
    #|        lc_pp_stage <= 3'd3;
    #|      end
    #|      if (lc_pp_stage == 3'd3 && lc_pp_head_ok) begin
    #|        lc_pp_capture_seen <= 1'b1;
    #|        if (lc_o_head_reserve && lc_pp_reservation_ok) begin
    #|          lc_pp_saved_entry <= lc_o_retirement_write_pointer;
    #|          lc_pp_saved_ticket <= lc_o_next_ticket;
    #|          lc_pp_reservation_seen <= 1'b1;
    #|          lc_pp_stage <= 3'd4;
    #|        end
    #|      end
    #|      if (lc_pp_head_owned && lc_o_head_finish) lc_pp_head_owned <= 1'b0;
    #|      if (lc_pp_ordinal_retire) begin
    #|        lc_pp_stage <= 3'd5;
    #|        lc_pp_head_owned <= 1'b0;
    #|      end
    #|    end
    #|  end
    #|
  out.write_string(history)
  out.to_string()
}
