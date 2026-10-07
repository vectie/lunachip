///|
fn fetched_useful_property_export() -> (
  @formal_core.FormalExport,
  ReadOnlyArray[String],
  ReadOnlyArray[String],
  ReadOnlyArray[String],
) raise FormalGateError {
  // Keep the five original legal-host predicates and all eight original public
  // conclusions, with their original IDs. Old pilot covers are not selected.
  let definitions = flux_tile_property_definitions()[:13].to_owned()
  for
    definition in [
      ("fu_initial_only_reset", @formal_core.FormalPropertyKind::Assumption),
      ("fu_public_producer_r1_c1", Assumption),
      ("fu_owned_response_offer_h1", Assumption),
      ("fu_public_history", Assertion),
      ("fu_write_identity", Assertion),
      ("fu_retirement_identity", Assertion),
      ("fu_useful_store_cover", Cover),
    ] {
    definitions.push(definition)
  }
  let path = "lc_formal_fetched_useful_top"
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
  for index, (name, kind) in definitions {
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
  let assumptions : Array[String] = []
  let assertions : Array[String] = []
  let covers : Array[String] = []
  for property in exported.properties() {
    match property.kind() {
      Assumption => assumptions.push(property.stable_name())
      Assertion => assertions.push(property.stable_name())
      Cover => covers.push(property.stable_name())
    }
  }
  (
    exported,
    ReadOnlyArray::from_array(assumptions),
    ReadOnlyArray::from_array(assertions),
    ReadOnlyArray::from_array(covers),
  )
}

///|
fn fetched_useful_harness(
  dut : FluxTileFormalDut,
  exported : String,
) -> String raise FormalGateError {
  // Reuse the complete original public monitor verbatim, not a second safety
  // implementation. No hierarchical observations, new DUT ports or cuts.
  let original = flux_tile_harness(PublicTransport, dut, "")
  let header = "module lc_formal_flux_tile_top;\n"
  let footer = "endmodule\n`default_nettype wire\n"
  dependency_require_marker(original, header)
  dependency_require_marker(original, footer)
  original
  .replace(old=header, new="module lc_formal_fetched_useful_top;\n")
  .replace(
    old=footer,
    new=fetched_useful_host_source() +
      fetched_useful_monitor_source() +
      exported +
      footer,
  )
}
