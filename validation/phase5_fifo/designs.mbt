///|
fn fifo_module(kind : FifoFixtureKind) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new(
    match kind {
      Depth4ScalarTwoStage => "Phase5FifoDepth4Scalar"
      Depth8AggregateThreeStage => "Phase5FifoDepth8Aggregate64"
      Depth4AsymmetricFourStage => "Phase5FifoDepth4Asymmetric"
    },
  )
  let source_clock = builder.input("source_clock", @wire.clock())
  let source_domain = builder.rising_edge(source_clock)
  let filler_clock1 = builder.input("filler_clock1", @wire.clock())
  let filler_domain1 = builder.rising_edge(filler_clock1)
  let filler_clock2 = builder.input("filler_clock2", @wire.clock())
  let filler_domain2 = builder.rising_edge(filler_clock2)
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let destination_domain = builder.rising_edge(destination_clock)
  let source_reset = builder.input("source_reset", @wire.reset())
  let destination_reset = builder.input("destination_reset", @wire.reset())
  let source_valid = builder.input("source_valid", @wire.bits(1))
  let source_lane0 = builder.input("source_lane0", @wire.uint(8))
  let destination_ready = builder.input("destination_ready", @wire.bits(1))
  let filler_zero = builder.constant(@wire.bits(1), 0UL)
  let filler_state1 = builder.register_state_in(filler_domain1, @wire.bits(1))
  let filler_state2 = builder.register_state_in(filler_domain2, @wire.bits(1))
  builder.connect_next(filler_state1, filler_state1.value())
  builder.connect_next(filler_state2, filler_state2.value())
  let filler_output1 = builder.output("filler_observed1", @wire.bits(1))
  let filler_output2 = builder.output("filler_observed2", @wire.bits(1))
  builder.connect(
    filler_output1,
    builder.bit_and(filler_state1.value(), filler_zero),
  )
  builder.connect(
    filler_output2,
    builder.bit_and(filler_state2.value(), filler_zero),
  )
  builder.output_timing(filler_output1, ProducedIn(filler_domain1.id()))
  builder.output_timing(filler_output2, ProducedIn(filler_domain2.id()))
  let payload = if kind.aggregate() {
    let source_word = builder.input("source_word", @wire.uint(32))
    let source_tag = builder.input("source_tag", @wire.bits(8))
    let source_lane1 = builder.input("source_lane1", @wire.uint(8))
    let source_lane2 = builder.input("source_lane2", @wire.uint(8))
    for input in [source_word, source_tag, source_lane1, source_lane2] {
      builder.input_timing(input, SampledIn(source_domain.id()))
    }
    @aggregate.Aggregate::record([
      ("word", @aggregate.Aggregate::leaf(source_word)),
      ("tag", @aggregate.Aggregate::leaf(source_tag)),
      (
        "lanes",
        @aggregate.Aggregate::vector([
          @aggregate.Aggregate::leaf(source_lane0),
          @aggregate.Aggregate::leaf(source_lane1),
          @aggregate.Aggregate::leaf(source_lane2),
        ]),
      ),
    ])
  } else {
    @aggregate.Aggregate::leaf(source_lane0)
  }
  let fifo = builder.asynchronous_fifo(
    "transport",
    source_domain,
    destination_domain,
    builder.ready_valid_forward(source_valid, payload),
    builder.ready_valid_backward(destination_ready),
    builder.synchronous_reset(source_reset, 0UL),
    builder.synchronous_reset(destination_reset, 0UL),
    kind.depth(),
    synchronizer_stages=kind.stages(),
  )
  let ready = builder.output("source_ready", @wire.bits(1))
  let valid = builder.output("destination_valid", @wire.bits(1))
  builder.connect(ready, fifo.source().ready())
  builder.connect(valid, fifo.destination().valid())
  let leaves = fifo.destination().payload().flatten()
  let output_names = if kind.aggregate() {
    [
      ("destination_word", @wire.uint(32)),
      ("destination_tag", @wire.bits(8)),
      ("destination_lane0", @wire.uint(8)),
      ("destination_lane1", @wire.uint(8)),
      ("destination_lane2", @wire.uint(8)),
    ]
  } else {
    [("destination_lane0", @wire.uint(8))]
  }
  let outputs : Array[@wire.Output] = [ready, valid]
  for index, item in output_names {
    let output = builder.output(item.0, item.1)
    builder.connect(output, leaves[index].value())
    outputs.push(output)
  }
  for input in [source_reset, source_valid, source_lane0] {
    builder.input_timing(input, SampledIn(source_domain.id()))
  }
  for input in [destination_reset, destination_ready] {
    builder.input_timing(input, SampledIn(destination_domain.id()))
  }
  builder.output_timing(ready, ProducedIn(source_domain.id()))
  for output in outputs[1:] {
    builder.output_timing(output, ProducedIn(destination_domain.id()))
  }
  builder.finish()
}

///|
fn fixture_design(kind : FifoFixtureKind) -> @ir.Design raise {
  @wire.single_design(
    "lunachip.phase5-fifo-differential/\{kind.id()}",
    fifo_module(kind),
  )
}

///|
fn source_domain_id() -> @ir.ClockDomainId raise {
  @ir.ClockDomainId::new(0)
}

///|
fn destination_domain_id() -> @ir.ClockDomainId raise {
  @ir.ClockDomainId::new(3)
}

///|
fn domain_clock_name(domain : Int) -> String raise FifoFixtureError {
  match domain {
    0 => "source_clock"
    3 => "destination_clock"
    _ => raise MissingDomainClock(domain)
  }
}
