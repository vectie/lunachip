///|
test "arbiter proof binds exact original clock fifteen free cuts and retained state events" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let before = @ir_codec.serialize(
    @ir.Design::single(
      "QueuedConcurrentQueueConservationPilot",
      fixture.hardware(),
    ),
  )
  let sequential = two_client_arbiter_sequential(fixture)
  let copied = @ir_codec.serialize(
    @ir.Design::single("TwoClientArbiterSequential", sequential.hardware),
  )
  let emitted = @rtl.emit_design(
    @ir.Design::single(
      "TwoClientArbiterSequential",
      two_client_arbiter_proof_view(sequential),
    ),
  )
  let source = two_client_arbiter_proof_source(fixture, sequential, emitted)
  assert_eq(
    source,
    two_client_arbiter_proof_source(fixture, sequential, emitted),
  )
  assert_eq(
    @ir_codec.serialize(
      @ir.Design::single(
        "QueuedConcurrentQueueConservationPilot",
        fixture.hardware(),
      ),
    ),
    before,
  )
  assert_eq(
    @ir_codec.serialize(
      @ir.Design::single("TwoClientArbiterSequential", sequential.hardware),
    ),
    copied,
  )
  assert_eq(sequential.hardware.nodes().length(), 108)
  assert_eq(sequential.probe.roots.length(), 11)
  assert_eq(
    sequential.probe.roots
    .iter()
    .fold(init=0, (bits, root) => bits + root.signal_type.width().bits()),
    172,
  )
  assert_true(source.contains("module lc_two_client_arbiter_bridge;"))
  assert_true(source.contains("logic lc_clock = 1'b0;"))
  assert_true(source.contains("always @($global_clock) lc_clock <= ~lc_clock;"))
  assert_eq(
    source
    .split(".\{port_identifier(emitted, InputPort, "clock")}(lc_clock)")
    .length() -
    1,
    1,
  )
  assert_eq(source.split("(* anyseq *)").length() - 1, 15)
  assert_eq(
    sequential.probe.candidates
    .iter()
    .fold(init=0, (bits, candidate) => {
      bits + candidate.original.signal_type().width().bits()
    }),
    233,
  )
  for candidate in sequential.probe.candidates {
    let name = "cut_n\{candidate.original.id().ordinal()}"
    assert_eq(
      source
      .split(
        "(* anyseq *) logic \{toggle_formal_width_range(candidate.original.signal_type().width().bits())}\{name};",
      )
      .length() -
      1,
      1,
    )
    assert_eq(
      source
      .split(".\{port_identifier(emitted, InputPort, name)}(\{name})")
      .length() -
      1,
      1,
    )
    assert_false(candidate.original.kind() is Constant(_))
    assert_false(
      sequential.probe.roots.any(root => root.node == candidate.original.id()),
    )
    assert_false(
      sequential.probe.events.any(event => event.node == candidate.original.id()),
    )
  }
  for boundary in sequential.probe.boundaries {
    let value = match boundary.original.kind() {
      Constant(value) =>
        "\{boundary.original.signal_type().width().bits()}'d\{value}"
      _ => "cut_n\{boundary.original.id().ordinal()}"
    }
    for role in boundary.roles {
      assert_eq(
        source
        .split(
          "wire \{toggle_formal_width_range(boundary.original.signal_type().width().bits())}lc_i_\{role} = \{value};",
        )
        .length() -
        1,
        1,
      )
    }
    if boundary.original.kind() is Constant(_) {
      assert_false(source.contains("cut_n\{boundary.original.id().ordinal()}"))
    }
  }
  for root in sequential.probe.roots {
    assert_eq(root.spec.initial(), None)
    assert_eq(
      source
      .split(
        ".\{port_identifier(emitted, OutputPort, "current_" + root.name)}(lc_o_\{root.name})",
      )
      .length() -
      1,
      1,
    )
    assert_true(
      source.contains(
        "logic \{toggle_formal_width_range(root.signal_type.width().bits())}lc_pre_\{root.name};",
      ),
    )
    assert_true(source.contains("lc_pre_\{root.name} <= lc_o_\{root.name};"))
  }
  for event in sequential.probe.events {
    assert_eq(
      source
      .split(
        ".\{port_identifier(emitted, OutputPort, event.name)}(lc_dut_\{event.name})",
      )
      .length() -
      1,
      1,
    )
  }
}

