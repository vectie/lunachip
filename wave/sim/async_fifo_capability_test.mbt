///|
fn simulated_fifo_module(stages~ : Int32 = 2) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("UnsupportedSimFifo")
  let source_clock = builder.input("source_clock", @wire.clock())
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let source_domain = builder.rising_edge(source_clock)
  let destination_domain = builder.rising_edge(destination_clock)
  let source_reset_signal = builder.input("source_reset", @wire.reset())
  let destination_reset_signal = builder.input(
    "destination_reset",
    @wire.reset(),
  )
  let valid = builder.input("valid", @wire.bits(1))
  let data = builder.input("data", @wire.uint(8))
  let data_second = builder.input("data_second", @wire.uint(8))
  let ready = builder.input("ready", @wire.bits(1))
  let prefixed_sync = builder.bit_synchronizer(
    "prefix",
    valid,
    destination_domain,
    2,
    source_domain~,
    reset=builder.synchronous_reset(destination_reset_signal, 0UL),
  )
  let fifo = builder.asynchronous_fifo(
    "fifo",
    source_domain,
    destination_domain,
    builder.ready_valid_forward(valid, @aggregate.Aggregate::leaf(data)),
    builder.ready_valid_backward(ready),
    builder.synchronous_reset(source_reset_signal, 0UL),
    builder.synchronous_reset(destination_reset_signal, 0UL),
    4,
    synchronizer_stages=stages,
  )
  let fifo_second = builder.asynchronous_fifo(
    "fifo_second",
    source_domain,
    destination_domain,
    builder.ready_valid_forward(valid, @aggregate.Aggregate::leaf(data_second)),
    builder.ready_valid_backward(ready),
    builder.synchronous_reset(source_reset_signal, 0UL),
    builder.synchronous_reset(destination_reset_signal, 0UL),
    4,
    synchronizer_stages=stages,
  )
  let source_ready = builder.output("source_ready", @wire.bits(1))
  let destination_valid = builder.output("destination_valid", @wire.bits(1))
  let destination_data = builder.output("destination_data", @wire.uint(8))
  let synchronized = builder.output("synchronized", @wire.bits(1))
  let second_ready = builder.output("second_ready", @wire.bits(1))
  let second_valid = builder.output("second_valid", @wire.bits(1))
  let second_data = builder.output("second_data", @wire.uint(8))
  builder.connect(source_ready, fifo.source().ready())
  builder.connect(destination_valid, fifo.destination().valid())
  builder.connect(
    destination_data,
    fifo.destination().payload().flatten()[0].value(),
  )
  builder.connect(synchronized, prefixed_sync)
  builder.connect(second_ready, fifo_second.source().ready())
  builder.connect(second_valid, fifo_second.destination().valid())
  builder.connect(
    second_data,
    fifo_second.destination().payload().flatten()[0].value(),
  )
  for input in [source_reset_signal, valid, data, data_second] {
    builder.input_timing(input, SampledIn(source_domain.id()))
  }
  for input in [destination_reset_signal, ready] {
    builder.input_timing(input, SampledIn(destination_domain.id()))
  }
  builder.output_timing(source_ready, ProducedIn(source_domain.id()))
  builder.output_timing(destination_valid, ProducedIn(destination_domain.id()))
  builder.output_timing(destination_data, ProducedIn(destination_domain.id()))
  builder.output_timing(synchronized, ProducedIn(destination_domain.id()))
  builder.output_timing(second_ready, ProducedIn(source_domain.id()))
  builder.output_timing(second_valid, ProducedIn(destination_domain.id()))
  builder.output_timing(second_data, ProducedIn(destination_domain.id()))
  builder.finish()
}

///|
test "valid asynchronous FIFO is prepared for simulation" {
  ignore(@sim.Simulator::prepare(simulated_fifo_module()))
}

