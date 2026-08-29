///|
fn known_value(width : Int, value : UInt64) -> @wave.LogicValue raise {
  @wave.LogicValue::from_uint64(width~, value=value & width_mask(width))
}

///|
fn normalized_known(
  width : Int,
  value : UInt64,
) -> @differential.NormalizedValue raise {
  @differential.NormalizedValue::parse(
    known_value(width, value).to_bit_string(),
  )
}

///|
fn padded_hex(value : UInt64, width : Int) -> String {
  value.to_string(radix=16).pad_start((width + 3) / 4, '0')
}

///|
fn input_value(
  kind : FixtureKind,
  name : String,
  width : Int,
  cycle : Int,
  generator : SplitMix64,
) -> UInt64 {
  if name == "reset" {
    return 0UL
  }
  if kind == ReadyValid && name == "in_valid" && cycle == 1 {
    return 1UL
  }
  generator.next() & width_mask(width)
}

///|
fn input_ports(ports : ReadOnlyArray[HarnessPort]) -> Array[HarnessPort] {
  let inputs : Array[HarnessPort] = []
  for port in ports {
    if port.direction == Input && !port.signal_type.is_clock() {
      inputs.push(port)
    }
  }
  inputs
}

///|
fn drive_row(
  plan : FixturePlan,
  inputs : ArrayView[HarnessPort],
  simulator : @sim.Simulator,
  generator : SplitMix64,
  stimuli : Array[@differential.Stimulus],
  event : UInt64,
  cycle : UInt64,
  reset_asserted : Bool,
  tsv : StringBuilder,
) -> Unit raise {
  tsv.write_string(cycle.to_string())
  for port in inputs {
    let value = if reset_asserted {
      if port.signal_type is Reset {
        1UL
      } else {
        0UL
      }
    } else {
      input_value(
        plan.kind,
        port.source_name,
        port.width,
        cycle.to_int(),
        generator,
      )
    }
    stimuli.push(
      @differential.Stimulus::drive(
        event,
        cycle,
        port.source_name,
        normalized_known(port.width, value),
      ),
    )
    simulator.set_input(port.source_name, known_value(port.width, value))
    tsv.write_char('\t')
    tsv.write_string(padded_hex(value, port.width))
  }
  tsv.write_char('\n')
}

///|
fn sample_row(
  outputs : ArrayView[HarnessPort],
  simulator : @sim.Simulator,
  stimuli : Array[@differential.Stimulus],
  observations : Array[@differential.Observation],
  event : UInt64,
  cycle : UInt64,
  tsv : StringBuilder,
) -> Unit raise {
  tsv.write_string(cycle.to_string())
  for output in outputs {
    stimuli.push(
      @differential.Stimulus::sample(event, cycle, output.source_name),
    )
    let value = simulator.output(output.source_name)
    if !value.is_fully_known() {
      raise UnsupportedUnknownExpected(tap=output.source_name, cycle~)
    }
    observations.push(
      @differential.Observation::checked(
        event,
        cycle,
        PostEdge,
        output.source_name,
        @differential.NormalizedValue::parse(value.to_bit_string()),
      ),
    )
    tsv.write_char('\t')
    tsv.write_string(padded_hex(value.to_uint64(), output.width))
  }
  tsv.write_char('\n')
}

///|
fn tsv_header(ports : ArrayView[HarnessPort]) -> String {
  let output = StringBuilder()
  output.write_string("cycle")
  for port in ports {
    output.write_char('\t')
    output.write_string(port.emitted_name)
  }
  output.write_char('\n')
  output.to_string()
}

///|
fn generate_run(
  plan : FixturePlan,
  design : @ir.Design,
  hardware_module : @ir.Module,
  ports : ReadOnlyArray[HarnessPort],
) -> (
  @differential.StimulusSequence,
  @differential.ObservationSet,
  String,
  String,
) raise {
  let clock = clock_port(ports)
  ignore(reset_port(ports))
  let inputs = input_ports(ports)
  let outputs = output_ports(ports)
  let simulator = @sim.Simulator::prepare(hardware_module)
  let generator = SplitMix64::new(plan.seed)
  let stimuli : Array[@differential.Stimulus] = []
  let observations : Array[@differential.Observation] = []
  let stimulus_tsv = StringBuilder()
  let expected_rows = StringBuilder()
  stimulus_tsv.write_string(tsv_header(inputs))
  expected_rows.write_string(tsv_header(outputs))

  // Cycle zero is the synchronous reset preamble. The plan's cycle count
  // includes only subsequent rows.
  drive_row(
    plan, inputs, simulator, generator, stimuli, 0UL, 0UL, true, stimulus_tsv,
  )
  stimuli.push(@differential.Stimulus::rising_edge(1UL, 0UL, clock.source_name))
  simulator.rising_edge(clock.source_name)
  for cycle in 1..<=plan.post_reset_cycles {
    let cycle_u64 = cycle.to_uint64()
    let drive_event = (cycle * 3).to_uint64()
    let edge_event = drive_event + 1UL
    let sample_event = drive_event + 2UL
    drive_row(
      plan, inputs, simulator, generator, stimuli, drive_event, cycle_u64, false,
      stimulus_tsv,
    )
    stimuli.push(
      @differential.Stimulus::rising_edge(
        edge_event,
        cycle_u64,
        clock.source_name,
      ),
    )
    simulator.rising_edge(clock.source_name)
    sample_row(
      outputs, simulator, stimuli, observations, sample_event, cycle_u64, expected_rows,
    )
  }
  let design_identity = @differential.DesignIdentity::checked(
    "lunachip.phase3/v1",
    sha256_hex(@ir_codec.serialize(design)),
  )
  let stimulus_text = stimulus_tsv.to_string()
  let result_identity = @differential.ResultIdentity::checked(
    design_identity,
    sha256_hex(stimulus_text),
  )
  let expected_tsv = StringBuilder()
  expected_tsv.write_string("LUNACHIP-PHASE3-RESULT\t1\t")
  expected_tsv.write_string(utf8_hex(design_identity.semantic_version()))
  expected_tsv.write_string("\tsha256\t")
  expected_tsv.write_string(design_identity.design_sha256())
  expected_tsv.write_string("\tsha256\t")
  expected_tsv.write_string(result_identity.stimulus_sha256())
  expected_tsv.write_char('\n')
  expected_tsv.write_string(expected_rows.to_string())
  (
    @differential.StimulusSequence::checked(design_identity, plan.seed, stimuli),
    @differential.ObservationSet::checked(result_identity, observations),
    stimulus_text,
    expected_tsv.to_string(),
  )
}
