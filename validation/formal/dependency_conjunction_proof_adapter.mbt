///|
// Header-only standalone adaptation, reversible byte-for-byte. No original
// register, cell, read-result, equation, memory policy or bound is rewritten.
fn dependency_conjunction_proof_adapter(
  sequential : DependencyConjunctionSequential,
  emitted : @rtl.EmittedDesign,
  observer : String,
) -> String raise {
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
    let comma = if index + 1 == lines.length() { "" } else { "," }
    ports.write_string("  \{line}\{comma}\n")
  }
  let header = "module \{dut.identifier()} (\n" + ports.to_string() + ");\n\n"
  let replacement = "module \{dut.identifier()};\n" +
    declarations.to_string() +
    "\n"
  let (source, _) = dependency_boolean_helpers(
    sequential.hardware,
    dut.source(),
  )
  if source.split(header).count() != 2 ||
    source.split("endmodule\n").count() != 2 ||
    observer.contains("endmodule") {
    raise InvalidFormalBundleIdentity(
      "dependency proof inputs: exact standalone splice",
    )
  }
  let inserted = observer + "endmodule\n"
  let result = source
    .replace(old=header, new=replacement)
    .replace(old="endmodule\n", new=inserted)
  if result
    .replace(old=inserted, new="endmodule\n")
    .replace(old=replacement, new=header) !=
    source {
    raise InvalidFormalBundleIdentity(
      "dependency proof inputs: reversible unchanged original body",
    )
  }
  result
}
