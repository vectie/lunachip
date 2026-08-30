///|
test "asynchronous FIFO preflight failures preserve builder usability" {
  let builder = @wire.ModuleBuilder::new("FifoPreflightRecovery")
  let source_clock = builder.input("source_clock", @wire.clock())
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let source_domain = builder.rising_edge(source_clock)
  let destination_domain = builder.rising_edge(destination_clock)
  let source_reset_signal = builder.input("source_reset", @wire.reset())
  let destination_reset_signal = builder.input(
    "destination_reset",
    @wire.reset(),
  )
  let wrong_reset_signal = builder.input("wrong_reset", @wire.reset())
  let active_low_signal = builder.input("active_low_reset", @wire.reset())
  let source_reset = builder.synchronous_reset(source_reset_signal, 0UL)
  let destination_reset = builder.synchronous_reset(
    destination_reset_signal, 0UL,
  )
  let wrong_reset = builder.synchronous_reset(wrong_reset_signal, 0UL)
  let active_low_reset = builder.synchronous_reset_active_low(
    active_low_signal, 0UL,
  )
  let valid = builder.input("valid", @wire.bits(1))
  let data = builder.input("data", @wire.uint(8))
  let wide_data = builder.input("wide_data", @wire.bits(65))
  let ready = builder.input("ready", @wire.bits(1))
  let forward = builder.ready_valid_forward(
    valid,
    @aggregate.Aggregate::leaf(data),
  )
  let wide_forward = builder.ready_valid_forward(
    valid,
    @aggregate.Aggregate::leaf(wide_data),
  )
  let backward = builder.ready_valid_backward(ready)
  for input in [source_reset_signal, active_low_signal, valid, data, wide_data] {
    builder.input_timing(input, SampledIn(source_domain.id()))
  }
  for input in [destination_reset_signal, wrong_reset_signal, ready] {
    builder.input_timing(input, SampledIn(destination_domain.id()))
  }
  try
    builder.asynchronous_fifo(
      "", source_domain, destination_domain, forward, backward, source_reset, destination_reset,
      4,
    )
  catch {
    @ir.IrError::EmptyName(kind~) => assert_eq(kind, "CDC primitive")
    error => fail("unexpected empty FIFO name error: \{Repr(error)}")
  } noraise {
    _ => fail("expected empty FIFO name rejection")
  }
  try
    builder.asynchronous_fifo(
      "bad_depth", source_domain, destination_domain, forward, backward, source_reset,
      destination_reset, 6,
    )
  catch {
    @ir.IrError::InvalidAsyncFifoDepth(..) => ()
    error => fail("unexpected FIFO depth error: \{Repr(error)}")
  } noraise {
    _ => fail("expected FIFO depth rejection")
  }
  try
    builder.asynchronous_fifo(
      "bad_stage",
      source_domain,
      destination_domain,
      forward,
      backward,
      source_reset,
      destination_reset,
      4,
      synchronizer_stages=5,
    )
  catch {
    @ir.IrError::InvalidAsyncFifoStageCount(..) => ()
    error => fail("unexpected FIFO stage error: \{Repr(error)}")
  } noraise {
    _ => fail("expected FIFO stage rejection")
  }
  try
    builder.asynchronous_fifo(
      "wide", source_domain, destination_domain, wide_forward, backward, source_reset,
      destination_reset, 4,
    )
  catch {
    @ir.IrError::AsyncFifoPayloadWidth(actual~, ..) => assert_eq(actual, 65)
    error => fail("unexpected FIFO width error: \{Repr(error)}")
  } noraise {
    _ => fail("expected FIFO payload-width rejection")
  }
  try
    builder.asynchronous_fifo(
      "active_low", source_domain, destination_domain, forward, backward, active_low_reset,
      destination_reset, 4,
    )
  catch {
    @ir.IrError::AsyncFifoResetMismatch(role~, ..) =>
      assert_eq(role, "source_reset")
    error => fail("unexpected FIFO polarity error: \{Repr(error)}")
  } noraise {
    _ => fail("expected FIFO active-low reset rejection")
  }
  try
    builder.asynchronous_fifo(
      "wrong_timing", source_domain, destination_domain, forward, backward, wrong_reset,
      destination_reset, 4,
    )
  catch {
    @ir.IrError::AsyncFifoResetMismatch(role~, ..) =>
      assert_eq(role, "source_reset_timing")
    error => fail("unexpected FIFO timing error: \{Repr(error)}")
  } noraise {
    _ => fail("expected FIFO reset-timing rejection")
  }
  let foreign = @wire.ModuleBuilder::new("ForeignFifo")
  let foreign_forward = foreign.ready_valid_forward(
    foreign.input("valid", @wire.bits(1)),
    @aggregate.Aggregate::leaf(foreign.input("data", @wire.uint(8))),
  )
  try
    builder.asynchronous_fifo(
      "foreign", source_domain, destination_domain, foreign_forward, backward, source_reset,
      destination_reset, 4,
    )
  catch {
    @wire.WireError::ForeignSignal => ()
    error => fail("unexpected foreign FIFO error: \{Repr(error)}")
  } noraise {
    _ => fail("expected foreign FIFO rejection")
  }
  let fifo = builder.asynchronous_fifo(
    "recovered", source_domain, destination_domain, forward, backward, source_reset,
    destination_reset, 4,
  )
  try
    builder.asynchronous_fifo(
      "recovered", source_domain, destination_domain, forward, backward, source_reset,
      destination_reset, 4,
    )
  catch {
    @ir.IrError::DuplicateCdcPrimitiveName(name) => assert_eq(name, "recovered")
    error => fail("unexpected duplicate FIFO error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate FIFO name rejection")
  }
  let ready_output = builder.output("source_ready", @wire.bits(1))
  let valid_output = builder.output("destination_valid", @wire.bits(1))
  let data_output = builder.output("destination_data", @wire.uint(8))
  builder.connect(ready_output, fifo.source().ready())
  builder.connect(valid_output, fifo.destination().valid())
  builder.connect(
    data_output,
    fifo.destination().payload().flatten()[0].value(),
  )
  builder.output_timing(ready_output, ProducedIn(source_domain.id()))
  builder.output_timing(valid_output, ProducedIn(destination_domain.id()))
  builder.output_timing(data_output, ProducedIn(destination_domain.id()))
  let hardware_module = builder.finish()
  assert_eq(hardware_module.cdc_primitives().length(), 1)
}
