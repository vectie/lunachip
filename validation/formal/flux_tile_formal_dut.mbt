///|
// All connections are resolved from typed public-port NameManifest mappings.
// No additional observation output and no hierarchical/internal identifier.
priv struct FluxTileFormalPort {
  role : String
  identifier : String
  width : Int
  input : Bool
}

///|
priv struct FluxTileFormalDut {
  identifier : String
  filename : String
  source : String
  ports : ReadOnlyArray[FluxTileFormalPort]
}

///|
fn flux_tile_formal_ports() -> Array[(String, Int, Bool)] {
  [
    ("clock", 1, true),
    ("reset", 1, true),
    ("config_valid", 1, true),
    ("config_base", 32, true),
    ("config_origin", 32, true),
    ("publish_valid", 1, true),
    ("publish_producer", 32, true),
    ("completion_ready", 1, true),
    ("memory_request_ready", 1, true),
    ("memory_response_valid", 1, true),
    ("memory_response_tag", 32, true),
    ("memory_response_fault", 2, true),
    ("memory_response_data", 32, true),
    ("config_ready", 1, false),
    ("publish_ready", 1, false),
    ("configured", 1, false),
    ("producer_count", 32, false),
    ("consumer_count", 32, false),
    ("ring_fault_valid", 1, false),
    ("ring_fault_code", 3, false),
    ("ring_fault_address", 32, false),
    ("halted", 1, false),
    ("transport_halted", 1, false),
    ("transport_fault_address", 32, false),
    ("queue_occupancy", 5, false),
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
fn flux_tile_formal_dut(
  hardware : @ir.Module,
  emitted : @rtl.EmittedDesign,
) -> FluxTileFormalDut raise FormalGateError {
  let emitted_module = top_emitted_module(emitted)
  let ports : Array[FluxTileFormalPort] = []
  for definition in flux_tile_formal_ports() {
    let (role, width, input) = definition
    let mut actual_width : Int? = None
    if input {
      for node in hardware.nodes() {
        if node.kind() is Input(name) && name == role {
          actual_width = Some(node.signal_type().width().bits())
        }
      }
    } else {
      for output in hardware.outputs() {
        if output.name() == role {
          actual_width = Some(output.signal_type().width().bits())
        }
      }
    }
    if actual_width != Some(width) {
      raise InvalidFormalBundleIdentity(
        "FluxTile formal public port width drifted: " + role,
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
  // The expected profile is complete; a new public pin requires review rather
  // than silently becoming an unconstrained/unconnected formal input.
  let top = emitted.manifest().top_module_ordinal()
  let mut count = 0
  for mapping in emitted.manifest().mappings() {
    if mapping.module_ordinal() == top &&
      (mapping.kind() is InputPort || mapping.kind() is OutputPort) {
      count += 1
    }
  }
  if count != ports.length() {
    raise InvalidFormalBundleIdentity(
      "FluxTile public formal port profile drifted",
    )
  }
  {
    identifier: emitted_module.identifier(),
    filename: emitted_module.filename(),
    source: emitted_module.source(),
    ports: ReadOnlyArray::from_array(ports),
  }
}
