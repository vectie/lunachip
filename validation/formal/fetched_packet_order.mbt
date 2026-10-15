///|
// Bind the original address and registered read-result nodes, not synthetic
// read ports. All names come from the canonical emitter manifest.
fn fetched_packet_node_name(
  emitted : @rtl.EmittedDesign,
  id : @ir.NodeId,
) -> String raise {
  guard emitted
    .manifest()
    .mappings()
    .filter(mapping => {
      mapping.kind() is Node &&
      mapping.module_ordinal() == emitted.manifest().top_module_ordinal() &&
      mapping.local_ordinal() == id.ordinal()
    })
    is [mapping] else {
    raise InvalidFormalBundleIdentity("fetched packet: exact node name")
  }
  mapping.identifier()
}

///|
fn fetched_packet_order_observer(
  source : @ir.Module,
  emitted : @rtl.EmittedDesign,
) -> String raise {
  let out = StringBuilder()
  for (name, port) in [("clock", "clock"), ("reset", "reset")] {
    out.write_string(
      "  wire lc_fp_\{name} = \{port_identifier(emitted, InputPort, port)};\n",
    )
  }
  for
    (name, port, width) in [
      ("push", "reader_packet_accept", 1),
      ("pop", "composition_queue_head_pop", 1),
      ("capture", "composition_queue_head_capture", 1),
      ("reserve", "composition_queue_head_reserve", 1),
      ("finish", "composition_queue_head_finish", 1),
      ("head_state", "composition_queue_head_state", 2),
    ] {
    out.write_string(
      "  wire \{toggle_formal_width_range(width)}lc_fp_\{name} = \{port_identifier(emitted, OutputPort, port)};\n",
    )
  }
  for lane in 0..<4 {
    guard source
      .memories()
      .filter(memory => memory.name() == "descriptor_lane_\{lane}.storage")
      is [memory] &&
      memory.depth().elements() == 2 &&
      memory.element_type() == @wire.bits(64) &&
      memory.read_write_policy() is ReadOld &&
      memory.multi_write_policy() is Reject &&
      memory.bounds_policy() is Fault &&
      memory.read_ports() is [read] &&
      read.latency() is OneCycle &&
      read.enable_behavior() is HoldLast &&
      read.enable() is Some(read_fire) &&
      memory.write_ports() is [write] &&
      write.enable() is Some(write_fire) &&
      write.mask() is All &&
      dependency_generation_node(source, read.address()).signal_type() ==
      @wire.uint(1) &&
      dependency_generation_node(source, write.address()).signal_type() ==
      @wire.uint(1) else {
      raise InvalidFormalBundleIdentity(
        "fetched packet: exact q2 port policies",
      )
    }
    guard emitted
      .manifest()
      .mappings()
      .filter(mapping => {
        mapping.kind() is Memory &&
        mapping.module_ordinal() == emitted.manifest().top_module_ordinal() &&
        mapping.local_ordinal() == memory.id().ordinal() &&
        mapping.source_name() == memory.name()
      })
      is [mapping] else {
      raise InvalidFormalBundleIdentity("fetched packet: exact original array")
    }
    for
      (name, id, width) in [
        ("read_pointer", read.address(), 1),
        ("write_pointer", write.address(), 1),
        ("read_fire", read_fire, 1),
        ("write_fire", write_fire, 1),
        ("response", read.result(), 64),
        ("input", write.data(), 64),
      ] {
      out.write_string(
        "  wire \{toggle_formal_width_range(width)}lc_fp_\{name}_\{lane} = \{fetched_packet_node_name(emitted, id)};\n",
      )
    }
    for
      (name, width) in [
        ("head_lane", 64),
        ("fifo_occupancy", 2),
        ("fifo_response_valid", 1),
      ] {
      out.write_string(
        "  wire \{toggle_formal_width_range(width)}lc_fp_\{name}_\{lane} = \{port_identifier(emitted, OutputPort, "composition_queue_" + name + "_" + lane.to_string())};\n",
      )
    }
    for slot in 0..<2 {
      out.write_string(
        "  wire [63:0] lc_fp_cell_\{slot}_\{lane} = \{mapping.identifier()}[\{slot}];\n",
      )
    }
  }
  for name in ["input", "response", "head_lane", "cell_0", "cell_1"] {
    out.write_string(
      "  wire [255:0] lc_fp_\{name} = {lc_fp_\{name}_3, lc_fp_\{name}_2, lc_fp_\{name}_1, lc_fp_\{name}_0};\n",
    )
  }
  out.write_string(fetched_packet_order_history())
  out.to_string()
}

///|
// A reversible suffix insertion leaves the complete canonical DUT body,
// header, memory cells, address expressions and read states byte-identical.
fn fetched_packet_order_insert(
  source : String,
  observer : String,
) -> String raise {
  guard source.split("endmodule\n").count() == 2 &&
    !observer.contains("endmodule") else {
    raise InvalidFormalBundleIdentity("fetched packet: unique observer splice")
  }
  let inserted = observer + "endmodule\n"
  let result = source.replace(old="endmodule\n", new=inserted)
  guard result.replace(old=inserted, new="endmodule\n") == source else {
    raise InvalidFormalBundleIdentity("fetched packet: reversible original RTL")
  }
  result
}
