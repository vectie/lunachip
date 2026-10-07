///|
test "FIFO prefix export preserves exact original register read write and eight active bounds equations" {
  let exported = queue_storage_prefix_export(
    @flux_tile.queued_concurrent_queue_formal_fixture(),
  )
  let hardware = exported.sequential.hardware
  let source = exported.positive
  let node_name = fn(id : @ir.NodeId) -> String raise {
    queue_storage_export_test_name(exported.emitted, Node, id.ordinal())
  }
  let bounds : Array[String] = []
  let memory_names : Array[String] = []
  for node in hardware.nodes() {
    guard node.kind() is Register(spec) else { continue }
    guard spec.reset() is Some(reset) else {
      fail("missing actual synchronous reset")
    }
    assert_eq(spec.initial(), None)
    assert_eq(spec.enable(), None)
    assert_eq(reset.mode(), Synchronous)
    assert_eq(reset.polarity(), ActiveHigh)
    let equation = "  always_ff @(posedge \{node_name(spec.domain().clock())}) begin\n    \{node_name(node.id())} <= \{node_name(reset.signal())} ? \{node.signal_type().width().bits()}'h\{reset.value().to_string(radix=16)} : (\{node_name(spec.next())});\n  end\n"
    assert_eq(exported.emitted.source().split(equation).count(), 2)
    assert_eq(source.split(equation).count(), 2)
    assert_eq(exported.negative.split(equation).count(), 2)
  }
  for memory in hardware.memories() {
    let ordinal = memory.id().ordinal()
    let cells = queue_storage_export_test_name(
      exported.emitted,
      Memory,
      ordinal,
    )
    memory_names.push(cells)
    assert_true(source.contains("  logic [63:0] \{cells} [0:2];\n"))
    assert_eq(memory.read_write_policy(), ReadOld)
    assert_eq(memory.multi_write_policy(), Reject)
    assert_eq(memory.bounds_policy(), Fault)
    guard memory.read_ports() is [read] && memory.write_ports() is [write] else {
      fail("actual single-port lane lost")
    }
    assert_eq(read.enable_behavior(), HoldLast)
    assert_eq(read.latency(), OneCycle)
    assert_eq(write.mask(), All)
    guard read.enable() is Some(read_enable) &&
      write.enable() is Some(write_enable) else {
      fail("actual lane controls lost")
    }
    let read_address = node_name(read.address())
    let write_address = node_name(write.address())
    let read_range = "(lc_ak\{ordinal}(\{read_address}) && ($unsigned(\{read_address}) < 2'd3))"
    let write_range = "(lc_ak\{ordinal}(\{write_address}) && ($unsigned(\{write_address}) < 2'd3))"
    let read_equation = "    \{node_name(read.result())} <= \{node_name(read_enable)} ? ((\{read_range}) ? (\{cells}[\{read_address}]) : 64'bx) : \{node_name(read.result())};\n"
    let write_equation = "    if (\{write_range}) \{cells}[\{write_address}] <= \{node_name(write_enable)} ? (\{node_name(write.data())}) : \{cells}[\{write_address}];\n"
    for equation in [read_equation, write_equation] {
      assert_eq(exported.emitted.source().split(equation).count(), 2)
      assert_eq(source.split(equation).count(), 2)
      assert_eq(exported.negative.split(equation).count(), 2)
    }
    for
      (role, port, enable, range) in [
        ("read", read.id().ordinal(), node_name(read_enable), read_range),
        ("write", write.id().ordinal(), node_name(write_enable), write_range),
      ] {
      let label = "lc_mem\{ordinal}_\{role}\{port}_bounds"
      let block = "    if (\{enable} !== 1'b0) begin\n      \{label}: assert (\{range} === 1'b1);\n    end\n"
      bounds.push(label)
      assert_eq(exported.emitted.source().split(block).count(), 2)
      assert_eq(source.split(block).count(), 2)
      assert_eq(exported.negative.split(block).count(), 2)
    }
    assert_false(source.contains("\{cells}[0] ="))
    assert_false(source.contains("\{cells}[1] ="))
    assert_false(source.contains("\{cells}[2] ="))
  }
  assert_eq(bounds.length(), 8)
  assert_eq(exported.memory_bounds, ReadOnlyArray::from_array(bounds))
  assert_eq(
    exported.memory_identifiers,
    ReadOnlyArray::from_array(memory_names),
  )
}