///|
test "CDC-tampered FIFO is rejected before simulator preparation" {
  let encoded = @codec.serialize(
    @ir.Design::single("unsupported-sim-fifo", simulated_fifo_module()),
  )
  let tampered = @codec.parse(
      encoded.replace(
        old="INPUT_TIMING 4 sampled_in 0",
        new="INPUT_TIMING 4 sampled_in 1",
      ),
    )
    .top_module()
    .unwrap()
  try @sim.Simulator::prepare(tampered) catch {
    @sim.SimulatorError::CdcRejected(
      UnsafeDependency(sink=FifoSourceValid(primitive), ..)
    ) => assert_eq(primitive.ordinal(), 1)
    error => fail("unexpected tampered FIFO simulator error: \{Repr(error)}")
  } noraise {
    _ => fail("expected tampered FIFO CDC rejection")
  }
}

///|
fn fifo_drive(
  name : String,
  width : Int32,
  value : UInt64,
) -> @sim.InputDrive raise {
  @sim.InputDrive::checked(name, @wave.LogicValue::from_uint64(width~, value~))
}

///|
fn fifo_event(
  simulator : @sim.Simulator,
  time : UInt64,
  drives : Array[@sim.InputDrive],
  domains : Array[@ir.ClockDomainId],
) -> Unit raise {
  simulator.apply_event(
    @sim.TimestampEvent::checked(
      @sim.SimulationTime::from_uint64(time),
      drives,
      domains,
    ),
  )
}

///|
test "FIFO reset enqueue FWFT backpressure and dequeue are exact" {
  let simulator = @sim.Simulator::prepare(simulated_fifo_module())
  let source = @ir.ClockDomainId::new(0)
  let destination = @ir.ClockDomainId::new(1)
  fifo_event(
    simulator,
    1UL,
    [
      fifo_drive("source_reset", 1, 1UL),
      fifo_drive("destination_reset", 1, 1UL),
      fifo_drive("valid", 1, 0UL),
      fifo_drive("data", 8, 0UL),
      fifo_drive("ready", 1, 0UL),
    ],
    [source, destination],
  )
  assert_eq(simulator.output("source_ready").to_uint64(), 1UL)
  assert_eq(simulator.output("destination_valid").to_uint64(), 0UL)
  assert_eq(simulator.output("destination_data").to_uint64(), 0UL)
  fifo_event(
    simulator,
    2UL,
    [
      fifo_drive("source_reset", 1, 0UL),
      fifo_drive("destination_reset", 1, 0UL),
      fifo_drive("valid", 1, 1UL),
      fifo_drive("data", 8, 0xa5UL),
    ],
    [source],
  )
  fifo_event(simulator, 3UL, [fifo_drive("valid", 1, 0UL)], [destination])
  fifo_event(simulator, 4UL, [], [destination])
  fifo_event(simulator, 5UL, [], [destination])
  assert_eq(simulator.output("destination_valid").to_uint64(), 1UL)
  assert_eq(simulator.output("destination_data").to_uint64(), 0xa5UL)
  fifo_event(simulator, 6UL, [], [destination])
  assert_eq(simulator.output("destination_data").to_uint64(), 0xa5UL)
  fifo_event(simulator, 7UL, [fifo_drive("ready", 1, 1UL)], [destination])
  assert_eq(simulator.output("destination_valid").to_uint64(), 0UL)
  assert_eq(simulator.output("destination_data").to_uint64(), 0UL)
}

///|
test "FIFO snapshot restores private payload state" {
  let simulator = @sim.Simulator::prepare(simulated_fifo_module())
  let source = @ir.ClockDomainId::new(0)
  let destination = @ir.ClockDomainId::new(1)
  fifo_event(
    simulator,
    1UL,
    [
      fifo_drive("source_reset", 1, 1UL),
      fifo_drive("destination_reset", 1, 1UL),
      fifo_drive("valid", 1, 0UL),
      fifo_drive("data", 8, 0UL),
      fifo_drive("ready", 1, 0UL),
    ],
    [source, destination],
  )
  fifo_event(
    simulator,
    2UL,
    [
      fifo_drive("source_reset", 1, 0UL),
      fifo_drive("destination_reset", 1, 0UL),
      fifo_drive("valid", 1, 1UL),
      fifo_drive("data", 8, 0x31UL),
    ],
    [source],
  )
  let snapshot = simulator.snapshot()
  fifo_event(simulator, 3UL, [fifo_drive("data", 8, 0x72UL)], [source])
  simulator.restore(snapshot)
  fifo_event(simulator, 3UL, [fifo_drive("valid", 1, 0UL)], [destination])
  fifo_event(simulator, 4UL, [], [destination])
  fifo_event(simulator, 5UL, [], [destination])
  assert_eq(simulator.output("destination_data").to_uint64(), 0x31UL)
}

