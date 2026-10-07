///|
// The original harness is used as a carrier, not instantiated as another DUT.
// Every port is bound to its exact original public pin/observation in the union.
fn dependency_conjunction_proof_carrier(
  sequential : DependencyConjunctionSequential,
  emitted : @rtl.EmittedDesign,
) -> DependencyFormalDut raise {
  let ports : Array[FluxTileFormalPort] = []
  for (role, width, input) in dependency_public_ports() {
    let identifier = if role == "clock" {
      port_identifier(emitted, InputPort, "clock")
    } else if input {
      guard sequential.cuts.filter(cut => cut.roles == [role]) is [cut] &&
        cut.signal_type == queue_public_port_type(role, width) else {
        raise InvalidFormalBundleIdentity(
          "dependency proof inputs: original public pin identity/type",
        )
      }
      let original = dependency_generation_input(
        sequential.probe.packet.source,
        role,
        cut.signal_type,
      )
      if original != cut.node {
        raise InvalidFormalBundleIdentity(
          "dependency proof inputs: public pin replaced by foreign producer",
        )
      }
      port_identifier(emitted, InputPort, "cut_n\{cut.node.ordinal()}")
    } else {
      guard sequential.probe.packet.source
        .outputs()
        .filter(output => output.name() == role)
        is [output] &&
        output.signal_type() == queue_public_port_type(role, width) else {
        raise InvalidFormalBundleIdentity(
          "dependency proof inputs: original public output identity/type",
        )
      }
      port_identifier(emitted, OutputPort, "public_" + role)
    }
    ports.push({ role, width, input, identifier, })
  }
  let observations : Array[FluxTileFormalPort] = []
  for (role, width) in dependency_expected_observations() {
    let binding = dependency_generation_binding(sequential.probe.bindings, role)
    let name = "dependency_" + dependency_role_name(role)
    guard sequential.probe.observations.filter(observation => {
        observation.name == name
      })
      is [observation] &&
      observation.node == binding.node &&
      observation.signal_type == binding.signal_type &&
      binding.signal_type.width().bits() == width &&
      !sequential.cuts.any(cut => cut.node == binding.node) else {
      raise InvalidFormalBundleIdentity(
        "dependency proof inputs: original noncut dependency role",
      )
    }
    observations.push({
      role: dependency_role_name(role),
      width,
      input: false,
      identifier: port_identifier(emitted, OutputPort, name),
    })
  }
  {
    identifier: top_emitted_module(emitted).identifier(),
    filename: "private-dependency.sv",
    source: "",
    production_filename: "private-dependency-production.sv",
    production_source: "",
    ports: ReadOnlyArray::from_array(ports),
    observation_ports: ReadOnlyArray::from_array(observations),
  }
}

///|
fn dependency_conjunction_proof_bindings(
  sequential : DependencyConjunctionSequential,
  emitted : @rtl.EmittedDesign,
) -> String raise {
  let carrier = dependency_conjunction_proof_carrier(sequential, emitted)
  let out = StringBuilder()
  for port in carrier.ports {
    if port.role == "clock" {
      continue
    }
    out.write_string(
      "  wire \{toggle_formal_width_range(port.width)}lc_\{port.role};\n  assign lc_\{port.role} = \{port.identifier};\n",
    )
  }
  for port in carrier.observation_ports {
    out.write_string(
      "  wire \{toggle_formal_width_range(port.width)}lc_o_\{port.role};\n  assign lc_o_\{port.role} = \{port.identifier};\n",
    )
  }
  out.to_string()
}

///|
fn dependency_conjunction_proof_original_monitor(
  sequential : DependencyConjunctionSequential,
  emitted : @rtl.EmittedDesign,
  variant : DependencyFormalFixture,
) -> String raise {
  let carrier = dependency_conjunction_proof_carrier(sequential, emitted)
  let (properties, _, _, _) = dependency_property_export(LatestWriter)
  let original = dependency_harness(variant, carrier, properties.source())
  // The COMPLETE decoder is the boundary. Starting at the host marker would
  // silently lose raw syntax decode and the whole independent generation ghost.
  let decoder = dependency_decode_source()
  guard original.split(decoder).to_array() is [_, tail] else {
    raise InvalidFormalBundleIdentity(
      "dependency proof inputs: complete original decoder boundary",
    )
  }
  guard tail.split("endmodule\n`default_nettype wire\n").to_array()
    is [body, ""] else {
    raise InvalidFormalBundleIdentity(
      "dependency proof inputs: original harness ending",
    )
  }
  if body.split(dependency_ghost_source()).count() != 2 ||
    body.split(properties.source()).count() != 2 {
    raise InvalidFormalBundleIdentity(
      "dependency proof inputs: complete original ghost/property bytes",
    )
  }
  decoder + body.to_owned()
}
