///|
priv struct InputRow {
  reset : UInt64
  read_address : UInt64
  write_address0 : UInt64
  data0 : UInt64
  write_enable0 : UInt64
  read_enable : UInt64
  result_valid : UInt64
  mask0 : UInt64
  mask1 : UInt64
  write_address1 : UInt64
  data1 : UInt64
  write_enable1 : UInt64
}

///|
fn row_value(row : InputRow, name : String) -> UInt64 {
  match name {
    "reset" => row.reset
    "read_address" => row.read_address
    "write_address0" => row.write_address0
    "data0" => row.data0
    "write_enable0" => row.write_enable0
    "read_enable" => row.read_enable
    "result_valid" => row.result_valid
    "mask0" => row.mask0
    "mask1" => row.mask1
    "write_address1" => row.write_address1
    "data1" => row.data1
    "write_enable1" => row.write_enable1
    _ => 0UL
  }
}

///|
fn row_for(
  kind : FixtureKind,
  cycle : Int32,
  generator : @verilator.DeterministicPrng,
) -> InputRow {
  let depth = if kind == NonPowerOfTwo || kind == UndefinedSafe { 3 } else { 4 }
  if cycle == 0 {
    return {
      reset: 1UL,
      read_address: 0UL,
      write_address0: 0UL,
      data0: 0xa5UL,
      write_enable0: 1UL,
      read_enable: 1UL,
      result_valid: 0UL,
      mask0: 0xfUL,
      mask1: 0xfUL,
      write_address1: 1UL,
      data1: 0x5aUL,
      write_enable1: 0UL,
    }
  }
  if cycle == 1 {
    return {
      reset: 0UL,
      read_address: 0UL,
      write_address0: 1UL,
      data0: 0x11UL,
      write_enable0: 0UL,
      read_enable: 1UL,
      result_valid: 1UL,
      mask0: 0xfUL,
      mask1: 0xfUL,
      write_address1: 2UL,
      data1: 0x22UL,
      write_enable1: 0UL,
    }
  }
  if cycle <= depth {
    let address = (cycle - 1).to_uint64()
    let direct_read = kind == WholeReadNew ||
      kind == MaskedWrite ||
      kind == LowerPortIdWins
    return {
      reset: 0UL,
      read_address: if direct_read {
        address
      } else {
        0UL
      },
      write_address0: address,
      data0: (0x30 + cycle).to_uint64(),
      write_enable0: 1UL,
      read_enable: 1UL,
      result_valid: 1UL,
      mask0: 0xfUL,
      mask1: 0xfUL,
      write_address1: (address + 1UL) % depth.to_uint64(),
      data1: (0x80 + cycle).to_uint64(),
      write_enable1: 0UL,
    }
  }
  if kind == UndefinedSafe && cycle % 19 == 0 {
    return {
      reset: 0UL,
      read_address: 3UL,
      write_address0: 3UL,
      data0: 0xdeUL,
      write_enable0: 1UL,
      read_enable: 1UL,
      result_valid: 0UL,
      mask0: 0xfUL,
      mask1: 0UL,
      write_address1: 0UL,
      data1: 0UL,
      write_enable1: 0UL,
    }
  }
  if kind == UndefinedSafe && (cycle - 1) % 19 == 0 {
    return {
      reset: 0UL,
      read_address: 0UL,
      write_address0: 0UL,
      data0: 0UL,
      write_enable0: 0UL,
      read_enable: 1UL,
      result_valid: 1UL,
      mask0: 0UL,
      mask1: 0UL,
      write_address1: 0UL,
      data1: 0UL,
      write_enable1: 0UL,
    }
  }
  if kind == UndefinedSafe && cycle % 17 == 0 {
    return {
      reset: 0UL,
      read_address: 1UL,
      write_address0: 1UL,
      data0: 0xc7UL,
      write_enable0: 1UL,
      read_enable: 1UL,
      result_valid: 0UL,
      mask0: 0xfUL,
      mask1: 0UL,
      write_address1: 0UL,
      data1: 0UL,
      write_enable1: 0UL,
    }
  }
  if kind == UndefinedSafe && (cycle - 1) % 17 == 0 {
    return {
      reset: 0UL,
      read_address: 1UL,
      write_address0: 0UL,
      data0: 0UL,
      write_enable0: 0UL,
      read_enable: 1UL,
      result_valid: 1UL,
      mask0: 0UL,
      mask1: 0UL,
      write_address1: 0UL,
      data1: 0UL,
      write_enable1: 0UL,
    }
  }
  let random0 = generator.next()
  let random1 = generator.next()
  let random2 = generator.next()
  let random3 = generator.next()
  let mut read_address = random0 % depth.to_uint64()
  let mut write_address0 = random1 % depth.to_uint64()
  if kind == UndefinedSafe && write_address0 == read_address {
    write_address0 = (write_address0 + 1UL) % depth.to_uint64()
  }
  if kind == NoChange && cycle % 2 == 0 {
    write_address0 = read_address
  }
  if kind == LowerPortIdWins {
    read_address = write_address0
  }
  if kind == NonPowerOfTwo && cycle % 7 == 0 {
    read_address = 3UL
  }
  if kind == NonPowerOfTwo && cycle % 11 == 0 {
    write_address0 = 3UL
  }
  let write_address1 = if kind == LowerPortIdWins {
    write_address0
  } else {
    random2 % depth.to_uint64()
  }
  {
    reset: 0UL,
    read_address,
    write_address0,
    data0: random2 & 0xffUL,
    write_enable0: if (kind == Enables && cycle % 3 == 0) ||
      (kind == NonPowerOfTwo && cycle % 11 == 0) {
      0UL
    } else {
      1UL
    },
    read_enable: if (kind == Enables && cycle % 5 == 0) ||
      (kind == NonPowerOfTwo && cycle % 7 == 0) {
      0UL
    } else {
      1UL
    },
    result_valid: 1UL,
    mask0: if kind == LowerPortIdWins {
      if cycle % 2 == 0 {
        0x5UL
      } else {
        0x3UL
      }
    } else {
      random3 & 0xfUL
    },
    mask1: if kind == LowerPortIdWins {
      if cycle % 2 == 0 {
        0xfUL
      } else {
        0xcUL
      }
    } else {
      0UL
    },
    write_address1,
    data1: random3 & 0xffUL,
    write_enable1: if kind == LowerPortIdWins {
      1UL
    } else {
      0UL
    },
  }
}