///|
test "sparse primitive IDs and two FIFO descriptors keep payload lanes isolated" {
  let simulator = @sim.Simulator::prepare(simulated_fifo_module())
  let source = @ir.ClockDomainId::new(0)
  let destination = @ir.ClockDomainId::new(1)
  fifo_event(
    simulator,
    1UL,
    [
      fifo_drive("source_reset", 1, 1UL),
      fifo_drive("destination_reset", 1, 1UL),
      fifo_drive("valid", 1, 0UL),
      fifo_drive("data", 8, 0UL),
      fifo_drive("data_second", 8, 0UL),
      fifo_drive("ready", 1, 0UL),
    ],
    [source, destination],
  )
  fifo_event(
    simulator,
    2UL,
    [
      fifo_drive("source_reset", 1, 0UL),
      fifo_drive("destination_reset", 1, 0UL),
      fifo_drive("valid", 1, 1UL),
      fifo_drive("data", 8, 0x12UL),
      fifo_drive("data_second", 8, 0xe7UL),
    ],
    [source],
  )
  fifo_event(simulator, 3UL, [fifo_drive("valid", 1, 0UL)], [destination])
  fifo_event(simulator, 4UL, [], [destination])
  fifo_event(simulator, 5UL, [], [destination])
  assert_eq(simulator.output("destination_data").to_uint64(), 0x12UL)
  assert_eq(simulator.output("second_data").to_uint64(), 0xe7UL)
}

///|
test "depth-four FIFO reaches full wraps and drains in order" {
  let simulator = @sim.Simulator::prepare(simulated_fifo_module())
  let source = @ir.ClockDomainId::new(0)
  let destination = @ir.ClockDomainId::new(1)
  fifo_event(
    simulator,
    1UL,
    [
      fifo_drive("source_reset", 1, 1UL),
      fifo_drive("destination_reset", 1, 1UL),
      fifo_drive("valid", 1, 0UL),
      fifo_drive("data", 8, 0UL),
      fifo_drive("data_second", 8, 0UL),
      fifo_drive("ready", 1, 0UL),
    ],
    [source, destination],
  )
  fifo_event(
    simulator,
    2UL,
    [
      fifo_drive("source_reset", 1, 0UL),
      fifo_drive("destination_reset", 1, 0UL),
      fifo_drive("valid", 1, 1UL),
      fifo_drive("data", 8, 1UL),
      fifo_drive("data_second", 8, 11UL),
    ],
    [source],
  )
  for value in 2..<=4 {
    fifo_event(
      simulator,
      (value + 1).to_uint64(),
      [
        fifo_drive("data", 8, value.to_uint64()),
        fifo_drive("data_second", 8, (value + 10).to_uint64()),
      ],
      [source],
    )
  }
  assert_eq(simulator.output("source_ready").to_uint64(), 0UL)
  fifo_event(simulator, 6UL, [fifo_drive("valid", 1, 0UL)], [destination])
  fifo_event(simulator, 7UL, [], [destination])
  fifo_event(simulator, 8UL, [], [destination])
  for expected in 1..<=4 {
    assert_eq(
      simulator.output("destination_data").to_uint64(),
      expected.to_uint64(),
    )
    fifo_event(
      simulator,
      (8 + expected).to_uint64(),
      if expected == 1 {
        [fifo_drive("ready", 1, 1UL)]
      } else {
        []
      },
      [destination],
    )
  }
  assert_eq(simulator.output("destination_valid").to_uint64(), 0UL)
  assert_eq(simulator.output("destination_data").to_uint64(), 0UL)
}

