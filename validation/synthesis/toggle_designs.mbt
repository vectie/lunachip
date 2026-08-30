///|
fn toggle_synthesis_module(kind : ToggleSynthesisKind) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("Synthesis" + kind.id())
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
  let source_valid = builder.input("source_valid", @wire.bits(1))
  let destination_ready = builder.input("destination_ready", @wire.bits(1))
  let payload = match kind {
    Scalar2Stage => {
      let word = builder.input("source_word", @wire.uint(13))
      builder.input_timing(word, SampledIn(source_domain.id()))
      @aggregate.Aggregate::leaf(word)
    }
    Record3Stage | Record4Stage => {
      let word = builder.input("source_word", @wire.uint(13))
      let tag = builder.input("source_tag", @wire.bits(3))
      builder.input_timing(word, SampledIn(source_domain.id()))
      builder.input_timing(tag, SampledIn(source_domain.id()))
      @aggregate.Aggregate::record([
        ("word", @aggregate.Aggregate::leaf(word)),
        ("tag", @aggregate.Aggregate::leaf(tag)),
      ])
    }
  }
  let handshake = builder.toggle_handshake(
    "crossing",
    source_domain,
    destination_domain,
    builder.ready_valid_forward(source_valid, payload),
    builder.ready_valid_backward(destination_ready),
    source_reset,
    destination_reset,
    synchronizer_stages=kind.stage_count(),
  )
  let source_ready = builder.output("source_ready", @wire.bits(1))
  let destination_valid = builder.output("destination_valid", @wire.bits(1))
  builder.connect(source_ready, handshake.source().ready())
  builder.connect(destination_valid, handshake.destination().valid())
  for index, leaf in handshake.destination().payload().flatten() {
    let output = builder.output(
      "destination_payload_\{index}",
      leaf.value().signal_type(),
    )
    builder.connect(output, leaf.value())
    builder.output_timing(output, ProducedIn(destination_domain.id()))
  }
  for input in [source_reset_signal, source_valid] {
    builder.input_timing(input, SampledIn(source_domain.id()))
  }
  for input in [destination_reset_signal, destination_ready] {
    builder.input_timing(input, SampledIn(destination_domain.id()))
  }
  builder.output_timing(source_ready, ProducedIn(source_domain.id()))
  builder.output_timing(destination_valid, ProducedIn(destination_domain.id()))
  builder.finish()
}

///|
fn toggle_synthesis_design(kind : ToggleSynthesisKind) -> @ir.Design raise {
  @wire.single_design(
    "phase5-synthesis-" + kind.id(),
    toggle_synthesis_module(kind),
  )
}