///|
test "FIFO prefix watch captures public bits physical slot and ordinal rank without feeding original state" {
  let exported = queue_storage_prefix_export(
    @flux_tile.queued_concurrent_queue_formal_fixture(),
  )
  let observer = queue_storage_export_test_observer(exported, exported.positive)
  let negative_observer = queue_storage_export_test_observer(
    exported,
    exported.negative,
  )
  let sequential = exported.sequential
  let output_name = fn(name : String) -> String raise {
    guard sequential.hardware
      .outputs()
      .map(output => output.name())
      .search(name)
      is Some(index) else {
      fail("missing original output alias")
    }
    queue_storage_export_test_name(exported.emitted, OutputPort, index)
  }
  let pair : Array[String] = []
  let reset : Array[String] = []
  for root in sequential.probe.roots {
    let observed_name = "lc_o_" + root.name
    assert_eq(
      observer
      .split(
        "  assign \{observed_name} = \{output_name("current_" + root.name)};\n",
      )
      .count(),
      2,
    )
    pair.push(observed_name)
    reset.push("(\{observed_name} == 0)")
  }
  for event in sequential.probe.events {
    assert_eq(
      observer
      .split("  assign lc_dut_\{event.name} = \{output_name(event.name)};\n")
      .count(),
      2,
    )
  }
  for cut in sequential.cuts {
    guard cut.roles is [role] else { fail("nonunique cut role") }
    if role == "reset" ||
      role == "descriptor_valid" ||
      role.has_prefix("descriptor_lane_") {
      let mapped_node = queue_storage_test_node(
        sequential.original_to_local,
        cut.node,
      )
      let port = queue_storage_export_test_name(
        exported.emitted,
        InputPort,
        mapped_node.ordinal(),
      )
      assert_eq(observer.split("  assign lc_\{role} = \{port};\n").count(), 2)
    }
  }
  for lane in 0..<4 {
    assert_eq(
      observer
      .split(
        "  assign lc_response_\{lane} = \{output_name("fifo_response_data_" + lane.to_string())};\n",
      )
      .count(),
      2,
    )
    pair.push("lc_response_\{lane}")
    let memory = exported.memory_identifiers[lane]
    for slot in 0..<3 {
      assert_eq(
        observer
        .split("  assign lc_cell_\{lane}_\{slot} = \{memory}[\{slot}];\n")
        .count(),
        2,
      )
      pair.push("lc_cell_\{lane}_\{slot}")
    }
    assert_eq(
      observer
      .split("  assign lc_watched_cell_\{lane} = \{memory}[lc_watch_slot];\n")
      .count(),
      2,
    )
  }
  assert_eq(pair.length(), 44)
  assert_true(
    observer.contains(
      "wire [1332:0] lc_actual_storage_pair = {" + pair.join(", ") + "};",
    ),
  )
  assert_true(
    observer.contains(
      "wire lc_reset_establishment = !lc_previous_rising_reset || (" +
      reset.join(" && "),
    ),
  )
  let fragments : Array[String] = [
    "  (* anyseq *) logic lc_watch_select;\n", "  wire [255:0] lc_public_packet = {lc_descriptor_lane_3,\n    lc_descriptor_lane_2, lc_descriptor_lane_1, lc_descriptor_lane_0};\n",
    "  wire lc_admit = lc_descriptor_valid && lc_dut_descriptor_ready;\n", "  wire lc_take_watch = !lc_reset && lc_admit && !lc_watch_chosen && lc_watch_select;\n",
    "  wire lc_watched_pop = !lc_reset && lc_watch_queued && lc_pop && lc_watch_rank == 0;\n",
    "        lc_saved_packet <= lc_public_packet;\n", "        lc_watch_slot <= lc_o_fifo_write_pointer_0;\n",
    "        lc_watch_rank <= lc_public_count - (lc_pop ? 3'd1 : 3'd0);\n", "      end else if (lc_watch_queued && lc_pop) begin\n        if (lc_watch_rank != 0) lc_watch_rank <= lc_watch_rank - 3'd1;\n        else lc_watch_queued <= 1'b0;\n",
    "      lc_response_due <= lc_watched_pop;\n", "      lc_head_due <= lc_response_due && lc_dut_head_capture;\n",
    "      if (lc_response_due && lc_dut_head_capture) begin\n        lc_capture_seen <= 1'b1;\n        lc_head_held <= 1'b1;\n      end else if (lc_effective_finish) lc_head_held <= 1'b0;\n",
    "  wire lc_count_step_ok = (!lc_pop || lc_public_count != 0)\n    && (!lc_admit || lc_pop || lc_public_count < 3'd3);\n",
    "  wire lc_watch_location = lc_watch_slot < 2'd3 && lc_watch_rank < lc_public_count\n    && lc_watch_slot == lc_wrap3({1'b0, lc_o_fifo_read_pointer_0} + lc_watch_rank);\n",
    "  wire lc_watched_slot_and_cells = !lc_seen_edge || !lc_watch_queued\n    || (lc_watch_location && lc_raw_cells_match);\n",
    "  wire lc_watched_head = !lc_seen_edge || !(lc_head_due || lc_head_held)\n    || lc_raw_head == lc_saved_packet;\n",
    "  wire lc_watched_transfer = lc_seen_edge && !lc_reset && lc_head_due\n    && lc_watch_chosen && lc_response_seen && lc_capture_seen\n    && lc_raw_structure && lc_raw_watch_structure && lc_raw_head == lc_saved_packet;\n",
  ]
  for fragment in fragments {
    assert_eq(observer.split(fragment).count(), 2)
    assert_eq(negative_observer.split(fragment).count(), 2)
  }
  // Uninterpreted 256-bit capture: no decoding, ticket, caller-ID or content
  // predicate selects the watch. Neither saved data nor SRAM read state resets.
  assert_eq(observer.split("lc_saved_packet <=").count(), 2)
  assert_false(observer.contains("lc_saved_packet ="))
  assert_false(observer.contains("lc_saved_packet <= 256'd0"))
  assert_false(observer.contains("lc_entry_id"))
  assert_false(observer.contains("lc_watch_select && lc_raw"))
  for
    flag in [
      "watch_chosen", "watch_queued", "response_due", "head_due", "head_held", "response_seen",
      "capture_seen",
    ] {
    assert_eq(observer.split("      lc_\{flag} <= 1'b0;\n").count(), 2)
  }
  assert_true(
    observer.contains("if (lc_reset) begin\n      lc_public_count <= 3'd0;"),
  )
  assert_true(
    observer.contains(
      "      lc_watch_rank <= 3'd0;\n      lc_watch_slot <= 2'd0;",
    ),
  )
  assert_true(
    observer.contains(
      "wire [255:0] lc_raw_response = {lc_response_3, lc_response_2,\n    lc_response_1, lc_response_0};",
    ),
  )
  assert_true(
    observer.contains(
      "wire [255:0] lc_raw_head = {lc_o_head_lane_3, lc_o_head_lane_2,\n    lc_o_head_lane_1, lc_o_head_lane_0};",
    ),
  )
  assert_true(
    observer.contains(
      "wire lc_raw_cells_match = {lc_watched_cell_3, lc_watched_cell_2,\n    lc_watched_cell_1, lc_watched_cell_0} == lc_saved_packet;",
    ),
  )
  for lane in 0..<4 {
    for
      field in ["occupancy", "read_pointer", "write_pointer", "response_valid"] {
      assert_true(
        observer.contains(
          "(lc_o_fifo_\{field}_\{lane} == lc_o_fifo_\{field}_0)",
        ),
      )
    }
    assert_true(
      observer.contains(
        "(lc_o_fifo_read_pointer_\{lane} < 2'd3 && lc_o_fifo_write_pointer_\{lane} < 2'd3)",
      ),
    )
    assert_true(
      observer.contains(
        "(lc_o_fifo_write_pointer_\{lane} == lc_wrap3({1'b0, lc_o_fifo_read_pointer_\{lane}} + {1'b0, lc_o_fifo_occupancy_\{lane}}))",
      ),
    )
    assert_true(
      observer.contains(
        "(lc_dut_fifo_push_fire_\{lane} == lc_admit && lc_dut_fifo_pop_fire_\{lane} == lc_pop)",
      ),
    )
  }
  let original = "  wire [255:0] lc_checked_response = lc_raw_response;\n"
  let changed = "  wire [255:0] lc_checked_response = (lc_raw_response ^ (lc_genuine_response ? 256'h100000000000000000000000000000000 : 256'd0));\n"
  assert_eq(observer.split(original).count(), 2)
  assert_eq(negative_observer.split(changed).count(), 2)
  assert_eq(
    exported.negative.replace(old=changed, new=original),
    exported.positive,
  )
  assert_true(
    observer.contains(
      "wire lc_genuine_response = lc_seen_edge && !lc_reset && lc_watch_chosen\n    && lc_response_due && lc_o_fifo_response_valid_0 && lc_dut_head_capture\n    && lc_raw_response_match;",
    ),
  )
  assert_eq(observer.split("lc_checked_response").count(), 3)
  assert_true(
    observer.contains(
      "lc_o_head_state == 2'd1 && lc_checked_response == lc_saved_packet",
    ),
  )
  assert_true(
    observer.contains(
      "lc_actual_storage_pair === lc_previous_actual_storage_pair",
    ),
  )
  assert_true(
    observer.contains("lc_observer_pair === lc_previous_observer_pair"),
  )
  assert_true(observer.contains("|| (!lc_previous_clock && lc_clock)"))
  assert_true(
    observer.contains("logic [1332:0] lc_previous_actual_storage_pair;"),
  )
  assert_true(
    observer.contains(
      "wire [272:0] lc_observer_pair = {lc_seen_edge, lc_previous_rising_reset,\n    lc_public_count, lc_watch_chosen,",
    ),
  )
  assert_true(observer.contains("logic [272:0] lc_previous_observer_pair;"))
  assert_true(
    observer.contains(
      "lc_previous_actual_storage_pair <= lc_actual_storage_pair;",
    ),
  )
  assert_true(
    observer.contains("lc_previous_observer_pair <= lc_observer_pair;"),
  )
}

