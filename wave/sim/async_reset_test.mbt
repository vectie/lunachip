///|
fn async_reset_u8() -> @ir.SignalType raise {
  UInt(@ir.Width::new(8))
}

///|
fn async_reset_bit() -> @ir.SignalType raise {
  Bits(@ir.Width::new(1))
}

///|
fn async_reset_fixture() -> @ir.Module raise {
  let clock_a = @ir.NodeId::new(0)
  let clock_b = @ir.NodeId::new(1)
  let reset_high = @ir.NodeId::new(2)
  let reset_low = @ir.NodeId::new(3)
  let enable_a = @ir.NodeId::new(4)
  let enable_b = @ir.NodeId::new(5)
  let next_a = @ir.NodeId::new(6)
  let next_b = @ir.NodeId::new(7)
  let state_a = @ir.NodeId::new(8)
  let state_b = @ir.NodeId::new(9)
  let domain_a = @ir.ClockDomain::rising(clock_a)
  let domain_b = @ir.ClockDomain::rising(clock_b)
  let u8 = async_reset_u8()
  @ir.Module::checked_with_metadata(
    "AsyncResetFixture",
    [domain_b, domain_a],
    [
      @ir.Node::new(clock_a, Clock, Input("clock_a")),
      @ir.Node::new(clock_b, Clock, Input("clock_b")),
      @ir.Node::new(reset_high, Reset, Input("reset_high")),
      @ir.Node::new(reset_low, Reset, Input("reset_low")),
      @ir.Node::new(enable_a, async_reset_bit(), Input("enable_a")),
      @ir.Node::new(enable_b, async_reset_bit(), Input("enable_b")),
      @ir.Node::new(next_a, u8, Input("next_a")),
      @ir.Node::new(next_b, u8, Input("next_b")),
      @ir.Node::new(
        state_a,
        u8,
        Register(
          @ir.RegisterSpec::new(
            domain_a,
            next_a,
            reset=@ir.ResetSpec::explicit(
              reset_high,
              15UL,
              Asynchronous,
              ActiveHigh,
            ),
            enable=enable_a,
            initial=165UL,
          ),
        ),
      ),
      @ir.Node::new(
        state_b,
        u8,
        Register(
          @ir.RegisterSpec::new(
            domain_b,
            next_b,
            reset=@ir.ResetSpec::explicit(
              reset_low,
              240UL,
              Asynchronous,
              ActiveLow,
            ),
            enable=enable_b,
            initial=60UL,
          ),
        ),
      ),
    ],
    [],
    [
      @ir.OutputPort::new("state_a", u8, state_a),
      @ir.OutputPort::new("state_b", u8, state_b),
    ],
    @ir.ModuleMetadata::checked_complete(
      [],
      [],
      [
        @ir.InputTimingBinding::new(reset_high, Asynchronous),
        @ir.InputTimingBinding::new(reset_low, Asynchronous),
        @ir.InputTimingBinding::new(enable_a, SampledIn(domain_a.id())),
        @ir.InputTimingBinding::new(enable_b, SampledIn(domain_b.id())),
        @ir.InputTimingBinding::new(next_a, SampledIn(domain_a.id())),
        @ir.InputTimingBinding::new(next_b, SampledIn(domain_b.id())),
      ],
      [
        @ir.OutputTimingBinding::checked("state_a", ProducedIn(domain_a.id())),
        @ir.OutputTimingBinding::checked("state_b", ProducedIn(domain_b.id())),
      ],
      [],
    ),
  )
}

///|
fn async_drive(
  name : String,
  width : Int,
  value : UInt64,
) -> @sim.InputDrive raise {
  @sim.InputDrive::checked(name, @wave.LogicValue::from_uint64(width~, value~))
}

///|
fn async_unknown_drive(name : String) -> @sim.InputDrive raise {
  @sim.InputDrive::checked(name, @wave.LogicValue::unknown(width=1))
}

///|
fn async_event(
  time : UInt64,
  drives : ArrayView[@sim.InputDrive],
  domains : ArrayView[@ir.ClockDomainId],
) -> @sim.TimestampEvent raise {
  @sim.TimestampEvent::checked(
    @sim.SimulationTime::from_uint64(time),
    drives,
    domains,
  )
}

///|
test "asynchronous reset acts on drive-only events in both polarities" {
  let simulator = @sim.Simulator::prepare(async_reset_fixture())
  simulator.apply_event(
    async_event(
      1UL,
      [async_drive("reset_high", 1, 1UL), async_drive("reset_low", 1, 0UL)],
      [],
    ),
  )
  assert_eq(simulator.output("state_a").to_uint64(), 15UL)
  assert_eq(simulator.output("state_b").to_uint64(), 240UL)
  assert_eq(simulator.cycle().value(), 0UL)
  simulator.apply_event(
    async_event(
      2UL,
      [async_drive("reset_low", 1, 1UL), async_drive("reset_high", 1, 0UL)],
      [],
    ),
  )
  assert_eq(simulator.output("state_a").to_uint64(), 15UL)
  assert_eq(simulator.output("state_b").to_uint64(), 240UL)
}

