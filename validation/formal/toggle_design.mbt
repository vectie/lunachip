///|
priv struct ToggleFormalDesign {
  design : @ir.Design
  primitive : @ir.ToggleHandshakePrimitive
}

///|
fn toggle_formal_design(
  fixture : ToggleFormalFixture,
) -> ToggleFormalDesign raise {
  let design_kind = if fixture is ValidToggleScalar2 {
    "scalar-2"
  } else if fixture is ValidToggleRecord4 {
    "record-4"
  } else {
    "record-3"
  }
  let builder = @wire.ModuleBuilder::new("FormalToggle" + design_kind)
  let source_clock = builder.input("source_clock", @wire.clock())
  let source_domain = builder.rising_edge(source_clock)
  // Preserve a sparse public domain table so formal bindings cannot silently
  // substitute a dense clock index.
  let zero = builder.constant(@wire.bits(1), 0UL)
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let destination_domain = builder.rising_edge(destination_clock)
  let filler = builder.bit_or(zero, zero)
  let source_reset_signal = builder.input("source_reset", @wire.reset())
  let destination_reset_signal = builder.input(
    "destination_reset",
    @wire.reset(),
  )
  let source_valid_input = builder.input("source_valid", @wire.bits(1))
  let source_valid = builder.bit_xor(source_valid_input, filler)
  let source_word = builder.input("source_word", @wire.bits(8))
  let source_tag = if fixture.has_record_payload() {
    Some(builder.input("source_tag", @wire.bits(3)))
  } else {
    None
  }
  let destination_ready = builder.input("destination_ready", @wire.bits(1))
  let payload = match source_tag {
    Some(tag) =>
      @aggregate.Aggregate::record([
        ("word", @aggregate.Aggregate::leaf(source_word)),
        ("tag", @aggregate.Aggregate::leaf(tag)),
      ])
    None => @aggregate.Aggregate::leaf(source_word)
  }
  let handshake = builder.toggle_handshake(
    "formal_transport",
    source_domain,
    destination_domain,
    builder.ready_valid_forward(source_valid, payload),
    builder.ready_valid_backward(destination_ready),
    builder.synchronous_reset(source_reset_signal, 0UL),
    builder.synchronous_reset(destination_reset_signal, 0UL),
    synchronizer_stages=fixture.stage_count(),
  )
  let source_ready = builder.output("source_ready", @wire.bits(1))
  let destination_valid = builder.output("destination_valid", @wire.bits(1))
  let destination_word = builder.output("destination_word", @wire.bits(8))
  builder.connect(source_ready, handshake.source().ready())
  builder.connect(destination_valid, handshake.destination().valid())
  let destination_payload = handshake.destination().payload().flatten()
  builder.connect(destination_word, destination_payload[0].value())
  let destination_outputs : Array[@wire.Output] = [
    destination_valid, destination_word,
  ]
  match source_tag {
    Some(_) => {
      let destination_tag = builder.output("destination_tag", @wire.bits(3))
      builder.connect(destination_tag, destination_payload[1].value())
      destination_outputs.push(destination_tag)
    }
    None => ()
  }
  for input in [source_reset_signal, source_valid_input, source_word] {
    builder.input_timing(input, SampledIn(source_domain.id()))
  }
  match source_tag {
    Some(tag) => builder.input_timing(tag, SampledIn(source_domain.id()))
    None => ()
  }
  builder.input_timing(
    destination_reset_signal,
    SampledIn(destination_domain.id()),
  )
  builder.input_timing(destination_ready, SampledIn(destination_domain.id()))
  builder.output_timing(source_ready, ProducedIn(source_domain.id()))
  for output in destination_outputs {
    builder.output_timing(output, ProducedIn(destination_domain.id()))
  }
  let hardware_module = builder.finish()
  guard hardware_module.cdc_primitives() is [ToggleHandshake(primitive)] else {
    raise InvalidToggleHandshakeBundle(
      "public constructor did not retain exactly one toggle handshake",
    )
  }
  {
    design: @ir.Design::single(
      "phase5-formal-toggle-" + design_kind,
      hardware_module,
    ),
    primitive,
  }
}

