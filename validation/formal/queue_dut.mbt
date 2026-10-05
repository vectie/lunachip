///|
priv struct QueueFormalDut {
  identifier : String
  filename : String
  source : String
  production_filename : String
  production_source : String
  ports : ReadOnlyArray[FluxTileFormalPort]
  observation_ports : ReadOnlyArray[FluxTileFormalPort]
}

///|
fn queue_formal_dut(
  fixture : @flux_tile.QueueConservationFixture,
  emitted : @rtl.EmittedDesign,
) -> QueueFormalDut raise FormalGateError {
  let hardware = fixture.hardware()
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
      raise InvalidFormalBundleIdentity("queue public port type drift: " + role)
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
    raise InvalidFormalBundleIdentity("queue public port profile drift")
  }
  let expected = queue_expected_observations()
  if expected.length() != 115 ||
    fixture.observations().length() != expected.length() {
    raise InvalidFormalBundleIdentity("queue observation count drift")
  }
  let observation_ports : Array[FluxTileFormalPort] = []
  let declarations : Array[String] = []
  let assignments : Array[String] = []
  for (role, signal_type) in expected {
    let name = queue_role_name(role)
    let selected = fixture.observations().filter(item => item.role() == role)
    if selected.length() != 1 {
      raise InvalidFormalBundleIdentity("missing/duplicate queue role: " + name)
    }
    let observation = selected[0]
    if observation.signal_type() != signal_type {
      raise InvalidFormalBundleIdentity("queue observation type drift: " + name)
    }
    guard hardware.node(observation.node()) is Some(node) &&
      node.signal_type() == signal_type else {
      raise InvalidFormalBundleIdentity(
        "queue role lacks exact typed node: " + name,
      )
    }
    let identifier = "lc_formal_observe_" + name
    for prior in observation_ports {
      // Two roles may refer to one node. Role and formal pin keys may not alias.
      if prior.role == name || prior.identifier == identifier {
        raise InvalidFormalBundleIdentity(
          "duplicate queue observation role/port",
        )
      }
    }
    let emitted_node = emitted_node_identifier(
      emitted,
      observation.node().ordinal(),
    )
    let width = signal_type.width().bits()
    observation_ports.push({ role: name, identifier, width, input: false, })
    declarations.push(
      "  output logic \{toggle_formal_width_range(width)}\{identifier}",
    )
    assignments.push("  assign \{identifier} = \{emitted_node};\n")
  }
  let boundary = "\n);\n\n"
  let ending = "endmodule\n\n`default_nettype wire"
  dependency_require_marker(production.source(), boundary)
  dependency_require_marker(production.source(), ending)
  // Only this formal copy uses the existing Boolean comparison adapter.
  // Ordinary emitted RTL, registers, memories and production ports are intact.
  let (boolean_source, _) = dependency_boolean_helpers(
    hardware,
    production.source(),
  )
  let source = boolean_source
    .replace(old=boundary, new=",\n" + declarations.join(",\n") + boundary)
    .replace(old=ending, new=assignments.join("") + ending)
  {
    identifier: production.identifier(),
    filename: "formal-dut.sv",
    source,
    production_filename: "production-" + production.filename(),
    production_source: production.source(),
    ports: ReadOnlyArray::from_array(ports),
    observation_ports: ReadOnlyArray::from_array(observation_ports),
  }
}