///|
fn drive_row(
  row : InputRow,
  inputs : ArrayView[@verilator.HarnessPort],
  simulator : @sim.Simulator,
  stimuli : Array[@differential.Stimulus],
  event : UInt64,
  cycle : UInt64,
  tsv : StringBuilder,
) -> Unit raise {
  tsv.write_string(cycle.to_string())
  for port in inputs {
    let value = row_value(row, port.source_name)
    let logic = @verilator.known_value(port.width, value)
    stimuli.push(
      @differential.Stimulus::drive(
        event,
        cycle,
        port.source_name,
        @verilator.normalized_known(port.width, value),
      ),
    )
    simulator.set_input(port.source_name, logic)
    tsv.write_char('\t')
    tsv.write_string(@verilator.padded_hex(value, port.width))
  }
  tsv.write_char('\n')
}

///|
fn sample_row(
  outputs : ArrayView[@verilator.HarnessPort],
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
      raise UnknownExpected(tap=output.source_name, cycle~)
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
    tsv.write_string(@verilator.padded_hex(value.to_uint64(), output.width))
  }
  tsv.write_char('\n')
}

///|
fn result_protocol() -> @verilator.ResultProtocol raise {
  @verilator.ResultProtocol::checked(
    "LUNACHIP-PHASE4-RESULT", "1", "lunachip.phase4/v1",
  )
}

///|
fn generate_run(
  plan : FixturePlan,
  design : @ir.Design,
  hardware_module : @ir.Module,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> (
  @differential.StimulusSequence,
  @differential.ObservationSet,
  String,
  String,
) raise {
  let clock = @verilator.clock_port(ports)
  ignore(@verilator.reset_port(ports))
  let inputs = @verilator.input_ports(ports)
  let outputs = @verilator.output_ports(ports)
  let simulator = @sim.Simulator::prepare(hardware_module)
  let generator = @verilator.DeterministicPrng::new(plan.seed)
  let stimuli : Array[@differential.Stimulus] = []
  let observations : Array[@differential.Observation] = []
  let stimulus_tsv = StringBuilder()
  let expected_rows = StringBuilder()
  stimulus_tsv.write_string(@verilator.tsv_header(inputs))
  expected_rows.write_string(@verilator.tsv_header(outputs))
  let preamble = row_for(plan.kind, 0, generator)
  drive_row(preamble, inputs, simulator, stimuli, 0UL, 0UL, stimulus_tsv)
  stimuli.push(@differential.Stimulus::rising_edge(1UL, 0UL, clock.source_name))
  simulator.rising_edge(clock.source_name)
  for cycle in 1..<=plan.post_reset_cycles {
    let cycle_u64 = cycle.to_uint64()
    let drive_event = (cycle * 3).to_uint64()
    let edge_event = drive_event + 1UL
    let sample_event = drive_event + 2UL
    drive_row(
      row_for(plan.kind, cycle, generator),
      inputs,
      simulator,
      stimuli,
      drive_event,
      cycle_u64,
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
  let protocol = result_protocol()
  let design_identity = @differential.DesignIdentity::checked(
    protocol.semantic_version(),
    @verilator.sha256_hex(@ir_codec.serialize(design)),
  )
  let stimulus_text = stimulus_tsv.to_string()
  let result_identity = @differential.ResultIdentity::checked(
    design_identity,
    @verilator.sha256_hex(stimulus_text),
  )
  let expected_tsv = StringBuilder()
  expected_tsv.write_string(protocol.magic())
  expected_tsv.write_char('\t')
  expected_tsv.write_string(protocol.version())
  expected_tsv.write_char('\t')
  expected_tsv.write_string(
    @verilator.utf8_hex(design_identity.semantic_version()),
  )
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
