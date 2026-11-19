///|
priv struct ToggleFormalObservation {
  role : String
  width : Int32
  port : String
  node : String
}

///|
priv struct ToggleFormalDut {
  identifier : String
  filename : String
  source : String
  observations : Array[ToggleFormalObservation]
}

///|
fn ToggleFormalDut::identifier(self : ToggleFormalDut) -> String {
  self.identifier
}

///|
fn ToggleFormalDut::filename(self : ToggleFormalDut) -> String {
  self.filename
}

///|
fn ToggleFormalDut::source(self : ToggleFormalDut) -> String {
  self.source
}

///|
fn toggle_formal_expected_roles(
  fixture : ToggleFormalFixture,
) -> Array[(String, Int32)] {
  let roles = [
    ("source_accept", 1),
    ("destination_capture", 1),
    ("destination_consume", 1),
    ("acknowledge_toggle", 1),
    ("held_word", 8),
  ]
  if fixture.has_record_payload() {
    roles.push(("held_tag", 3))
  }
  roles
}

///|
fn toggle_formal_width_range(width : Int32) -> String {
  if width == 1 {
    ""
  } else {
    "[\{width - 1}:0] "
  }
}

///|
fn toggle_require_unique_formal_marker(
  source : String,
  marker : String,
  label : String,
) -> Unit raise FormalGateError {
  if source.split(marker).count() != 2 {
    raise InvalidToggleHandshakeBundle(
      "formal toggle DUT expected exactly one emitted module \{label}",
    )
  }
}

///|
fn toggle_validate_formal_observations(
  fixture : ToggleFormalFixture,
  observations : Array[ToggleFormalObservation],
) -> Unit raise FormalGateError {
  let expected = toggle_formal_expected_roles(fixture)
  if observations.length() != expected.length() {
    raise InvalidToggleHandshakeBundle(
      "formal toggle DUT observation inventory is incomplete",
    )
  }
  for index, observation in observations {
    let (expected_role, expected_width) = expected[index]
    if observation.role != expected_role ||
      observation.width != expected_width ||
      observation.port != "lc_formal_observe_\{expected_role}" ||
      observation.node == "" {
      raise InvalidToggleHandshakeBundle(
        "formal toggle DUT observation inventory is not exact and typed",
      )
    }
    for prior_index in 0..<index {
      let prior = observations[prior_index]
      if observation.role == prior.role ||
        observation.port == prior.port ||
        observation.node == prior.node {
        raise InvalidToggleHandshakeBundle(
          "formal toggle DUT observation roles, ports, and nodes must be unique",
        )
      }
    }
  }
}

///|
fn toggle_formal_observation(
  emitted : @rtl.EmittedDesign,
  role : String,
  width : Int32,
  id : @ir.NodeId,
) -> ToggleFormalObservation raise FormalGateError {
  {
    role,
    width,
    port: "lc_formal_observe_\{role}",
    node: emitted_node_identifier(emitted, id.ordinal()),
  }
}

///|
fn toggle_formal_observations(
  fixture : ToggleFormalFixture,
  design : @ir.Design,
  emitted : @rtl.EmittedDesign,
) -> Array[ToggleFormalObservation] raise FormalGateError {
  guard design.top_module() is Some(hardware_module) else {
    raise MissingTopModule
  }
  guard hardware_module.cdc_primitives() is [ToggleHandshake(spec)] else {
    raise InvalidToggleHandshakeBundle(
      "formal design must contain exactly one toggle handshake",
    )
  }
  let held_payload = spec.held_payload()
  let expected_payload_leaves = if fixture.has_record_payload() { 2 } else { 1 }
  if held_payload.length() != expected_payload_leaves {
    raise InvalidToggleHandshakeBundle(
      "formal toggle DUT held-payload shape does not match its fixture",
    )
  }
  let observations = [
    toggle_formal_observation(emitted, "source_accept", 1, spec.source_accept()),
    toggle_formal_observation(
      emitted,
      "destination_capture",
      1,
      spec.destination_capture(),
    ),
    toggle_formal_observation(
      emitted,
      "destination_consume",
      1,
      spec.destination_consume(),
    ),
    toggle_formal_observation(
      emitted,
      "acknowledge_toggle",
      1,
      spec.acknowledge_toggle(),
    ),
    toggle_formal_observation(emitted, "held_word", 8, held_payload[0]),
  ]
  if fixture.has_record_payload() {
    observations.push(
      toggle_formal_observation(emitted, "held_tag", 3, held_payload[1]),
    )
  }
  observations
}

///|
fn toggle_add_formal_observation_ports(
  fixture : ToggleFormalFixture,
  production_source : String,
  observations : Array[ToggleFormalObservation],
) -> String raise FormalGateError {
  toggle_validate_formal_observations(fixture, observations)
  let ports = observations
    .map(observation => {
      "  output logic \{toggle_formal_width_range(observation.width)}\{observation.port}"
    })
    .join(",\n")
  let port_boundary = "\n);\n\n"
  let module_end = "endmodule\n\n`default_nettype wire"
  toggle_require_unique_formal_marker(
    production_source, port_boundary, "port boundary",
  )
  toggle_require_unique_formal_marker(production_source, module_end, "end")
  let source_with_ports = production_source.replace(
    old=port_boundary,
    new=",\n\{ports}\{port_boundary}",
  )
  let assignments = observations
    .map(observation => "  assign \{observation.port} = \{observation.node};\n")
    .join("")
  let source = source_with_ports.replace(
    old=module_end,
    new="\{assignments}\{module_end}",
  )
  for index, observation in observations {
    let suffix = if index + 1 == observations.length() {
      "\n);\n\n"
    } else {
      ",\n"
    }
    let declaration = "  output logic \{toggle_formal_width_range(observation.width)}\{observation.port}\{suffix}"
    let assignment = "  assign \{observation.port} = \{observation.node};\n"
    if source.split(declaration).count() != 2 ||
      source.split(assignment).count() != 2 {
      raise InvalidToggleHandshakeBundle(
        "formal toggle observation port and assignment must each occur once",
      )
    }
  }
  source
}

///|
/// Builds an isolated, deterministic formal observation boundary.
///
/// The public toggle handle does not expose internal state after `finish`, and
/// canonical IR intentionally retains no formal-only fanout. This adapter binds
/// typed emitted-node identities to explicit output ports after production
/// emission. Exact inventory and splice uniqueness checks make emitter drift
/// fail closed rather than silently editing an ambiguous module.
fn toggle_formal_dut(
  fixture : ToggleFormalFixture,
  design : @ir.Design,
  emitted : @rtl.EmittedDesign,
  production_dut : @rtl.EmittedModule,
) -> ToggleFormalDut raise FormalGateError {
  let observations = toggle_formal_observations(fixture, design, emitted)
  let source = toggle_add_formal_observation_ports(
    fixture,
    production_dut.source(),
    observations,
  )
  {
    identifier: production_dut.identifier(),
    filename: production_dut.filename(),
    source,
    observations,
  }
}
