///|
test "original monitor bridge has verbatim history one startup premise and original labels" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let sequential = queue_control_sequential(fixture)
  let emitted = @rtl.emit_design(
    @ir.Design::single("QueueControlSequential", sequential.hardware),
  )
  let positive = queue_monitor_proof_source(fixture, sequential, emitted)
  let negative = queue_monitor_proof_source(
    fixture,
    sequential,
    emitted,
    negative=true,
  )
  assert_eq(positive.split(queue_monitor_source(Conservation)).count(), 2)
  assert_eq(negative.split(queue_monitor_source(NegativePopulation)).count(), 2)
  assert_eq(positive.split("(* anyseq *)").count() - 1, 8)
  assert_eq(positive.split(": assume (").count() - 1, 1)
  assert_eq(positive.split(": assert (").count() - 1, 3)
  assert_eq(negative.split(": assume (").count() - 1, 1)
  assert_eq(negative.split(": assert (").count() - 1, 3)
  assert_true(positive.contains("logic lc_clock = 1'b0;"))
  assert_true(
    positive.contains("always @($global_clock) lc_clock <= ~lc_clock;"),
  )
  assert_false(positive.contains("logic lc_seen_edge"))
  assert_false(positive.contains("logic lc_g_public_outstanding"))
  let (exported, _, _, _) = queue_property_export(Conservation)
  let properties = exported.property_manifest().properties()
  assert_true(
    positive.contains(
      "\{properties[0].stable_name()}: assume ((lc_queue_sampled || lc_reset) === 1'b1);",
    ),
  )
  assert_eq(properties[4:7].map(property => property.name()), [
    "lane_atomicity_and_response", "packet_population_conserved", "retirement_event_ownership",
  ])
  for property in properties[4:7] {
    let assertion = "\{property.stable_name()}: assert ((lc_\{property.name()}) === 1'b1);"
    assert_eq(positive.split(assertion).count(), 2)
    assert_eq(negative.split(assertion).count(), 2)
  }
  let fields = queue_monitor_history_fields()
  assert_eq(fields.length(), 16)
  assert_eq(fields.iter().fold(init=0, (sum, field) => sum + field.1), 35)
  let monitor = queue_monitor_source(Conservation)
  assert_eq(monitor.split("logic ").count() - 1, 16)
  // Eight unconstrained boundaries + clock + the sixteen original monitor
  // registers. No previous-pair, bounded-counter or supporting ghost is added.
  assert_eq(positive.split("logic ").count() - 1, 25)
  for (name, width) in fields {
    let declaration = "logic \{toggle_formal_width_range(width)}\{name} = "
    assert_eq(monitor.split(declaration).count(), 2)
  }
  assert_true(
    positive.contains("lc_queue_outstanding <= lc_queue_outstanding - 4'd1;"),
  )
  assert_true(
    positive.contains("lc_queue_outstanding <= lc_queue_outstanding + 4'd1;"),
  )
  assert_false(positive.contains("lc_queue_outstanding <= lc_raw_population"))
  assert_true(
    positive.contains("&& (!lc_queue_sampled || lc_raw_invariant_ok)"),
  )
  let original = "  wire [4:0] lc_checked_retirement_population = lc_o_retirement_occupancy;\n"
  let changed = "  wire [4:0] lc_checked_retirement_population = lc_o_retirement_occupancy + (lc_mutate_population ? 5'd1 : 5'd0);\n"
  assert_eq(positive.split(original).count(), 2)
  assert_eq(negative.split(changed).count(), 2)
  assert_eq(negative.replace(old=changed, new=original), positive)
  assert_true(
    negative.contains(
      "wire lc_mutate_population = !lc_reset && lc_queue_admission_seen\n    && lc_queue_reservation_seen && lc_o_retirement_occupancy != 5'd0\n    && lc_raw_population_relation;",
    ),
  )
  assert_false(negative.contains("lc_genuine_reserve"))
  assert_false(negative.contains("lc_checked_population"))
}

