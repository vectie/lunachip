///|
// Independently rebuild the entire canonical module header and require every
// byte of its Boolean-qualified original body before any observer insertion.
fn queue_packet_proof_test_observer(
  exported : QueuePacketCompositionExport,
  source : String,
) -> String raise {
  guard exported.emitted
    .modules()
    .filter(item => {
      item.module_ordinal() == exported.emitted.manifest().top_module_ordinal()
    })
    is [dut] else {
    fail("nonunique emitted top")
  }
  let lines : Array[String] = []
  let declarations = StringBuilder()
  for node in exported.sequential.hardware.nodes() {
    guard node.kind() is Input(name) else { continue }
    let identifier = queue_storage_export_test_name(
      exported.emitted,
      InputPort,
      node.id().ordinal(),
    )
    let signal_type = queue_storage_export_test_type(node.signal_type())
    lines.push("input \{signal_type} \{identifier}")
    if name == "clock" {
      declarations.write_string(
        "  logic \{identifier} = 1'b0;\n  always @($global_clock) \{identifier} <= ~\{identifier};\n  wire lc_clock = \{identifier};\n",
      )
    } else {
      declarations.write_string(
        "  (* anyseq *) \{signal_type} \{identifier};\n",
      )
    }
  }
  for index, output in exported.sequential.hardware.outputs() {
    let identifier = queue_storage_export_test_name(
      exported.emitted,
      OutputPort,
      index,
    )
    let signal_type = queue_storage_export_test_type(output.signal_type())
    lines.push("output \{signal_type} \{identifier}")
    declarations.write_string("  \{signal_type} \{identifier};\n")
  }
  let ports = StringBuilder()
  for index, line in lines {
    let comma = if index + 1 == lines.length() { "" } else { "," }
    ports.write_string("  \{line}\{comma}\n")
  }
  let header = "module \{dut.identifier()} (\n" + ports.to_string() + ");\n\n"
  let replacement = "module \{dut.identifier()};\n" +
    declarations.to_string() +
    "\n"
  let boolean = queue_storage_export_test_boolean(
    exported.sequential.hardware,
    dut.source(),
  )
  assert_eq(exported.boolean_source, boolean)
  guard boolean.split(header).to_array() is [preamble, tail] else {
    fail("complete original header drift")
  }
  guard tail.split("endmodule\n").to_array() is [body, suffix] else {
    fail("original body ending drift")
  }
  let prefix = preamble.to_owned() + replacement + body.to_owned()
  guard source.split(prefix).to_array() is ["", observed_tail] else {
    fail("original production body changed")
  }
  guard observed_tail.split("endmodule\n").to_array()
    is [observer, observed_suffix] else {
    fail("observer boundary drift")
  }
  assert_eq(observed_suffix, suffix)
  assert_eq(
    source,
    prefix + observer.to_owned() + "endmodule\n" + suffix.to_owned(),
  )
  observer.to_owned()
}

