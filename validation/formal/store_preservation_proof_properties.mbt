///|
fn store_preservation_properties(
  top : String,
) -> @formal_core.FormalExport raise FormalGateError {
  let clock = named_signal(top, "clock")
  let domain = @formal_core.ObservationDomain::rising_pre_edge(clock) catch {
    error => raise FormalContract(error)
  }
  let definitions : Array[(String, @formal_core.FormalPropertyKind)] = [
    ("startup_reset", Assumption),
    ("reservation_exclusion", Assertion),
    ("capture_publication_and_lease", Assertion),
    ("produced_storage", Assertion),
    ("pending_and_dma_payload", Assertion),
    ("cursor_progress_and_terminal", Assertion),
    ("reset_establishment", Assertion),
    ("coherent_store_overlap", Cover),
  ]
  let properties : Array[@formal_core.FormalProperty] = []
  let bindings : Array[@formal_core.FormalSignalBinding] = [
    @formal_core.FormalSignalBinding::checked(clock, "lc_clock") catch {
      error => raise FormalContract(error)
    },
  ]
  for index, definition in definitions {
    let (name, kind) = definition
    let predicate = named_signal(top, name)
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
  @formal_core.export_yosys_clocked_properties(plan, bindings) catch {
    error => raise FormalContract(error)
  }
}
