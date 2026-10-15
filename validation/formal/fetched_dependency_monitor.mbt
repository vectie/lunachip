///|
// The original harness is only a byte carrier for its independent predicates.
// Its DUT instance, symbolic inputs, peer premises and covers are NOT copied.
fn fetched_dependency_predicates() -> String raise {
  let carrier : DependencyFormalDut = {
    identifier: "unused",
    filename: "unused",
    source: "",
    production_filename: "unused",
    production_source: "",
    ports: [],
    observation_ports: [],
  }
  let original = dependency_harness(LatestWriterGenerationSupport, carrier, "")
  let marker = "  (* mem2reg *) wire [1:0] lc_checked_status [0:5];\n"
  guard original.split(marker).to_array() is [_, tail] &&
    tail.strip_suffix("endmodule\n`default_nettype wire\n") is Some(tail) else {
    raise InvalidFormalBundleIdentity(
      "fetched dependency: complete original predicate suffix",
    )
  }
  marker + tail.to_owned()
}

///|
fn fetched_dependency_support() -> String raise {
  let out = StringBuilder()
  for (role, width) in dependency_expected_observations() {
    let name = dependency_role_name(role)
    out.write_string(
      "  wire \{toggle_formal_width_range(width)}lc_o_\{name} = lc_dut_composition_dependency_\{name};\n",
    )
  }
  out.write_string(dependency_decode_source())
  out.write_string(dependency_ghost_source())
  out.write_string(fetched_dependency_predicates())
  out.write_string("  always @($global_clock) begin\n")
  // A terminal-only watch cannot establish ownership across an arbitrarily
  // long DMA wait. Check that same history throughout the real busy phase.
  for (engine, prefix) in [(0, "load"), (1, "compute"), (2, "store")] {
    out.write_string(
      "    lc_fd_owner_history_\{engine}: assert ((!lc_seen_edge || (lc_g_\{prefix}_owned == (lc_dut_composition_queue_engine_state_\{engine} != 0) && (!lc_g_\{prefix}_owned || lc_o_\{prefix}_terminal_ticket == lc_g_\{prefix}_ticket))) === 1'b1);\n",
    )
  }
  out.write_string(
    "    lc_fd_issue_history: assert ((!lc_seen_edge || (lc_g_authorized == (lc_dut_composition_queue_engine_state_1 == 2'd1) && (!lc_g_authorized || lc_inner_identity_matches))) === 1'b1);\n",
  )
  for
    (name, kind) in dependency_property_definitions(
      LatestWriterGenerationSupport,
    ) {
    if kind is Assertion {
      out.write_string(
        "    lc_fd_\{name}: assert ((!lc_seen_edge || lc_\{name}) === 1'b1);\n",
      )
    }
  }
  // Strong global correspondence, including the PRE of a later reset. All
  // reference transitions use actual events and the independently decoded head.
  let fields = [
    "lc_o_next_ticket == lc_g_next", "lc_o_head_ticket == lc_g_head",
  ]
  for slot in 0..<6 {
    fields.push("lc_o_writer_status_\{slot} == lc_g_status[\{slot}]")
    fields.push("lc_o_writer_ticket_\{slot} == lc_g_ticket[\{slot}]")
  }
  for source in 0..<2 {
    fields.push(
      "lc_o_dependency_status_\{source} == lc_g_snapshot_status[\{source}]",
    )
    fields.push(
      "lc_o_dependency_ticket_\{source} == lc_g_snapshot_ticket[\{source}]",
    )
  }
  out.write_string(
    "    lc_fd_generation_established: assert ((!lc_seen_edge || (\{fields.join(" && ")})) === 1'b1);\n  end\n",
  )
  out.to_string()
}
