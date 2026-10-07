///|
fn direct_completion_property_definitions(
  fixture : DirectCompletionFixture,
) -> Array[(String, @formal_core.FormalPropertyKind)] {
  let definitions : Array[(String, @formal_core.FormalPropertyKind)] = [
    ("dc_initial_only_reset", Assumption),
    ("dc_host_descriptor_stable", Assumption),
    ("dc_host_owned_success_response", Assumption),
    ("dc_host_response_stable", Assumption),
    ("dc_host_request_ready_r2", Assumption),
    ("dc_host_response_offer_h2", Assumption),
    ("dc_host_completion_ready_c2", Assumption),
    ("dc_ordinal_history", Assertion),
    ("dc_request_stable", Assertion),
    ("dc_completion_stable", Assertion),
    ("dc_transport_serial_owned", Assertion),
    ("dc_response_readiness", Assertion),
    ("dc_watched_retirement_deadline", Assertion),
    ("dc_watched_terminal_cover", Cover),
    ("dc_watched_retirement_cover", Cover),
    ("dc_useful_store_cover", Cover),
  ]
  if fixture is UsefulStore {
    definitions.push(("dc_public_producer_sequence", Assumption))
  }
  definitions
}

///|
fn direct_completion_property_export(
  fixture : DirectCompletionFixture,
) -> (
  @formal_core.FormalExport,
  ReadOnlyArray[String],
  ReadOnlyArray[String],
  ReadOnlyArray[String],
  ReadOnlyArray[String],
) raise FormalGateError {
  let path = "lc_formal_direct_completion_top"
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
  for index, definition in direct_completion_property_definitions(fixture) {
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
  let fairness : Array[String] = []
  let assertions : Array[String] = []
  let covers : Array[String] = []
  for item in exported.properties() {
    match item.kind() {
      Assumption =>
        if item.source_name() == "dc_host_request_ready_r2" ||
          item.source_name() == "dc_host_response_offer_h2" ||
          item.source_name() == "dc_host_completion_ready_c2" {
          fairness.push(item.stable_name())
        } else {
          legal.push(item.stable_name())
        }
      Assertion => assertions.push(item.stable_name())
      Cover => covers.push(item.stable_name())
    }
  }
  (
    exported,
    ReadOnlyArray::from_array(legal),
    ReadOnlyArray::from_array(fairness),
    ReadOnlyArray::from_array(assertions),
    ReadOnlyArray::from_array(covers),
  )
}

///|
fn direct_completion_timing_contract(
  domain : @ir.ClockDomainId,
  legal : ReadOnlyArray[String],
  fairness : ReadOnlyArray[String],
) -> @formal_core.FormalTimingContract raise FormalGateError {
  let clock_signal = named_signal("lc_formal_direct_completion_top", "clock")
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
    fairness,
    AtomicGlobalPreState,
  ) catch {
    error => raise FormalContract(error)
  }
}

///|
fn direct_completion_harness(
  fixture : DirectCompletionFixture,
  dut : QueueFormalDut,
  exported : String,
) -> String raise FormalGateError {
  if dut.observation_ports.length() != 115 {
    raise InvalidFormalBundleIdentity(
      "direct completion: exact existing observation roster",
    )
  }
  let out = StringBuilder()
  out.write_string(
    "`default_nettype none\nmodule lc_formal_direct_completion_top;\n  logic lc_clock = 1'b0;\n  always @($global_clock) lc_clock <= ~lc_clock;\n",
  )
  for port in dut.ports {
    if port.role != "clock" {
      let symbolic = if port.input && port.role != "reset" {
        "(* anyseq *) "
      } else {
        ""
      }
      out.write_string(
        "  \{symbolic}logic \{toggle_formal_width_range(port.width)}lc_\{port.role};\n",
      )
    }
  }
  for port in dut.observation_ports {
    out.write_string(
      "  logic \{toggle_formal_width_range(port.width)}lc_o_\{port.role};\n",
    )
  }
  out.write_string("  \{dut.identifier} lc_dut (\n")
  for port in dut.ports {
    out.write_string("    .\{port.identifier}(lc_\{port.role}),\n")
  }
  for index, port in dut.observation_ports {
    out.write_string("    .\{port.identifier}(lc_o_\{port.role})")
    out.write_string(
      if index + 1 == dut.observation_ports.length() {
        "\n"
      } else {
        ",\n"
      },
    )
  }
  out.write_string("  );\n")
  out.write_string(direct_completion_host_source())
  out.write_string(
    direct_completion_monitor_source(fixture is NegativeDeadline),
  )
  out.write_string(direct_completion_useful_source())
  out.write_string(exported)
  out.write_string("endmodule\n`default_nettype wire\n")
  out.to_string()
}
