///|
fn async_two_stage_module() -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("Phase5AsyncTwoStage")
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let destination = builder.rising_edge(destination_clock)
  let source = builder.input("source", @wire.bits(1))
  let reset_signal = builder.input("reset", @wire.reset())
  builder.input_timing(source, Asynchronous)
  builder.input_timing(reset_signal, SampledIn(destination.id()))
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let synchronized = builder.bit_synchronizer(
    "async_sync",
    source,
    destination,
    2,
    reset~,
  )
  let output = builder.output("synchronized", @wire.bits(1))
  builder.output_timing(output, ProducedIn(destination.id()))
  builder.connect(output, synchronized)
  builder.finish()
}

///|
fn timed_module(name : String, stages : Int) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new(name)
  let source_clock = builder.input("source_clock", @wire.clock())
  // Keep a real, semantically neutral path between the two clock inputs so
  // the public builder produces sparse domain IDs 0 and 3. The filler remains
  // reachable through source_state and cannot be dropped as dead IR.
  let filler_zero = builder.constant(@wire.bits(1), 0UL)
  let filler_path = builder.bit_or(filler_zero, filler_zero)
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let source_domain = builder.rising_edge(source_clock)
  let destination = builder.rising_edge(destination_clock)
  let source_next = builder.input("source_next", @wire.bits(1))
  let source_reset_signal = builder.input("source_reset", @wire.reset())
  let destination_reset_signal = builder.input(
    "destination_reset",
    @wire.reset(),
  )
  builder.input_timing(source_next, SampledIn(source_domain.id()))
  builder.input_timing(source_reset_signal, SampledIn(source_domain.id()))
  builder.input_timing(destination_reset_signal, SampledIn(destination.id()))
  let effective_source = builder.bit_xor(source_next, filler_path)
  let source_reset = builder.synchronous_reset(source_reset_signal, 0UL)
  let source_state = builder.register_in(
    source_domain,
    effective_source,
    reset=source_reset,
  )
  let destination_reset = builder.synchronous_reset(
    destination_reset_signal, 0UL,
  )
  let synchronized = builder.bit_synchronizer(
    "timed_sync",
    source_state,
    destination,
    stages,
    source_domain~,
    reset=destination_reset,
  )
  let synchronized_output = builder.output("synchronized", @wire.bits(1))
  builder.output_timing(synchronized_output, ProducedIn(destination.id()))
  builder.connect(synchronized_output, synchronized)
  builder.finish()
}

///|
fn fixture_module(kind : SyncFixtureKind) -> @ir.Module raise {
  match kind {
    AsyncTwoStage => async_two_stage_module()
    TimedThreeStage => timed_module("Phase5TimedThreeStage", 3)
    TimedFourStage => timed_module("Phase5TimedFourStage", 4)
  }
}

///|
fn fixture_design(kind : SyncFixtureKind) -> @ir.Design raise {
  @wire.single_design("lunachip.phase5-sync/\{kind.id()}", fixture_module(kind))
}

///|
fn source_domain_id() -> @ir.ClockDomainId raise {
  @ir.ClockDomainId::new(0)
}

///|
fn destination_domain_id(kind : SyncFixtureKind) -> @ir.ClockDomainId raise {
  @ir.ClockDomainId::new(
    match kind {
      AsyncTwoStage => 0
      TimedThreeStage | TimedFourStage => 3
    },
  )
}

///|
fn domain_clock_name(kind : SyncFixtureKind, domain : Int) -> String raise {
  match (kind, domain) {
    (AsyncTwoStage, 0) => "destination_clock"
    (TimedThreeStage | TimedFourStage, 0) => "source_clock"
    (TimedThreeStage | TimedFourStage, 3) => "destination_clock"
    _ => raise MissingDomainClock(domain)
  }
}