///|
fn toggle_property_export() -> (
  @formal_core.FormalExport,
  ReadOnlyArray[String],
  ReadOnlyArray[String],
  ReadOnlyArray[String],
  ReadOnlyArray[String],
  ReadOnlyArray[String],
) raise FormalGateError {
  let path = "lc_formal_toggle_top"
  let observer = named_signal(path, "formal_step_clock")
  let domain = @formal_core.ObservationDomain::rising_pre_edge(observer) catch {
    error => raise FormalContract(error)
  }
  let definitions : Array[(String, @formal_core.FormalPropertyKind, String)] = [
    (
      "source_clock_transition_legal",
      Assumption,
      "source_clock_transition_legal",
    ),
    (
      "destination_clock_transition_legal",
      Assumption,
      "destination_clock_transition_legal",
    ),
    ("source_clock_fair", Assumption, "source_clock_fair"),
    ("destination_clock_fair", Assumption, "destination_clock_fair"),
    (
      "coordinated_reset_initialization",
      Assumption,
      "coordinated_reset_initialization",
    ),
    ("source_protocol_hold", Assumption, "source_protocol_hold"),
    ("destination_eventual_ready", Assumption, "destination_eventual_ready"),
    ("one_item_in_flight_capacity", Assertion, "one_item_in_flight_capacity"),
    (
      "source_payload_stable_while_outstanding",
      Assertion,
      "source_payload_stable_while_outstanding",
    ),
    (
      "destination_response_stable_under_backpressure",
      Assertion,
      "destination_response_stable_under_backpressure",
    ),
    (
      "no_duplicate_acknowledge_or_consume",
      Assertion,
      "no_duplicate_acknowledge_or_consume",
    ),
    (
      "watched_transaction_data_integrity",
      Assertion,
      "watched_transaction_data_integrity",
    ),
    (
      "watched_transaction_completes_under_bounded_clocks_and_eventual_ready",
      Assertion,
      "watched_transaction_completes",
    ),
    (
      "coincident_source_destination_edge",
      Cover,
      "coincident_source_destination_edge",
    ),
    (
      "simultaneous_destination_consume_and_refill",
      Cover,
      "simultaneous_destination_consume_and_refill",
    ),
    (
      "watched_transaction_accept_capture_consume",
      Cover,
      "watched_transaction_accept_capture_consume",
    ),
  ]
  let properties : Array[@formal_core.FormalProperty] = []
  for index, definition in definitions {
    let (name, kind, predicate) = definition
    properties.push(
      checked_formal_property(
        property_id(index),
        name,
        kind,
        named_signal(path, predicate),
        domain,
        NeverDisabled,
      ),
    )
  }
  let plan = @formal_core.FormalPropertyPlan::checked(properties) catch {
    error => raise FormalContract(error)
  }
  let bindings : Array[@formal_core.FormalSignalBinding] = []
  let bind = fn(
    signal : @property.PropertySignal,
    identifier : String,
  ) raise FormalGateError {
    bindings.push(
      @formal_core.FormalSignalBinding::checked(signal, identifier) catch {
        error => raise FormalContract(error)
      },
    )
  }
  bind(observer, "lc_formal_step_clock")
  for _, definition in definitions {
    let (_, _, predicate) = definition
    bind(named_signal(path, predicate), "lc_" + predicate)
  }
  let exported = @formal_core.export_yosys_clocked_properties(plan, bindings) catch {
    error => raise FormalContract(error)
  }
  let legal : Array[String] = []
  let fairness : Array[String] = []
  let assumptions : Array[String] = []
  let assertions : Array[String] = []
  let covers : Array[String] = []
  for index, property in exported.properties() {
    let (name, kind, _) = definitions[index]
    match kind {
      Assumption => {
        assumptions.push(property.stable_name())
        if name.has_suffix("transition_legal") {
          legal.push(property.stable_name())
        } else if name.has_suffix("clock_fair") {
          fairness.push(property.stable_name())
        }
      }
      Assertion => assertions.push(property.stable_name())
      Cover => covers.push(property.stable_name())
    }
  }
  (
    exported,
    ReadOnlyArray::from_array(legal),
    ReadOnlyArray::from_array(fairness),
    ReadOnlyArray::from_array(assumptions),
    ReadOnlyArray::from_array(assertions),
    ReadOnlyArray::from_array(covers),
  )
}
