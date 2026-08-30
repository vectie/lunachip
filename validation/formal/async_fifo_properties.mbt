///|
fn async_fifo_property_export() -> (
  @formal_core.FormalExport,
  ReadOnlyArray[String],
  ReadOnlyArray[String],
  ReadOnlyArray[String],
  ReadOnlyArray[String],
  ReadOnlyArray[String],
) raise FormalGateError {
  let path = "lc_formal_async_fifo_top"
  let observer = named_signal(path, "formal_step_clock")
  let domain = @formal_core.ObservationDomain::rising_pre_edge(observer) catch {
    error => raise FormalContract(error)
  }
  let protocol_inactive = named_signal(path, "protocol_inactive")
  let inactive_disable = @formal_core.DisableBehavior::when_known_high_asynchronous(
    protocol_inactive,
  ) catch {
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
    ("source_transfer_guard_exact", Assertion, "source_transfer_guard_exact"),
    (
      "destination_transfer_guard_exact",
      Assertion,
      "destination_transfer_guard_exact",
    ),
    (
      "write_binary_pointer_hold_or_increment",
      Assertion,
      "write_binary_pointer_hold_or_increment",
    ),
    (
      "read_binary_pointer_hold_or_increment",
      Assertion,
      "read_binary_pointer_hold_or_increment",
    ),
    ("write_gray_equation_exact", Assertion, "write_gray_equation_exact"),
    (
      "write_gray_hold_or_one_bit_transition",
      Assertion,
      "write_gray_hold_or_one_bit_transition",
    ),
    ("read_gray_equation_exact", Assertion, "read_gray_equation_exact"),
    (
      "read_gray_hold_or_one_bit_transition",
      Assertion,
      "read_gray_hold_or_one_bit_transition",
    ),
    (
      "read_gray_source_pipeline_exact",
      Assertion,
      "read_gray_source_pipeline_exact",
    ),
    (
      "write_gray_destination_pipeline_exact",
      Assertion,
      "write_gray_destination_pipeline_exact",
    ),
    ("full_equation_exact", Assertion, "full_equation_exact"),
    ("nonempty_equation_exact", Assertion, "nonempty_equation_exact"),
    (
      "write_address_selection_exact",
      Assertion,
      "write_address_selection_exact",
    ),
    ("write_address_in_bounds", Assertion, "write_address_in_bounds"),
    ("read_address_selection_exact", Assertion, "read_address_selection_exact"),
    ("read_address_in_bounds", Assertion, "read_address_in_bounds"),
    ("no_write_while_full", Assertion, "no_write_while_full"),
    ("no_consume_while_empty", Assertion, "no_consume_while_empty"),
    (
      "destination_payload_stable_under_backpressure",
      Assertion,
      "destination_payload_stable_under_backpressure",
    ),
    ("watched_token_ordering", Assertion, "watched_token_ordering"),
    ("watched_token_data_integrity", Assertion, "watched_token_data_integrity"),
    (
      "watched_token_consumed_under_bounded_clocks_and_eventual_ready",
      Assertion,
      "watched_token_consumed",
    ),
    (
      "coincident_source_destination_edge",
      Cover,
      "coincident_source_destination_edge",
    ),
    ("fifo_reaches_full", Cover, "fifo_reaches_full"),
    ("write_pointer_wraps", Cover, "write_pointer_wraps"),
    ("read_pointer_wraps", Cover, "read_pointer_wraps"),
    (
      "simultaneous_enqueue_and_dequeue",
      Cover,
      "simultaneous_enqueue_and_dequeue",
    ),
    ("watched_token_consumed", Cover, "watched_token_consumed_cover"),
  ]
  let properties : Array[@formal_core.FormalProperty] = []
  for index, definition in definitions {
    let (name, kind, predicate) = definition
    let disable : @formal_core.DisableBehavior = match kind {
      Assumption => NeverDisabled
      Assertion | Cover => inactive_disable
    }
    properties.push(
      checked_formal_property(
        property_id(index),
        name,
        kind,
        named_signal(path, predicate),
        domain,
        disable,
      ),
    )
  }
  let plan = @formal_core.FormalPropertyPlan::checked(properties) catch {
    error => raise FormalContract(error)
  }
  let bindings : Array[@formal_core.FormalSignalBinding] = []
  bindings.push(
    @formal_core.FormalSignalBinding::checked(observer, "lc_formal_step_clock") catch {
      error => raise FormalContract(error)
    },
  )
  bindings.push(
    @formal_core.FormalSignalBinding::checked(
      protocol_inactive, "lc_protocol_inactive",
    ) catch {
      error => raise FormalContract(error)
    },
  )
  for _, definition in definitions {
    let (_, _, predicate) = definition
    let signal = named_signal(path, predicate)
    bindings.push(
      @formal_core.FormalSignalBinding::checked(signal, "lc_" + predicate) catch {
        error => raise FormalContract(error)
      },
    )
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