///|
test "packet composition proof inputs preserve entire production body original watch and twelve original properties" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let before = @ir_codec.serialize(
    @ir.Design::single(
      "QueuedConcurrentQueueConservationPilot",
      fixture.hardware(),
    ),
  )
  let exported = queue_packet_composition_export(fixture)
  let observer = queue_packet_proof_test_observer(exported, exported.positive)
  let negative_observer = queue_packet_proof_test_observer(
    exported,
    exported.negative,
  )
  assert_eq(
    sha256_hex(before),
    "35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc",
  )
  assert_eq(
    exported.sequential.inventory_digest,
    "01275b9792d9f2bd9bbb9b026a8de861931b0821dc9634f4439fa9f1c391e7b2",
  )
  assert_eq(
    before,
    @ir_codec.serialize(
      @ir.Design::single(
        "QueuedConcurrentQueueConservationPilot",
        fixture.hardware(),
      ),
    ),
  )
  assert_eq(exported.sequential.cuts.length(), 101)
  assert_eq(exported.positive.split("(* anyseq *)").count(), 103)
  for cut in exported.sequential.cuts {
    let mapped = queue_storage_test_node(
      exported.sequential.original_to_local,
      cut.node,
    )
    let identifier = queue_storage_export_test_name(
      exported.emitted,
      InputPort,
      mapped.ordinal(),
    )
    let declaration = "  (* anyseq *) \{queue_storage_export_test_type(cut.signal_type)} \{identifier};\n"
    assert_eq(exported.positive.split(declaration).count(), 2)
    assert_eq(exported.negative.split(declaration).count(), 2)
  }
  let output_name = fn(name : String) -> String raise {
    guard exported.sequential.hardware
      .outputs()
      .map(output => output.name())
      .search(name)
      is Some(index) else {
      fail("missing original output binding")
    }
    queue_storage_export_test_name(exported.emitted, OutputPort, index)
  }
  assert_eq(exported.sequential.probe.observations.length(), 115)
  for observation in exported.sequential.probe.observations {
    let binding = "  assign lc_o_\{observation.name} = \{output_name(observation.name)};\n"
    assert_eq(observer.split(binding).count(), 2)
    assert_eq(negative_observer.split(binding).count(), 2)
  }
  for (role, width, input) in dependency_public_ports() {
    if role == "clock" {
      continue
    }
    let identifier = if input {
      guard exported.sequential.cuts.filter(cut => cut.roles == [role]) is [cut] else {
        fail("lost original public pin")
      }
      assert_eq(cut.signal_type, queue_public_port_type(role, width))
      let mapped = queue_storage_test_node(
        exported.sequential.original_to_local,
        cut.node,
      )
      queue_storage_export_test_name(
        exported.emitted,
        InputPort,
        mapped.ordinal(),
      )
    } else {
      output_name("public_" + role)
    }
    assert_eq(
      observer.split("  assign lc_\{role} = \{identifier};\n").count(),
      2,
    )
  }
  for
    source in [
      queue_monitor_source(Conservation),
      queue_retirement_records_source(false),
      queue_packet_provenance_source(false),
    ] {
    assert_eq(observer.split(source).count(), 2)
  }
  assert_eq(
    negative_observer.split(queue_packet_provenance_source(true)).count(),
    2,
  )
  let checked_positive = "  wire [255:0] lc_pp_checked_response_packet = lc_pp_saved_packet;\n"
  let checked_negative = "  wire [255:0] lc_pp_checked_response_packet = (lc_pp_saved_packet ^ (lc_pp_genuine_response ? (256'd1 << 128) : 256'd0));\n"
  assert_eq(
    exported.negative.replace(old=checked_negative, new=checked_positive),
    exported.positive,
  )
  assert_eq(observer.split("(* anyseq *) logic lc_pp_select;").count(), 2)
  assert_false(observer.contains("lc_watch_select"))
  let (original, legal, assertions, covers) = queue_property_export(
    PacketProvenance,
  )
  let expected_properties = original
    .properties()
    .filter(property => {
      !(property.kind() is Cover) ||
      property.source_name() == "packet_provenance_transfer_cover"
    })
  assert_eq(
    exported.properties.properties(),
    ReadOnlyArray::from_array(expected_properties),
  )
  let expected_manifest = original
    .property_manifest()
    .properties()
    .filter(property => {
      !(property.kind() is Cover) ||
      property.name() == "packet_provenance_transfer_cover"
    })
  assert_eq(
    exported.properties.property_manifest().properties(),
    ReadOnlyArray::from_array(expected_manifest),
  )
  assert_eq(legal.length(), 4)
  assert_eq(assertions.length(), 7)
  assert_eq(covers.length(), 3)
  let mut kept = 0
  let mut selected_source = original.source()
  for property in original.properties() {
    let operation = match property.kind() {
      Assumption => "assume"
      Assertion => "assert"
      Cover => "cover"
    }
    let block = "  always @(posedge lc_clock) begin\n    \{property.stable_name()}: \{operation} ((lc_\{property.source_name()}) === 1'b1);\n  end\n"
    assert_eq(original.source().split(block).count(), 2)
    if property.kind() is Cover &&
      property.source_name() != "packet_provenance_transfer_cover" {
      selected_source = selected_source.replace(old=block, new="")
      assert_false(observer.contains(block))
      assert_false(negative_observer.contains(block))
    } else {
      kept += 1
      assert_eq(observer.split(block).count(), 2)
      assert_eq(negative_observer.split(block).count(), 2)
    }
  }
  assert_eq(kept, 12)
  assert_eq(exported.properties.source(), selected_source)
  assert_eq(observer.split(": assume").count(), 5)
  // Extract the host bytes independently from an ordinary original DUT harness.
  let ordinary = @rtl.emit_design(
    @ir.Design::single(
      "QueuedConcurrentQueueConservationPilot",
      fixture.hardware(),
    ),
  )
  let original_harness = queue_harness(
    PacketProvenance,
    queue_formal_dut(fixture, ordinary),
    original.source(),
  )
  guard original_harness.split("  logic lc_seen_edge = 1'b0;\n").to_array()
    is [_, original_tail] else {
    fail("original host marker")
  }
  guard original_tail.split(queue_monitor_source(Conservation)).to_array()
    is [host_tail, _] else {
    fail("original host ending")
  }
  assert_eq(
    observer
    .split("  logic lc_seen_edge = 1'b0;\n" + host_tail.to_owned())
    .count(),
    2,
  )
  assert_true(
    observer.contains(
      "wire [65:0] lc_response_payload = {lc_memory_response_tag,",
    ),
  )
}

