///|
fn flux_tile_formal_design() -> @ir.Design raise {
  // Preserve the exact canonical graph/name of the first differential fixture.
  @ir.Design::single(
    "phase6-fetched-concurrent-1x1-k2",
    @flux_tile.ring_concurrent_tile(
      rows=1,
      columns=1,
      max_reduction=2,
      host_bytes=1024UL,
      ring_depth=4,
      queue_depth=2,
    ),
  )
}

///|
fn flux_tile_property_definitions() -> Array[
  (String, @formal_core.FormalPropertyKind),
] {
  // Both read/write predicates are retained. The bounded first-packet pilot
  // does not exercise writes; source-set/constructor documentation state that
  // limit explicitly instead of presenting a vacuous write branch as evidence.
  [
    ("initial_joint_reset", Assumption),
    ("host_config_stable_until_accept", Assumption),
    ("host_publication_stable_until_accept", Assumption),
    ("host_response_stable_until_accept", Assumption),
    ("host_response_flushed_during_reset", Assumption),
    ("transport_request_address_in_aperture", Assertion),
    ("transport_request_payload_legal", Assertion),
    ("transport_request_stable_until_accept", Assertion),
    ("command_completion_stable_until_accept", Assertion),
    ("transport_at_most_one_outstanding", Assertion),
    ("transport_response_has_owner", Assertion),
    ("transport_no_response_edge_request", Assertion),
    ("joint_reset_suppresses_public_transfers", Assertion),
    ("reachable_held_request", Cover),
    ("reachable_owned_response", Cover),
    ("reachable_first_command_terminal", Cover),
  ]
}

///|
fn flux_tile_property_export() -> (
  @formal_core.FormalExport,
  ReadOnlyArray[String],
  ReadOnlyArray[String],
  ReadOnlyArray[String],
) raise FormalGateError {
  let path = "lc_formal_flux_tile_top"
  let clock = named_signal(path, "clock")
  let domain = @formal_core.ObservationDomain::rising_pre_edge(clock) catch {
    error => raise FormalContract(error)
  }
  let definitions = flux_tile_property_definitions()
  let properties : Array[@formal_core.FormalProperty] = []
  let bindings : Array[@formal_core.FormalSignalBinding] = [
    @formal_core.FormalSignalBinding::checked(clock, "lc_clock") catch {
      error => raise FormalContract(error)
    },
  ]
  for index, definition in definitions {
    let (name, kind) = definition
    let predicate = named_signal(path, name)
    // Every predicate handles reset explicitly, including reset suppression.
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
fn flux_tile_timing_contract(
  domain : @ir.ClockDomainId,
  legal : ReadOnlyArray[String],
) -> @formal_core.FormalTimingContract raise FormalGateError {
  let clock_signal = named_signal("lc_formal_flux_tile_top", "clock")
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
fn flux_tile_expected_failure(
  fixture : FluxTileFormalFixture,
  properties : @formal_core.FormalPropertyManifest,
) -> String raise FormalGateError {
  let wanted = match fixture {
    PublicTransport => return "none"
    NegativeRequestBounds => "transport_request_address_in_aperture"
    NegativeRequestStability => "transport_request_stable_until_accept"
  }
  for item in properties.properties() {
    if item.name() == wanted {
      return item.stable_name()
    }
  }
  raise InvalidFormalBundleIdentity("missing FluxTile sensitivity assertion")
}
