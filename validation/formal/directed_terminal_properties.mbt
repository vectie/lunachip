///|
fn directed_terminal_property_definitions() -> Array[
  (String, @formal_core.FormalPropertyKind),
] {
  [
    ("initial_joint_reset", Assumption),
    ("host_config_stable_until_accept", Assumption),
    ("host_publication_stable_until_accept", Assumption),
    ("host_response_stable_until_accept", Assumption),
    ("host_response_flushed_during_reset", Assumption),
    ("directed_initial_reset_only", Assumption),
    ("directed_single_legal_config", Assumption),
    ("directed_single_publication", Assumption),
    ("directed_unstalled_ready", Assumption),
    ("directed_owned_response_available", Assumption),
    ("directed_matching_success_response", Assumption),
    ("directed_fence_memory_image", Assumption),
    ("directed_successful_first_fence", Cover),
  ]
}

///|
fn directed_terminal_property_export() -> (
  @formal_core.FormalExport,
  ReadOnlyArray[String],
  String,
) raise FormalGateError {
  let path = "lc_formal_flux_tile_top"
  let clock = named_signal(path, "clock")
  let domain = @formal_core.ObservationDomain::rising_pre_edge(clock) catch {
    error => raise FormalContract(error)
  }
  let definitions = directed_terminal_property_definitions()
  let properties : Array[@formal_core.FormalProperty] = []
  let bindings : Array[@formal_core.FormalSignalBinding] = [
    @formal_core.FormalSignalBinding::checked(clock, "lc_clock") catch {
      error => raise FormalContract(error)
    },
  ]
  for index, definition in definitions {
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
  let mut cover : String? = None
  for item in exported.properties() {
    match item.kind() {
      Assumption => legal.push(item.stable_name())
      Cover => cover = Some(item.stable_name())
      Assertion =>
        raise InvalidFormalBundleIdentity(
          "directed terminal fixture must not claim safety",
        )
    }
  }
  guard cover is Some(label) else {
    raise InvalidFormalBundleIdentity("missing directed Fence cover")
  }
  (exported, ReadOnlyArray::from_array(legal), label)
}
