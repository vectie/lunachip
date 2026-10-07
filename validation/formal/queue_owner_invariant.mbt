///|
// Conclusions over original retained state. Raw busy includes Done and does
// not disappear during PRE synchronous reset. No payload/transport leaf is a
// premise, and no caller ID is used as an ownership identity.
fn queue_owner_shape_source() -> String {
  let out = StringBuilder()
  let shape : Array[String] = [
    "(lc_o_head_state <= 2'd3)", "(lc_o_head_entry < 5'd3)", "(lc_o_retirement_read_pointer < 5'd3)",
    "(lc_o_retirement_write_pointer < 5'd3)", "(lc_o_retirement_occupancy <= 5'd3)",
    "(lc_o_fifo_response_valid_0 == (lc_o_head_state == 2'd1))",
  ]
  for lane in 0..<4 {
    shape.push("(lc_o_fifo_occupancy_\{lane} == lc_o_fifo_occupancy_0)")
    shape.push("(lc_o_fifo_occupancy_\{lane} <= 2'd3)")
    shape.push(
      "(lc_o_fifo_response_valid_\{lane} == lc_o_fifo_response_valid_0)",
    )
  }
  for engine in 0..<3 {
    let width = if engine == 1 { 2 } else { 3 }
    let done = if engine == 1 { 3 } else { 4 }
    shape.push("(lc_o_engine_state_\{engine} <= \{width}'d\{done})")
    out.write_string(
      "  wire lc_busy_\{engine} = lc_o_engine_state_\{engine} != \{width}'d0;\n",
    )
  }
  out.write_string(
    "  wire [2:0] lc_entry_valid_mask = {lc_o_entry_valid_2, lc_o_entry_valid_1, lc_o_entry_valid_0};\n",
  )
  let ring : Array[String] = []
  // Exact cyclic intervals, including empty/full; counts alone cannot rule
  // out holes or a wrong allocation/acknowledgment slot.
  for read in 0..<3 {
    for occupancy in 0..<4 {
      let mut mask = 0
      for offset in 0..<occupancy {
        mask = mask | (1 << ((read + offset) % 3))
      }
      ring.push(
        "(lc_o_retirement_read_pointer == 5'd\{read} && lc_o_retirement_occupancy == 5'd\{occupancy} && lc_o_retirement_write_pointer == 5'd\{(read + occupancy) % 3} && lc_entry_valid_mask == 3'd\{mask})",
      )
    }
  }
  out.write_string("  wire lc_ring_contiguous = \{ring.join(" || ")};\n")
  shape.push("lc_ring_contiguous")
  out.write_string("  wire lc_owner_structure_ok = \{shape.join(" && ")};\n")
  out.to_string()
}

///|
fn queue_owner_ticket_source() -> String {
  let out = StringBuilder()
  out.write_string(
    "  // Sized UInt32 arithmetic preserves cyclic order across ticket wrap.\n" +
    "  wire [31:0] lc_oldest_live_ticket = lc_o_next_ticket - {27'd0, lc_o_retirement_occupancy};\n" +
    "  wire [31:0] lc_newest_live_ticket = lc_o_next_ticket - 32'd1;\n",
  )
  let order : Array[String] = []
  for read in 0..<3 {
    for offset in 0..<3 {
      let entry = (read + offset) % 3
      order.push(
        "(!(lc_o_retirement_read_pointer == 5'd\{read} && lc_o_retirement_occupancy > 5'd\{offset}) || lc_o_entry_ticket_\{entry} == (lc_oldest_live_ticket + 32'd\{offset}))",
      )
    }
  }
  let pending : Array[String] = []
  for entry in 0..<3 {
    out.write_string(
      "  wire lc_pending_head_\{entry} = lc_o_head_state == 2'd3 && lc_o_head_entry == 5'd\{entry};\n",
    )
    pending.push(
      "(lc_o_head_entry == 5'd\{entry} && lc_o_retirement_write_pointer == 5'd\{(entry + 1) % 3} && lc_o_entry_valid_\{entry} && !lc_o_entry_terminal_\{entry} && lc_o_entry_ticket_\{entry} == lc_o_head_ticket)",
    )
  }
  out.write_string(
    "  wire lc_pending_head_ok = lc_o_head_state != 2'd3 || (lc_o_retirement_occupancy != 5'd0 && lc_o_head_ticket == lc_newest_live_ticket && (\{pending.join(" || ")}));\n",
  )
  out.write_string(
    "  wire lc_owner_ticket_order_ok = (\{order.join(" && ")}) && lc_pending_head_ok;\n",
  )
  out.to_string()
}

