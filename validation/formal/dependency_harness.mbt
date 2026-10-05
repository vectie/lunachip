///|
fn dependency_harness(
  fixture : DependencyFormalFixture,
  dut : DependencyFormalDut,
  property_source : String,
) -> String {
  let out = StringBuilder()
  let header =
    #|`default_nettype none
    #|// Dependency authorization only; no FIFO, retirement, leases or liveness.
    #|module lc_formal_dependency_top;
    #|  logic lc_clock = 1'b0;
    #|  always @($global_clock) lc_clock <= ~lc_clock;
    #|
  out.write_string(header)
  for port in dut.ports {
    if port.role != "clock" {
      let symbolic = if port.input { "(* anyseq *) " } else { "" }
      out.write_string(
        "  \{symbolic}logic \{toggle_formal_width_range(port.width)}lc_\{port.role};\n",
      )
    }
  }
  for port in dut.observation_ports {
    out.write_string(
      "  logic \{toggle_formal_width_range(port.width)}lc_o_\{port.role};\n",
    )
  }
  out.write_string("  \{dut.identifier} lc_dut (\n")
  for port in dut.ports {
    out.write_string("    .\{port.identifier}(lc_\{port.role}),\n")
  }
  for index, port in dut.observation_ports {
    out.write_string("    .\{port.identifier}(lc_o_\{port.role})")
    out.write_string(
      if index + 1 == dut.observation_ports.length() {
        "\n"
      } else {
        ",\n"
      },
    )
  }
  out.write_string("  );\n")
  out.write_string(dependency_decode_source())
  out.write_string(dependency_ghost_source())
  let host =
    #|  logic lc_seen_edge = 1'b0;
    #|  logic lc_previous_descriptor_hold = 1'b0;
    #|  logic lc_previous_response_hold = 1'b0;
    #|  logic [255:0] lc_previous_descriptor_payload = 256'd0;
    #|  logic [65:0] lc_previous_response_payload = 66'd0;
    #|  wire [255:0] lc_descriptor_payload = {lc_descriptor_lane_3,
    #|    lc_descriptor_lane_2, lc_descriptor_lane_1, lc_descriptor_lane_0};
    #|  wire [65:0] lc_response_payload = {lc_memory_response_tag,
    #|    lc_memory_response_fault, lc_memory_response_data};
    #|  always_ff @(posedge lc_clock) begin
    #|    lc_seen_edge <= 1'b1;
    #|    if (lc_reset) begin
    #|      lc_previous_descriptor_hold <= 1'b0;
    #|      lc_previous_response_hold <= 1'b0;
    #|    end else begin
    #|      lc_previous_descriptor_hold <= lc_descriptor_valid && !lc_descriptor_ready;
    #|      lc_previous_response_hold <= lc_memory_response_valid && !lc_memory_response_ready;
    #|      lc_previous_descriptor_payload <= lc_descriptor_payload;
    #|      lc_previous_response_payload <= lc_response_payload;
    #|    end
    #|  end
    #|  wire lc_initial_joint_reset = lc_seen_edge || lc_reset;
    #|  wire lc_host_descriptor_stable_until_accept = lc_reset || !lc_previous_descriptor_hold
    #|    || (lc_descriptor_valid && lc_descriptor_payload == lc_previous_descriptor_payload);
    #|  wire lc_host_response_stable_until_accept = lc_reset || !lc_previous_response_hold
    #|    || (lc_memory_response_valid && lc_response_payload == lc_previous_response_payload);
    #|  // No tag/status/success assumption: faults and poison remain symbolic.
    #|  wire lc_host_response_flushed_during_reset = !lc_reset || !lc_memory_response_valid;
    #|
  out.write_string(host)
  out.write_string("  wire [1:0] lc_checked_status [0:5];\n")
  for index in 0..<6 {
    let checked = if fixture is NegativeFailedGeneration {
      "(lc_g_status[\{index}] == 2'd3 && lc_o_status[\{index}] == 2'd3 ? 2'd2 : lc_o_status[\{index}])"
    } else {
      "lc_o_status[\{index}]"
    }
    out.write_string("  assign lc_checked_status[\{index}] = \{checked};\n")
  }
  let priority_ticket = if fixture is NegativeNewIntentPriority {
    "(lc_priority_check ? lc_priority_old_ticket : lc_o_ticket[lc_priority_slot])"
  } else {
    "lc_o_ticket[lc_priority_slot]"
  }
  let inner_reduction = if fixture is NegativeInnerIdentity {
    "(lc_o_compute_latched_reduction ^ (lc_inner_accept ? 13'd1 : 13'd0))"
  } else {
    "lc_o_compute_latched_reduction"
  }
  out.write_string(
    "  wire [31:0] lc_checked_priority_ticket = \{priority_ticket};\n",
  )
  out.write_string(
    "  wire [12:0] lc_checked_inner_reduction = \{inner_reduction};\n",
  )
  let writer_checks = Array::makei(6, index => {
    "(lc_checked_status[\{index}] == lc_g_status[\{index}] && lc_o_ticket[\{index}] == lc_g_ticket[\{index}])"
  }).join("\n    && ")
  out.write_string(
    "  wire lc_latest_writer_matches_independent_model = lc_reset\n    || (lc_o_next_ticket == lc_g_next && \{writer_checks});\n",
  )
  let predicates =
    #|  wire lc_source_snapshots_prepublication_match_model = lc_reset || lc_o_head_state != 2'd3
    #|    || (lc_o_head_ticket == lc_g_head
    #|      && lc_o_dependency_status_0 == lc_g_snapshot_status[0]
    #|      && lc_o_dependency_status_1 == lc_g_snapshot_status[1]
    #|      && lc_o_dependency_ticket_0 == lc_g_snapshot_ticket[0]
    #|      && lc_o_dependency_ticket_1 == lc_g_snapshot_ticket[1]);
    #|  wire lc_consumer_admission_requires_successful_generations = lc_reset
    #|    || ((!lc_o_load_accept || (lc_priority_eligible && lc_raw_is_load))
    #|      && (!lc_o_compute_accept || (lc_priority_eligible && lc_raw_is_mat && lc_g_sources_good))
    #|      && (!lc_o_store_accept || (lc_priority_eligible && lc_raw_is_store && lc_g_resolved0 == 2'd2)));
    #|  wire lc_unavailable_dependency_rejection_exact = lc_reset
    #|    || ((lc_o_local_reject == lc_g_expected_reject)
    #|      && (!lc_dispatch_active || lc_o_local_fault == lc_g_expected_local_fault)
    #|      && (!lc_g_expected_reject || (!lc_o_compute_accept && !lc_o_store_accept)));
    #|  wire lc_new_intent_wins_matching_older_terminal = lc_reset || !lc_priority_check
    #|    || (lc_o_status[lc_priority_slot] == 2'd1 && lc_checked_priority_ticket == lc_priority_ticket);
    #|  wire lc_inner_identity_matches = lc_o_compute_latched_ticket == lc_g_authorized_ticket
    #|    && lc_o_compute_latched_a == lc_g_authorized_a
    #|    && lc_o_compute_latched_b == lc_g_authorized_b
    #|    && lc_o_compute_latched_c == lc_g_authorized_c
    #|    && lc_o_compute_latched_rows == lc_g_authorized_rows
    #|    && lc_o_compute_latched_columns == lc_g_authorized_columns
    #|    && lc_checked_inner_reduction == lc_g_authorized_reduction;
    #|  // Authorization is remembered from outer acceptance, not current latest
    #|  // writers, which can legitimately change during the registered Issue gap.
    #|  wire lc_inner_compute_preserves_saved_authorization = lc_reset || !lc_o_inner_command_valid
    #|    || (lc_g_authorized && lc_inner_identity_matches);
    #|  wire lc_terminal_ticket_matches_accepted_owner = lc_reset
    #|    || ((!lc_o_load_terminal || (lc_g_load_owned && lc_o_load_terminal_ticket == lc_g_load_ticket))
    #|      && (!lc_o_compute_terminal || (lc_g_compute_owned && lc_o_compute_terminal_ticket == lc_g_compute_ticket))
    #|      && (!lc_o_store_terminal || (lc_g_store_owned && lc_o_store_terminal_ticket == lc_g_store_ticket)));
    #|  wire lc_failed_reload_source0 = lc_g_resolved0 == 2'd3
    #|    && lc_g_snapshot_ticket[0] == lc_g_ticket[lc_raw_source0]
    #|    && lc_g_status[lc_raw_source0] == 2'd3 && lc_g_failed_after_success[lc_raw_source0];
    #|  wire lc_failed_reload_source1 = lc_g_resolved1 == 2'd3
    #|    && lc_g_snapshot_ticket[1] == lc_g_ticket[lc_raw_source1]
    #|    && lc_g_status[lc_raw_source1] == 2'd3 && lc_g_failed_after_success[lc_raw_source1];
    #|  wire lc_reachable_failed_reload_then_mat_fault4 = lc_priority_eligible && lc_raw_is_mat
    #|    && (lc_failed_reload_source0 || lc_failed_reload_source1)
    #|    && lc_o_local_reject && lc_o_local_fault == 4'd4;
    #|  wire lc_reachable_failed_mat_then_store_fault5 = lc_priority_eligible && lc_raw_is_store
    #|    && lc_failed_reload_source0 && lc_o_local_reject && lc_o_local_fault == 4'd5;
    #|  wire lc_bad_syntax_used0 = lc_raw_source0 == lc_bad_syntax_slot
    #|    && lc_g_snapshot_ticket[0] == lc_bad_syntax_ticket && lc_g_resolved0 == 2'd2;
    #|  wire lc_bad_syntax_used1 = lc_raw_source1 == lc_bad_syntax_slot
    #|    && lc_g_snapshot_ticket[1] == lc_bad_syntax_ticket && lc_g_resolved1 == 2'd2;
    #|  wire lc_reachable_invalid_syntax_preserves_usable_generation = !lc_reset && lc_bad_syntax_prior
    #|    && ((lc_o_compute_accept && lc_o_compute_preflight == 4'd0 && lc_g_sources_good
    #|        && (lc_bad_syntax_used0 || lc_bad_syntax_used1))
    #|      || (lc_o_store_accept && lc_bad_syntax_used0));
    #|  wire lc_reachable_older_terminal_with_new_intent = !lc_reset && lc_priority_check
    #|    && lc_priority_old_ticket != lc_priority_ticket
    #|    && lc_o_status[lc_priority_slot] == 2'd1 && lc_o_ticket[lc_priority_slot] == lc_priority_ticket;
    #|  wire lc_reachable_authorized_outer_to_inner_compute = lc_inner_accept
    #|    && lc_g_authorized && lc_inner_identity_matches;
    #|
  out.write_string(predicates)
  out.write_string(property_source)
  out.write_string("endmodule\n`default_nettype wire\n")
  out.to_string()
}