///|
test "arbiter proof keeps eight conclusions and sole first rising reset premise" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let sequential = two_client_arbiter_sequential(fixture)
  let emitted = @rtl.emit_design(
    @ir.Design::single(
      "TwoClientArbiterSequential",
      two_client_arbiter_proof_view(sequential),
    ),
  )
  let source = two_client_arbiter_proof_source(fixture, sequential, emitted)
  assert_eq(source.split("assume (").length() - 1, 1)
  assert_eq(source.split(": assert (").length() - 1, 8)
  assert_eq(source.split("cover (").length() - 1, 0)
  for
    group in [
      "payload", "history", "routes", "arbitration", "edge_updates", "reset_zero",
      "established", "nonrising_hold",
    ] {
    assert_eq(
      source.split("lc_arbiter_" + group + ": assert (").length() - 1,
      1,
    )
  }
  assert_true(
    source.contains(
      "lc_initial_joint_reset: assume ((lc_seen_edge || lc_reset) === 1'b1);",
    ),
  )
  assert_true(source.contains("logic [171:0] lc_previous_pair;"))
  assert_true(source.contains("(!lc_previous_clock && lc_clock)"))
  assert_true(source.contains("lc_current_pair == lc_previous_pair"))
  guard source.split("wire [171:0] lc_current_pair = {").to_array() is [_, tail] else {
    fail("missing unique original arbiter state tuple")
  }
  let pair = tail.split("};").to_array()[0]
  assert_eq(pair.split(", ").length(), 11)
  assert_false(pair.contains("checked"))
  assert_false(pair.contains("lc_pre_"))
  assert_false(pair.contains("lc_dut_"))
  guard source.split("  always @($global_clock) begin\n").to_array()
    is [rising, global] else {
    fail("expected one explicit global assertion sampler")
  }
  for
    group in [
      "payload", "history", "routes", "arbitration", "edge_updates", "reset_zero",
    ] {
    assert_true(rising.contains("lc_arbiter_" + group + ": assert ("))
    assert_false(global.contains("lc_arbiter_" + group + ": assert ("))
  }
  assert_true(rising.contains("lc_initial_joint_reset: assume ("))
  assert_false(global.contains("assume"))
  for group in ["established", "nonrising_hold"] {
    assert_true(global.contains("lc_arbiter_" + group + ": assert ("))
    assert_false(rising.contains("lc_arbiter_" + group + ": assert ("))
  }
  assert_true(
    global.contains(
      "lc_arbiter_established: assert ((!lc_seen_edge || lc_raw_invariant) === 1'b1);",
    ),
  )
  assert_true(
    rising.contains(
      "lc_arbiter_edge_updates: assert ((!lc_seen_edge || lc_previous_rising_reset\n      || lc_edge_updates_ok) === 1'b1);",
    ),
  )
  assert_true(
    rising.contains(
      "lc_arbiter_reset_zero: assert ((!lc_previous_rising_reset\n      || (lc_all_reset_zero && lc_observers_reset_zero)) === 1'b1);",
    ),
  )
}

///|
test "arbiter negative changes only checked stalled payload data bit zero" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let sequential = two_client_arbiter_sequential(fixture)
  let emitted = @rtl.emit_design(
    @ir.Design::single(
      "TwoClientArbiterSequential",
      two_client_arbiter_proof_view(sequential),
    ),
  )
  let positive = two_client_arbiter_proof_source(fixture, sequential, emitted)
  let negative = two_client_arbiter_proof_source(
    fixture,
    sequential,
    emitted,
    negative=true,
  )
  let original = "  wire [103:0] lc_checked_payload = lc_raw_payload;\n"
  let changed = "  wire [103:0] lc_checked_payload = (lc_raw_payload ^ (lc_genuine_stalled_offer ? (104'd1 << 32) : 104'd0));\n"
  assert_eq(positive.split(original).length() - 1, 1)
  assert_eq(negative.split(changed).length() - 1, 1)
  assert_eq(negative.replace(old=changed, new=original), positive)
  // One declaration plus one dedicated comparison. The mutation cannot feed
  // any observer update, raw establishment, request identity or controller.
  assert_eq(negative.split("lc_checked_payload").length() - 1, 2)
}

