///|
priv struct InputRow {
  reset : UInt64
  config_valid : UInt64
  config_base : UInt64
  publish_valid : UInt64
  publish_producer : UInt64
  completion_ready : UInt64
  bus : HostDrive
}

///|
fn row_value(
  row : InputRow,
  name : String,
  config_origin~ : UInt64 = 0UL,
) -> UInt64 raise {
  match name {
    "reset" => row.reset
    "config_valid" => row.config_valid
    "config_base" => row.config_base
    "config_origin" => config_origin
    "publish_valid" => row.publish_valid
    "publish_producer" => row.publish_producer
    "completion_ready" => row.completion_ready
    "memory_request_ready" => row.bus.request_ready
    "memory_response_valid" => row.bus.response_valid
    "memory_response_tag" => row.bus.response_tag
    "memory_response_fault" => row.bus.response_fault
    "memory_response_data" => row.bus.response_data
    _ => fail("unhandled fixture input: \{name}")
  }
}

///|
fn drive_row(
  simulator : @sim.Simulator,
  ports : ArrayView[@verilator.HarnessPort],
  row : InputRow,
  cycle : UInt64,
  stimuli : Array[@differential.Stimulus],
  tsv : StringBuilder,
  config_origin~ : UInt64 = 0UL,
) -> Unit raise {
  tsv.write_string(cycle.to_string())
  for port in ports {
    let value = row_value(row, port.source_name, config_origin~)
    simulator.set_input(
      port.source_name,
      @verilator.known_value(port.width, value),
    )
    stimuli.push(
      @differential.Stimulus::drive(
        cycle * 3UL,
        cycle,
        port.source_name,
        @verilator.normalized_known(port.width, value),
      ),
    )
    tsv.write_char('\t')
    tsv.write_string(@verilator.padded_hex(value, port.width))
  }
  tsv.write_char('\n')
  simulator.settle()
}

///|
fn sample_row(
  simulator : @sim.Simulator,
  ports : ArrayView[@verilator.HarnessPort],
  cycle : UInt64,
  stimuli : Array[@differential.Stimulus],
  observations : Array[@differential.Observation],
  tsv : StringBuilder,
) -> Unit raise {
  tsv.write_string(cycle.to_string())
  for port in ports {
    let value = simulator.output(port.source_name)
    if !value.is_fully_known() {
      fail("unknown output \{port.source_name} at cycle \{cycle}")
    }
    let event = cycle * 3UL + 2UL
    stimuli.push(@differential.Stimulus::sample(event, cycle, port.source_name))
    observations.push(
      @differential.Observation::checked(
        event,
        cycle,
        PostEdge,
        port.source_name,
        @differential.NormalizedValue::parse(value.to_bit_string()),
      ),
    )
    tsv.write_char('\t')
    tsv.write_string(@verilator.padded_hex(value.to_uint64(), port.width))
  }
  tsv.write_char('\n')
}

///|
priv struct FixtureTrace {
  simulator : @sim.Simulator
  clock : String
  inputs : Array[@verilator.HarnessPort]
  outputs : Array[@verilator.HarnessPort]
  stimuli : Array[@differential.Stimulus]
  observations : Array[@differential.Observation]
  stimulus_tsv : StringBuilder
  expected_rows : StringBuilder
}

///|
fn fixture_trace(
  hardware : @ir.Module,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> FixtureTrace raise {
  let inputs = @verilator.input_ports(ports)
  let outputs = @verilator.output_ports(ports)
  let stimulus_tsv = StringBuilder()
  let expected_rows = StringBuilder()
  stimulus_tsv.write_string(@verilator.tsv_header(inputs))
  expected_rows.write_string(@verilator.tsv_header(outputs))
  {
    simulator: @sim.Simulator::prepare(hardware),
    clock: @verilator.clock_port(ports).source_name,
    inputs,
    outputs,
    stimuli: [],
    observations: [],
    stimulus_tsv,
    expected_rows,
  }
}

///|
fn FixtureTrace::drive(
  self : FixtureTrace,
  row : InputRow,
  cycle : UInt64,
  config_origin~ : UInt64 = 0UL,
) -> Unit raise {
  drive_row(
    self.simulator,
    self.inputs,
    row,
    cycle,
    self.stimuli,
    self.stimulus_tsv,
    config_origin~,
  )
}

///|
fn FixtureTrace::edge(
  self : FixtureTrace,
  cycle : UInt64,
  observe~ : Bool,
) -> Unit raise {
  self.stimuli.push(
    @differential.Stimulus::rising_edge(cycle * 3UL + 1UL, cycle, self.clock),
  )
  self.simulator.rising_edge(self.clock)
  if observe {
    sample_row(
      self.simulator,
      self.outputs,
      cycle,
      self.stimuli,
      self.observations,
      self.expected_rows,
    )
  }
}

///|
fn FixtureTrace::finish(
  self : FixtureTrace,
  design : @ir.Design,
  cycles : Int32,
  summary : String,
) -> FixtureRun raise {
  let protocol = result_protocol()
  let identity = @differential.DesignIdentity::checked(
    protocol.semantic_version(),
    @verilator.sha256_hex(@ir_codec.serialize(design)),
  )
  let stimulus_text = self.stimulus_tsv.to_string()
  let result_identity = @differential.ResultIdentity::checked(
    identity,
    @verilator.sha256_hex(stimulus_text),
  )
  let expected_tsv = "\{protocol.magic()}\t\{protocol.version()}\t\{@verilator.utf8_hex(identity.semantic_version())}\tsha256\t\{identity.design_sha256()}\tsha256\t\{result_identity.stimulus_sha256()}\n" +
    self.expected_rows.to_string()
  {
    stimulus: @differential.StimulusSequence::checked(
      identity,
      0UL,
      self.stimuli,
    ),
    expected: @differential.ObservationSet::checked(
      result_identity,
      self.observations,
    ),
    stimulus_tsv: stimulus_text,
    expected_tsv,
    cycles,
    summary,
  }
}