///|
// Explicit one-hot patterns avoid truncating sums of one-bit predicates.
fn queue_owner_onehot(name : String, width : Int) -> String {
  let cases : Array[String] = []
  for bit in 0..<width {
    cases.push("(\{name} == \{width}'d\{1 << bit})")
  }
  "(" + cases.join(" || ") + ")"
}

///|
fn queue_owner_bijection_source() -> String {
  let out = StringBuilder()
  let bijection : Array[String] = []
  for engine in 0..<3 {
    for entry in 0..<3 {
      out.write_string(
        "  wire lc_owner_match_\{entry}_\{engine} = lc_busy_\{engine} && lc_o_entry_valid_\{entry} && !lc_o_entry_terminal_\{entry} && lc_o_entry_ticket_\{entry} == lc_o_engine_ticket_\{engine};\n",
      )
    }
    out.write_string(
      "  wire [2:0] lc_owner_mask_\{engine} = {lc_owner_match_2_\{engine}, lc_owner_match_1_\{engine}, lc_owner_match_0_\{engine}};\n",
    )
    out.write_string(
      "  wire lc_engine_owned_\{engine} = !lc_busy_\{engine} || \{queue_owner_onehot("lc_owner_mask_\{engine}", 3)};\n",
    )
    bijection.push("lc_engine_owned_\{engine}")
    for other in 0..<engine {
      bijection.push(
        "(!(lc_busy_\{engine} && lc_busy_\{other}) || lc_o_engine_ticket_\{engine} != lc_o_engine_ticket_\{other})",
      )
    }
  }
  for entry in 0..<3 {
    let name = "lc_entry_owner_mask_\{entry}"
    out.write_string(
      "  wire [3:0] \{name} = {lc_owner_match_\{entry}_2, lc_owner_match_\{entry}_1, lc_owner_match_\{entry}_0, lc_pending_head_\{entry}};\n",
    )
    bijection.push(
      "((lc_o_entry_valid_\{entry} && !lc_o_entry_terminal_\{entry}) ? \{queue_owner_onehot(name, 4)} : (\{name} == 4'd0))",
    )
  }
  out.write_string(
    "  wire lc_owner_bijection_ok = \{bijection.join(" && ")};\n",
  )
  out.write_string(
    "  wire lc_raw_owner_invariant = lc_owner_structure_ok && lc_owner_ticket_order_ok && lc_owner_bijection_ok;\n",
  )
  out.to_string()
}