///|
test "arbiter observer snapshots raw contenders and checks saved PRE without feeding DUT" {
  let observer = two_client_arbiter_observer_source()
  let relation = two_client_arbiter_relation_source()
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let probe = two_client_arbiter_probe(fixture)
  let edge = two_client_arbiter_edge_source(probe)
  assert_true(
    observer.contains(
      "wire lc_selected_engine = lc_i_engine_valid\n    && (!lc_i_reader_valid || lc_o_preference);",
    ),
  )
  assert_true(
    observer.contains(
      "wire [103:0] lc_reader_payload = {lc_i_reader_write, lc_i_reader_address,\n    lc_i_reader_bytes, lc_i_reader_mask, lc_i_reader_data, lc_i_reader_tag};",
    ),
  )
  assert_true(
    observer.contains(
      "wire [103:0] lc_engine_payload = {lc_i_engine_write, lc_i_engine_address,\n    lc_i_engine_bytes, lc_i_engine_mask, lc_i_engine_data, lc_i_engine_tag};",
    ),
  )
  assert_true(
    observer.contains(
      "if (lc_dut_grant) begin\n        lc_snapshot_valid <= 1'b1;\n        lc_saved_payload <= lc_selected_payload;\n        lc_saved_owner <= lc_selected_engine;",
    ),
  )
  assert_false(observer.contains("lc_saved_payload <= lc_raw_payload"))
  assert_true(observer.contains("lc_accepted_owner <= lc_saved_owner;"))
  assert_true(
    observer.contains("lc_accepted_local_tag <= lc_saved_payload[31:0];"),
  )
  assert_true(
    observer.contains(
      "lc_public_request_count <= lc_public_request_count + 32'd1;",
    ),
  )
  assert_true(
    observer.contains(
      "else if (lc_dut_response_accept) lc_outstanding <= 1'b0;",
    ),
  )
  assert_true(
    observer.contains(
      "if (lc_dut_grant || lc_dut_response_accept) lc_stall_seen <= 1'b0;\n      else if (lc_dut_offer && !lc_i_request_ready) lc_stall_seen <= 1'b1;",
    ),
  )
  assert_true(observer.contains("lc_stall_seen <= 1'b0;"))
  assert_false(observer.contains("lc_checked_payload"))
  assert_false(observer.contains("assume"))
  assert_true(
    relation.contains(
      "wire lc_raw_history_ok = (lc_snapshot_valid == lc_raw_active)\n    && (lc_outstanding == lc_raw_wait)",
    ),
  )
  assert_true(relation.contains("lc_o_next_tag == lc_public_request_count"))
  assert_true(relation.contains("lc_o_expected_tag == lc_accepted_global_tag"))
  assert_true(relation.contains("lc_o_next_tag == lc_saved_global_tag + 32'd1"))
  assert_true(
    relation.contains("!(lc_dut_request_accept && lc_dut_response_accept)"),
  )
  assert_true(relation.contains("lc_i_response_fault >= 2'd2"))
  assert_true(
    relation.contains(
      "lc_dut_route_response_fault == (lc_malformed ? 2'd2 : lc_i_response_fault)",
    ),
  )
  assert_true(
    relation.contains(
      "&& lc_snapshot_valid && lc_stall_seen && lc_dut_offer\n    && lc_raw_payload_match && lc_raw_invariant;",
    ),
  )
  guard relation.split("wire lc_raw_invariant = ").to_array() is [_, invariant] else {
    fail("missing unique independent raw establishment")
  }
  assert_eq(
    invariant.split(";").to_array()[0],
    "lc_raw_payload_ok && lc_raw_history_ok",
  )
  assert_false(relation.contains("lc_checked_payload"))
  assert_false(relation.contains("assume"))
  assert_true(edge.contains("lc_pre_selected_engine <= lc_selected_engine;"))
  assert_true(edge.contains("lc_pre_selected_payload <= lc_selected_payload;"))
  assert_true(
    edge.contains(
      "lc_o_preference == (lc_pre_request_accept ? !lc_pre_owner : lc_pre_preference)",
    ),
  )
  assert_true(
    edge.contains(
      "lc_raw_payload == (lc_pre_grant ? lc_pre_selected_payload : {lc_pre_write, lc_pre_address, lc_pre_bytes, lc_pre_mask, lc_pre_data, lc_pre_local_tag})",
    ),
  )
  assert_true(edge.contains("lc_pre_state != 2'd3 || lc_o_state == 2'd3"))
  assert_false(edge.contains("lc_checked_payload"))
  assert_false(edge.contains("assume"))
}

