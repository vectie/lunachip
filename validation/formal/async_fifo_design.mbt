///|
priv struct AsyncFifoFormalDesign {
  design : @ir.Design
}

///|
fn async_fifo_formal_design() -> AsyncFifoFormalDesign raise {
  let builder = @wire.ModuleBuilder::new("FormalAsyncFifoDepth4")
  let source_clock = builder.input("source_clock", @wire.clock())
  let source_domain = builder.rising_edge(source_clock)
  let zero = builder.constant(@wire.bits(1), 0UL)
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let destination_domain = builder.rising_edge(destination_clock)
  let filler = builder.bit_or(zero, zero)
  let source_reset = builder.input("source_reset", @wire.reset())
  let destination_reset = builder.input("destination_reset", @wire.reset())
  let source_valid_raw = builder.input("source_valid", @wire.bits(1))
  let source_valid = builder.bit_xor(source_valid_raw, filler)
  let source_word = builder.input("source_word", @wire.bits(8))
  let destination_ready = builder.input("destination_ready", @wire.bits(1))
  let fifo = builder.asynchronous_fifo(
    "formal_fifo",
    source_domain,
    destination_domain,
    builder.ready_valid_forward(
      source_valid,
      @aggregate.Aggregate::leaf(source_word),
    ),
    builder.ready_valid_backward(destination_ready),
    builder.synchronous_reset(source_reset, 0UL),
    builder.synchronous_reset(destination_reset, 0UL),
    4,
    synchronizer_stages=2,
  )
  let source_ready = builder.output("source_ready", @wire.bits(1))
  let destination_valid = builder.output("destination_valid", @wire.bits(1))
  let destination_word = builder.output("destination_word", @wire.bits(8))
  builder.connect(source_ready, fifo.source().ready())
  builder.connect(destination_valid, fifo.destination().valid())
  builder.connect(
    destination_word,
    fifo.destination().payload().flatten()[0].value(),
  )
  for input in [source_reset, source_valid_raw, source_word] {
    builder.input_timing(input, SampledIn(source_domain.id()))
  }
  for input in [destination_reset, destination_ready] {
    builder.input_timing(input, SampledIn(destination_domain.id()))
  }
  builder.output_timing(source_ready, ProducedIn(source_domain.id()))
  for output in [destination_valid, destination_word] {
    builder.output_timing(output, ProducedIn(destination_domain.id()))
  }
  let hardware_module = builder.finish()
  guard hardware_module.cdc_primitives() is [AsyncFifo(primitive)] else {
    raise InvalidAsyncFifoFormalBundle(
      "formal asynchronous FIFO did not retain exactly one primitive",
    )
  }
  ignore(primitive)
  {
    design: @ir.Design::single(
      "phase5-formal-async-fifo-depth4", hardware_module,
    ),
  }
}
