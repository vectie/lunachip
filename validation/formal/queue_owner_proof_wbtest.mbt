///|
test "queue owner proof inputs bind original clock all thirty roots and fifty nine events" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let before = @ir_codec.serialize(
    @ir.Design::single(
      "QueuedConcurrentQueueConservationPilot",
      fixture.hardware(),
    ),
  )
  let sequential = queue_owner_sequential(fixture)
  let emitted = @rtl.emit_design(
    @ir.Design::single("QueueOwnerSequential", sequential.hardware),
  )
  let source = queue_owner_proof_source(fixture, sequential, emitted)
  assert_eq(source, queue_owner_proof_source(fixture, sequential, emitted))
  assert_eq(
    @ir_codec.serialize(
      @ir.Design::single(
        "QueuedConcurrentQueueConservationPilot",
        fixture.hardware(),
      ),
    ),
    before,
  )
  assert_true(source.contains("module lc_queue_owner_bridge;"))
  assert_true(source.contains("logic lc_clock = 1'b0;"))
  assert_true(source.contains("always @($global_clock) lc_clock <= ~lc_clock;"))
  assert_true(
    source.contains(
      ".\{port_identifier(emitted, InputPort, "clock")}(lc_clock)",
    ),
  )
  assert_eq(source.split("(* anyseq *)").length() - 1, 82)
  for root in sequential.plan.probe.roots {
    let port = port_identifier(emitted, OutputPort, "current_" + root.name)
    assert_eq(source.split(".\{port}(lc_o_\{root.name})").length() - 1, 1)
    assert_true(
      source.contains(
        "wire \{toggle_formal_width_range(root.signal_type.width().bits())}lc_o_\{root.name};",
      ),
    )
    assert_true(
      source.contains(
        "logic \{toggle_formal_width_range(root.signal_type.width().bits())}lc_pre_\{root.name};",
      ),
    )
    assert_true(source.contains("lc_pre_\{root.name} <= lc_o_\{root.name};"))
    assert_false(sequential.plan.cuts.any(cut => cut.node == root.node))
  }
  for event in sequential.plan.probe.events {
    let port = port_identifier(emitted, OutputPort, event.name)
    assert_eq(source.split(".\{port}(lc_dut_\{event.name})").length() - 1, 1)
  }
  for name in ["reset", "descriptor_valid", "completion_ready"] {
    guard sequential.plan.cuts.filter(cut => cut.roles.contains(name)) is [cut] else {
      fail("missing original public boundary")
    }
    assert_true(
      source.contains("wire lc_\{name} = cut_n\{cut.node.ordinal()};"),
    )
  }
  assert_true(source.contains("wire [303:0] lc_current_pair = {"))
  assert_true(source.contains("logic [303:0] lc_previous_pair;"))
  guard source.split("wire [303:0] lc_current_pair = {").to_array() is [_, tail] else {
    fail("missing unique raw state pair")
  }
  let pair = tail.split("};").to_array()[0]
  assert_eq(pair.split(", ").length(), 30)
  assert_false(pair.contains("checked"))
  assert_false(pair.contains("lc_pre_"))
  assert_false(pair.contains("lc_dut_"))
}

///|
test "queue owner proof has nine conclusions and only first sampled reset premise" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let sequential = queue_owner_sequential(fixture)
  let emitted = @rtl.emit_design(
    @ir.Design::single("QueueOwnerSequential", sequential.hardware),
  )
  let source = queue_owner_proof_source(fixture, sequential, emitted)
  assert_eq(source.split(": assume (").length() - 1, 1)
  assert_eq(source.split(": assert (").length() - 1, 9)
  assert_eq(source.split(": cover (").length() - 1, 0)
  for
    label in [
      "lc_owner_structure", "lc_owner_ticket_order", "lc_owner_bijection", "lc_owner_engine_identity",
      "lc_owner_events", "lc_owner_edge_updates", "lc_owner_reset_zero", "lc_owner_established",
      "lc_owner_nonrising_hold",
    ] {
    assert_eq(source.split(label + ": assert (").length() - 1, 1)
  }
  assert_true(
    source.contains(
      "lc_initial_joint_reset: assume ((lc_seen_edge || lc_reset) === 1'b1);",
    ),
  )
  assert_true(source.contains("!lc_seen_edge || lc_raw_owner_invariant"))
  assert_true(source.contains("!lc_previous_rising_reset || lc_all_reset_zero"))
  assert_true(
    source.contains(
      "!lc_seen_edge || lc_previous_rising_reset || lc_owner_edge_updates_ok",
    ),
  )
  assert_true(source.contains("(!lc_previous_clock && lc_clock)"))
  assert_true(source.contains("lc_current_pair == lc_previous_pair"))
  assert_true(source.contains(queue_owner_invariant_source()))
  assert_false(source.contains("lc_g_public_outstanding"))
  assert_false(source.contains("lc_o_entry_id"))
  assert_false(source.contains("lc_o_entry_progress"))
  assert_false(source.contains("fairness"))
}

