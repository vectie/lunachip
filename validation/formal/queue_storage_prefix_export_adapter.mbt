///|
fn queue_storage_prefix_logic(signal_type : @ir.SignalType) -> String {
  let width = signal_type.width().bits()
  let signed = if signal_type is SInt(_) { " signed" } else { "" }
  let range = if width == 1 { "" } else { " [\{width - 1}:0]" }
  "logic" + signed + range
}

///|
// Resolve arrays by all three original-to-local manifest identities, never by
// guessing emitted names or using unsupported hierarchical references.
fn queue_storage_prefix_memory_identifiers(
  sequential : QueueStorageSequential,
  emitted : @rtl.EmittedDesign,
) -> ReadOnlyArray[String] raise FormalGateError {
  let names : Array[String] = []
  for lane in sequential.probe.lanes {
    let mapped = queue_storage_sequential_mapped_memory(
      sequential.original_to_local_memory,
      lane.memory.id(),
    )
    guard emitted
      .manifest()
      .mappings()
      .filter(mapping => {
        mapping.kind() is Memory &&
        mapping.module_ordinal() == emitted.manifest().top_module_ordinal() &&
        mapping.local_ordinal() == mapped.ordinal() &&
        mapping.source_name() == lane.memory.name()
      })
      is [mapping] else {
      raise InvalidFormalBundleIdentity(
        "queue storage prefix: exact memory manifest binding",
      )
    }
    names.push(mapping.identifier())
  }
  ReadOnlyArray::from_array(names)
}

///|
// A purpose-specific reversible header adapter. The original body, including
// actual SRAM/read-result declarations and all eight bounds assertions, is
// unchanged. No generic SV parser and no additional hardware observation port.
fn queue_storage_prefix_adapter(
  sequential : QueueStorageSequential,
  emitted : @rtl.EmittedDesign,
  observer : String,
) -> String raise FormalGateError {
  let dut = top_emitted_module(emitted)
  let lines : Array[String] = []
  let declarations = StringBuilder()
  for node in sequential.hardware.nodes() {
    guard node.kind() is Input(name) else { continue }
    let identifier = port_identifier(emitted, InputPort, name)
    let signal_type = queue_storage_prefix_logic(node.signal_type())
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
  for output in sequential.hardware.outputs() {
    let identifier = port_identifier(emitted, OutputPort, output.name())
    let signal_type = queue_storage_prefix_logic(output.signal_type())
    lines.push("output \{signal_type} \{identifier}")
    declarations.write_string("  \{signal_type} \{identifier};\n")
  }
  let ports = StringBuilder()
  for index, line in lines {
    ports.write_string(
      "  \{line}\{if index + 1 == lines.length() { "" } else { "," }}\n",
    )
  }
  let header = "module \{dut.identifier()} (\n" + ports.to_string() + ");\n\n"
  let replacement = "module \{dut.identifier()};\n" +
    declarations.to_string() +
    "\n"
  // Same existing narrowly qualified Boolean-helper adapter; original emitted
  // source remains a separately retained artifact, not overwritten here.
  let (source, _) = dependency_boolean_helpers(
    sequential.hardware,
    dut.source(),
  )
  if source.split(header).count() != 2 ||
    source.split("endmodule\n").count() != 2 ||
    lines.length() != 138 ||
    observer.contains("endmodule") {
    raise InvalidFormalBundleIdentity(
      "queue storage prefix: canonical standalone splice",
    )
  }
  let adapted = source.replace(old=header, new=replacement)
  let inserted = observer + "endmodule\n"
  let result = adapted.replace(old="endmodule\n", new=inserted)
  if result
    .replace(old=inserted, new="endmodule\n")
    .replace(old=replacement, new=header) !=
    source {
    raise InvalidFormalBundleIdentity(
      "queue storage prefix: reversible unchanged body",
    )
  }
  result
}
