///|
test "combined state-cell accounting accepts exact limit and rejects one over" {
  assert_eq(checked_prepared_state_cells(6UL, 4UL, 10), 10UL)
  try checked_prepared_state_cells(6UL, 5UL, 10) catch {
    UnsupportedTotalStateCells(total~, maximum~) => {
      assert_eq(total, 11UL)
      assert_eq(maximum, 10)
    }
    error => fail("unexpected state-cell error: \{Repr(error)}")
  } noraise {
    _ => fail("expected combined state-cell rejection")
  }
}

///|
test "combined state-cell accounting saturates arithmetic overflow" {
  try checked_prepared_state_cells(18446744073709551614UL, 2UL, 1048576) catch {
    UnsupportedTotalStateCells(total~, ..) =>
      assert_eq(total, 18446744073709551615UL)
    error => fail("unexpected overflow error: \{Repr(error)}")
  } noraise {
    _ => fail("expected saturated combined state-cell rejection")
  }
}

///|
fn rollback_fifo_module() -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("RollbackFifo")
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
  builder.finish()
}

///|
test "post-write settlement failure rolls back FIFO lanes and all event state" {
  let hardware_module = rollback_fifo_module()
  let simulator = prepare_kernel(hardware_module)
  let source = @ir.ClockDomainId::new(0)
  let destination = @ir.ClockDomainId::new(1)
  simulator.apply_event(
    TimestampEvent::checked(
      SimulationTime::from_uint64(1UL),
      [
        InputDrive::checked("source_reset", @wave.LogicValue::one(width=1)),
        InputDrive::checked("destination_reset", @wave.LogicValue::one(width=1)),
        InputDrive::checked("valid", @wave.LogicValue::zero(width=1)),
        InputDrive::checked("data", @wave.LogicValue::zero(width=8)),
        InputDrive::checked("ready", @wave.LogicValue::zero(width=1)),
      ],
      [source, destination],
    ),
  )
  guard hardware_module.cdc_primitives()[0] is AsyncFifo(fifo) else {
    fail("expected FIFO")
  }
  simulator.values[fifo.nonempty().ordinal()] = @wave.LogicValue::one(width=1)
  simulator.settle()
  simulator.async_fifos[0].lanes[0][1] = @wave.LogicValue::unknown(width=7)
  let before = simulator.snapshot()
  try
    simulator.apply_event(
      TimestampEvent::checked(
        SimulationTime::from_uint64(2UL),
        [
          InputDrive::checked("source_reset", @wave.LogicValue::zero(width=1)),
          InputDrive::checked(
            "destination_reset",
            @wave.LogicValue::zero(width=1),
          ),
          InputDrive::checked("valid", @wave.LogicValue::one(width=1)),
          InputDrive::checked(
            "data",
            @wave.LogicValue::from_uint64(width=8, value=0xa5UL),
          ),
          InputDrive::checked("ready", @wave.LogicValue::one(width=1)),
        ],
        [source, destination],
      ),
    )
  catch {
    @wave.LogicValueError::WidthMismatch(left~, right~) => {
      assert_eq(left, 7)
      assert_eq(right, 8)
    }
    error => fail("unexpected injected settlement error: \{Repr(error)}")
  } noraise {
    _ => fail("expected injected post-write settlement failure")
  }
  assert_eq(simulator.snapshot(), before)
  assert_false(simulator.async_fifos[0].lanes[0][0].is_fully_known())
}