///|
test "queue owner raw invariant keeps cyclic tickets pending newest slot and Done owners" {
  let source = queue_owner_invariant_source()
  assert_true(
    source.contains("lc_o_next_ticket - {27'd0, lc_o_retirement_occupancy}"),
  )
  assert_true(source.contains("lc_o_next_ticket - 32'd1"))
  assert_true(
    source.contains(
      "lc_o_head_state != 2'd3 || (lc_o_retirement_occupancy != 5'd0",
    ),
  )
  assert_true(source.contains("lc_o_head_ticket == lc_newest_live_ticket"))
  for entry in 0..<3 {
    assert_true(
      source.contains(
        "lc_o_head_entry == 5'd\{entry} && lc_o_retirement_write_pointer == 5'd\{(entry + 1) % 3}",
      ),
    )
    assert_true(
      source.contains(
        "lc_o_entry_valid_\{entry} && !lc_o_entry_terminal_\{entry} && lc_o_entry_ticket_\{entry} == lc_o_head_ticket",
      ),
    )
    assert_true(source.contains("wire [3:0] lc_entry_owner_mask_\{entry}"))
    assert_true(source.contains("(lc_entry_owner_mask_\{entry} == 4'd0)"))
    for bit in 0..<4 {
      assert_true(
        source.contains("lc_entry_owner_mask_\{entry} == 4'd\{1 << bit}"),
      )
    }
  }
  for engine in 0..<3 {
    let width = if engine == 1 { 2 } else { 3 }
    let done = if engine == 1 { 3 } else { 4 }
    assert_true(
      source.contains(
        "wire lc_busy_\{engine} = lc_o_engine_state_\{engine} != \{width}'d0;",
      ),
    )
    assert_true(
      source.contains("lc_o_engine_state_\{engine} <= \{width}'d\{done}"),
    )
    assert_true(
      source.contains(
        "lc_dut_engine_terminal_\{engine} == (lc_o_engine_state_\{engine} == \{width}'d\{done})",
      ),
    )
    assert_true(
      source.contains(
        "lc_collector_mask_\{engine} == (lc_dut_engine_terminal_\{engine} ? lc_owner_mask_\{engine} : 3'd0)",
      ),
    )
    for bit in 0..<3 {
      assert_true(source.contains("lc_owner_mask_\{engine} == 3'd\{1 << bit}"))
    }
    for other in 0..<engine {
      assert_true(
        source.contains(
          "lc_o_engine_ticket_\{engine} != lc_o_engine_ticket_\{other}",
        ),
      )
    }
  }
  guard source.split("wire lc_raw_owner_invariant = ").to_array() is [_, tail] else {
    fail("missing unique raw invariant")
  }
  let invariant = tail.split(";").to_array()[0]
  assert_false(invariant.contains("reset"))
  assert_false(invariant.contains("checked"))
  assert_true(source.contains("wire lc_owner_events_ok = lc_reset ?"))
}

