///|
fn direct8_arbiter_property_export(
  clock_identifier : String,
) -> @formal_core.FormalExport raise {
  // Share the physical/top named clock with the parent timing contract, but
  // bind it locally inside the unchanged DUT. No hierarchical RTL reference.
  let clock = named_signal("lc_formal_direct_completion_top", "clock")
  let domain = @formal_core.ObservationDomain::rising_pre_edge(clock)
  let properties : Array[@formal_core.FormalProperty] = []
  let bindings : Array[@formal_core.FormalSignalBinding] = [
    @formal_core.FormalSignalBinding::checked(clock, clock_identifier),
  ]
  for index, name in direct8_arbiter_property_names() {
    let predicate = named_signal("lc_formal_direct_completion_top.lc_dut", name)
    properties.push(
      checked_formal_property(
        property_id(15 + index),
        name,
        Assertion,
        predicate,
        domain,
        NeverDisabled,
      ),
    )
    bindings.push(
      @formal_core.FormalSignalBinding::checked(predicate, "lc_" + name),
    )
  }
  @formal_core.export_yosys_clocked_properties(
    @formal_core.FormalPropertyPlan::checked(properties),
    bindings,
  )
}

///|
fn direct8_arbiter_overlay(
  fixture : @flux_tile.QueueConservationFixture,
  emitted : @rtl.EmittedDesign,
  exported : @formal_core.FormalExport,
) -> (String, String) raise {
  let probe = direct8_arbiter_probe(fixture)
  let (bindings, report) = direct8_arbiter_bindings(
    direct8_arbiter_aliases(fixture, probe),
    emitted,
  )
  (
    "  // BEGIN direct8 arbiter queue proof observers only\n" +
    bindings +
    direct8_arbiter_source() +
    exported.source() +
    "  // END direct8 arbiter queue proof observers only\n",
    report,
  )
}

///|
fn direct8_arbiter_dut(
  original : QueueFormalDut,
  overlay : String,
) -> QueueFormalDut raise {
  assert_eq(original.source.split("endmodule\n").count(), 2)
  let source = original.source.replace(
    old="endmodule\n",
    new=overlay + "endmodule\n",
  )
  assert_eq(source.replace(old=overlay, new=""), original.source)
  {
    identifier: original.identifier,
    filename: original.filename,
    source,
    production_filename: original.production_filename,
    production_source: original.production_source,
    ports: original.ports,
    observation_ports: original.observation_ports,
  }
}
