///|
priv struct InputRow {
  reset : UInt64
  config_valid : UInt64
  publish_valid : UInt64
  publish_producer : UInt64
  completion_ready : UInt64
  bus : HostDrive
}

///|
fn row_value(row : InputRow, name : String) -> UInt64 raise {
  match name {
    "reset" => row.reset
    "config_valid" => row.config_valid
    "config_base" => 512UL
    "config_origin" => 0UL
    "publish_valid" => row.publish_valid
    "publish_producer" => row.publish_producer
    "completion_ready" => row.completion_ready
    "memory_request_ready" => row.bus.request_ready
    "memory_response_valid" => row.bus.response_valid
    "memory_response_tag" => row.bus.response_tag
    "memory_response_fault" => 0UL
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
) -> Unit raise {
  tsv.write_string(cycle.to_string())
  for port in ports {
    let value = row_value(row, port.source_name)
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
fn generate_run(
  design : @ir.Design,
  hardware : @ir.Module,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> FixtureRun raise {
  let simulator = @sim.Simulator::prepare(hardware)
  let host = host()
  let clock = @verilator.clock_port(ports).source_name
  let inputs = @verilator.input_ports(ports)
  let outputs = @verilator.output_ports(ports)
  let stimuli : Array[@differential.Stimulus] = []
  let observations : Array[@differential.Observation] = []
  let stimulus_tsv = StringBuilder()
  let expected_rows = StringBuilder()
  stimulus_tsv.write_string(@verilator.tsv_header(inputs))
  expected_rows.write_string(@verilator.tsv_header(outputs))
  let reset_row : InputRow = {
    reset: 1UL,
    config_valid: 0UL,
    publish_valid: 0UL,
    publish_producer: 0UL,
    completion_ready: 0UL,
    bus: {
      request_ready: 0UL,
      response_valid: 0UL,
      response_tag: 0UL,
      response_data: 0UL,
    },
  }
  drive_row(simulator, inputs, reset_row, 0UL, stimuli, stimulus_tsv)
  stimuli.push(@differential.Stimulus::rising_edge(1UL, 0UL, clock))
  simulator.rising_edge(clock)
  let mut configured = false
  let mut first_published = false
  let mut final_published = false
  let mut fence_installed = false
  let mut hold_until = 0
  let mut held_once = false
  let mut retired = 0
  let mut cycles = 0
  for cycle in 1..<=4096 {
    if !fence_installed && output_value(simulator, "consumer_count") >= 1UL {
      install_packet(host.memory, 0, fence_packet())
      fence_installed = true
    }
    if !held_once && output_value(simulator, "completion_valid") == 1UL {
      hold_until = cycle + 9
      held_once = true
    }
    let publish = output_value(simulator, "configured") == 1UL &&
      (!first_published || (fence_installed && !final_published))
    let row : InputRow = {
      reset: 0UL,
      config_valid: if configured {
        0UL
      } else {
        1UL
      },
      publish_valid: if publish {
        1UL
      } else {
        0UL
      },
      publish_producer: if first_published {
        5UL
      } else {
        4UL
      },
      completion_ready: if cycle < hold_until {
        0UL
      } else {
        1UL
      },
      bus: host.drive(cycle),
    }
    let cycle_u64 = cycle.to_uint64()
    drive_row(simulator, inputs, row, cycle_u64, stimuli, stimulus_tsv)
    if row.config_valid == 1UL && output_value(simulator, "config_ready") == 1UL {
      configured = true
    }
    if row.publish_valid == 1UL &&
      output_value(simulator, "publish_ready") == 1UL {
      if first_published {
        final_published = true
      } else {
        first_published = true
      }
    }
    if row.completion_ready == 1UL &&
      output_value(simulator, "completion_valid") == 1UL {
      let progress = [2UL, 2UL, 0UL, 4UL, 0UL]
      if retired >= 5 ||
        output_value(simulator, "completion_id") != (41 + retired).to_uint64() ||
        output_value(simulator, "completion_fault") != 0UL ||
        output_value(simulator, "completion_bytes_completed") !=
        progress[retired] ||
        output_value(simulator, "completion_fault_address") != 0UL {
        fail("unexpected ordered completion \{retired}")
      }
      retired += 1
    }
    host.accept(simulator, row.bus)
    stimuli.push(
      @differential.Stimulus::rising_edge(
        cycle_u64 * 3UL + 1UL,
        cycle_u64,
        clock,
      ),
    )
    simulator.rising_edge(clock)
    sample_row(
      simulator, outputs, cycle_u64, stimuli, observations, expected_rows,
    )
    cycles = cycle
    if output_value(simulator, "ring_fault_valid") != 0UL ||
      output_value(simulator, "transport_halted") != 0UL {
      fail("successful fixture encountered a device fault")
    }
    if retired == 5 && host.pending is None {
      break
    }
  }
  if retired != 5 ||
    !final_published ||
    !held_once ||
    host.stalls == 0 ||
    host.requests != 165 ||
    host.reads != 164 ||
    host.writes != 4 ||
    output_value(simulator, "producer_count") != 5UL ||
    output_value(simulator, "consumer_count") != 5UL ||
    output_value(simulator, "accepted_steps") != 2UL ||
    output_value(simulator, "elapsed_cycles") != 3UL ||
    output_value(simulator, "active_cycles") != 2UL ||
    output_value(simulator, "stall_cycles") != 0UL ||
    output_value(simulator, "capture_cycles") != 1UL {
    fail("fixture did not complete its bounded workload and counters")
  }
  let oracle = verify_workload(host.memory)
  let protocol = result_protocol()
  let identity = @differential.DesignIdentity::checked(
    protocol.semantic_version(),
    @verilator.sha256_hex(@ir_codec.serialize(design)),
  )
  let stimulus_text = stimulus_tsv.to_string()
  let result_identity = @differential.ResultIdentity::checked(
    identity,
    @verilator.sha256_hex(stimulus_text),
  )
  let expected_tsv = "\{protocol.magic()}\t\{protocol.version()}\t\{@verilator.utf8_hex(identity.semantic_version())}\tsha256\t\{identity.design_sha256()}\tsha256\t\{result_identity.stimulus_sha256()}\n" +
    expected_rows.to_string()
  {
    stimulus: @differential.StimulusSequence::checked(identity, 0UL, stimuli),
    expected: @differential.ObservationSet::checked(
      result_identity, observations,
    ),
    stimulus_tsv: stimulus_text,
    expected_tsv,
    cycles,
    summary: "LUNACHIP-PHASE6-FIXTURE 1\nPROFILE flux-tile-0/fetched-concurrent\nDEVICE-ABI 1.0\nDESCRIPTOR 0.2\nCYCLES \{cycles}\nCOMPLETIONS 5\nREQUESTS 165\nREAD-BYTES 164\nWRITE-BYTES 4\nRESULT \{oracle}\nORACLE match\nRING-SLOT-REUSE true\nCOMPLETION-HOLD-CYCLES 9\nCLAIM generated-reference-only\nEND\n",
  }
}
