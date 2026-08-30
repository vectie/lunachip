///|
priv struct SynchronizerFormalObservation {
  port : String
  node : String
}

///|
priv struct SynchronizerFormalDut {
  identifier : String
  filename : String
  source : String
  stage_ports : ReadOnlyArray[String]
  source_port : String
}

///|
fn SynchronizerFormalDut::identifier(self : SynchronizerFormalDut) -> String {
  self.identifier
}

///|
fn SynchronizerFormalDut::filename(self : SynchronizerFormalDut) -> String {
  self.filename
}

///|
fn SynchronizerFormalDut::source(self : SynchronizerFormalDut) -> String {
  self.source
}

///|
fn synchronizer_require_unique_marker(
  source : String,
  marker : String,
  label : String,
) -> Unit raise FormalGateError {
  if source.split(marker).length() != 2 {
    raise InvalidSynchronizerBundle(
      "formal DUT expected exactly one emitted module \{label}",
    )
  }
}

///|
fn synchronizer_validate_formal_observations(
  observations : Array[SynchronizerFormalObservation],
) -> Unit raise FormalGateError {
  if observations.length() != 4 {
    raise InvalidSynchronizerBundle(
      "formal synchronizer DUT expected three stages and one source",
    )
  }
  for index, observation in observations {
    if observation.port == "" || observation.node == "" {
      raise InvalidSynchronizerBundle(
        "formal synchronizer observation must be fully identified",
      )
    }
    for prior in 0..<index {
      if observations[prior].port == observation.port ||
        observations[prior].node == observation.node {
        raise InvalidSynchronizerBundle(
          "formal synchronizer observations must be unique",
        )
      }
    }
  }
}

///|
fn synchronizer_add_formal_observation_ports(
  production_source : String,
  observations : Array[SynchronizerFormalObservation],
) -> String raise FormalGateError {
  synchronizer_validate_formal_observations(observations)
  let ports = observations
    .map(observation => "  output logic \{observation.port}")
    .join(",\n")
  let port_boundary = "\n);\n\n"
  let module_end = "endmodule\n\n`default_nettype wire"
  synchronizer_require_unique_marker(
    production_source, port_boundary, "port boundary",
  )
  synchronizer_require_unique_marker(production_source, module_end, "end")
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
    let declaration = "  output logic \{observation.port}\{suffix}"
    let assignment = "  assign \{observation.port} = \{observation.node};\n"
    if source.split(declaration).length() != 2 ||
      source.split(assignment).length() != 2 {
      raise InvalidSynchronizerBundle(
        "formal synchronizer observation port must be explicit and unique",
      )
    }
  }
  source
}

///|
fn synchronizer_formal_dut(
  design : @ir.Design,
  emitted : @rtl.EmittedDesign,
  production_dut : @rtl.EmittedModule,
) -> SynchronizerFormalDut raise FormalGateError {
  guard design.top_module() is Some(hardware_module) else {
    raise MissingTopModule
  }
  guard hardware_module.cdc_primitives() is [BitSynchronizer(spec)] else {
    raise InvalidSynchronizerBundle(
      "formal synchronizer design must contain exactly one primitive",
    )
  }
  let observations : Array[SynchronizerFormalObservation] = []
  for index, stage in spec.stages() {
    observations.push({
      port: "lc_formal_observe_stage\{index}",
      node: emitted_node_identifier(emitted, stage.ordinal()),
    })
  }
  observations.push({
    port: "lc_formal_observe_source_value",
    node: emitted_node_identifier(emitted, spec.source().ordinal()),
  })
  let source = synchronizer_add_formal_observation_ports(
    production_dut.source(),
    observations,
  )
  {
    identifier: production_dut.identifier(),
    filename: production_dut.filename(),
    source,
    stage_ports: ReadOnlyArray::from_array(
      observations[0:3].map(observation => observation.port),
    ),
    source_port: observations[3].port,
  }
}
