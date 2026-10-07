///|
fn fetched_transport_proof_bindings(
  sequential : FetchedTransportSequential,
  emitted : @rtl.EmittedDesign,
) -> String raise {
  fetched_transport_proof_require(sequential)
  let view = fetched_transport_proof_view(sequential)
  if emitted !=
    @rtl.emit_design(@ir.Design::single("FetchedTransportProofView", view)) {
    raise InvalidFormalBundleIdentity("fetched proof: exact emission required")
  }
  let out = StringBuilder()
  out.write_string(
    "`default_nettype none\nmodule lc_fetched_transport_bridge;\n  logic lc_clock = 1'b0;\n  always @($global_clock) lc_clock <= ~lc_clock;\n",
  )
  let connections : Array[String] = [
    "    .\{port_identifier(emitted,InputPort,"clock")}(lc_clock)",
  ]
  for cut in sequential.probe.candidates {
    let name = "cut_n\{cut.original.id().ordinal()}"
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      cut.original.id(),
    )
    guard view.node(mapped) is Some(node) &&
      node.kind() == Input(name) &&
      node.signal_type() == cut.original.signal_type() else {
      raise InvalidFormalBundleIdentity("fetched proof: exact raw interface")
    }
    out.write_string(
      "  (* anyseq *) logic \{toggle_formal_width_range(node.signal_type().width().bits())}\{name};\n",
    )
    connections.push("    .\{port_identifier(emitted,InputPort,name)}(\{name})")
  }
  for output in view.outputs() {
    let name = output.name()
    let variable = if name.has_prefix("current_") {
      "lc_o_" + name[8:].to_owned()
    } else if name.has_prefix("proof_") {
      "lc_v_" + name[6:].to_owned()
    } else {
      "lc_dut_" + name
    }
    out.write_string(
      "  wire \{toggle_formal_width_range(output.signal_type().width().bits())}\{variable};\n",
    )
    connections.push(
      "    .\{port_identifier(emitted,OutputPort,name)}(\{variable})",
    )
  }
  out.write_string(
    "  \{top_emitted_module(emitted).identifier()} lc_dut(\n\{connections.join(",\n")}\n  );\n",
  )
  for boundary in sequential.probe.boundaries {
    let original = boundary.original
    let value = match original.kind() {
      Constant(value) => "\{original.signal_type().width().bits()}'d\{value}"
      _ => "cut_n\{original.id().ordinal()}"
    }
    for role in boundary.roles {
      out.write_string(
        "  wire \{toggle_formal_width_range(original.signal_type().width().bits())}lc_i_\{role} = \{value};\n",
      )
    }
  }
  let pair = sequential.probe.roots
    .map(root => "lc_o_" + root.name)
    .iter()
    .to_array()
    .join(", ")
  let zero = sequential.probe.roots
    .map(root => "(lc_o_\{root.name} == 0)")
    .iter()
    .to_array()
    .join(" && ")
  out.write_string(
    "  wire lc_reset = lc_i_reset;\n  wire [665:0] lc_actual_pair = {\{pair}};\n  wire lc_all_reset_zero = \{zero};\n",
  )
  // Constant reader fields remain bound to the original source contract.
  // Client record response tag/data aliases are source-reviewed, not separate
  // response-data stability or synthetic passthrough theorems.
  out.write_string(
    "  wire lc_i_reader_valid = lc_v_reader_valid;\n  wire lc_i_reader_response_ready = lc_v_reader_ready;\n  wire [31:0] lc_i_reader_address = lc_v_reader_address;\n  wire [31:0] lc_i_reader_tag = lc_o_reader_tag;\n  wire lc_i_reader_write = 1'b0;\n  wire [2:0] lc_i_reader_bytes = 3'd1;\n  wire [3:0] lc_i_reader_mask = 4'd1;\n  wire [31:0] lc_i_reader_data = 32'd0;\n",
  )
  out.to_string()
}
