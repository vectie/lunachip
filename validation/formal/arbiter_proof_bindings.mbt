///|
// Bind checked original nodes through the emitted port manifest. Raw constant
// roles keep their actual reviewed values; they never acquire free inputs.
fn two_client_arbiter_proof_bindings(
  fixture : @flux_tile.QueueConservationFixture,
  sequential : TwoClientArbiterSequential,
  emitted : @rtl.EmittedDesign,
) -> String raise {
  let source = fixture.hardware()
  let probe = sequential.probe
  two_client_arbiter_require_materialization(source, probe)
  let proof_view = two_client_arbiter_proof_view(sequential)
  if sha256_hex(
      @ir_codec.serialize(
        @ir.Design::single("QueuedConcurrentQueueConservationPilot", source),
      ),
    ) !=
    probe.production_digest {
    raise InvalidFormalBundleIdentity("arbiter proof: frozen original source")
  }
  let clock = dependency_generation_mapped(
    sequential.original_to_local,
    probe.clock,
  )
  guard sequential.hardware.node(clock) is Some(node) &&
    node.signal_type() is Clock &&
    node.kind() is Input("clock") else {
    raise InvalidFormalBundleIdentity("arbiter proof: original clock binding")
  }
  let out = StringBuilder()
  out.write_string(
    "`default_nettype none\nmodule lc_two_client_arbiter_bridge;\n" +
    "  logic lc_clock = 1'b0;\n" +
    "  always @($global_clock) lc_clock <= ~lc_clock;\n",
  )
  let connections : Array[String] = [
    "    .\{port_identifier(emitted, InputPort, "clock")}(lc_clock)",
  ]
  for candidate in probe.candidates {
    let name = "cut_n\{candidate.original.id().ordinal()}"
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      candidate.original.id(),
    )
    guard sequential.hardware.node(mapped) is Some(node) &&
      node.signal_type() == candidate.original.signal_type() &&
      node.kind() == Input(name) else {
      raise InvalidFormalBundleIdentity(
        "arbiter proof: exact raw input binding",
      )
    }
    out.write_string(
      "  (* anyseq *) logic \{toggle_formal_width_range(node.signal_type().width().bits())}\{name};\n",
    )
    connections.push(
      "    .\{port_identifier(emitted, InputPort, name)}(\{name})",
    )
  }
  let zero : Array[String] = []
  let pair : Array[String] = []
  for root in probe.roots {
    let name = "current_" + root.name
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      root.node,
    )
    guard sequential.hardware.outputs().filter(output => output.name() == name)
      is [output] &&
      output.driver() == mapped &&
      output.signal_type() == root.signal_type else {
      raise InvalidFormalBundleIdentity("arbiter proof: original root output")
    }
    out.write_string(
      "  wire \{toggle_formal_width_range(root.signal_type.width().bits())}lc_o_\{root.name};\n",
    )
    connections.push(
      "    .\{port_identifier(emitted, OutputPort, name)}(lc_o_\{root.name})",
    )
    zero.push("(lc_o_\{root.name} == 0)")
    pair.push("lc_o_" + root.name)
  }
  for event in probe.events {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      event.node,
    )
    guard sequential.hardware
      .outputs()
      .filter(output => output.name() == event.name)
      is [output] &&
      output.driver() == mapped &&
      output.signal_type() == event.signal_type else {
      raise InvalidFormalBundleIdentity("arbiter proof: original event output")
    }
    out.write_string(
      "  wire \{toggle_formal_width_range(event.signal_type.width().bits())}lc_dut_\{event.name};\n",
    )
    connections.push(
      "    .\{port_identifier(emitted, OutputPort, event.name)}(lc_dut_\{event.name})",
    )
  }
  // The extra export-only raw-data observation has no theorem attached. It
  // preserves the reviewed unused cut without changing original controller.
  guard proof_view
    .outputs()
    .filter(output => output.name() == "raw_response_data_observation")
    is [observation] else {
    raise InvalidFormalBundleIdentity("arbiter proof: raw observation output")
  }
  out.write_string(
    "  wire \{toggle_formal_width_range(observation.signal_type().width().bits())}lc_raw_response_data_observation;\n",
  )
  connections.push(
    "    .\{port_identifier(emitted, OutputPort, "raw_response_data_observation")}(lc_raw_response_data_observation)",
  )
  // Verify original public request/response drivers independently of the
  // private projection aliases before calling their events public history.
  for
    (public_name, role) in [
      ("memory_request_valid", "offer"),
      ("memory_response_ready", "response_ready"),
      ("transport_halted", "poisoned"),
    ] {
    guard probe.events.filter(event => event.name == role) is [event] &&
      two_client_arbiter_output(source, public_name, event.signal_type) ==
      event.node else {
      raise InvalidFormalBundleIdentity("arbiter proof: public event driver")
    }
  }
  for name in ["write", "address", "bytes", "mask", "data", "next_tag"] {
    guard probe.roots.filter(root => root.name == name) is [root] else {
      raise InvalidFormalBundleIdentity("arbiter proof: public payload root")
    }
    let public_name = "memory_request_" +
      (if name == "next_tag" { "tag" } else { name })
    if two_client_arbiter_output(source, public_name, root.signal_type) !=
      root.node {
      raise InvalidFormalBundleIdentity("arbiter proof: public payload driver")
    }
  }
  out.write_string(
    "  \{top_emitted_module(emitted).identifier()} lc_dut(\n\{connections.join(",\n")}\n  );\n",
  )
  for boundary in probe.boundaries {
    let original = boundary.original
    let value = match original.kind() {
      Constant(value) => {
        let mapped = dependency_generation_mapped(
          sequential.original_to_local,
          original.id(),
        )
        guard sequential.hardware.node(mapped) is Some(node) &&
          node == @ir.Node::new(mapped, original.signal_type(), Constant(value)) else {
          raise InvalidFormalBundleIdentity(
            "arbiter proof: original constant role",
          )
        }
        "\{original.signal_type().width().bits()}'d\{value}"
      }
      _ => {
        guard probe.candidates.filter(candidate => {
            candidate.original == original
          })
          is [_] else {
          raise InvalidFormalBundleIdentity(
            "arbiter proof: unreviewed raw role",
          )
        }
        "cut_n\{original.id().ordinal()}"
      }
    }
    for role in boundary.roles {
      out.write_string(
        "  wire \{toggle_formal_width_range(original.signal_type().width().bits())}lc_i_\{role} = \{value};\n",
      )
    }
  }
  out.write_string("  wire lc_reset = lc_i_reset;\n")
  out.write_string("  wire lc_all_reset_zero = \{zero.join(" && ")};\n")
  out.write_string("  wire [171:0] lc_current_pair = {\{pair.join(", ")}};\n")
  out.to_string()
}