///|
test "unknown transfer control and derived unknown address never invent writes" {
  let hardware_module = simulated_fifo_module()
  let simulator = @sim.Simulator::prepare(hardware_module)
  guard hardware_module.cdc_primitives()[1] is AsyncFifo(fifo) else {
    fail("expected sparse-ID FIFO")
  }
  let source = @ir.ClockDomainId::new(0)
  let destination = @ir.ClockDomainId::new(1)
  fifo_event(
    simulator,
    1UL,
    [
      fifo_drive("source_reset", 1, 1UL),
      fifo_drive("destination_reset", 1, 1UL),
      fifo_drive("valid", 1, 0UL),
      fifo_drive("data", 8, 0UL),
      fifo_drive("data_second", 8, 0UL),
      fifo_drive("ready", 1, 0UL),
    ],
    [source, destination],
  )
  fifo_event(
    simulator,
    2UL,
    [
      fifo_drive("source_reset", 1, 0UL),
      fifo_drive("destination_reset", 1, 0UL),
      @sim.InputDrive::checked("valid", @wave.LogicValue::unknown(width=1)),
      fifo_drive("data", 8, 0xa5UL),
      fifo_drive("data_second", 8, 0x5aUL),
    ],
    [source],
  )
  assert_false(simulator.value(fifo.write_binary()).is_fully_known())
  fifo_event(simulator, 3UL, [fifo_drive("valid", 1, 1UL)], [source])
  assert_false(simulator.value(fifo.write_address()).is_fully_known())
  // Coordinated reset recovers the ordinary pointer graph; private storage is
  // intentionally not reset and neither X-controlled edge counted as a write.
  fifo_event(
    simulator,
    4UL,
    [
      fifo_drive("source_reset", 1, 1UL),
      fifo_drive("destination_reset", 1, 1UL),
      fifo_drive("valid", 1, 0UL),
    ],
    [source, destination],
  )
  assert_eq(simulator.output("source_ready").to_uint64(), 1UL)
  assert_eq(simulator.output("destination_valid").to_uint64(), 0UL)
  assert_eq(simulator.output("destination_data").to_uint64(), 0UL)
  assert_false(simulator.value(fifo.raw_reads()[0]).is_fully_known())
}

///|
test "three and four synchronizer stages delay visibility exactly" {
  for stages in [3, 4] {
    let simulator = @sim.Simulator::prepare(simulated_fifo_module(stages~))
    let source = @ir.ClockDomainId::new(0)
    let destination = @ir.ClockDomainId::new(1)
    fifo_event(
      simulator,
      1UL,
      [
        fifo_drive("source_reset", 1, 1UL),
        fifo_drive("destination_reset", 1, 1UL),
        fifo_drive("valid", 1, 0UL),
        fifo_drive("data", 8, 0UL),
        fifo_drive("data_second", 8, 0UL),
        fifo_drive("ready", 1, 0UL),
      ],
      [source, destination],
    )
    fifo_event(
      simulator,
      2UL,
      [
        fifo_drive("source_reset", 1, 0UL),
        fifo_drive("destination_reset", 1, 0UL),
        fifo_drive("valid", 1, 1UL),
        fifo_drive("data", 8, stages.to_uint64()),
      ],
      [source],
    )
    for edge in 0..<stages {
      fifo_event(
        simulator,
        (edge + 3).to_uint64(),
        if edge == 0 {
          [fifo_drive("valid", 1, 0UL)]
        } else {
          []
        },
        [destination],
      )
      assert_eq(simulator.output("destination_valid").to_uint64(), 0UL)
    }
    fifo_event(simulator, (stages + 3).to_uint64(), [], [destination])
    assert_eq(simulator.output("destination_valid").to_uint64(), 1UL)
    assert_eq(
      simulator.output("destination_data").to_uint64(),
      stages.to_uint64(),
    )
  }
}
