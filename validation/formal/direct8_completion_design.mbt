///|
// Bind every existing public pin to the ordinary original device and its emitter
// manifest. No observation output, graph cut, forced state or debug ABI is added.
fn direct8_completion_dut(
  hardware : @ir.Module,
  emitted : @rtl.EmittedDesign,
) -> QueueFormalDut raise FormalGateError {
  let production = top_emitted_module(emitted)
  let ports : Array[FluxTileFormalPort] = []
  for (role, width, input) in dependency_public_ports() {
    let expected_type = queue_public_port_type(role, width)
    let mut actual_type : @ir.SignalType? = None
    if input {
      for node in hardware.nodes() {
        if node.kind() is Input(name) && name == role {
          actual_type = Some(node.signal_type())
        }
      }
    } else {
      for output in hardware.outputs() {
        if output.name() == role {
          actual_type = Some(output.signal_type())
        }
      }
    }
    if actual_type != Some(expected_type) {
      raise InvalidFormalBundleIdentity(
        "direct8 public port type drift: " + role,
      )
    }
    ports.push({
      role,
      width,
      input,
      identifier: port_identifier(
        emitted,
        if input {
          InputPort
        } else {
          OutputPort
        },
        role,
      ),
    })
  }
  let top = emitted.manifest().top_module_ordinal()
  let mut count = 0
  for mapping in emitted.manifest().mappings() {
    if mapping.module_ordinal() == top &&
      (mapping.kind() is InputPort || mapping.kind() is OutputPort) {
      count += 1
    }
  }
  if count != ports.length() {
    raise InvalidFormalBundleIdentity("direct8 public port roster drift")
  }
  let (source, _) = dependency_boolean_helpers(hardware, production.source())
  {
    identifier: production.identifier(),
    filename: "formal-dut.sv",
    source,
    production_filename: "production-" + production.filename(),
    production_source: production.source(),
    ports: ReadOnlyArray::from_array(ports),
    observation_ports: [],
  }
}

///|
fn direct8_completion_harness(
  fixture : DirectCompletionFixture,
  dut : QueueFormalDut,
  exported : String,
) -> String raise FormalGateError {
  if !dut.observation_ports.is_empty() {
    raise InvalidFormalBundleIdentity("direct8 plain public device required")
  }
  let out = StringBuilder()
  out.write_string(
    "`default_nettype none\nmodule lc_formal_direct_completion_top;\n  logic lc_clock = 1'b0;\n  always @($global_clock) lc_clock <= ~lc_clock;\n",
  )
  for port in dut.ports {
    if port.role != "clock" {
      let symbolic = if port.input && port.role != "reset" {
        "(* anyseq *) "
      } else {
        ""
      }
      out.write_string(
        "  \{symbolic}logic \{toggle_formal_width_range(port.width)}lc_\{port.role};\n",
      )
    }
  }
  out.write_string("  \{dut.identifier} lc_dut (\n")
  for index, port in dut.ports {
    out.write_string("    .\{port.identifier}(lc_\{port.role})")
    out.write_string(if index + 1 == dut.ports.length() { "\n" } else { ",\n" })
  }
  out.write_string("  );\n")
  out.write_string(direct_completion_host_source())
  out.write_string(
    direct8_completion_monitor_source(fixture is NegativeDeadline),
  )
  out.write_string(direct8_completion_useful_source())
  out.write_string(exported)
  out.write_string("endmodule\n`default_nettype wire\n")
  out.to_string()
}