///|
fn queue_owner_event_source() -> String {
  let out = StringBuilder()
  let active : Array[String] = []
  let reset_zero : Array[String] = []
  for
    name in [
      "head_pop", "head_capture", "head_reserve", "head_issue", "head_finish", "head_reject",
      "head_fence", "retirement_valid", "retirement_fire", "descriptor_ready",
    ] {
    reset_zero.push("!lc_dut_" + name)
  }
  let ready : Array[String] = []
  let response : Array[String] = []
  for lane in 0..<4 {
    ready.push("lc_dut_fifo_pop_ready_\{lane}")
    response.push("lc_o_fifo_response_valid_\{lane}")
  }
  active.push(
    "(lc_dut_head_pop == (lc_o_head_state == 2'd0 && \{ready.join(" && ")}))",
  )
  active.push(
    "(lc_dut_head_capture == (lc_o_head_state == 2'd1 && \{response.join(" && ")}))",
  )
  active.push(
    "(lc_dut_head_reserve == (lc_o_head_state == 2'd2 && lc_o_retirement_occupancy < 5'd3))",
  )
  active.push(
    "(lc_dut_head_issue == (lc_dut_engine_accept_0 || lc_dut_engine_accept_1 || lc_dut_engine_accept_2))",
  )
  active.push(
    "(!(lc_dut_engine_accept_0 && lc_dut_engine_accept_1) && !(lc_dut_engine_accept_0 && lc_dut_engine_accept_2) && !(lc_dut_engine_accept_1 && lc_dut_engine_accept_2))",
  )
  active.push(
    "(lc_dut_head_finish == (lc_dut_head_issue || lc_dut_head_reject || lc_dut_head_fence))",
  )
  active.push(
    "(!(lc_dut_head_issue && lc_dut_head_reject) && !(lc_dut_head_issue && lc_dut_head_fence) && !(lc_dut_head_reject && lc_dut_head_fence))",
  )
  let oldest : Array[String] = []
  for entry in 0..<3 {
    oldest.push(
      "(lc_o_retirement_read_pointer == 5'd\{entry} && lc_o_entry_valid_\{entry} && lc_o_entry_terminal_\{entry})",
    )
  }
  active.push("(lc_dut_retirement_valid == (\{oldest.join(" || ")}))")
  active.push(
    "(lc_dut_retirement_fire == (lc_dut_retirement_valid && lc_completion_ready))",
  )
  for engine in 0..<3 {
    let width = if engine == 1 { 2 } else { 3 }
    let done = if engine == 1 { 3 } else { 4 }
    active.push(
      "(!lc_dut_engine_accept_\{engine} || (lc_o_engine_state_\{engine} == \{width}'d0 && lc_o_head_state == 2'd3))",
    )
    active.push(
      "(lc_dut_engine_terminal_\{engine} == (lc_o_engine_state_\{engine} == \{width}'d\{done}))",
    )
    out.write_string(
      "  wire [2:0] lc_collector_mask_\{engine} = {lc_dut_entry_collector_2_\{engine}, lc_dut_entry_collector_1_\{engine}, lc_dut_entry_collector_0_\{engine}};\n",
    )
    active.push(
      "(lc_collector_mask_\{engine} == (lc_dut_engine_terminal_\{engine} ? lc_owner_mask_\{engine} : 3'd0))",
    )
    active.push(
      "(!lc_dut_engine_terminal_\{engine} || \{queue_owner_onehot("lc_collector_mask_\{engine}", 3)})",
    )
    reset_zero.push("!lc_dut_engine_accept_\{engine}")
    reset_zero.push("!lc_dut_engine_terminal_\{engine}")
  }
  for entry in 0..<3 {
    let terminal = "lc_terminal_source_mask_\{entry}"
    out.write_string(
      "  wire [3:0] \{terminal} = {lc_dut_entry_collector_\{entry}_2, lc_dut_entry_collector_\{entry}_1, lc_dut_entry_collector_\{entry}_0, lc_dut_entry_local_terminal_\{entry}};\n",
    )
    out.write_string("  wire lc_terminal_event_\{entry} = |\{terminal};\n")
    active.push("(\{terminal} == 4'd0 || \{queue_owner_onehot(terminal, 4)})")
    active.push(
      "(lc_dut_entry_allocate_\{entry} == (lc_dut_head_reserve && lc_o_retirement_write_pointer == 5'd\{entry}))",
    )
    active.push(
      "(lc_dut_entry_acknowledge_\{entry} == (lc_dut_retirement_fire && lc_o_retirement_read_pointer == 5'd\{entry}))",
    )
    active.push(
      "(lc_dut_entry_local_terminal_\{entry} == ((lc_dut_head_reject || lc_dut_head_fence) && lc_o_head_entry == 5'd\{entry}))",
    )
    active.push(
      "(!lc_dut_entry_allocate_\{entry} || !lc_o_entry_valid_\{entry})",
    )
    active.push(
      "(!lc_dut_entry_acknowledge_\{entry} || (lc_o_entry_valid_\{entry} && lc_o_entry_terminal_\{entry} && !lc_terminal_event_\{entry}))",
    )
    active.push(
      "(!lc_terminal_event_\{entry} || (lc_o_entry_valid_\{entry} && !lc_o_entry_terminal_\{entry} && !lc_dut_entry_allocate_\{entry} && !lc_dut_entry_acknowledge_\{entry}))",
    )
    active.push(
      "(!lc_dut_entry_local_terminal_\{entry} || (lc_pending_head_\{entry} && lc_o_entry_ticket_\{entry} == lc_o_head_ticket && !lc_dut_head_issue))",
    )
    for suffix in ["allocate", "acknowledge", "local_terminal"] {
      reset_zero.push("!lc_dut_entry_\{suffix}_\{entry}")
    }
    for engine in 0..<3 {
      reset_zero.push("!lc_dut_entry_collector_\{entry}_\{engine}")
    }
  }
  out.write_string(
    "  wire lc_owner_events_ok = lc_reset ? (\{reset_zero.join(" && ")}) : (\{active.join(" && ")});\n",
  )
  out.to_string()
}

///|
fn queue_owner_invariant_source() -> String {
  queue_owner_shape_source() +
  queue_owner_ticket_source() +
  queue_owner_bijection_source() +
  queue_owner_event_source()
}
