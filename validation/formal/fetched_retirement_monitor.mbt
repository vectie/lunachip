///|
// Exact q2 state, not a q3 theorem or a new state machine. Ticket subtraction
// stays UInt32 modular; pointer/occupancy tests use all five original bits.
fn fetched_retirement_support() -> String {
  let out = StringBuilder()
  out.write_string(
    (
      #|  wire [1:0] lc_fr_valid_mask = {lc_q_entry_valid_1, lc_q_entry_valid_0};
      #|  wire lc_fr_pointer_range = lc_q_retirement_read_pointer < 5'd2
      #|    && lc_q_retirement_write_pointer < 5'd2 && lc_q_retirement_occupancy <= 5'd2
      #|    && lc_q_head_entry < 5'd2;
      #|  wire lc_fr_head_live = lc_q_head_state == 2'd3;
      #|  wire lc_fr_head_valid = lc_q_head_entry == 5'd0 ? lc_q_entry_valid_0 : lc_q_entry_valid_1;
      #|  wire lc_fr_head_terminal = lc_q_head_entry == 5'd0 ? lc_q_entry_terminal_0 : lc_q_entry_terminal_1;
      #|  wire [31:0] lc_fr_head_ticket = lc_q_head_entry == 5'd0 ? lc_q_entry_ticket_0 : lc_q_entry_ticket_1;
      #|  wire lc_fr_oldest_valid = lc_q_retirement_read_pointer == 5'd0 ? lc_q_entry_valid_0 : lc_q_entry_valid_1;
      #|  wire lc_fr_oldest_terminal = lc_q_retirement_read_pointer == 5'd0 ? lc_q_entry_terminal_0 : lc_q_entry_terminal_1;
      #|  wire [31:0] lc_fr_oldest_ticket = lc_q_retirement_read_pointer == 5'd0 ? lc_q_entry_ticket_0 : lc_q_entry_ticket_1;
      #|  wire [99:0] lc_fr_public_payload = {lc_completion_id, lc_completion_fault, lc_completion_bytes_completed, lc_completion_fault_address};
      #|  wire [99:0] lc_fr_oldest_payload = lc_q_retirement_read_pointer == 5'd0
      #|    ? {lc_q_entry_id_0, lc_q_entry_fault_0, lc_q_entry_progress_0, lc_q_entry_address_0}
      #|    : {lc_q_entry_id_1, lc_q_entry_fault_1, lc_q_entry_progress_1, lc_q_entry_address_1};
      #|
    ),
  )
  let rings : Array[String] = []
  for read in 0..<2 {
    for count in 0..<3 {
      let fields = [
        "lc_q_retirement_read_pointer == 5'd\{read}",
        "lc_q_retirement_write_pointer == 5'd\{(read+count)%2}",
        "lc_q_retirement_occupancy == 5'd\{count}",
      ]
      let mut mask = 0
      for rank in 0..<count {
        let entry = (read + rank) % 2
        mask = mask | (1 << entry)
        fields.push(
          "lc_q_entry_ticket_\{entry} == lc_q_next_ticket - 32'd\{count-rank}",
        )
      }
      fields.push("lc_fr_valid_mask == 2'd\{mask}")
      rings.push("(" + fields.join(" && ") + ")")
    }
  }
  out.write_string("  wire lc_fr_ring_tickets = \{rings.join(" || ")};\n")
  out.write_string(
    (
      #|  wire lc_fr_head_owned = !lc_fr_head_live || (lc_fr_pointer_range
      #|    && lc_q_retirement_occupancy != 5'd0 && lc_fr_head_valid && !lc_fr_head_terminal
      #|    && lc_fr_head_ticket == lc_q_head_ticket && lc_q_head_ticket == lc_q_next_ticket - 32'd1
      #|    && lc_q_head_entry == (lc_q_retirement_write_pointer == 5'd0 ? 5'd1 : 5'd0));
      #|  logic lc_fr_previous_hold = 1'b0;
      #|  logic [99:0] lc_fr_previous_payload;
      #|  logic [4:0] lc_fr_previous_pointer;
      #|  logic [31:0] lc_fr_previous_ticket;
      #|
    ),
  )
  for entry in 0..<2 {
    out.write_string(
      "  wire [131:0] lc_fr_record_\{entry} = {lc_q_entry_ticket_\{entry}, lc_q_entry_id_\{entry}, lc_q_entry_fault_\{entry}, lc_q_entry_progress_\{entry}, lc_q_entry_address_\{entry}};\n" +
      "  logic lc_fr_previous_watch_\{entry} = 1'b0;\n" +
      "  logic [131:0] lc_fr_previous_record_\{entry};\n",
    )
  }
  out.write_string(
    (
      #|  always @(posedge lc_clock) begin
      #|    lc_fr_previous_hold <= !lc_reset && lc_completion_valid && !lc_completion_ready;
      #|    lc_fr_previous_payload <= lc_fr_public_payload;
      #|    lc_fr_previous_pointer <= lc_q_retirement_read_pointer;
      #|    lc_fr_previous_ticket <= lc_fr_oldest_ticket;
      #|
    ),
  )
  for entry in 0..<2 {
    out.write_string(
      "    lc_fr_previous_watch_\{entry} <= !lc_reset && lc_q_entry_valid_\{entry} && lc_q_entry_terminal_\{entry} && !lc_q_entry_acknowledge_\{entry};\n" +
      "    lc_fr_previous_record_\{entry} <= lc_fr_record_\{entry};\n" +
      "    lc_fr_terminal_record_\{entry}: assert ((lc_reset || !lc_fr_previous_watch_\{entry} || (lc_q_entry_valid_\{entry} && lc_q_entry_terminal_\{entry} && lc_fr_record_\{entry} == lc_fr_previous_record_\{entry})) === 1'b1);\n",
    )
  }
  out.write_string(
    (
      #|    // Current ready does not disable this watch: the release PRE is checked.
      #|    lc_fr_held_completion: assert ((lc_reset || !lc_fr_previous_hold || (lc_completion_valid
      #|      && lc_q_retirement_read_pointer == lc_fr_previous_pointer && lc_fr_oldest_ticket == lc_fr_previous_ticket
      #|      && lc_fr_public_payload == lc_fr_previous_payload)) === 1'b1);
      #|  end
      #|  always @($global_clock) begin
      #|    // Independent public history is checked against real retained state.
      #|    lc_fr_public_owned: assert ((!lc_seen_edge || lc_owned == (lc_o_arbiter_state == 2'd2)) === 1'b1);
      #|    lc_fr_public_request_history: assert ((!lc_seen_edge || !lc_previous_request_hold
      #|      || (lc_o_arbiter_state == 2'd1 && lc_request_payload == lc_previous_request_payload)) === 1'b1);
      #|    lc_fr_public_completion_history: assert ((!lc_seen_edge || (lc_previous_completion_hold == lc_fr_previous_hold
      #|      && (!lc_previous_completion_hold || lc_previous_completion_payload == lc_fr_previous_payload))) === 1'b1);
      #|    lc_fr_ring_structure: assert ((!lc_seen_edge || (lc_fr_pointer_range && lc_fr_ring_tickets)) === 1'b1);
      #|    lc_fr_reserved_head: assert ((!lc_seen_edge || lc_fr_head_owned) === 1'b1);
      #|    lc_fr_oldest_selected: assert ((!lc_seen_edge || lc_reset || (lc_fr_pointer_range
      #|      && lc_completion_valid == (lc_fr_oldest_valid && lc_fr_oldest_terminal)
      #|      && (!lc_completion_valid || lc_fr_public_payload == lc_fr_oldest_payload))) === 1'b1);
      #|
    ),
  )
  for entry in 0..<2 {
    out.write_string(
      "    lc_fr_allocate_unused_\{entry}: assert ((!lc_seen_edge || !lc_q_entry_allocate_\{entry} || !lc_q_entry_valid_\{entry}) === 1'b1);\n" +
      "    lc_fr_local_owned_\{entry}: assert ((!lc_seen_edge || !lc_q_entry_local_terminal_\{entry} || (lc_fr_head_live && lc_q_head_entry == 5'd\{entry} && lc_q_entry_valid_\{entry} && !lc_q_entry_terminal_\{entry} && lc_q_entry_ticket_\{entry} == lc_q_head_ticket)) === 1'b1);\n",
    )
  }
  for engine in 0..<3 {
    let owners = [
      for entry in 0..<2 => {
        "(lc_q_entry_valid_\{entry} && !lc_q_entry_terminal_\{entry} && lc_q_entry_ticket_\{entry} == lc_q_engine_ticket_\{engine} && !(lc_fr_head_live && lc_q_head_entry == 5'd\{entry}))"
      }
    ]
    out.write_string(
      "    lc_fr_engine_owned_\{engine}: assert ((!lc_seen_edge || lc_q_engine_state_\{engine} == 0 || (\{owners.join(" || ")})) === 1'b1);\n" +
      "    lc_fr_accept_owned_\{engine}: assert ((!lc_seen_edge || !lc_q_engine_accept_\{engine} || (lc_fr_head_live && lc_fr_head_owned)) === 1'b1);\n",
    )
    for other in (engine + 1)..<3 {
      out.write_string(
        "    lc_fr_engine_unique_\{engine}_\{other}: assert ((!lc_seen_edge || lc_q_engine_state_\{engine} == 0 || lc_q_engine_state_\{other} == 0 || lc_q_engine_ticket_\{engine} != lc_q_engine_ticket_\{other}) === 1'b1);\n",
      )
    }
  }
  out.write_string(
    "    lc_fr_accept_onehot: assert ((!lc_seen_edge || !((lc_q_engine_accept_0 && lc_q_engine_accept_1) || (lc_q_engine_accept_0 && lc_q_engine_accept_2) || (lc_q_engine_accept_1 && lc_q_engine_accept_2))) === 1'b1);\n",
  )
  out.write_string("  end\n")
  out.to_string().replace_all(old="lc_q_", new="lc_dut_composition_queue_")
}
