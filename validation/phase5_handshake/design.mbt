///|
pub struct HandshakeFixture {
  hardware_module : @ir.Module
  design : @ir.Design
  source_domain : @ir.ClockDomainId
  destination_domain : @ir.ClockDomainId
  primitive : @ir.ToggleHandshakePrimitive
}

///|
pub fn handshake_fixture(stages : Int32) -> HandshakeFixture raise {
  let builder = @wire.ModuleBuilder::new("Phase5ToggleHandshake")
  let source_clock = builder.input("source_clock", @wire.clock())
  let source_domain = builder.rising_edge(source_clock)
  // A reachable neutral path keeps the public clock-domain IDs sparse. This
  // makes every native event exercise the same identity rule as replay.
  let filler_zero = builder.constant(@wire.bits(1), 0UL)
  let filler_path = builder.bit_or(filler_zero, filler_zero)
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let destination_domain = builder.rising_edge(destination_clock)
  let source_reset_signal = builder.input("source_reset", @wire.reset())
  let destination_reset_signal = builder.input(
    "destination_reset",
    @wire.reset(),
  )
  let source_valid_input = builder.input("source_valid", @wire.bits(1))
  let source_word = builder.input("source_word", @wire.bits(8))
  let source_tag = builder.input("source_tag", @wire.bits(3))
  let destination_ready = builder.input("destination_ready", @wire.bits(1))
  let source_valid = builder.bit_xor(source_valid_input, filler_path)
  let payload = @aggregate.Aggregate::record([
    ("word", @aggregate.Aggregate::leaf(source_word)),
    ("tag🔥", @aggregate.Aggregate::leaf(source_tag)),
  ])
  let handshake = builder.toggle_handshake(
    "crossing🌙",
    source_domain,
    destination_domain,
    builder.ready_valid_forward(source_valid, payload),
    builder.ready_valid_backward(destination_ready),
    builder.synchronous_reset(source_reset_signal, 0UL),
    builder.synchronous_reset(destination_reset_signal, 0UL),
    synchronizer_stages=stages,
  )
  let source_ready_output = builder.output("source_ready", @wire.bits(1))
  let destination_valid_output = builder.output(
    "destination_valid",
    @wire.bits(1),
  )
  let destination_word_output = builder.output(
    "destination_word",
    @wire.bits(8),
  )
  let destination_tag_output = builder.output("destination_tag", @wire.bits(3))
  builder.connect(source_ready_output, handshake.source().ready())
  builder.connect(destination_valid_output, handshake.destination().valid())
  let destination_payload = handshake.destination().payload().flatten()
  builder.connect(destination_word_output, destination_payload[0].value())
  builder.connect(destination_tag_output, destination_payload[1].value())
  for
    input in [source_reset_signal, source_valid_input, source_word, source_tag] {
    builder.input_timing(input, SampledIn(source_domain.id()))
  }
  builder.input_timing(
    destination_reset_signal,
    SampledIn(destination_domain.id()),
  )
  builder.input_timing(destination_ready, SampledIn(destination_domain.id()))
  builder.output_timing(source_ready_output, ProducedIn(source_domain.id()))
  for
    output in [
      destination_valid_output, destination_word_output, destination_tag_output,
    ] {
    builder.output_timing(output, ProducedIn(destination_domain.id()))
  }
  let hardware_module = builder.finish()
  guard hardware_module.cdc_primitives()[0] is ToggleHandshake(primitive) else {
    abort("public constructor did not retain a toggle-handshake primitive")
  }
  let design = @wire.single_design("lunachip.phase5-handshake", hardware_module)
  {
    hardware_module,
    design,
    source_domain: source_domain.id(),
    destination_domain: destination_domain.id(),
    primitive,
  }
}

///|
pub fn HandshakeFixture::hardware_module(self : HandshakeFixture) -> @ir.Module {
  self.hardware_module
}

///|
pub fn HandshakeFixture::design(self : HandshakeFixture) -> @ir.Design {
  self.design
}

///|
pub fn HandshakeFixture::source_domain(
  self : HandshakeFixture,
) -> @ir.ClockDomainId {
  self.source_domain
}

///|
pub fn HandshakeFixture::destination_domain(
  self : HandshakeFixture,
) -> @ir.ClockDomainId {
  self.destination_domain
}

///|
pub fn HandshakeFixture::primitive(
  self : HandshakeFixture,
) -> @ir.ToggleHandshakePrimitive {
  self.primitive
}