///|
test "arbiter proof rejects original clock mapping changed to retained state" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let sequential = two_client_arbiter_sequential(fixture)
  let emitted = @rtl.emit_design(
    @ir.Design::single(
      "TwoClientArbiterSequential",
      two_client_arbiter_proof_view(sequential),
    ),
  )
  let mapping = sequential.original_to_local.iter().to_array()
  mapping[sequential.probe.clock.ordinal()] = Some(
    dependency_generation_mapped(
      sequential.original_to_local,
      sequential.probe.roots[0].node,
    ),
  )
  let invalid : TwoClientArbiterSequential = {
    ..sequential,
    original_to_local: ReadOnlyArray::from_array(mapping),
  }
  try two_client_arbiter_proof_source(fixture, invalid, emitted) catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong arbiter original-clock identity rejection")
  } noraise {
    _ => fail("retained state was accepted as the arbiter proof clock")
  }
}

///|
test "arbiter emission view adds only actual raw response data observation without replacing core" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let sequential = two_client_arbiter_sequential(fixture)
  let core = sequential.hardware
  let before = @ir_codec.serialize(
    @ir.Design::single("TwoClientArbiterSequential", core),
  )
  let view = two_client_arbiter_proof_view(sequential)
  assert_eq(view, two_client_arbiter_proof_view(sequential))
  assert_eq(view.name(), core.name())
  assert_eq(view.nodes(), core.nodes())
  assert_eq(view.domains(), core.domains())
  assert_eq(view.memories(), core.memories())
  assert_eq(view.cdc_primitives(), core.cdc_primitives())
  assert_eq(view.metadata(), core.metadata())
  assert_eq(view.nodes().length(), 108)
  assert_eq(view.outputs().length(), 29)
  assert_eq(core.outputs().length(), 28)
  for index, output in core.outputs() {
    assert_eq(view.outputs()[index], output)
  }
  let original = dependency_generation_input(
    fixture.hardware(),
    "memory_response_data",
    @wire.bits(32),
  )
  assert_eq(original.ordinal(), 14)
  guard sequential.probe.candidates.filter(candidate => {
      candidate.roles.contains("response_data")
    })
    is [candidate] else {
    fail("missing actual response data boundary")
  }
  assert_eq(candidate.original.id(), original)
  let mapped = arbiter_materialization_test_id(
    sequential.original_to_local,
    original,
  )
  assert_eq(mapped.ordinal(), 8)
  assert_eq(
    view.outputs()[28],
    @ir.OutputPort::new("raw_response_data_observation", @wire.bits(32), mapped),
  )
  assert_eq(dependency_generation_node(view, mapped).kind(), Input("cut_n14"))
  // Keep strict all-node emitter rejection intact for the accepted core. The
  // observed boundary adds no nodes, state, cuts, premise or extra conclusion.
  try
    @rtl.emit_design(@ir.Design::single("TwoClientArbiterSequential", core))
  catch {
    @rtl.UnreachableNode(module_name~, node~) => {
      assert_eq(module_name, "TwoClientArbiterSequential")
      assert_eq(node, 8)
    }
    _ => fail("unexpected raw arbiter core emission error")
  } noraise {
    _ => fail("expected strict unused response data rejection")
  }
  let emitted = @rtl.emit_design(
    @ir.Design::single("TwoClientArbiterSequential", view),
  )
  let source = two_client_arbiter_proof_source(fixture, sequential, emitted)
  assert_eq(
    source
    .split(
      ".\{port_identifier(emitted, OutputPort, "raw_response_data_observation")}(lc_raw_response_data_observation)",
    )
    .length() -
    1,
    1,
  )
  assert_eq(source.split("lc_raw_response_data_observation").length() - 1, 2)
  assert_eq(source.split("(* anyseq *)").length() - 1, 15)
  assert_eq(source.split("assume (").length() - 1, 1)
  assert_eq(source.split(": assert (").length() - 1, 8)
  assert_eq(
    @ir_codec.serialize(@ir.Design::single("TwoClientArbiterSequential", core)),
    before,
  )
}
