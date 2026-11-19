///|
fn sync_bit(value : UInt64) -> @wave.LogicValue raise {
  if value == 0UL {
    @wave.LogicValue::zero(width=1)
  } else {
    @wave.LogicValue::one(width=1)
  }
}

///|
fn async_synchronizer_with_reset(stages : Int32) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("AsyncBitSynchronizer")
  let source = builder.input("source", @wire.bits(1))
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let destination = builder.rising_edge(destination_clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  builder.input_timing(source, Asynchronous)
  builder.input_timing(reset_signal, SampledIn(destination.id()))
  let synchronized = builder.bit_synchronizer(
    "async_sync",
    source,
    destination,
    stages,
    reset~,
  )
  let output = builder.output("synchronized", @wire.bits(1))
  builder.output_timing(output, ProducedIn(destination.id()))
  builder.connect(output, synchronized)
  builder.finish()
}

///|
fn async_synchronizer_without_reset(stages : Int32) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("AsyncBitSynchronizerNoReset")
  let source = builder.input("source", @wire.bits(1))
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let destination = builder.rising_edge(destination_clock)
  builder.input_timing(source, Asynchronous)
  let synchronized = builder.bit_synchronizer(
    "async_sync_no_reset", source, destination, stages,
  )
  let output = builder.output("synchronized", @wire.bits(1))
  builder.output_timing(output, ProducedIn(destination.id()))
  builder.connect(output, synchronized)
  builder.finish()
}

///|
fn timed_synchronizer(
  stages : Int32,
  destination_first : Bool,
) -> (@ir.Module, @ir.ClockDomainId, @ir.ClockDomainId) raise {
  let builder = @wire.ModuleBuilder::new(
    if destination_first {
      "TimedSynchronizerDestinationFirst"
    } else {
      "TimedSynchronizerSourceFirst"
    },
  )
  let (source_clock, destination_clock) = if destination_first {
    let destination_clock = builder.input("destination_clock", @wire.clock())
    let source_clock = builder.input("source_clock", @wire.clock())
    (source_clock, destination_clock)
  } else {
    let source_clock = builder.input("source_clock", @wire.clock())
    let destination_clock = builder.input("destination_clock", @wire.clock())
    (source_clock, destination_clock)
  }
  let source_domain = builder.rising_edge(source_clock)
  let destination = builder.rising_edge(destination_clock)
  let source_next = builder.input("source_next", @wire.bits(1))
  let reset_signal = builder.input("reset", @wire.reset())
  builder.input_timing(source_next, SampledIn(source_domain.id()))
  builder.input_timing(reset_signal, SampledIn(destination.id()))
  let source_state = builder.register_in(
    source_domain,
    source_next,
    initial=0UL,
  )
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let synchronized = builder.bit_synchronizer(
    "timed_sync",
    source_state,
    destination,
    stages,
    source_domain~,
    reset~,
  )
  let source_output = builder.output("source_state", @wire.bits(1))
  builder.output_timing(source_output, ProducedIn(source_domain.id()))
  builder.connect(source_output, source_state)
  let synchronized_output = builder.output("synchronized", @wire.bits(1))
  builder.output_timing(synchronized_output, ProducedIn(destination.id()))
  builder.connect(synchronized_output, synchronized)
  (builder.finish(), source_domain.id(), destination.id())
}

///|
fn sync_event(
  time : UInt64,
  drives : ArrayView[@sim.InputDrive],
  domains : ArrayView[@ir.ClockDomainId],
) -> @sim.TimestampEvent raise {
  @sim.TimestampEvent::checked(
    @sim.SimulationTime::from_uint64(time),
    drives,
    domains,
  )
}

///|
fn sync_drive(name : String, value : UInt64) -> @sim.InputDrive raise {
  @sim.InputDrive::checked(name, sync_bit(value))
}

///|
test "asynchronous bit synchronizers have exact two three and four edge latency" {
  for stages in [2, 3, 4] {
    let simulator = @sim.Simulator::prepare(
      async_synchronizer_with_reset(stages),
    )
    simulator.set_input("source", sync_bit(1UL))
    simulator.set_input("reset", sync_bit(1UL))
    simulator.rising_edge("destination_clock")
    assert_eq(simulator.output("synchronized").to_bit_string(), "0")
    simulator.set_input("reset", sync_bit(0UL))
    for _ in 1..<stages {
      simulator.rising_edge("destination_clock")
      assert_eq(simulator.output("synchronized").to_bit_string(), "0")
    }
    simulator.rising_edge("destination_clock")
    assert_eq(simulator.output("synchronized").to_bit_string(), "1")
  }
}

