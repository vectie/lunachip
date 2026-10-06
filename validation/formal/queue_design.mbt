///|
fn queue_property_definitions(
  records~ : Bool,
  packet_provenance~ : Bool,
) -> Array[(String, @formal_core.FormalPropertyKind)] {
  let definitions : Array[(String, @formal_core.FormalPropertyKind)] = [
    ("initial_joint_reset", Assumption),
    ("host_descriptor_stable_until_accept", Assumption),
    ("host_response_stable_until_accept", Assumption),
    ("host_response_flushed_during_reset", Assumption),
    ("lane_atomicity_and_response", Assertion),
    ("packet_population_conserved", Assertion),
    ("retirement_event_ownership", Assertion),
    ("reachable_full_refill_capture", Cover),
  ]
  if records {
    definitions.push(("terminal_entry_immutable", Assertion))
    definitions.push(("oldest_terminal_selected", Assertion))
    definitions.push(("held_completion_immutable", Assertion))
    definitions.push(("reachable_held_oldest_younger_collector", Cover))
  }
  if packet_provenance {
    definitions.push(("packet_provenance_ok", Assertion))
    definitions.push(("packet_provenance_transfer_cover", Cover))
  }
  definitions
}

///|
fn queue_property_export(
  fixture : QueueFormalFixture,
) -> (
  @formal_core.FormalExport,
  ReadOnlyArray[String],
  ReadOnlyArray[String],
  ReadOnlyArray[String],
) raise FormalGateError {
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
    index, definition in queue_property_definitions(
      records=queue_records_profile(fixture),
      packet_provenance=queue_packet_provenance_profile(fixture),
    ) {
    let (name, kind) = definition
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
  let exported = @formal_core.export_yosys_clocked_properties(plan, bindings) catch {
    error => raise FormalContract(error)
  }
  let legal : Array[String] = []
  let assertions : Array[String] = []
  let covers : Array[String] = []
  for item in exported.properties() {
    match item.kind() {
      Assumption => legal.push(item.stable_name())
      Assertion => assertions.push(item.stable_name())
      Cover => covers.push(item.stable_name())
    }
  }
  (
    exported,
    ReadOnlyArray::from_array(legal),
    ReadOnlyArray::from_array(assertions),
    ReadOnlyArray::from_array(covers),
  )
}

///|
fn queue_timing_contract(
  domain : @ir.ClockDomainId,
  legal : ReadOnlyArray[String],
) -> @formal_core.FormalTimingContract raise FormalGateError {
  let clock_signal = named_signal("lc_formal_queue_top", "clock")
  let clock = @formal_core.FormalClockBinding::checked(
    domain,
    clock_signal,
    Rising,
  ) catch {
    error => raise FormalContract(error)
  }
  @formal_core.FormalTimingContract::checked(
    @formal_core.GlobalFormalTimestep::checked(2),
    [clock],
    legal,
    [],
    AtomicGlobalPreState,
  ) catch {
    error => raise FormalContract(error)
  }
}

///|
fn queue_expected_failure(
  fixture : QueueFormalFixture,
  properties : @formal_core.FormalPropertyManifest,
) -> String raise FormalGateError {
  if queue_positive_profile(fixture) {
    return "none"
  }
  let name = match fixture {
    NegativePopulation => "packet_population_conserved"
    NegativeHeldPayload => "held_completion_immutable"
    NegativePacketProvenance => "packet_provenance_ok"
    Conservation | RetirementRecords | PacketProvenance => "none"
  }
  for item in properties.properties() {
    if item.name() == name {
      return item.stable_name()
    }
  }
  raise InvalidFormalBundleIdentity(
    "missing queue sensitivity assertion: \{name}",
  )
}