///|
test "set_input stages reset without creating a partial hidden event" {
  let simulator = @sim.Simulator::prepare(async_reset_fixture())
  simulator.set_input(
    "reset_high",
    @wave.LogicValue::from_uint64(width=1, value=1UL),
  )
  simulator.settle()
  assert_eq(simulator.output("state_a").to_uint64(), 165UL)
  assert_eq(simulator.time().value(), 0UL)
  assert_eq(simulator.event_ordinal(), 0UL)
  simulator.apply_event(
    @sim.TimestampEvent::drives_only(@sim.SimulationTime::from_uint64(1UL), [
      async_drive("enable_a", 1, 0UL),
    ]),
  )
  assert_eq(simulator.output("state_a").to_uint64(), 15UL)
  assert_eq(simulator.time().value(), 1UL)
  assert_eq(simulator.event_ordinal(), 1UL)
}

///|
test "unknown asynchronous resets merge reset against retained state" {
  let simulator = @sim.Simulator::prepare(async_reset_fixture())
  simulator.apply_event(
    async_event(
      1UL,
      [async_unknown_drive("reset_high"), async_unknown_drive("reset_low")],
      [],
    ),
  )
  assert_eq(simulator.output("state_a").to_bit_string(), "x0x0x1x1")
  assert_eq(simulator.output("state_b").to_bit_string(), "xx11xx00")
}