///|
test "packet proof strengthening uses same watch actual slot raw read head and ordinal record without new premises" {
  let exported = queue_packet_composition_export(
    @flux_tile.queued_concurrent_queue_formal_fixture(),
  )
  let observer = queue_packet_proof_test_observer(exported, exported.positive)
  let negative_observer = queue_packet_proof_test_observer(
    exported,
    exported.negative,
  )
  let strengthening = queue_packet_composition_strengthening_source(
    exported.sequential,
    exported.emitted,
  )
  assert_eq(observer.split(strengthening).count(), 2)
  assert_eq(negative_observer.split(strengthening).count(), 2)
  assert_false(strengthening.contains("assume"))
  assert_false(strengthening.contains("anyseq"))
  assert_false(strengthening.contains("lc_pp_failed"))
  assert_false(strengthening.contains("lc_pp_checked_response_packet"))
  assert_eq(strengthening.split("logic ").count(), 2)
  assert_true(
    strengthening.contains(
      "else if (lc_pp_watch && lc_pp_counts_ok)\n      lc_pp_saved_fifo_slot <= lc_s_fifo_write_pointer_0;",
    ),
  )
  assert_true(
    strengthening.contains("wire lc_pp_queued_relation = lc_pp_stage != 3'd1"),
  )
  assert_true(
    strengthening.contains("wire lc_pp_response_relation = lc_pp_stage != 3'd2"),
  )
  assert_true(
    strengthening.contains("wire lc_pp_head_relation = lc_pp_stage != 3'd3"),
  )
  assert_true(
    strengthening.contains("wire lc_pp_record_relation = lc_pp_stage != 3'd4"),
  )
  let checked_history =
    #|  wire lc_pp_history_relation = lc_pp_stage <= 3'd5
    #|    && (!lc_pp_active || lc_pp_taken)
    #|    && (lc_pp_stage != 3'd3 || lc_pp_response_seen)
    #|    && (lc_pp_stage != 3'd4 || (lc_pp_response_seen
    #|      && lc_pp_capture_seen && lc_pp_reservation_seen));
    #|
  assert_eq(strengthening.split(checked_history).count(), 2)
  assert_true(
    strengthening.contains(
      "|| (lc_pp_history_relation && lc_pp_fifo_structure && lc_pp_queued_relation",
    ),
  )
  // The first stage3 PRE legitimately has capture_seen == 0. Bind this check
  // to the original stage2 update rather than inventing a stronger history.
  let response_history =
    #|      if (lc_pp_stage == 3'd2 && lc_pp_genuine_response) begin
    #|        lc_pp_response_seen <= 1'b1;
    #|        lc_pp_head_owned <= 1'b1;
    #|        lc_pp_stage <= 3'd3;
    #|      end
    #|
  assert_eq(
    queue_packet_provenance_source(false).split(response_history).count(),
    2,
  )
  assert_false(response_history.contains("lc_pp_capture_seen"))
  assert_true(
    strengthening.contains(
      "lc_pp_saved_ticket == lc_o_next_ticket - lc_pp_record_distance",
    ),
  )
  assert_true(
    strengthening.contains("lc_pp_entry_id == lc_pp_saved_packet[63:32]"),
  )
  assert_true(strengthening.contains("default: lc_pp_wrap3 = value;"))
  assert_true(
    strengthening.contains(
      "{1'd0, lc_pp_retire_older} < lc_o_retirement_occupancy",
    ),
  )
  for lane in exported.sequential.probe.lanes {
    let mapped = queue_storage_test_node(
      exported.sequential.original_to_local,
      lane.read_pointer.node,
    )
    guard exported.sequential.hardware.nodes()[mapped.ordinal()].kind()
      is Register(_) else {
      fail("FIFO pointer became cut")
    }
    let memory = queue_storage_export_test_name(
      exported.emitted,
      Memory,
      lane.lane,
    )
    assert_eq(
      strengthening
      .split(
        "wire [63:0] lc_pp_saved_cell_\{lane.lane} = \{memory}[lc_pp_saved_fifo_slot];",
      )
      .count(),
      2,
    )
  }
  assert_eq(exported.strengthening_assertions, ["lc_packet_strengthening"])
}

