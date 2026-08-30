///|
fn handshake_module(kind : HandshakeFixtureKind) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new(
    match kind {
      DirectedScalar => "Phase5HandshakeDirectedScalar"
      MultiLeafRational => "Phase5HandshakeMultiLeaf"
      CoincidentRefill => "Phase5HandshakeCoincidentRefill"
      CoordinatedResetFlush => "Phase5HandshakeResetFlush"
      SeededRational => "Phase5HandshakeSeeded"
    },
  )
  let source_clock = builder.input("source_clock", @wire.clock())
  let source_domain = builder.rising_edge(source_clock)
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let destination_domain = builder.rising_edge(destination_clock)
  let source_reset_signal = builder.input("source_reset", @wire.reset())
  let destination_reset_signal = builder.input(
    "destination_reset",
    @wire.reset(),
  )
  let source_valid = builder.input("source_valid", @wire.bits(1))
  let source_word = builder.input("source_word", @wire.uint(8))
  let source_tag = if kind == MultiLeafRational {
    Some(builder.input("source_tag", @wire.bits(3)))
  } else {
    None
  }
  let destination_ready = builder.input("destination_ready", @wire.bits(1))
  let payload = match source_tag {
    Some(tag) =>
      @aggregate.Aggregate::record([
        ("word", @aggregate.Aggregate::leaf(source_word)),
        ("tag🔥", @aggregate.Aggregate::leaf(tag)),
      ])
    None => @aggregate.Aggregate::leaf(source_word)
  }
  let handshake = builder.toggle_handshake(
    "transport🌙",
    source_domain,
    destination_domain,
    builder.ready_valid_forward(source_valid, payload),
    builder.ready_valid_backward(destination_ready),
    builder.synchronous_reset(source_reset_signal, 0UL),
    builder.synchronous_reset(destination_reset_signal, 0UL),
    synchronizer_stages=match kind {
      DirectedScalar | CoordinatedResetFlush => 2
      MultiLeafRational | SeededRational => 3
      CoincidentRefill => 4
    },
  )
  let source_ready_output = builder.output("source_ready", @wire.bits(1))
  let destination_valid_output = builder.output(
    "destination_valid",
    @wire.bits(1),
  )
  let destination_word_output = builder.output(
    "destination_word",
    @wire.uint(8),
  )
  builder.connect(source_ready_output, handshake.source().ready())
  builder.connect(destination_valid_output, handshake.destination().valid())
  let destination_leaves = handshake.destination().payload().flatten()
  builder.connect(destination_word_output, destination_leaves[0].value())
  let outputs : Array[@wire.Output] = [
    source_ready_output, destination_valid_output, destination_word_output,
  ]
  match source_tag {
    Some(_) => {
      let destination_tag_output = builder.output(
        "destination_tag",
        @wire.bits(3),
      )
      builder.connect(destination_tag_output, destination_leaves[1].value())
      outputs.push(destination_tag_output)
    }
    None => ()
  }
  for input in [source_reset_signal, source_valid, source_word] {
    builder.input_timing(input, SampledIn(source_domain.id()))
  }
  match source_tag {
    Some(tag) => builder.input_timing(tag, SampledIn(source_domain.id()))
    None => ()
  }
  for input in [destination_reset_signal, destination_ready] {
    builder.input_timing(input, SampledIn(destination_domain.id()))
  }
  builder.output_timing(source_ready_output, ProducedIn(source_domain.id()))
  for output in outputs[1:] {
    builder.output_timing(output, ProducedIn(destination_domain.id()))
  }
  builder.finish()
}

///|
fn fixture_design(kind : HandshakeFixtureKind) -> @ir.Design raise {
  @wire.single_design(
    "lunachip.phase5-handshake-differential/\{kind.id()}",
    handshake_module(kind),
  )
}

///|
fn source_domain_id() -> @ir.ClockDomainId raise {
  @ir.ClockDomainId::new(0)
}

///|
fn destination_domain_id() -> @ir.ClockDomainId raise {
  @ir.ClockDomainId::new(1)
}

///|
fn domain_clock_name(domain : Int) -> String raise HandshakeFixtureError {
  match domain {
    0 => "source_clock"
    1 => "destination_clock"
    _ => raise MissingDomainClock(domain)
  }
}
