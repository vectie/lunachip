///|
// Keep the original property identities and bytes. The two unrelated covers
// are omitted; p13 remains the actual same-watch ordinal retirement cover.
fn queue_packet_composition_properties() -> @formal_core.FormalExport raise FormalGateError {
  let (exported, legal, assertions, covers) = queue_property_export(
    PacketProvenance,
  )
  if legal.length() != 4 || assertions.length() != 7 || covers.length() != 3 {
    raise InvalidFormalBundleIdentity(
      "packet composition proof inputs: original property inventory",
    )
  }
  let mut source = exported.source()
  for property in exported.properties() {
    if property.kind() is Cover &&
      property.source_name() != "packet_provenance_transfer_cover" {
      let block = "  always @(posedge lc_clock) begin\n    \{property.stable_name()}: cover ((lc_\{property.source_name()}) === 1'b1);\n  end\n"
      if source.split(block).count() != 2 {
        raise InvalidFormalBundleIdentity(
          "packet composition proof inputs: original cover block drift",
        )
      }
      source = source.replace(old=block, new="")
    }
  }
  let path = "lc_formal_queue_top"
  let clock = named_signal(path, "clock")
  let domain = @formal_core.ObservationDomain::rising_pre_edge(clock) catch {
    error => raise FormalContract(error)
  }
  let properties : Array[@formal_core.FormalProperty] = []
  let bindings : Array[@formal_core.FormalSignalBinding] = [
    @formal_core.FormalSignalBinding::checked(clock, "lc_clock") catch {
      error => raise FormalContract(error)
    },
  ]
  for
    index, (name, kind) in queue_property_definitions(
      records=true,
      packet_provenance=true,
    ) {
    if kind is Cover && name != "packet_provenance_transfer_cover" {
      continue
    }
    let predicate = named_signal(path, name)
    properties.push(
      checked_formal_property(
        property_id(index),
        name,
        kind,
        predicate,
        domain,
        NeverDisabled,
      ),
    )
    bindings.push(
      @formal_core.FormalSignalBinding::checked(predicate, "lc_" + name) catch {
        error => raise FormalContract(error)
      },
    )
  }
  let plan = @formal_core.FormalPropertyPlan::checked(properties) catch {
    error => raise FormalContract(error)
  }
  let selected = @formal_core.export_yosys_clocked_properties(plan, bindings) catch {
    error => raise FormalContract(error)
  }
  if selected.properties().length() != 12 || selected.source() != source {
    raise InvalidFormalBundleIdentity(
      "packet composition proof inputs: checked subset/source correspondence",
    )
  }
  selected
}

///|
// The carrier gives queue_harness its actual mapped pins, then extracts only
// its original host/monitor/property tail. No shadow module is instantiated.
fn queue_packet_composition_original_monitor(
  sequential : QueuePacketCompositionSequential,
  emitted : @rtl.EmittedDesign,
  negative : Bool,
) -> String raise FormalGateError {
  let ports : Array[FluxTileFormalPort] = []
  for (role, width, input) in dependency_public_ports() {
    let identifier = if role == "clock" {
      port_identifier(emitted, InputPort, "clock")
    } else if input {
      guard sequential.cuts.filter(cut => cut.roles == [role]) is [cut] else {
        raise InvalidFormalBundleIdentity(
          "packet composition proof inputs: original public pin missing",
        )
      }
      if cut.signal_type != queue_public_port_type(role, width) {
        raise InvalidFormalBundleIdentity(
          "packet composition proof inputs: original public pin type",
        )
      }
      port_identifier(emitted, InputPort, "cut_n\{cut.node.ordinal()}")
    } else {
      port_identifier(emitted, OutputPort, "public_" + role)
    }
    ports.push({ role, width, input, identifier, })
  }
  let observations : Array[FluxTileFormalPort] = []
  for observation in sequential.probe.observations {
    observations.push({
      role: observation.name,
      width: observation.signal_type.width().bits(),
      input: false,
      identifier: port_identifier(emitted, OutputPort, observation.name),
    })
  }
  let dut : QueueFormalDut = {
    identifier: top_emitted_module(emitted).identifier(),
    filename: "private-packet.sv",
    source: "",
    production_filename: "private-packet-production.sv",
    production_source: "",
    ports: ReadOnlyArray::from_array(ports),
    observation_ports: ReadOnlyArray::from_array(observations),
  }
  let original = queue_harness(
    if negative {
      NegativePacketProvenance
    } else {
      PacketProvenance
    },
    dut,
    queue_packet_composition_properties().source(),
  )
  let marker = "  logic lc_seen_edge = 1'b0;\n"
  guard original.split(marker).to_array() is [_, tail] else {
    raise InvalidFormalBundleIdentity(
      "packet composition proof inputs: original host boundary",
    )
  }
  guard tail.split("endmodule\n`default_nettype wire\n").to_array()
    is [body, ""] else {
    raise InvalidFormalBundleIdentity(
      "packet composition proof inputs: original monitor ending",
    )
  }
  marker + body.to_owned()
}

///|
fn queue_packet_composition_bindings(
  sequential : QueuePacketCompositionSequential,
  emitted : @rtl.EmittedDesign,
) -> String raise FormalGateError {
  let out = StringBuilder()
  for (role, width, input) in dependency_public_ports() {
    if role == "clock" {
      continue
    }
    let identifier = if input {
      guard sequential.cuts.filter(cut => cut.roles == [role]) is [cut] else {
        raise InvalidFormalBundleIdentity(
          "packet composition proof inputs: exact public binding",
        )
      }
      port_identifier(emitted, InputPort, "cut_n\{cut.node.ordinal()}")
    } else {
      port_identifier(emitted, OutputPort, "public_" + role)
    }
    out.write_string(
      "  wire \{toggle_formal_width_range(width)}lc_\{role};\n  assign lc_\{role} = \{identifier};\n",
    )
  }
  for observation in sequential.probe.observations {
    let identifier = port_identifier(emitted, OutputPort, observation.name)
    out.write_string(
      "  wire \{toggle_formal_width_range(observation.signal_type.width().bits())}lc_o_\{observation.name};\n  assign lc_o_\{observation.name} = \{identifier};\n",
    )
  }
  // Original FIFO address registers are not among the 115 observation roles.
  for lane in sequential.probe.lanes {
    for root in [lane.read_pointer, lane.write_pointer] {
      let identifier = port_identifier(
        emitted,
        OutputPort,
        "current_" + root.name,
      )
      out.write_string(
        "  wire [1:0] lc_s_\{root.name};\n  assign lc_s_\{root.name} = \{identifier};\n",
      )
    }
  }
  out.to_string()
}