///|
test "packet proof inputs retain every original cell read state register and all eight bounds without SRAM initialization" {
  let exported = queue_packet_composition_export(
    @flux_tile.queued_concurrent_queue_formal_fixture(),
  )
  let observer = queue_packet_proof_test_observer(exported, exported.positive)
  let output_name = fn(name : String) -> String raise {
    guard exported.sequential.hardware
      .outputs()
      .map(output => output.name())
      .search(name)
      is Some(index) else {
      fail("missing original output")
    }
    queue_storage_export_test_name(exported.emitted, OutputPort, index)
  }
  let pair : Array[String] = []
  let mut bits = 0
  for root in exported.sequential.probe.roots {
    pair.push(output_name("current_" + root.name))
    bits += root.signal_type.width().bits()
  }
  assert_eq(bits, 876)
  let names : Array[String] = []
  let bounds : Array[String] = []
  for lane in exported.sequential.probe.lanes {
    let memory = queue_storage_export_test_name(
      exported.emitted,
      Memory,
      lane.lane,
    )
    names.push(memory)
    pair.push(output_name("fifo_response_data_\{lane.lane}"))
    bits += 64
    assert_eq(lane.memory.read_write_policy(), ReadOld)
    assert_eq(lane.read.enable_behavior(), HoldLast)
    assert_eq(lane.read.latency(), OneCycle)
    assert_eq(lane.write.mask(), All)
    for slot in 0..<3 {
      pair.push("\{memory}[\{slot}]")
      bits += 64
      assert_false(exported.positive.contains("\{memory}[\{slot}] ="))
    }
    assert_true(exported.positive.contains("  logic [63:0] \{memory} [0:2];\n"))
    for operation in ["read0", "write0"] {
      let label = "lc_mem\{lane.lane}_\{operation}_bounds"
      bounds.push(label)
      assert_eq(exported.positive.split(label + ": assert").count(), 2)
      assert_eq(exported.negative.split(label + ": assert").count(), 2)
    }
  }
  assert_eq(bits, 1900)
  assert_eq(
    observer
    .split("  wire [1899:0] lc_packet_actual_pair = {\{pair.join(", ")}};\n")
    .count(),
    2,
  )
  assert_eq(exported.memory_identifiers, ReadOnlyArray::from_array(names))
  assert_eq(exported.memory_bounds, ReadOnlyArray::from_array(bounds))
  assert_eq(exported.global_assertions, ["lc_packet_nonrising_hold"])
  assert_true(observer.contains("(!lc_packet_previous_clock && lc_clock)"))
  assert_true(
    observer.contains("(lc_packet_actual_pair === lc_packet_previous_pair)"),
  )
  assert_true(observer.contains("logic [1899:0] lc_packet_previous_pair;"))
  assert_false(observer.contains("logic [1899:0] lc_packet_previous_pair ="))
  assert_false(exported.positive.contains("lc_dut."))
}
