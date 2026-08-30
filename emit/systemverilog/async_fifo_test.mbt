///|
fn emitted_fifo_design() -> @ir.Design raise {
  let builder = @wire.ModuleBuilder::new("UnsupportedFifo")
  let source_clock = builder.input("source_clock", @wire.clock())
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let source_domain = builder.rising_edge(source_clock)
  let destination_domain = builder.rising_edge(destination_clock)
  let source_reset_signal = builder.input("source_reset", @wire.reset())
  let destination_reset_signal = builder.input(
    "destination_reset",
    @wire.reset(),
  )
  let source_reset = builder.synchronous_reset(source_reset_signal, 0UL)
  let destination_reset = builder.synchronous_reset(
    destination_reset_signal, 0UL,
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
    source_reset,
    destination_reset,
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
  @wire.single_design("unsupported-fifo", builder.finish())
}

///|
test "valid asynchronous FIFO is rejected before generic reachability" {
  try @systemverilog.emit_design(emitted_fifo_design()) catch {
    @systemverilog.EmitError::UnsupportedAsyncFifo(module_name~, primitive~) => {
      assert_eq(module_name, "UnsupportedFifo")
      assert_eq(primitive, 0)
    }
    error => fail("unexpected FIFO emission error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unsupported FIFO emission")
  }
}

///|
test "CDC-tampered asynchronous FIFO is rejected before unsupported capability" {
  let encoded = @codec.serialize(emitted_fifo_design())
  let tampered = @codec.parse(
    encoded.replace(
      old="INPUT_TIMING 4 sampled_in 0",
      new="INPUT_TIMING 4 sampled_in 1",
    ),
  )
  try @systemverilog.emit_design(tampered) catch {
    CdcRejected(UnsafeDependency(sink=FifoSourceValid(primitive), ..)) =>
      assert_eq(primitive.ordinal(), 0)
    error => fail("unexpected tampered FIFO emission error: \{Repr(error)}")
  } noraise {
    _ => fail("expected tampered FIFO CDC rejection")
  }
}
