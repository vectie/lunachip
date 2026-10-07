///|
// Names and widths only: the authoritative state/updates are emitted verbatim
// by queue_monitor_source, not regenerated from this inventory.
fn queue_monitor_history_fields() -> ReadOnlyArray[(String, Int)] {
  let fields : Array[(String, Int)] = [
    ("lc_queue_sampled", 1),
    ("lc_queue_outstanding", 4),
    ("lc_queue_admission_seen", 1),
    ("lc_queue_reservation_seen", 1),
    ("lc_expected_response_valid", 1),
    ("lc_expected_read_pointer", 5),
    ("lc_expected_write_pointer", 5),
    ("lc_expected_retirement_occupancy", 5),
    ("lc_previous_full_refill", 1),
  ]
  for lane in 0..<4 {
    fields.push(("lc_expected_fifo_occupancy_\{lane}", 2))
  }
  for entry in 0..<3 {
    fields.push(("lc_expected_entry_valid_\{entry}", 1))
  }
  ReadOnlyArray::from_array(fields)
}

///|
fn queue_monitor_proof_cut(
  sequential : QueueControlSequential,
  role : String,
  expected : @ir.SignalType,
) -> DependencyGenerationCut raise FormalGateError {
  guard sequential.plan.cuts.filter(cut => cut.roles.contains(role)) is [cut] &&
    cut.signal_type == expected &&
    !sequential.plan.roots.any(root => root.node == cut.node) else {
    raise InvalidFormalBundleIdentity(
      "queue monitor proof: typed boundary " + role,
    )
  }
  let mapped = dependency_generation_mapped(
    sequential.original_to_local,
    cut.node,
  )
  let node = dependency_generation_node(sequential.hardware, mapped)
  if node.signal_type() != expected ||
    node.kind() != Input("cut_n\{cut.node.ordinal()}") {
    raise InvalidFormalBundleIdentity(
      "queue monitor proof: boundary identity " + role,
    )
  }
  cut
}

///|
// Check the actual public driver before giving an existing event a public name.
// These identities are not assumed equalities in the formal model.
fn queue_monitor_proof_public_output(
  fixture : @flux_tile.QueueConservationFixture,
  sequential : QueueControlSequential,
  public_name : String,
  event_name : String,
) -> Unit raise FormalGateError {
  let expected = queue_public_port_type(public_name, 1)
  guard fixture
    .hardware()
    .outputs()
    .filter(output => output.name() == public_name)
    is [public_output] &&
    sequential.plan.events.filter(event => event.name == event_name) is [event] &&
    public_output.driver() == event.node &&
    public_output.signal_type() == expected &&
    event.signal_type == expected else {
    raise InvalidFormalBundleIdentity(
      "queue monitor proof: public driver " + public_name,
    )
  }
  guard sequential.hardware
    .outputs()
    .filter(output => output.name() == event_name)
    is [local_output] &&
    local_output.signal_type() == event.signal_type &&
    local_output.driver() ==
    dependency_generation_mapped(sequential.original_to_local, event.node) else {
    raise InvalidFormalBundleIdentity(
      "queue monitor proof: copied public driver " + public_name,
    )
  }
}

///|
fn queue_monitor_proof_source(
  fixture : @flux_tile.QueueConservationFixture,
  sequential : QueueControlSequential,
  emitted : @rtl.EmittedDesign,
  negative? : Bool = false,
) -> String raise {
  queue_monitor_proof_public_output(
    fixture, sequential, "descriptor_ready", "descriptor_ready",
  )
  queue_monitor_proof_public_output(
    fixture, sequential, "completion_valid", "retirement_valid",
  )
  let out = StringBuilder()
  out.write_string(
    "`default_nettype none\nmodule lc_queue_monitor_bridge;\n  logic lc_clock = 1'b0;\n  always @($global_clock) lc_clock <= ~lc_clock;\n",
  )
  let connections : Array[String] = [
    "    .\{port_identifier(emitted, InputPort, "clock")}(lc_clock)",
  ]
  for cut in sequential.plan.cuts {
    if sequential.plan.roots.any(root => root.node == cut.node) {
      continue
    }
    let name = "cut_n\{cut.node.ordinal()}"
    out.write_string(
      "  (* anyseq *) logic \{toggle_formal_width_range(cut.signal_type.width().bits())}\{name};\n",
    )
    connections.push(
      "    .\{port_identifier(emitted, InputPort, name)}(\{name})",
    )
  }
  for root in sequential.plan.roots {
    out.write_string(
      "  wire \{toggle_formal_width_range(root.signal_type.width().bits())}lc_o_\{root.name};\n",
    )
    connections.push(
      "    .\{port_identifier(emitted, OutputPort, "current_" + root.name)}(lc_o_\{root.name})",
    )
  }
  for event in sequential.plan.events {
    out.write_string(
      "  wire \{toggle_formal_width_range(event.signal_type.width().bits())}lc_o_\{event.name};\n",
    )
    connections.push(
      "    .\{port_identifier(emitted, OutputPort, event.name)}(lc_o_\{event.name})",
    )
  }
  out.write_string(
    "  \{top_emitted_module(emitted).identifier()} lc_dut(\n\{connections.join(",\n")}\n  );\n",
  )
  for role in ["reset", "descriptor_valid", "completion_ready"] {
    let signal_type = if role == "reset" {
      @ir.SignalType::Reset
    } else {
      @wire.bits(1)
    }
    let cut = queue_monitor_proof_cut(sequential, role, signal_type)
    out.write_string("  wire lc_\{role} = cut_n\{cut.node.ordinal()};\n")
  }
  for entry in 0..<3 {
    let binding = queue_control_binding(fixture, EntryTerminal(entry))
    let cut = queue_monitor_proof_cut(sequential, binding.name, @wire.bits(1))
    if cut.node != binding.node {
      raise InvalidFormalBundleIdentity(
        "queue monitor proof: terminal identity",
      )
    }
    out.write_string(
      "  wire lc_o_\{binding.name} = cut_n\{cut.node.ordinal()};\n",
    )
  }
  let public_outputs =
    #|  wire lc_descriptor_ready = lc_o_descriptor_ready;
    #|  wire lc_completion_valid = lc_o_retirement_valid;
    #|
  out.write_string(public_outputs)
  out.write_string(
    queue_monitor_source(
      if negative {
        NegativePopulation
      } else {
        Conservation
      },
    ),
  )
  // No extra history flag or supporting premise: the monitor's original
  // sampled flag is initialized zero and becomes one at its first rising edge.
  let (exported, _, _, _) = queue_property_export(Conservation)
  let properties = exported.property_manifest().properties()
  out.write_string("  always @(posedge lc_clock) begin\n")
  out.write_string(
    "    \{properties[0].stable_name()}: assume ((lc_queue_sampled || lc_reset) === 1'b1);\n",
  )
  for property in properties[4:7] {
    out.write_string(
      "    \{property.stable_name()}: assert ((lc_\{property.name()}) === 1'b1);\n",
    )
  }
  out.write_string("  end\nendmodule\n`default_nettype wire\n")
  out.to_string()
}
