///|
fn replay_fifo_design() -> @ir.Design raise {
  let builder = @wire.ModuleBuilder::new("ReplayFifo")
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
  let ready = builder.input("ready", @wire.bits(1))
  let fifo = builder.asynchronous_fifo(
    "fifo",
    source_domain,
    destination_domain,
    builder.ready_valid_forward(valid, @aggregate.Aggregate::leaf(data)),
    builder.ready_valid_backward(ready),
    builder.synchronous_reset(source_reset_signal, 0UL),
    builder.synchronous_reset(destination_reset_signal, 0UL),
    4,
  )
  let source_ready = builder.output("source_ready", @wire.bits(1))
  let destination_valid = builder.output("destination_valid", @wire.bits(1))
  let destination_data = builder.output("destination_data", @wire.uint(8))
  builder.connect(source_ready, fifo.source().ready())
  builder.connect(destination_valid, fifo.destination().valid())
  builder.connect(
    destination_data,
    fifo.destination().payload().flatten()[0].value(),
  )
  for input in [source_reset_signal, valid, data] {
    builder.input_timing(input, SampledIn(source_domain.id()))
  }
  for input in [destination_reset_signal, ready] {
    builder.input_timing(input, SampledIn(destination_domain.id()))
  }
  builder.output_timing(source_ready, ProducedIn(source_domain.id()))
  builder.output_timing(destination_valid, ProducedIn(destination_domain.id()))
  builder.output_timing(destination_data, ProducedIn(destination_domain.id()))
  @ir.Design::single("replay-fifo", builder.finish())
}

///|
fn replay_fifo_input(
  name : String,
  width : Int,
  value : UInt64,
) -> @replay.NamedInput raise {
  @replay.NamedInput::checked(
    name,
    @wave.LogicValue::from_uint64(width~, value~),
  )
}

///|
fn replay_fifo_bundle() -> @replay.ReplayBundle raise {
  let source = @ir.ClockDomainId::new(0)
  let destination = @ir.ClockDomainId::new(1)
  let events : Array[@replay.AtomicReplayEvent] = [
    @replay.AtomicReplayEvent::checked(
      1UL,
      1UL,
      [
        replay_fifo_input("source_reset", 1, 1UL),
        replay_fifo_input("destination_reset", 1, 1UL),
        replay_fifo_input("valid", 1, 0UL),
        replay_fifo_input("data", 8, 0UL),
        replay_fifo_input("ready", 1, 0UL),
      ],
      [source, destination],
    ),
    @replay.AtomicReplayEvent::checked(
      2UL,
      2UL,
      [
        replay_fifo_input("source_reset", 1, 0UL),
        replay_fifo_input("destination_reset", 1, 0UL),
        replay_fifo_input("valid", 1, 1UL),
        replay_fifo_input("data", 8, 1UL),
      ],
      [source],
    ),
    @replay.AtomicReplayEvent::checked(
      3UL,
      3UL,
      [replay_fifo_input("valid", 1, 0UL)],
      [destination],
    ),
    @replay.AtomicReplayEvent::checked(4UL, 4UL, [], [destination]),
    @replay.AtomicReplayEvent::checked(5UL, 5UL, [], [destination]),
  ]
  let mut time = 5UL
  for value in 2..<=5 {
    time += 1UL
    events.push(
      @replay.AtomicReplayEvent::checked(
        time,
        time,
        [
          replay_fifo_input("valid", 1, 1UL),
          replay_fifo_input("data", 8, value.to_uint64()),
          replay_fifo_input("ready", 1, 1UL),
        ],
        [source, destination],
      ),
    )
    for delay in 0..<3 {
      time += 1UL
      events.push(
        @replay.AtomicReplayEvent::checked(
          time,
          time,
          if delay == 0 {
            [replay_fifo_input("valid", 1, 0UL)]
          } else {
            []
          },
          [source, destination],
        ),
      )
    }
  }
  @replay.ReplayBundle::checked_atomic(
    replay_fifo_design(),
    "lunachip-semantics/2",
    [@replay.ReplayOption::checked("fifo-profile", "coordinated-idle")],
    1UL,
    events,
    AtTime(time),
    [
      @trace.TraceSignal::checked("ReplayFifo", "destination_valid", 1),
      @trace.TraceSignal::checked("ReplayFifo", "destination_data", 8),
    ],
    @replay.ReplayDigest::checked("fnv1a-64", "0000000000000000"),
  )
}

///|
test "direct and decoded FIFO replay preserve FWFT behavior and digest" {
  let bundle = replay_fifo_bundle()
  let canonical = @replay.serialize(bundle)
  let restored = @replay.parse(canonical)
  assert_eq(@replay.serialize(restored), canonical)
  let direct = @replay.execute(bundle)
  let decoded = @replay.execute(restored)
  assert_true(direct.stop_reached())
  assert_eq(direct.digest(), decoded.digest())
  assert_eq(@trace.serialize(direct.trace()), @trace.serialize(decoded.trace()))
  let frames = direct.trace().atomic_frames()
  let final_changes = frames[frames.length() - 1].changes()
  assert_eq(final_changes.length(), 2)
  assert_eq(final_changes[0].signal_index(), 0)
  assert_eq(final_changes[0].value().to_uint64(), 5UL)
  assert_eq(final_changes[1].signal_index(), 1)
  assert_eq(final_changes[1].value().to_uint64(), 1UL)
}