///|
test "synchronous active-high reset overrides asserted synchronizer data" {
  let simulator = @sim.Simulator::prepare(async_synchronizer_with_reset(2))
  simulator.set_input("source", sync_bit(1UL))
  simulator.set_input("reset", sync_bit(1UL))
  for _ in 0..<3 {
    simulator.rising_edge("destination_clock")
    assert_eq(simulator.output("synchronized").to_bit_string(), "0")
  }
  simulator.set_input("reset", sync_bit(0UL))
  simulator.rising_edge("destination_clock")
  assert_eq(simulator.output("synchronized").to_bit_string(), "0")
  simulator.rising_edge("destination_clock")
  assert_eq(simulator.output("synchronized").to_bit_string(), "1")
}

///|
test "unreset synchronizer stages propagate X until the source traverses them" {
  let simulator = @sim.Simulator::prepare(async_synchronizer_without_reset(3))
  simulator.set_input("source", sync_bit(1UL))
  assert_eq(simulator.output("synchronized").to_bit_string(), "x")
  for _ in 1..<3 {
    simulator.rising_edge("destination_clock")
    assert_eq(simulator.output("synchronized").to_bit_string(), "x")
  }
  simulator.rising_edge("destination_clock")
  assert_eq(simulator.output("synchronized").to_bit_string(), "1")
}

///|
test "an unknown asynchronous source traverses one stage per destination edge" {
  let simulator = @sim.Simulator::prepare(async_synchronizer_with_reset(3))
  simulator.set_input("source", sync_bit(0UL))
  simulator.set_input("reset", sync_bit(1UL))
  simulator.rising_edge("destination_clock")
  assert_eq(simulator.output("synchronized").to_bit_string(), "0")
  simulator.set_input("reset", sync_bit(0UL))
  simulator.set_input("source", @wave.LogicValue::unknown(width=1))
  for _ in 1..<3 {
    simulator.rising_edge("destination_clock")
    assert_eq(simulator.output("synchronized").to_bit_string(), "0")
  }
  simulator.rising_edge("destination_clock")
  assert_eq(simulator.output("synchronized").to_bit_string(), "x")
}

///|
test "timed source observes exact destination-edge latency" {
  let (hardware_module, _, _) = timed_synchronizer(3, false)
  let simulator = @sim.Simulator::prepare(hardware_module)
  simulator.set_input("reset", sync_bit(1UL))
  simulator.rising_edge("destination_clock")
  simulator.set_input("reset", sync_bit(0UL))
  simulator.set_input("source_next", sync_bit(1UL))
  simulator.rising_edge("source_clock")
  assert_eq(simulator.output("source_state").to_bit_string(), "1")
  for _ in 1..<3 {
    simulator.rising_edge("destination_clock")
    assert_eq(simulator.output("synchronized").to_bit_string(), "0")
  }
  simulator.rising_edge("destination_clock")
  assert_eq(simulator.output("synchronized").to_bit_string(), "1")
}

///|
test "coincident domains sample old state independent of declaration order" {
  let (source_first_module, source_first_source, source_first_destination) = timed_synchronizer(
    2, false,
  )
  let (
    destination_first_module,
    destination_first_source,
    destination_first_destination,
  ) = timed_synchronizer(2, true)
  let source_first = @sim.Simulator::prepare(source_first_module)
  let destination_first = @sim.Simulator::prepare(destination_first_module)
  source_first.apply_event(
    sync_event(1UL, [sync_drive("reset", 1UL)], [source_first_destination]),
  )
  destination_first.apply_event(
    sync_event(1UL, [sync_drive("reset", 1UL)], [destination_first_destination]),
  )
  source_first.apply_event(
    sync_event(
      2UL,
      [sync_drive("source_next", 1UL), sync_drive("reset", 0UL)],
      [source_first_source, source_first_destination],
    ),
  )
  destination_first.apply_event(
    sync_event(
      2UL,
      [sync_drive("reset", 0UL), sync_drive("source_next", 1UL)],
      [destination_first_destination, destination_first_source],
    ),
  )
  assert_eq(source_first.output("source_state").to_bit_string(), "1")
  assert_eq(destination_first.output("source_state").to_bit_string(), "1")
  assert_eq(source_first.output("synchronized").to_bit_string(), "0")
  assert_eq(destination_first.output("synchronized").to_bit_string(), "0")
  source_first.apply_event(sync_event(3UL, [], [source_first_destination]))
  destination_first.apply_event(
    sync_event(3UL, [], [destination_first_destination]),
  )
  // A sequential domain walk would expose the newly committed source here.
  // Atomic sampling instead retains the old source for the first stage at t=2.
  assert_eq(source_first.output("synchronized").to_bit_string(), "0")
  assert_eq(destination_first.output("synchronized").to_bit_string(), "0")
  source_first.apply_event(sync_event(4UL, [], [source_first_destination]))
  destination_first.apply_event(
    sync_event(4UL, [], [destination_first_destination]),
  )
  assert_eq(source_first.output("synchronized").to_bit_string(), "1")
  assert_eq(destination_first.output("synchronized").to_bit_string(), "1")
}
