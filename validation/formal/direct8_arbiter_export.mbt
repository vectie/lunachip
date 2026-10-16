///|
fn direct8_arbiter_property_export(
  clock_identifier : String,
  engine_progress? : Bool = false,
  owner_support? : Bool = false,
  completed_prefix? : Bool = false,
  latency? : Bool = false,
  service_credit? : Bool = false,
) -> @formal_core.FormalExport raise {
  // Share the physical/top named clock with the parent timing contract, but
  // bind it locally inside the unchanged DUT. No hierarchical RTL reference.
  let clock = named_signal("lc_formal_direct_completion_top", "clock")
  let domain = @formal_core.ObservationDomain::rising_pre_edge(clock)
  let properties : Array[@formal_core.FormalProperty] = []
  let bindings : Array[@formal_core.FormalSignalBinding] = [
    @formal_core.FormalSignalBinding::checked(clock, clock_identifier),
  ]
  let names = direct8_arbiter_property_names().iter().to_array()
  if engine_progress {
    for name in direct8_engine_property_names(owner_support~, completed_prefix~) {
      names.push(name)
    }
  }
  if latency {
    for name in direct8_latency_property_names(service_credit~) {
      names.push(name)
    }
  }
  for index, name in names {
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
  engine_progress? : Bool = false,
  owner_support? : Bool = false,
  completed_prefix? : Bool = false,
  latency? : Bool = false,
  service_credit? : Bool = false,
) -> (String, String) raise {
  let probe = direct8_arbiter_probe(fixture)
  let aliases = direct8_arbiter_aliases(fixture, probe).iter().to_array()
  if engine_progress {
    for binding in direct8_engine_transfer_bindings(fixture, probe) {
      aliases.push(binding)
    }
    for binding in direct8_engine_compute_bindings(fixture) {
      aliases.push(binding)
    }
    if owner_support {
      for binding in direct8_engine_owner_bindings(fixture, probe) {
        aliases.push(binding)
      }
    }
  }
  let (bindings, report) = direct8_arbiter_bindings(
    ReadOnlyArray::from_array(aliases),
    emitted,
  )
  (
    "  // BEGIN direct8 arbiter queue proof observers only\n" +
    bindings +
    direct8_arbiter_source() +
    (if engine_progress {
      direct8_engine_source(owner_support~, completed_prefix~)
    } else {
      ""
    }) +
    (if latency { direct8_latency_source() } else { "" }) +
    (if service_credit { direct8_service_credit_source() } else { "" }) +
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
