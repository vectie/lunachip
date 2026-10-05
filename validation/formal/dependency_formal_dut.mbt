///|
priv struct DependencyFormalDut {
  identifier : String
  filename : String
  source : String
  production_filename : String
  production_source : String
  ports : ReadOnlyArray[FluxTileFormalPort]
  observation_ports : ReadOnlyArray[FluxTileFormalPort]
}

///|
fn dependency_role_name(role : @flux_tile.QueuedConcurrentFormalRole) -> String {
  match role {
    HeadLane(index) => "head_lane_\{index}"
    HeadState => "head_state"
    HeadReserve => "head_reserve"
    NextTicket => "next_ticket"
    HeadTicket => "head_ticket"
    WriterStatus(index) => "writer_status_\{index}"
    WriterTicket(index) => "writer_ticket_\{index}"
    DependencyStatus(index) => "dependency_status_\{index}"
    DependencyTicket(index) => "dependency_ticket_\{index}"
    LocalReject => "local_reject"
    LocalFault => "local_fault"
    LoadAccept => "load_accept"
    ComputeAccept => "compute_accept"
    StoreAccept => "store_accept"
    LoadTerminal => "load_terminal"
    LoadTerminalTicket => "load_terminal_ticket"
    LoadTerminalFault => "load_terminal_fault"
    ComputeTerminal => "compute_terminal"
    ComputeTerminalTicket => "compute_terminal_ticket"
    ComputeTerminalFault => "compute_terminal_fault"
    StoreTerminal => "store_terminal"
    StoreTerminalTicket => "store_terminal_ticket"
    StoreTerminalFault => "store_terminal_fault"
    ComputePreflight => "compute_preflight"
    InnerCommandValid => "inner_command_valid"
    InnerCommandReady => "inner_command_ready"
    ComputeLatchedTicket => "compute_latched_ticket"
    ComputeLatchedA => "compute_latched_a"
    ComputeLatchedB => "compute_latched_b"
    ComputeLatchedC => "compute_latched_c"
    ComputeLatchedRows => "compute_latched_rows"
    ComputeLatchedColumns => "compute_latched_columns"
    ComputeLatchedReduction => "compute_latched_reduction"
  }
}

///|
fn dependency_expected_observations() -> Array[
  (@flux_tile.QueuedConcurrentFormalRole, Int),
] {
  let roles : Array[(@flux_tile.QueuedConcurrentFormalRole, Int)] = []
  for index in 0..<4 {
    roles.push((HeadLane(index), 64))
  }
  let head : Array[(@flux_tile.QueuedConcurrentFormalRole, Int)] = [
    (HeadState, 2),
    (HeadReserve, 1),
    (NextTicket, 32),
    (HeadTicket, 32),
  ]
  for item in head {
    roles.push(item)
  }
  for index in 0..<6 {
    roles.push((WriterStatus(index), 2))
    roles.push((WriterTicket(index), 32))
  }
  for index in 0..<2 {
    roles.push((DependencyStatus(index), 2))
    roles.push((DependencyTicket(index), 32))
  }
  let tail : Array[(@flux_tile.QueuedConcurrentFormalRole, Int)] = [
    (LoadAccept, 1),
    (ComputeAccept, 1),
    (StoreAccept, 1),
    (LoadTerminal, 1),
    (LoadTerminalTicket, 32),
    (LoadTerminalFault, 4),
    (ComputeTerminal, 1),
    (ComputeTerminalTicket, 32),
    (ComputeTerminalFault, 4),
    (StoreTerminal, 1),
    (StoreTerminalTicket, 32),
    (StoreTerminalFault, 4),
    (ComputePreflight, 4),
    (InnerCommandValid, 1),
    (InnerCommandReady, 1),
    (ComputeLatchedTicket, 32),
    (ComputeLatchedA, 1),
    (ComputeLatchedB, 1),
    (ComputeLatchedC, 1),
    (ComputeLatchedRows, 13),
    (ComputeLatchedColumns, 13),
    (ComputeLatchedReduction, 13),
    (LocalReject, 1),
    (LocalFault, 4),
  ]
  for item in tail {
    roles.push(item)
  }
  roles
}