///|
test "monitor bridge aliases exact roots lane events public drivers and same terminal cuts" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let sequential = queue_control_sequential(fixture)
  let emitted = @rtl.emit_design(
    @ir.Design::single("QueueControlSequential", sequential.hardware),
  )
  let bridge = queue_monitor_proof_source(fixture, sequential, emitted)
  assert_eq(sequential.plan.roots.length(), 16)
  assert_eq(sequential.plan.events.length(), 38)
  assert_eq(
    sequential.hardware
    .nodes()
    .filter(node => node.kind() is Register(_))
    .length(),
    16,
  )
  assert_eq(
    sequential.hardware.nodes().filter(node => node.kind() is Input(_)).length(),
    9,
  )
  assert_eq(sequential.hardware.outputs().length(), 54)
  assert_eq(sequential.hardware.memories().length(), 0)
  assert_eq(
    sequential.plan.roots
    .iter()
    .fold(init=0, (sum, root) => sum + root.signal_type.width().bits()),
    37,
  )
  for root in sequential.plan.roots {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      root.node,
    )
    let source = dependency_generation_node(fixture.hardware(), root.node)
    assert_eq(source.signal_type(), root.signal_type)
    guard source.kind() is Register(spec) else {
      fail("missing original register")
    }
    assert_eq(spec, root.spec)
    guard sequential.hardware
      .outputs()
      .filter(output => output.name() == "current_" + root.name)
      is [output] else {
      fail("missing current output")
    }
    assert_eq(output.driver(), mapped)
    assert_eq(output.signal_type(), root.signal_type)
    assert_eq(
      bridge
      .split(
        ".\{port_identifier(emitted, OutputPort, "current_" + root.name)}(lc_o_\{root.name})",
      )
      .count(),
      2,
    )
  }
  for event in sequential.plan.events {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      event.node,
    )
    guard sequential.hardware
      .outputs()
      .filter(output => output.name() == event.name)
      is [output] else {
      fail("missing original event output")
    }
    assert_eq(output.driver(), mapped)
    assert_eq(output.signal_type(), event.signal_type)
    assert_eq(
      bridge
      .split(
        ".\{port_identifier(emitted, OutputPort, event.name)}(lc_o_\{event.name})",
      )
      .count(),
      2,
    )
  }
  for role in ["reset", "descriptor_valid", "completion_ready"] {
    let signal_type = if role == "reset" {
      @ir.SignalType::Reset
    } else {
      @wire.bits(1)
    }
    let cut = queue_monitor_proof_cut(sequential, role, signal_type)
    assert_eq(
      bridge.split("wire lc_\{role} = cut_n\{cut.node.ordinal()};").count(),
      2,
    )
  }
  for entry in 0..<3 {
    let binding = queue_control_binding(fixture, EntryTerminal(entry))
    let cut = queue_monitor_proof_cut(sequential, binding.name, @wire.bits(1))
    assert_eq(cut.node, binding.node)
    assert_eq(
      bridge
      .split("wire lc_o_\{binding.name} = cut_n\{cut.node.ordinal()};")
      .count(),
      2,
    )
    assert_eq(
      bridge.split("(* anyseq *) logic cut_n\{cut.node.ordinal()};").count(),
      2,
    )
  }
  for
    (public_name, event_name) in [
      ("descriptor_ready", "descriptor_ready"),
      ("completion_valid", "retirement_valid"),
    ] {
    queue_monitor_proof_public_output(
      fixture, sequential, public_name, event_name,
    )
    guard fixture
      .hardware()
      .outputs()
      .filter(output => output.name() == public_name)
      is [public_output] else {
      fail("missing actual public output")
    }
    guard sequential.plan.events.filter(event => event.name == event_name)
      is [event] else {
      fail("missing matching event")
    }
    assert_eq(public_output.driver(), event.node)
    assert_eq(public_output.signal_type(), @wire.bits(1))
    assert_eq(
      bridge.split("wire lc_\{public_name} = lc_o_\{event_name};").count(),
      2,
    )
  }
  try
    queue_monitor_proof_public_output(
      fixture, sequential, "completion_valid", "head_pop",
    )
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong public alias rejection")
  } noraise {
    _ => fail("distinct public driver was accepted")
  }
  try
    queue_monitor_proof_cut(sequential, "completion_ready", @wire.uint(1))
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong cut type rejection")
  } noraise {
    _ => fail("untyped public cut was accepted")
  }
}