///|
fn synchronous_active_low_fixture() -> @ir.Module raise {
  let clock = @ir.NodeId::new(0)
  let reset = @ir.NodeId::new(1)
  let next = @ir.NodeId::new(2)
  let state = @ir.NodeId::new(3)
  let domain = @ir.ClockDomain::rising(clock)
  let u8 = async_reset_u8()
  @ir.Module::checked_with_metadata(
    "SynchronousActiveLow",
    [domain],
    [
      @ir.Node::new(clock, Clock, Input("clock")),
      @ir.Node::new(reset, Reset, Input("reset_n")),
      @ir.Node::new(next, u8, Input("next")),
      @ir.Node::new(
        state,
        u8,
        Register(
          @ir.RegisterSpec::new(
            domain,
            next,
            reset=@ir.ResetSpec::explicit(reset, 7UL, Synchronous, ActiveLow),
            initial=0UL,
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
        @ir.InputTimingBinding::new(reset, SampledIn(domain.id())),
        @ir.InputTimingBinding::new(next, SampledIn(domain.id())),
      ],
      [@ir.OutputTimingBinding::checked("state", ProducedIn(domain.id()))],
      [],
    ),
  )
}

///|
test "synchronous active-low reset normalizes known and unknown edge controls" {
  let simulator = @sim.Simulator::prepare(synchronous_active_low_fixture())
  let domain = @ir.ClockDomainId::new(0)
  simulator.apply_event(
    async_event(
      1UL,
      [async_drive("reset_n", 1, 0UL), async_drive("next", 8, 42UL)],
      [domain],
    ),
  )
  assert_eq(simulator.output("state").to_uint64(), 7UL)
  simulator.apply_event(
    async_event(
      2UL,
      [async_drive("reset_n", 1, 1UL), async_drive("next", 8, 42UL)],
      [domain],
    ),
  )
  assert_eq(simulator.output("state").to_uint64(), 42UL)
  simulator.apply_event(
    async_event(
      3UL,
      [async_unknown_drive("reset_n"), async_drive("next", 8, 42UL)],
      [domain],
    ),
  )
  assert_eq(simulator.output("state").to_bit_string(), "00x0xx1x")
}

///|
test "coincident deassertion samples next and assertion overrides edge controls" {
  let domain_a = @ir.ClockDomainId::new(0)
  let domain_b = @ir.ClockDomainId::new(1)
  let simulator = @sim.Simulator::prepare(async_reset_fixture())
  simulator.apply_event(
    async_event(
      1UL,
      [
        async_drive("reset_high", 1, 0UL),
        async_drive("reset_low", 1, 1UL),
        async_drive("enable_a", 1, 1UL),
        async_drive("enable_b", 1, 1UL),
        async_drive("next_a", 8, 51UL),
        async_drive("next_b", 8, 85UL),
      ],
      [domain_b, domain_a],
    ),
  )
  assert_eq(simulator.output("state_a").to_uint64(), 51UL)
  assert_eq(simulator.output("state_b").to_uint64(), 85UL)
  simulator.apply_event(
    async_event(
      2UL,
      [
        async_drive("reset_low", 1, 0UL),
        async_drive("reset_high", 1, 1UL),
        async_drive("enable_b", 1, 0UL),
        async_drive("enable_a", 1, 0UL),
        async_drive("next_b", 8, 170UL),
        async_drive("next_a", 8, 204UL),
      ],
      [domain_a, domain_b],
    ),
  )
  assert_eq(simulator.output("state_a").to_uint64(), 15UL)
  assert_eq(simulator.output("state_b").to_uint64(), 240UL)
}

///|
fn async_reset_dependency_fixture() -> @ir.Module raise {
  let clock = @ir.NodeId::new(0)
  let reset_a = @ir.NodeId::new(1)
  let reset_b = @ir.NodeId::new(2)
  let state_a = @ir.NodeId::new(3)
  let state_b = @ir.NodeId::new(4)
  let domain = @ir.ClockDomain::rising(clock)
  let u8 = async_reset_u8()
  @ir.Module::checked_with_metadata(
    "AsyncResetDependency",
    [domain],
    [
      @ir.Node::new(clock, Clock, Input("clock")),
      @ir.Node::new(reset_a, Reset, Input("reset_a")),
      @ir.Node::new(reset_b, Reset, Input("reset_b")),
      @ir.Node::new(
        state_a,
        u8,
        Register(
          @ir.RegisterSpec::new(
            domain,
            state_a,
            reset=@ir.ResetSpec::explicit(
              reset_a,
              90UL,
              Asynchronous,
              ActiveHigh,
            ),
            initial=0UL,
          ),
        ),
      ),
      @ir.Node::new(
        state_b,
        u8,
        Register(
          @ir.RegisterSpec::new(
            domain,
            state_a,
            reset=@ir.ResetSpec::explicit(
              reset_b,
              255UL,
              Asynchronous,
              ActiveHigh,
            ),
            initial=0UL,
          ),
        ),
      ),
    ],
    [],
    [
      @ir.OutputPort::new("state_a", u8, state_a),
      @ir.OutputPort::new("state_b", u8, state_b),
    ],
    @ir.ModuleMetadata::checked_complete(
      [],
      [],
      [
        @ir.InputTimingBinding::new(reset_a, Asynchronous),
        @ir.InputTimingBinding::new(reset_b, Asynchronous),
      ],
      [
        @ir.OutputTimingBinding::checked("state_a", ProducedIn(domain.id())),
        @ir.OutputTimingBinding::checked("state_b", ProducedIn(domain.id())),
      ],
      [],
    ),
  )
}

///|
test "clock candidates observe the globally committed asynchronous reset phase" {
  let simulator = @sim.Simulator::prepare(async_reset_dependency_fixture())
  simulator.apply_event(
    async_event(
      1UL,
      [async_drive("reset_a", 1, 1UL), async_drive("reset_b", 1, 0UL)],
      [@ir.ClockDomainId::new(0)],
    ),
  )
  assert_eq(simulator.output("state_a").to_uint64(), 90UL)
  // State B's next input is state A. Seeing 90 here proves that every async
  // effect committed before the coincident clock candidates were sampled.
  assert_eq(simulator.output("state_b").to_uint64(), 90UL)
}

///|
test "unknown reset at an edge merges reset against enabled next state" {
  let simulator = @sim.Simulator::prepare(async_reset_fixture())
  simulator.apply_event(
    async_event(
      1UL,
      [
        async_unknown_drive("reset_high"),
        async_drive("enable_a", 1, 1UL),
        async_drive("next_a", 8, 51UL),
      ],
      [@ir.ClockDomainId::new(0)],
    ),
  )
  assert_eq(simulator.output("state_a").to_bit_string(), "00xxxx11")
}

///|
test "drive and domain permutations plus snapshot restore are exact" {
  let domain_a = @ir.ClockDomainId::new(0)
  let domain_b = @ir.ClockDomainId::new(1)
  let drives = [
    async_drive("reset_high", 1, 0UL),
    async_drive("reset_low", 1, 1UL),
    async_drive("enable_a", 1, 1UL),
    async_drive("enable_b", 1, 1UL),
    async_drive("next_a", 8, 18UL),
    async_drive("next_b", 8, 52UL),
  ]
  let reversed = [
    drives[5],
    drives[4],
    drives[3],
    drives[2],
    drives[1],
    drives[0],
  ]
  let first = @sim.Simulator::prepare(async_reset_fixture())
  let second = @sim.Simulator::prepare(async_reset_fixture())
  first.apply_event(async_event(1UL, drives, [domain_b, domain_a]))
  second.apply_event(async_event(1UL, reversed, [domain_a, domain_b]))
  assert_eq(first.output("state_a"), second.output("state_a"))
  assert_eq(first.output("state_b"), second.output("state_b"))
  let snapshot = first.snapshot()
  let transition = [
    async_drive("reset_high", 1, 1UL),
    async_drive("reset_low", 1, 0UL),
  ]
  first.apply_event(async_event(2UL, transition, []))
  assert_eq(first.output("state_a").to_uint64(), 15UL)
  assert_eq(first.output("state_b").to_uint64(), 240UL)
  first.restore(snapshot)
  assert_eq(first.output("state_a").to_uint64(), 18UL)
  assert_eq(first.output("state_b").to_uint64(), 52UL)
  first.apply_event(async_event(2UL, transition, []))
  assert_eq(first.output("state_a").to_uint64(), 15UL)
  assert_eq(first.output("state_b").to_uint64(), 240UL)
  assert_eq(first.time().value(), 2UL)
  assert_eq(first.event_ordinal(), 2UL)
}