///|
test "queue owner negative changes only checked loader comparison after real reset cleared histories" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let sequential = queue_owner_sequential(fixture)
  let emitted = @rtl.emit_design(
    @ir.Design::single("QueueOwnerSequential", sequential.hardware),
  )
  let positive = queue_owner_proof_source(fixture, sequential, emitted)
  let negative = queue_owner_proof_source(
    fixture,
    sequential,
    emitted,
    negative=true,
  )
  let original = "  wire [31:0] lc_checked_loader_ticket = lc_o_engine_ticket_0;\n"
  let changed = "  wire [31:0] lc_checked_loader_ticket = (lc_o_engine_ticket_0 + (lc_genuine_busy_loader ? 32'd1 : 32'd0));\n"
  assert_eq(positive.split(original).length() - 1, 1)
  assert_eq(negative.split(changed).length() - 1, 1)
  assert_eq(negative.replace(old=changed, new=original), positive)
  assert_eq(negative.split("lc_checked_loader_ticket").length() - 1, 4)
  assert_true(
    negative.contains("lc_checked_loader_owner_mask == lc_owner_mask_0"),
  )
  assert_true(
    negative.contains("lc_engine_owned_0 && lc_checked_loader_owner_mask"),
  )
  assert_true(
    negative.contains(
      "wire lc_admit = lc_descriptor_valid && lc_dut_descriptor_ready;",
    ),
  )
  for name in ["admission_seen", "reservation_seen", "loader_accept_seen"] {
    assert_true(negative.contains("logic lc_\{name} = 1'b0;"))
    assert_true(negative.contains("lc_\{name} <= 1'b0;"))
    assert_true(negative.contains("lc_\{name} <= 1'b1;"))
  }
  assert_true(negative.contains("if (lc_admit) lc_admission_seen <= 1'b1;"))
  assert_true(
    negative.contains("if (lc_dut_head_reserve) lc_reservation_seen <= 1'b1;"),
  )
  assert_true(
    negative.contains(
      "if (lc_dut_engine_accept_0) lc_loader_accept_seen <= 1'b1;",
    ),
  )
  assert_true(
    negative.contains("wire lc_genuine_busy_loader = !lc_reset && lc_seen_edge"),
  )
  assert_true(
    negative.contains(
      "&& lc_admission_seen && lc_reservation_seen && lc_loader_accept_seen",
    ),
  )
  assert_true(negative.contains("&& lc_raw_owner_invariant && lc_busy_0;"))
  for engine in 0..<3 {
    assert_true(
      negative.contains(
        "lc_o_engine_ticket_\{engine} == (lc_pre_engine_accept_\{engine} ? lc_pre_head_ticket : lc_pre_engine_ticket_\{engine})",
      ),
    )
    let width = if engine == 1 { 2 } else { 3 }
    assert_true(
      negative.contains(
        "!lc_pre_engine_terminal_\{engine} || lc_o_engine_state_\{engine} == \{width}'d0",
      ),
    )
  }
  for entry in 0..<3 {
    assert_true(
      negative.contains(
        "lc_pre_terminal_event_\{entry} <= lc_terminal_event_\{entry};",
      ),
    )
    assert_true(
      negative.contains(
        "lc_o_entry_ticket_\{entry} == (lc_pre_entry_allocate_\{entry} ? lc_pre_next_ticket : lc_pre_entry_ticket_\{entry})",
      ),
    )
    assert_true(
      negative.contains(
        "lc_pre_entry_allocate_\{entry} ? 1'b0 : (lc_pre_terminal_event_\{entry} ? 1'b1 : lc_pre_entry_terminal_\{entry})",
      ),
    )
  }
}

///|
test "queue owner proof rejects remapped clock that is actually essential state" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let sequential = queue_owner_sequential(fixture)
  let emitted = @rtl.emit_design(
    @ir.Design::single("QueueOwnerSequential", sequential.hardware),
  )
  let mapping = sequential.original_to_local.iter().to_array()
  mapping[sequential.plan.probe.clock.ordinal()] = Some(
    dependency_generation_mapped(
      sequential.original_to_local,
      sequential.plan.probe.roots[0].node,
    ),
  )
  let invalid : QueueOwnerSequential = {
    ..sequential,
    original_to_local: ReadOnlyArray::from_array(mapping),
  }
  try queue_owner_proof_source(fixture, invalid, emitted) catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong original-clock identity rejection")
  } noraise {
    _ => fail("state was accepted as the original proof clock")
  }
}