///|
test "FIFO prefix properties have direct top labels seven conclusions one cover and startup only assumption" {
  let exported = queue_storage_prefix_export(
    @flux_tile.queued_concurrent_queue_formal_fixture(),
  )
  let properties = exported.properties.property_manifest().properties()
  let definitions : Array[(String, @formal_core.FormalPropertyKind)] = [
    ("startup_reset", Assumption),
    ("fifo_structure", Assertion),
    ("fifo_public_count", Assertion),
    ("watched_slot_and_cells", Assertion),
    ("watched_response", Assertion),
    ("watched_head", Assertion),
    ("watch_structure", Assertion),
    ("reset_establishment", Assertion),
    ("watched_transfer", Cover),
  ]
  assert_eq(properties.length(), definitions.length())
  assert_eq(exported.properties.properties().length(), definitions.length())
  guard exported.emitted
    .modules()
    .filter(emitted_module => {
      emitted_module.module_ordinal() ==
      exported.emitted.manifest().top_module_ordinal()
    })
    is [top] else {
    fail("missing exact emitted top")
  }
  assert_eq(exported.top_identifier, top.identifier())
  assert_true(
    exported.positive.contains("module \{exported.top_identifier};\n"),
  )
  assert_eq(exported.positive.split(": assume (").count(), 2)
  assert_eq(exported.positive.split(": assert (").count(), 17)
  assert_eq(exported.positive.split(": cover (").count(), 2)
  assert_eq(exported.positive.split(exported.properties.source()).count(), 2)
  assert_eq(exported.negative.split(exported.properties.source()).count(), 2)
  for index, (name, kind) in definitions {
    let property = properties[index]
    assert_eq(property.id().ordinal(), index)
    assert_eq(property.name(), name)
    assert_eq(property.kind(), kind)
    assert_eq(property.disable(), NeverDisabled)
    assert_eq(
      property.domain().clock(),
      @property.PropertySignal::named(exported.top_identifier, "clock"),
    )
    assert_eq(
      property.predicate(),
      @property.PropertySignal::named(exported.top_identifier, name),
    )
    let encoded = @utf8.encode(name)
      .iter()
      .map(byte => byte.to_int().to_string(radix=16).pad_start(2, '0'))
      .join("")
    assert_eq(property.stable_name(), "lc_p\{index}_b\{encoded}")
    let operation = match kind {
      Assumption => "assume"
      Assertion => "assert"
      Cover => "cover"
    }
    let block = "  always @(posedge lc_clock) begin\n    \{property.stable_name()}: \{operation} ((lc_\{name}) === 1'b1);\n  end\n"
    assert_eq(exported.positive.split(block).count(), 2)
    assert_eq(exported.negative.split(block).count(), 2)
    assert_false(property.stable_name().contains("/"))
  }
  let observer = queue_storage_export_test_observer(exported, exported.positive)
  assert_true(
    observer.contains("wire lc_startup_reset = lc_seen_edge || lc_reset;"),
  )
  assert_true(observer.contains("lc_seen_edge <= 1'b1;"))
  assert_eq(observer.split("lc_seen_edge <=").count(), 2)
  assert_false(observer.contains("lc_reset =="))
  assert_false(observer.contains("fairness"))
  assert_false(observer.contains("assume (lc_raw"))
  assert_true(
    observer.contains(
      "wire lc_fifo_structure = !lc_seen_edge || lc_raw_structure;",
    ),
  )
  assert_true(
    observer.contains(
      "wire lc_watch_structure = !lc_seen_edge || lc_raw_watch_structure;",
    ),
  )
  assert_eq(observer.split("lc_storage_nonrising_hold: assert (").count(), 2)
}
