///|
const RESULT_MAGIC : String = "LUNACHIP-PHASE5-HANDSHAKE-RESULT"

///|
const RESULT_VERSION : String = "2"

///|
const RESULT_SEMANTIC_VERSION : String = "lunachip.phase5-handshake-differential/v1"

///|
fn parse_binary(value : String) -> UInt64 {
  let mut result = 0UL
  for symbol in value {
    result = (result << 1) | (if symbol == '1' { 1UL } else { 0UL })
  }
  result
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
fn result_identity_prefix(
  design : @ir.Design,
  stimulus_tsv : String,
  ticks_per_source_unit : UInt64,
) -> String raise {
  let design_identity = @differential.DesignIdentity::checked(
    RESULT_SEMANTIC_VERSION,
    @verilator.sha256_hex(@ir_codec.serialize(design)),
  )
  let identity = @differential.ResultIdentity::checked(
    design_identity,
    @verilator.sha256_hex(stimulus_tsv),
  )
  "\{RESULT_MAGIC}\t\{RESULT_VERSION}\t\{@verilator.utf8_hex(design_identity.semantic_version())}\tsha256\t\{design_identity.design_sha256()}\tsha256\t\{identity.stimulus_sha256()}\ttimebase\t\{ticks_per_source_unit}\n"
}

///|
fn result_header(outputs : ArrayView[@verilator.HarnessPort]) -> String {
  let out = StringBuilder()
  out.write_string("time\tboundary")
  for output in outputs {
    out.write_string("\t\{output.source_name()}")
  }
  out.write_char('\n')
  out.to_string()
}

///|
fn append_result_row(
  out : StringBuilder,
  event : @verilator.AtomicStimulusEvent,
  outputs : ArrayView[@verilator.HarnessPort],
  simulator : @sim.Simulator,
) -> Unit raise {
  out.write_string("\{event.time()}\t\{event.boundary()}")
  for output in outputs {
    let value = simulator.output(output.source_name())
    if !value.is_fully_known() {
      raise InvalidActualResult(
        reason="LunaWave produced unknown output \{output.source_name()}",
        row=event.boundary().to_int() + 3,
      )
    }
    out.write_string(
      "\t\{@verilator.padded_hex(value.to_uint64(), output.width())}",
    )
  }
  out.write_char('\n')
}

///|
fn generate_result_tsv(
  design : @ir.Design,
  hardware_module : @ir.Module,
  ports : ReadOnlyArray[@verilator.HarnessPort],
  stimulus : @verilator.AtomicStimulus,
  sequential_edges : Bool,
) -> String raise {
  let outputs = @verilator.output_ports(ports)
  let simulator = @sim.Simulator::prepare(hardware_module)
  let out = StringBuilder()
  out.write_string(
    result_identity_prefix(
      design,
      stimulus.to_tsv(),
      stimulus.ticks_per_source_unit(),
    ),
  )
  out.write_string(result_header(outputs))
  for event in stimulus.events() {
    if sequential_edges {
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
    append_result_row(out, event, outputs, simulator)
  }
  out.to_string()
}

///|
fn result_lines(source : String) -> Array[String] raise HandshakeFixtureError {
  if !source.has_suffix("\n") {
    raise InvalidActualResult(reason="missing final newline", row=0)
  }
  source.split("\n").map(line => line.to_owned()).to_array()
}

///|
fn result_cells(line : String) -> Array[String] {
  line.split("\t").map(cell => cell.to_owned()).to_array()
}

///|
fn canonical_result_uint(
  text : String,
  row : Int,
  field : String,
) -> UInt64 raise HandshakeFixtureError {
  if text.is_empty() || (text.length() > 1 && text[0] == '0') {
    raise InvalidActualResult(reason="noncanonical \{field}", row~)
  }
  @string.parse_uint64(text) catch {
    _ => raise InvalidActualResult(reason="invalid \{field}", row~)
  }
}

///|
fn canonical_hex(text : String) -> Bool {
  if text.is_empty() {
    return false
  }
  for symbol in text {
    if !((symbol >= '0' && symbol <= '9') || (symbol >= 'a' && symbol <= 'f')) {
      return false
    }
  }
  true
}

///|
fn first_result_mismatch(
  expected_source : String,
  actual_source : String,
) -> AtomicMismatch? raise HandshakeFixtureError {
  let expected_lines = result_lines(expected_source)
  let actual_lines = result_lines(actual_source)
  if actual_lines.length() != expected_lines.length() {
    raise InvalidActualResult(reason="wrong result row count", row=0)
  }
  if actual_lines[0] != expected_lines[0] {
    raise InvalidActualResult(reason="identity header mismatch", row=1)
  }
  if actual_lines[1] != expected_lines[1] {
    raise InvalidActualResult(reason="output header mismatch", row=2)
  }
  let output_names = result_cells(expected_lines[1])
  for index in 2..<(expected_lines.length() - 1) {
    let expected = result_cells(expected_lines[index])
    let observed = result_cells(actual_lines[index])
    if observed.length() != expected.length() {
      raise InvalidActualResult(reason="wrong column count", row=index + 1)
    }
    let time = canonical_result_uint(observed[0], index + 1, "time")
    let boundary = canonical_result_uint(observed[1], index + 1, "boundary")
    if observed[0] != expected[0] || observed[1] != expected[1] {
      raise InvalidActualResult(
        reason="exact time or boundary mismatch",
        row=index + 1,
      )
    }
    for column in 2..<observed.length() {
      if !canonical_hex(observed[column]) ||
        observed[column].length() != expected[column].length() {
        raise InvalidActualResult(
          reason="noncanonical hexadecimal result",
          row=index + 1,
        )
      }
      if observed[column] != expected[column] {
        return Some({
          time,
          boundary,
          output: output_names[column],
          expected: expected[column],
          actual: observed[column],
        })
      }
    }
  }
  None
}

///|
pub fn HandshakeFixtureBundle::compare_actual(
  self : HandshakeFixtureBundle,
  actual : String,
) -> AtomicMismatch? raise HandshakeFixtureError {
  first_result_mismatch(self.expected_tsv, actual)
}
