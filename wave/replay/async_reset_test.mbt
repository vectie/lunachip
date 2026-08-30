///|
fn replay_async_reset_design() -> @ir.Design raise {
  let clock = @ir.NodeId::new(0)
  let reset = @ir.NodeId::new(1)
  let enable = @ir.NodeId::new(2)
  let next = @ir.NodeId::new(3)
  let state = @ir.NodeId::new(4)
  let domain = @ir.ClockDomain::rising(clock)
  let u8 = @ir.SignalType::UInt(@ir.Width::new(8))
  let hardware_module = @ir.Module::checked_with_metadata(
    "AsyncReplay",
    [domain],
    [
      @ir.Node::new(clock, Clock, Input("clock")),
      @ir.Node::new(reset, Reset, Input("reset_n")),
      @ir.Node::new(enable, Bits(@ir.Width::new(1)), Input("enable")),
      @ir.Node::new(next, u8, Input("next")),
      @ir.Node::new(
        state,
        u8,
        Register(
          @ir.RegisterSpec::new(
            domain,
            next,
            reset=@ir.ResetSpec::explicit(reset, 15UL, Asynchronous, ActiveLow),
            enable~,
            initial=165UL,
          ),
        ),
      ),
    ],
    [],
    [@ir.OutputPort::new("state", u8, state)],
    @ir.ModuleMetadata::checked_complete(
      [],
      [],
      [
        @ir.InputTimingBinding::new(reset, Asynchronous),
        @ir.InputTimingBinding::new(enable, SampledIn(domain.id())),
        @ir.InputTimingBinding::new(next, SampledIn(domain.id())),
      ],
      [@ir.OutputTimingBinding::checked("state", ProducedIn(domain.id()))],
      [],
    ),
  )
  @ir.Design::single("async-reset-replay", hardware_module)
}

///|
fn replay_reset_input(
  name : String,
  value : @wave.LogicValue,
) -> @replay.NamedInput raise {
  @replay.NamedInput::checked(name, value)
}

///|
fn replay_known_input(
  name : String,
  width : Int,
  value : UInt64,
) -> @replay.NamedInput raise {
  replay_reset_input(name, @wave.LogicValue::from_uint64(width~, value~))
}

///|
fn replay_async_reset_bundle() -> @replay.ReplayBundle raise {
  let domain = @ir.ClockDomainId::new(0)
  @replay.ReplayBundle::checked_atomic(
    replay_async_reset_design(),
    "lunachip-semantics/2",
    [@replay.ReplayOption::checked("reset-order", "async-before-edge")],
    1UL,
    [
      @replay.AtomicReplayEvent::checked(
        1UL,
        1UL,
        [replay_known_input("reset_n", 1, 0UL)],
        [],
      ),
      @replay.AtomicReplayEvent::checked(
        2UL,
        2UL,
        [
          replay_known_input("reset_n", 1, 1UL),
          replay_known_input("enable", 1, 1UL),
          replay_known_input("next", 8, 51UL),
        ],
        [domain],
      ),
      @replay.AtomicReplayEvent::checked(
        3UL,
        3UL,
        [
          replay_reset_input("reset_n", @wave.LogicValue::unknown(width=1)),
          replay_known_input("next", 8, 51UL),
        ],
        [domain],
      ),
    ],
    AfterBoundary(3UL),
    [@trace.TraceSignal::checked("AsyncReplay", "state", 8)],
    @replay.ReplayDigest::checked("fnv1a-64", "0000000000000000"),
  )
}

///|
test "schema two replay preserves asynchronous reset ordering and X merge" {
  let bundle = replay_async_reset_bundle()
  let canonical = @replay.serialize(bundle)
  let restored = @replay.parse(canonical)
  assert_eq(@replay.serialize(restored), canonical)
  let direct = @replay.execute(bundle)
  let decoded = @replay.execute(restored)
  assert_eq(@trace.serialize(direct.trace()), @trace.serialize(decoded.trace()))
  let frames = direct.trace().atomic_frames()
  assert_eq(frames.length(), 4)
  assert_eq(frames[1].changes()[0].value().to_uint64(), 15UL)
  assert_eq(frames[2].changes()[0].value().to_uint64(), 51UL)
  assert_eq(frames[3].changes()[0].value().to_bit_string(), "00xxxx11")
  assert_true(direct.stop_reached())
}
