///|
const RESULT_MAGIC : String = "LUNACHIP-PHASE5-FIFO-RESULT"

///|
const RESULT_VERSION : String = "2"

///|
const RESULT_SEMANTIC_VERSION : String = "lunachip.phase5-fifo-differential/v1"

///|
fn parse_binary(value : String) -> UInt64 {
  let mut out = 0UL
  for c in value {
    out = (out << 1) | (if c == '1' { 1UL } else { 0UL })
  }
  out
}

///|
fn drive_logic(value : @differential.NormalizedValue) -> @wave.LogicValue raise {
  @wave.LogicValue::from_uint64(
    width=value.width(),
    value=parse_binary(value.value_bits()),
  )
}

///|
fn simulator_event(
  event : @verilator.AtomicStimulusEvent,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> @sim.TimestampEvent raise {
  let drives : Array[@sim.InputDrive] = []
  for drive in event.drives() {
    drives.push(
      @sim.InputDrive::checked(
        source_port_name(ports, drive.name()),
        drive_logic(drive.value()),
      ),
    )
  }
  @sim.TimestampEvent::checked(
    @sim.SimulationTime::from_uint64(event.time()),
    drives,
    event.domains().map(@ir.ClockDomainId::new),
  )
}

///|
fn identity_prefix(
  design : @ir.Design,
  stimulus : @verilator.AtomicStimulus,
) -> String raise {
  let d = @differential.DesignIdentity::checked(
    RESULT_SEMANTIC_VERSION,
    @verilator.sha256_hex(@ir_codec.serialize(design)),
  )
  let r = @differential.ResultIdentity::checked(
    d,
    @verilator.sha256_hex(stimulus.to_tsv()),
  )
  "\{RESULT_MAGIC}\t\{RESULT_VERSION}\t\{@verilator.utf8_hex(d.semantic_version())}\tsha256\t\{d.design_sha256()}\tsha256\t\{r.stimulus_sha256()}\ttimebase\t\{stimulus.ticks_per_source_unit()}\n"
}

///|
fn output_header(outputs : ArrayView[@verilator.HarnessPort]) -> String {
  let out = StringBuilder()
  out.write_string("time\tboundary")
  for port in outputs {
    out.write_string("\t\{port.source_name()}")
  }
  out.write_char('\n')
  out.to_string()
}

///|
fn drive_value(
  event : @verilator.AtomicStimulusEvent,
  ports : ReadOnlyArray[@verilator.HarnessPort],
  name : String,
) -> UInt64 raise FifoFixtureError {
  let emitted = emitted_port_name(ports, name)
  for drive in event.drives() {
    if drive.name() == emitted {
      return parse_binary(drive.value().value_bits())
    }
  }
  raise MissingPortMapping(name)
}

///|
fn payload_from_drives(
  kind : FifoFixtureKind,
  event : @verilator.AtomicStimulusEvent,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> Array[UInt64] raise {
  if kind.aggregate() {
    [
      drive_value(event, ports, "source_word"),
      drive_value(event, ports, "source_tag"),
      drive_value(event, ports, "source_lane0"),
      drive_value(event, ports, "source_lane1"),
      drive_value(event, ports, "source_lane2"),
    ]
  } else {
    [drive_value(event, ports, "source_lane0")]
  }
}

///|
fn payload_from_outputs(
  kind : FifoFixtureKind,
  simulator : @sim.Simulator,
) -> Array[UInt64] raise {
  if kind.aggregate() {
    [
      simulator.output("destination_word").to_uint64(),
      simulator.output("destination_tag").to_uint64(),
      simulator.output("destination_lane0").to_uint64(),
      simulator.output("destination_lane1").to_uint64(),
      simulator.output("destination_lane2").to_uint64(),
    ]
  } else {
    [simulator.output("destination_lane0").to_uint64()]
  }
}

///|
fn require_reset_coverage(
  coverage : FifoCoverage,
) -> Unit raise FifoFixtureError {
  if coverage.source_reset_assertions == 0 ||
    coverage.source_reset_releases == 0 ||
    coverage.destination_reset_assertions == 0 ||
    coverage.destination_reset_releases == 0 {
    raise IncompleteCoverage("missing per-domain reset assertion or release")
  }
}

///|
fn generate_results(
  kind : FifoFixtureKind,
  design : @ir.Design,
  hardware_module : @ir.Module,
  ports : ReadOnlyArray[@verilator.HarnessPort],
  stimulus : @verilator.AtomicStimulus,
  sequential : Bool,
) -> (String, FifoCoverage) raise {
  let outputs = @verilator.output_ports(ports)
  let simulator = @sim.Simulator::prepare(hardware_module)
  let rows = StringBuilder()
  rows.write_string(identity_prefix(design, stimulus))
  rows.write_string(output_header(outputs))
  let ledger : Array[Array[UInt64]] = []
  let mut read_index = 0
  let mut enq = 0
  let mut deq = 0
  let mut eo = 0
  let mut do_ = 0
  let mut both = 0
  let mut coincidences = 0
  let mut stalls = 0
  let mut full_in = 0
  let mut full_out = 0
  let mut empty_in = 0
  let mut empty_out = 0
  let mut source_reset_assertions = 0
  let mut source_reset_releases = 0
  let mut destination_reset_assertions = 0
  let mut destination_reset_releases = 0
  let mut source_reset_was_asserted = false
  let mut destination_reset_was_asserted = false
  for event in stimulus.events() {
    let src = event.domains().contains(0)
    let dst = event.domains().contains(3)
    let ready_known = simulator.output("source_ready").is_fully_known()
    let valid_known = simulator.output("destination_valid").is_fully_known()
    let pre_ready = ready_known &&
      simulator.output("source_ready").to_uint64() == 1UL
    let pre_valid = valid_known &&
      simulator.output("destination_valid").to_uint64() == 1UL
    let take = dst &&
      pre_valid &&
      drive_value(event, ports, "destination_ready") == 1UL
    let put = src &&
      pre_ready &&
      drive_value(event, ports, "source_valid") == 1UL
    let source_reset_now = drive_value(event, ports, "source_reset") == 1UL
    let destination_reset_now = drive_value(event, ports, "destination_reset") ==
      1UL
    if src {
      if source_reset_now && !source_reset_was_asserted {
        source_reset_assertions += 1
      }
      if !source_reset_now && source_reset_was_asserted {
        source_reset_releases += 1
      }
      source_reset_was_asserted = source_reset_now
    }
    if dst {
      if destination_reset_now && !destination_reset_was_asserted {
        destination_reset_assertions += 1
      }
      if !destination_reset_now && destination_reset_was_asserted {
        destination_reset_releases += 1
      }
      destination_reset_was_asserted = destination_reset_now
    }
    if src && dst {
      coincidences += 1
    }
    if dst && pre_valid && !take {
      stalls += 1
    }
    if take {
      if read_index >= ledger.length() {
        raise LedgerUnderflow(boundary=event.boundary())
      }
      let actual = payload_from_outputs(kind, simulator)
      let expected = ledger[read_index]
      for i, value in actual {
        if value != expected[i] {
          raise LedgerMismatch(
            boundary=event.boundary(),
            leaf=i,
            expected=expected[i],
            actual=value,
          )
        }
      }
      read_index += 1
      deq += 1
    }
    if put {
      ledger.push(payload_from_drives(kind, event, ports))
      enq += 1
    }
    if put && take {
      both += 1
    } else if put {
      eo += 1
    } else if take {
      do_ += 1
    }
    if sequential {
      for drive in event.drives() {
        simulator.set_input(
          source_port_name(ports, drive.name()),
          drive_logic(drive.value()),
        )
      }
      simulator.settle()
      for domain in event.domains() {
        simulator.rising_edge(domain_clock_name(domain))
      }
    } else {
      simulator.apply_event(simulator_event(event, ports))
    }
    let post_ready = simulator.output("source_ready").to_uint64() == 1UL
    let post_valid = simulator.output("destination_valid").to_uint64() == 1UL
    let out_of_reset = drive_value(event, ports, "source_reset") == 0UL &&
      drive_value(event, ports, "destination_reset") == 0UL
    if out_of_reset && ready_known && valid_known {
      if pre_ready && !post_ready {
        full_in += 1
      }
      if !pre_ready && post_ready {
        full_out += 1
      }
      if !pre_valid && post_valid {
        empty_out += 1
      }
      if pre_valid && !post_valid {
        empty_in += 1
      }
    }
    rows.write_string("\{event.time()}\t\{event.boundary()}")
    for output in outputs {
      let value = simulator.output(output.source_name())
      if !value.is_fully_known() {
        raise InvalidActualResult(
          reason="unknown output \{output.source_name()}",
          row=event.boundary().to_int() + 3,
        )
      }
      rows.write_string(
        "\t\{@verilator.padded_hex(value.to_uint64(), output.width())}",
      )
    }
    rows.write_char('\n')
  }
  let coverage : FifoCoverage = {
    enqueues: enq,
    dequeues: deq,
    enqueue_only: eo,
    dequeue_only: do_,
    simultaneous: both,
    coincidences,
    backpressure: stalls,
    full_entries: full_in,
    full_exits: full_out,
    empty_entries: empty_in,
    empty_exits: empty_out,
    write_wraps: enq / kind.depth(),
    read_wraps: deq / kind.depth(),
    source_reset_assertions,
    source_reset_releases,
    destination_reset_assertions,
    destination_reset_releases,
  }
  if !sequential {
    if read_index != ledger.length() {
      raise IncompleteCoverage(
        "ledger did not drain: \{read_index}/\{ledger.length()}",
      )
    }
    if coverage.write_wraps < 2 ||
      coverage.read_wraps < 2 ||
      eo == 0 ||
      do_ == 0 ||
      both == 0 ||
      coincidences == 0 ||
      stalls == 0 ||
      full_in == 0 ||
      full_out == 0 ||
      empty_in == 0 ||
      empty_out == 0 {
      raise IncompleteCoverage(
        "wraps=\{coverage.write_wraps}/\{coverage.read_wraps} only=\{eo}/\{do_} both=\{both} coincident=\{coincidences} stalls=\{stalls} full=\{full_in}/\{full_out} empty=\{empty_in}/\{empty_out}",
      )
    }
    require_reset_coverage(coverage)
  }
  (rows.to_string(), coverage)
}
