///|
// Observation-only whole fetched view. No projected state or free cut remains.
fn fetched_safety_view(
  sequential : FetchedTransportSequential,
) -> @ir.Module raise {
  fetched_transport_proof_require(sequential)
  let original = sequential.probe.source
  let outputs = original.outputs().iter().to_array()
  for output in fetched_transport_proof_view(sequential).outputs() {
    let originals = original
      .nodes()
      .filter(node => {
        sequential.original_to_local[node.id().ordinal()] ==
        Some(output.driver())
      })
    guard originals is [node] &&
      node.signal_type() == output.signal_type() &&
      !outputs.any(old => old.name() == output.name()) else {
      raise InvalidFormalBundleIdentity(
        "fetched safety: exact inverse output mapping",
      )
    }
    outputs.push(
      @ir.OutputPort::new(output.name(), output.signal_type(), node.id()),
    )
  }
  for lane in 0..<4 {
    guard original
      .memories()
      .filter(memory => memory.name() == "descriptor_lane_\{lane}.storage")
      is [memory] &&
      memory.depth().elements() == 2 &&
      memory.element_type() == @wire.bits(64) &&
      memory.bounds_policy() is Fault &&
      memory.read_write_policy() is ReadOld &&
      memory.write_ports() is [write] &&
      write.enable() is Some(fire) else {
      raise InvalidFormalBundleIdentity(
        "fetched safety: actual q2 descriptor memory",
      )
    }
    for (suffix, id) in [("fire", fire), ("data", write.data())] {
      let node = dependency_generation_node(original, id)
      outputs.push(
        @ir.OutputPort::new(
          "composition_lane_\{lane}_\{suffix}",
          node.signal_type(),
          id,
        ),
      )
    }
  }
  for shape_alias in fetched_safety_shape_roots(original) {
    outputs.push(
      @ir.OutputPort::new(
        shape_alias.name,
        shape_alias.signal_type,
        shape_alias.node,
      ),
    )
  }
  @ir.Module::checked_with_metadata(
    original.name(),
    original.domains(),
    original.nodes(),
    original.memories(),
    outputs,
    original.metadata(),
  )
}

///|
fn fetched_safety_variable(name : String) -> String {
  if name.has_prefix("current_") {
    "lc_o_" + name[8:].to_owned()
  } else if name.has_prefix("proof_") {
    "lc_v_" + name[6:].to_owned()
  } else {
    "lc_dut_" + name
  }
}

///|
// Retain all original supported monitor bytes after its binding prefix. Only
// replace the old DUT/cut binding prefix with original whole-graph connections.
fn fetched_safety_bindings(
  sequential : FetchedTransportSequential,
  component : @rtl.EmittedDesign,
  whole : @rtl.EmittedDesign,
  observed_view? : @ir.Module,
) -> String raise {
  let original = sequential.probe.source
  let component_view = fetched_transport_proof_view(sequential)
  let whole_view = observed_view.unwrap_or_else(() => {
    fetched_safety_view(sequential)
  })
  let out = StringBuilder()
  out.write_string(
    "`default_nettype none\nmodule lc_fetched_transport_bridge;\n  logic lc_clock = 1'b0;\n  always @($global_clock) lc_clock <= ~lc_clock;\n",
  )
  let connections : Array[String] = []
  for node in original.nodes() {
    if node.kind() is Input(name) {
      let variable = if name == "clock" {
        "lc_clock"
      } else if name == "reset" {
        "lc_external_reset"
      } else {
        "lc_" + name
      }
      if name != "clock" {
        out.write_string(
          "  (* anyseq *) logic \{toggle_formal_width_range(node.signal_type().width().bits())}\{variable};\n",
        )
      }
      connections.push(
        "    .\{port_identifier(whole,InputPort,name)}(\{variable})",
      )
    }
  }
  for output in whole_view.outputs() {
    let name = output.name()
    let variable = if component_view.outputs().any(item => item.name() == name) ||
      name.has_prefix("composition_") {
      fetched_safety_variable(name)
    } else {
      "lc_" + name
    }
    out.write_string(
      "  wire \{toggle_formal_width_range(output.signal_type().width().bits())}\{variable};\n",
    )
    connections.push(
      "    .\{port_identifier(whole,OutputPort,name)}(\{variable})",
    )
  }
  out.write_string(
    "  \{top_emitted_module(whole).identifier()} lc_full_dut(\n\{connections.join(",\n")}\n  );\n",
  )
  // Keep the accepted binding suffix (raw aliases, reset and666-bit state pair)
  // exact, while every old cut_n now denotes its actual original source node.
  let old = fetched_transport_proof_bindings(sequential, component)
  let marker = "  wire lc_i_"
  guard old.find(marker) is Some(start) else {
    raise InvalidFormalBundleIdentity("fetched safety: raw binding suffix")
  }
  for cut in sequential.probe.candidates {
    let name = "raw_n\{cut.original.id().ordinal()}"
    guard component_view.outputs().filter(output => output.name() == name)
      is [output] &&
      output.driver() ==
      dependency_generation_mapped(
        sequential.original_to_local,
        cut.original.id(),
      ) else {
      raise InvalidFormalBundleIdentity(
        "fetched safety: complete raw boundary binding",
      )
    }
    out.write_string(
      "  wire \{toggle_formal_width_range(cut.original.signal_type().width().bits())}cut_n\{cut.original.id().ordinal()} = \{fetched_safety_variable(name)};\n",
    )
  }
  out.write_string(old[start:].to_owned())
  out.to_string()
}

