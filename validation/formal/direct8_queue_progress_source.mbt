///|
fn direct8_queue_progress_source() -> String {
  let out = StringBuilder()
  let head : Array[String] = []
  let done : Array[String] = []
  let collect : Array[String] = []
  for
    (event, state) in [
      ("pop", 1),
      ("capture", 2),
      ("reserve", 3),
      ("finish", 0),
    ] {
    out.write_string("  logic lc_g_previous_head_\{event} = 1'b0;\n")
    out.write_string(
      "  always @(posedge lc_g_clock) lc_g_previous_head_\{event} <= !lc_g_reset && lc_g_q_head_\{event};\n",
    )
    head.push(
      "(!lc_g_previous_head_\{event} || lc_g_q_head_state == 2'd\{state})",
    )
  }
  for engine in 0..<3 {
    out.write_string("  logic lc_g_previous_done_\{engine} = 1'b0;\n")
    out.write_string(
      "  always @(posedge lc_g_clock) lc_g_previous_done_\{engine} <= !lc_g_reset && lc_g_q_engine_terminal_\{engine};\n",
    )
    done.push(
      "(!lc_g_previous_done_\{engine} || lc_g_q_engine_state_\{engine} == 0)",
    )
  }
  for entry in 0..<3 {
    let terms = Array::makei(3, engine => {
      "lc_g_q_entry_collector_\{entry}_\{engine}"
    })
    out.write_string("  logic lc_g_previous_collect_\{entry} = 1'b0;\n")
    out.write_string(
      "  always @(posedge lc_g_clock) lc_g_previous_collect_\{entry} <= !lc_g_reset && !lc_g_q_entry_allocate_\{entry} && (\{terms.join(" || ")});\n",
    )
    collect.push(
      "(!lc_g_previous_collect_\{entry} || lc_g_q_entry_terminal_\{entry})",
    )
  }
  for
    (name, terms) in [
      ("head_progress", head),
      ("engine_done_release", done),
      ("collector_commit", collect),
    ] {
    out.write_string(
      "  wire lc_d8g_\{name} = lc_g_reset || (\{terms.join(" && ")});\n",
    )
  }
  out.to_string()
}
