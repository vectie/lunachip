///|
let direct8_progress_supported_id : String = direct8_progress_id +
  "-fifo-support"

///|
// Strengthen induction with conclusions about the original four depth3 FIFO
// pointers, including idle cycles. Conditional access bounds alone cannot rule
// out an arbitrary induction-start pointer3 that remains idle until the last
// step. Resolve actual memory address registers through IR and emitter names;
// never guess node ordinals, replace state, constrain inputs or initialize RAM.
fn direct8_progress_fifo_support(
  hardware : @ir.Module,
  emitted : @rtl.EmittedDesign,
) -> String raise {
  let out = StringBuilder()
  let clock = port_identifier(emitted, InputPort, "clock")
  let reset = port_identifier(emitted, InputPort, "reset")
  let manifest = emitted.manifest()
  out.write_string("  // BEGIN direct8 FIFO induction conclusions only\n")
  out.write_string("  always @(posedge \{clock}) if (!\{reset}) begin\n")
  for lane in 0..<4 {
    guard hardware
      .memories()
      .filter(memory => memory.name() == "descriptor_lane_\{lane}.storage")
      is [memory] &&
      memory.depth().elements() == 3 &&
      memory.read_ports() is [read] &&
      memory.write_ports() is [write] else {
      fail("original depth3 FIFO memory/port identity required")
    }
    for
      (role, address) in [("read", read.address()), ("write", write.address())] {
      guard hardware.node(address) is Some(node) &&
        node.kind() is Register(spec) &&
        node.signal_type() == @wire.uint(2) &&
        spec.reset() is Some(reset_spec) else {
        fail("original two-bit resettable FIFO pointer required")
      }
      assert_eq(reset_spec.value(), 0UL)
      assert_eq(reset_spec.mode(), Synchronous)
      assert_eq(reset_spec.polarity(), ActiveHigh)
      assert_eq(spec.domain(), memory.domain())
      assert_eq(spec.initial(), None)
      guard hardware.node(reset_spec.signal()) is Some(reset_node) &&
        reset_node.kind() is Input("reset") else {
        fail("original public FIFO reset required")
      }
      guard manifest
        .mappings()
        .filter(mapping => {
          mapping.kind() is Node &&
          mapping.module_ordinal() == manifest.top_module_ordinal() &&
          mapping.local_ordinal() == address.ordinal()
        })
        is [mapping] else {
        fail("unique emitted original FIFO address node required")
      }
      out.write_string(
        "    lc_d8p_fifo_\{lane}_\{role}_range: assert ($unsigned(\{mapping.identifier()}) < 2'd3);\n",
      )
    }
  }
  out.write_string("  end\n  // END direct8 FIFO induction conclusions only\n")
  out.to_string()
}

///|
fn direct8_progress_with_fifo_support(
  hardware : @ir.Module,
  emitted : @rtl.EmittedDesign,
  original : QueueFormalDut,
) -> QueueFormalDut raise {
  let support = direct8_progress_fifo_support(hardware, emitted)
  let ending = "endmodule\n"
  assert_eq(original.source.split(ending).count(), 2)
  let source = original.source.replace(old=ending, new=support + ending)
  // A mechanically reversible assertion-only overlay. Production RTL, all
  // original equations/bounds and comparator bodies remain byte-for-byte.
  assert_eq(source.replace(old=support, new=""), original.source)
  {
    identifier: original.identifier,
    filename: original.filename,
    source,
    production_filename: original.production_filename,
    production_source: original.production_source,
    ports: original.ports,
    observation_ports: original.observation_ports,
  }
}