///|
fn fetched_safety_public_body(dut : FluxTileFormalDut) -> String raise {
  let (exported, _, _, _) = flux_tile_property_export()
  let harness = flux_tile_harness(PublicTransport, dut, exported.source())
  let marker = "  logic lc_seen_edge = 1'b0;\n"
  guard harness.split(marker).to_array() is [_, tail] else {
    raise InvalidFormalBundleIdentity("fetched safety: original public monitor")
  }
  let body = (marker + tail.to_owned()).replace_all(
    old="lc_seen_edge",
    new="lc_public_seen_edge",
  )
  guard body.strip_suffix("endmodule\n`default_nettype wire\n") is Some(body) else {
    raise InvalidFormalBundleIdentity("fetched safety: public monitor end")
  }
  let result = StringBuilder()
  for line in body.split("\n") {
    if line.contains(": cover (") {
      continue
    }
    result.write_string(line.to_owned() + "\n")
  }
  result.to_string()
}

///|
fn fetched_safety_handoff_source() -> String {
  let conclusions = [
    for lane in 0..<4 => {
      "(lc_dut_composition_lane_\{lane}_fire && lc_dut_composition_lane_\{lane}_data == lc_o_reader_lane_\{lane})"
    }
  ].join(" && ")
  "  always @(posedge lc_clock) begin\n" +
  "    lc_fetched_descriptor_admission: assert ((!lc_dut_reader_packet_accept || (\{conclusions})) === 1'b1);\n  end\n"
}

///|
fn fetched_safety_source(
  sequential : FetchedTransportSequential,
  component : @rtl.EmittedDesign,
  whole : @rtl.EmittedDesign,
  owner_only~ : Bool,
  observed_view? : @ir.Module,
  extra_support? : String = "",
) -> String raise {
  let old_bindings = fetched_transport_proof_bindings(sequential, component)
  let supported = fetched_transport_supported_source(sequential, component)
  guard supported.strip_prefix(old_bindings) is Some(body) else {
    raise InvalidFormalBundleIdentity("fetched safety: accepted monitor prefix")
  }
  let result = StringBuilder()
  result.write_string(
    fetched_safety_bindings(sequential, component, whole, observed_view?),
  )
  let mut omit_cover_tail = false
  for line in body.split("\n") {
    if line.contains("lc_initial_joint_reset: assume (") {
      continue
    }
    if line.contains("lc_fetched_packet_three_owners: cover (") {
      omit_cover_tail = true
      continue
    }
    if omit_cover_tail {
      guard line.has_suffix(");") else {
        raise InvalidFormalBundleIdentity(
          "fetched safety: complete two-line cover",
        )
      }
      omit_cover_tail = false
      continue
    }
    if line == "endmodule" || line == "`default_nettype wire" || line.is_empty() {
      continue
    }
    result.write_string(line.to_owned() + "\n")
  }
  let ordinary = flux_tile_formal_dut(
    sequential.probe.source,
    @rtl.emit_design(flux_tile_formal_design()),
  )
  let public = fetched_safety_public_body(ordinary)
  let (_, _, labels, _) = flux_tile_property_export()
  let excluded = [labels[0], labels[1], labels[3]] // aperture, payload, completion stability
  for line in public.split("\n") {
    if owner_only && excluded.any(label => line.contains(label + ": assert (")) {
      continue
    }
    if !line.is_empty() {
      result.write_string(line.to_owned() + "\n")
    }
  }
  result.write_string(fetched_safety_handoff_source())
  if !owner_only {
    result.write_string(fetched_safety_shape_support())
  }
  result.write_string(extra_support)
  result.write_string("endmodule\n`default_nettype wire\n")
  result.to_string()
}