///|
fn dependency_public_ports() -> Array[(String, Int, Bool)] {
  [
    ("clock", 1, true),
    ("reset", 1, true),
    ("descriptor_valid", 1, true),
    ("descriptor_lane_0", 64, true),
    ("descriptor_lane_1", 64, true),
    ("descriptor_lane_2", 64, true),
    ("descriptor_lane_3", 64, true),
    ("completion_ready", 1, true),
    ("memory_request_ready", 1, true),
    ("memory_response_valid", 1, true),
    ("memory_response_tag", 32, true),
    ("memory_response_fault", 2, true),
    ("memory_response_data", 32, true),
    ("descriptor_ready", 1, false),
    ("queue_occupancy", 5, false),
    ("halted", 1, false),
    ("transport_halted", 1, false),
    ("transport_fault_address", 32, false),
    ("completion_valid", 1, false),
    ("completion_id", 32, false),
    ("completion_fault", 4, false),
    ("completion_bytes_completed", 32, false),
    ("completion_fault_address", 32, false),
    ("memory_request_valid", 1, false),
    ("memory_request_write", 1, false),
    ("memory_request_address", 32, false),
    ("memory_request_bytes", 3, false),
    ("memory_request_mask", 4, false),
    ("memory_request_data", 32, false),
    ("memory_request_tag", 32, false),
    ("memory_response_ready", 1, false),
    ("accepted_steps", 13, false),
    ("elapsed_cycles", 64, false),
    ("active_cycles", 64, false),
    ("stall_cycles", 64, false),
    ("capture_cycles", 7, false),
  ]
}

///|
fn dependency_require_marker(
  source : String,
  marker : String,
) -> Unit raise FormalGateError {
  if source.split(marker).length() != 2 {
    raise InvalidFormalBundleIdentity(
      "ambiguous dependency formal adapter marker",
    )
  }
}

///|
fn dependency_formal_dut(
  fixture : @flux_tile.QueuedConcurrentFormalFixture,
  emitted : @rtl.EmittedDesign,
) -> DependencyFormalDut raise FormalGateError {
  let hardware = fixture.hardware()
  let production = top_emitted_module(emitted)
  let ports : Array[FluxTileFormalPort] = []
  for definition in dependency_public_ports() {
    let (role, width, input) = definition
    let mut actual : Int? = None
    if input {
      for node in hardware.nodes() {
        if node.kind() is Input(name) && name == role {
          actual = Some(node.signal_type().width().bits())
        }
      }
    } else {
      for output in hardware.outputs() {
        if output.name() == role {
          actual = Some(output.signal_type().width().bits())
        }
      }
    }
    if actual != Some(width) {
      raise InvalidFormalBundleIdentity(
        "dependency public port width drift: " + role,
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
    raise InvalidFormalBundleIdentity("dependency public port profile drift")
  }
  let expected = dependency_expected_observations()
  if fixture.observations().length() != expected.length() {
    raise InvalidFormalBundleIdentity("dependency observation count drift")
  }
  let observation_ports : Array[FluxTileFormalPort] = []
  let declarations : Array[String] = []
  let assignments : Array[String] = []
  for index, observation in fixture.observations() {
    let (role, width) = expected[index]
    if observation.role() != role ||
      observation.signal_type().width().bits() != width {
      raise InvalidFormalBundleIdentity(
        "dependency observation role/type drift",
      )
    }
    let mut actual_type : @ir.SignalType? = None
    for node in hardware.nodes() {
      if node.id() == observation.node() {
        actual_type = Some(node.signal_type())
      }
    }
    if actual_type != Some(observation.signal_type()) {
      raise InvalidFormalBundleIdentity(
        "dependency observation does not bind an exact typed node",
      )
    }
    let name = dependency_role_name(role)
    let identifier = "lc_formal_observe_" + name
    for prior in observation_ports {
      // Node aliases are intentional. Role/port identity, however, is unique.
      if prior.role == name || prior.identifier == identifier {
        raise InvalidFormalBundleIdentity(
          "duplicate dependency observation role/port",
        )
      }
    }
    let node = emitted_node_identifier(emitted, observation.node().ordinal())
    observation_ports.push({ role: name, identifier, width, input: false, })
    declarations.push(
      "  output logic \{toggle_formal_width_range(width)}\{identifier}",
    )
    assignments.push("  assign \{identifier} = \{node};\n")
  }
  let boundary = "\n);\n\n"
  let ending = "endmodule\n\n`default_nettype wire"
  dependency_require_marker(production.source(), boundary)
  dependency_require_marker(production.source(), ending)
  // Formal inputs/state are arbitrary binary choices, not four-state logic.
  // Keep every real unknown register/memory choice; adapt only comparison
  // function bodies, whose pointwise Boolean equivalence is checked separately.
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
