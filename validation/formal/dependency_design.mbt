///|
fn dependency_property_definitions() -> Array[
  (String, @formal_core.FormalPropertyKind),
] {
  [
    ("initial_joint_reset", Assumption),
    ("host_descriptor_stable_until_accept", Assumption),
    ("host_response_stable_until_accept", Assumption),
    ("host_response_flushed_during_reset", Assumption),
    ("latest_writer_matches_independent_model", Assertion),
    ("source_snapshots_prepublication_match_model", Assertion),
    ("consumer_admission_requires_successful_generations", Assertion),
    ("unavailable_dependency_rejection_exact", Assertion),
    ("new_intent_wins_matching_older_terminal", Assertion),
    ("inner_compute_preserves_saved_authorization", Assertion),
    ("terminal_ticket_matches_accepted_owner", Assertion),
    ("reachable_failed_reload_then_mat_fault4", Cover),
    ("reachable_failed_mat_then_store_fault5", Cover),
    ("reachable_invalid_syntax_preserves_usable_generation", Cover),
    ("reachable_older_terminal_with_new_intent", Cover),
    ("reachable_authorized_outer_to_inner_compute", Cover),
  ]
}

///|
fn dependency_property_export() -> (
  @formal_core.FormalExport,
  ReadOnlyArray[String],
  ReadOnlyArray[String],
  ReadOnlyArray[String],
) raise FormalGateError {
  let path = "lc_formal_dependency_top"
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
  for index, definition in dependency_property_definitions() {
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
fn dependency_timing_contract(
  domain : @ir.ClockDomainId,
  legal : ReadOnlyArray[String],
) -> @formal_core.FormalTimingContract raise FormalGateError {
  let clock_signal = named_signal("lc_formal_dependency_top", "clock")
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
fn dependency_expected_failure(
  fixture : DependencyFormalFixture,
  properties : @formal_core.FormalPropertyManifest,
) -> String raise FormalGateError {
  let wanted = match fixture {
    LatestWriter => return "none"
    NegativeFailedGeneration => "latest_writer_matches_independent_model"
    NegativeNewIntentPriority => "new_intent_wins_matching_older_terminal"
    NegativeInnerIdentity => "inner_compute_preserves_saved_authorization"
  }
  for item in properties.properties() {
    if item.name() == wanted {
      return item.stable_name()
    }
  }
  raise InvalidFormalBundleIdentity("missing dependency sensitivity assertion")
}
