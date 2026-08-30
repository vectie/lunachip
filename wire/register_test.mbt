///|
test "explicit register domain preserves reset enable and X initialization" {
  let builder = @wire.ModuleBuilder::new("ControlledCounter")
  let clock = builder.input("clock", @wire.clock())
  let reset_signal = builder.input("reset", @wire.reset())
  let enable = builder.input("enable", @wire.bits(1))
  let domain = builder.rising_edge(clock)
  let reset = builder.synchronous_reset(reset_signal, 23UL)
  assert_eq(domain.clock().id(), clock.id())
  assert_eq(domain.edge(), Rising)
  assert_eq(reset.signal().id(), reset_signal.id())
  assert_eq(reset.value(), 23UL)
  let state = builder.register_state_in(domain, @wire.uint(8), reset~, enable~)
  let one = builder.constant(@wire.uint(8), 1UL)
  builder.connect_next(state, builder.add(state.value(), one))
  let canonical = builder.finish()
  guard canonical.nodes()[3].kind() is Register(spec) else {
    fail("expected controlled register")
  }
  assert_eq(spec.domain().clock(), clock.id())
  assert_eq(spec.reset().map(value => value.value()), Some(23UL))
  assert_eq(spec.enable(), Some(enable.id()))
  assert_eq(spec.initial(), None)
  assert_eq(spec.action(true, true), LoadReset)
  assert_eq(spec.action(false, true), LoadNext)
  assert_eq(spec.action(false, false), Hold)
}

///|
test "direct controlled register uses the same canonical semantics" {
  let builder = @wire.ModuleBuilder::new("ControlledPipeline")
  let clock = builder.input("clock", @wire.clock())
  let reset_signal = builder.input("reset", @wire.reset())
  let enable = builder.input("enable", @wire.uint(1))
  let next = builder.input("next", @wire.uint(8))
  let domain = builder.rising_edge(clock)
  let reset = builder.synchronous_reset(reset_signal, 9UL)
  let state = builder.register_in(domain, next, reset~, enable~, initial=4UL)
  let output = builder.output("state", @wire.uint(8))
  builder.connect(output, state)
  let canonical = builder.finish()
  guard canonical.nodes()[4].kind() is Register(spec) else {
    fail("expected controlled register")
  }
  assert_eq(spec.next(), next.id())
  assert_eq(spec.initial(), Some(4UL))
}

///|
test "typed reset APIs add all polarities without weakening synchronous reset" {
  let synchronous_builder = @wire.ModuleBuilder::new("ActiveLowSynchronous")
  let synchronous_clock = synchronous_builder.input("clock", @wire.clock())
  let synchronous_reset_signal = synchronous_builder.input(
    "reset_n",
    @wire.reset(),
  )
  let synchronous_next = synchronous_builder.input("next", @wire.uint(8))
  let synchronous_domain = synchronous_builder.rising_edge(synchronous_clock)
  let synchronous_reset = synchronous_builder.synchronous_reset_active_low(
    synchronous_reset_signal, 7UL,
  )
  assert_eq(synchronous_reset.mode(), Synchronous)
  assert_eq(synchronous_reset.polarity(), ActiveLow)
  let synchronous_state = synchronous_builder.register_in(
    synchronous_domain,
    synchronous_next,
    reset=synchronous_reset,
  )
  let synchronous = synchronous_builder.finish()
  guard synchronous.node(synchronous_state.id()).unwrap().kind()
    is Register(synchronous_spec) else {
    fail("expected active-low synchronous register")
  }
  assert_eq(
    synchronous_spec.reset().map(item => (item.mode(), item.polarity())),
    Some((Synchronous, ActiveLow)),
  )

  let asynchronous_builder = @wire.ModuleBuilder::new("ActiveLowAsynchronous")
  let asynchronous_clock = asynchronous_builder.input("clock", @wire.clock())
  let asynchronous_reset_signal = asynchronous_builder.input(
    "reset_n",
    @wire.reset(),
  )
  let asynchronous_next = asynchronous_builder.input("next", @wire.uint(8))
  let asynchronous_domain = asynchronous_builder.rising_edge(asynchronous_clock)
  asynchronous_builder.input_timing(asynchronous_reset_signal, Asynchronous)
  asynchronous_builder.input_timing(
    asynchronous_next,
    SampledIn(asynchronous_domain.id()),
  )
  let asynchronous_reset = asynchronous_builder.asynchronous_reset_active_low(
    asynchronous_reset_signal, 5UL,
  )
  assert_eq(asynchronous_reset.mode(), Asynchronous)
  assert_eq(asynchronous_reset.polarity(), ActiveLow)
  let asynchronous_state = asynchronous_builder.register_async_in(
    asynchronous_domain, asynchronous_next, asynchronous_reset,
  )
  let asynchronous = asynchronous_builder.finish()
  guard asynchronous.node(asynchronous_state.id()).unwrap().kind()
    is Register(asynchronous_spec) else {
    fail("expected active-low asynchronous register")
  }
  assert_eq(
    asynchronous_spec.reset().map(item => (item.mode(), item.polarity())),
    Some((Asynchronous, ActiveLow)),
  )
}

///|
test "asynchronous reset ownership and width checks are fail closed" {
  let left = @wire.ModuleBuilder::new("LeftAsync")
  let right = @wire.ModuleBuilder::new("RightAsync")
  let clock = left.input("clock", @wire.clock())
  let next = left.input("next", @wire.uint(4))
  let domain = left.rising_edge(clock)
  let foreign_reset = right.asynchronous_reset(
    right.input("reset", @wire.reset()),
    0UL,
  )
  try left.register_async_in(domain, next, foreign_reset) catch {
    @wire.WireError::ForeignReset => ()
    error => fail("unexpected foreign async reset error: \{Repr(error)}")
  } noraise {
    _ => fail("expected foreign asynchronous reset rejection")
  }
  let wide = left.asynchronous_reset(left.input("reset", @wire.reset()), 16UL)
  try left.register_async_in(domain, next, wide) catch {
    @ir.IrError::ConstantOutOfRange(width~, value~) => {
      assert_eq(width, 4)
      assert_eq(value, 16UL)
    }
    error => fail("unexpected asynchronous reset width error: \{Repr(error)}")
  } noraise {
    _ => fail("expected asynchronous reset width rejection")
  }
}

///|
test "clock domains reject non-clocks and foreign ownership" {
  let left = @wire.ModuleBuilder::new("Left")
  let right = @wire.ModuleBuilder::new("Right")
  let not_clock = left.input("not_clock", @wire.uint(1))
  try left.rising_edge(not_clock) catch {
    @ir.IrError::ExpectedClock(node~) => assert_eq(node, 0)
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected clock type rejection")
  }
  let foreign_domain = right.rising_edge(right.input("clock", @wire.clock()))
  let next = left.input("next", @wire.uint(8))
  try left.register_in(foreign_domain, next) catch {
    @wire.WireError::ForeignClockDomain => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected foreign-domain rejection")
  }
}

///|
test "synchronous reset rejects non-reset and foreign ownership" {
  let left = @wire.ModuleBuilder::new("Left")
  let right = @wire.ModuleBuilder::new("Right")
  let not_reset = left.input("not_reset", @wire.bits(1))
  try left.synchronous_reset(not_reset, 0UL) catch {
    @ir.IrError::ExpectedReset(node~) => assert_eq(node, 0)
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected reset type rejection")
  }
  let clock = left.input("clock", @wire.clock())
  let domain = left.rising_edge(clock)
  let next = left.input("next", @wire.uint(8))
  let foreign_reset = right.synchronous_reset(
    right.input("reset", @wire.reset()),
    0UL,
  )
  try left.register_in(domain, next, reset=foreign_reset) catch {
    @wire.WireError::ForeignReset => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected foreign-reset rejection")
  }
}

///|
test "enable must be one-bit data" {
  for enable_type in [@wire.bits(2), @wire.reset()] {
    let builder = @wire.ModuleBuilder::new("BadEnable")
    let clock = builder.input("clock", @wire.clock())
    let enable = builder.input("enable", enable_type)
    let next = builder.input("next", @wire.uint(8))
    let domain = builder.rising_edge(clock)
    try builder.register_in(domain, next, enable~) catch {
      @ir.IrError::ExpectedEnable(node~) => assert_eq(node, 1)
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected enable type rejection")
    }
  }
}

///|
test "reset and initial values are checked before appending state" {
  let builder = @wire.ModuleBuilder::new("WideControl")
  let clock = builder.input("clock", @wire.clock())
  let reset_signal = builder.input("reset", @wire.reset())
  let next = builder.input("next", @wire.uint(4))
  let domain = builder.rising_edge(clock)
  let reset = builder.synchronous_reset(reset_signal, 16UL)
  for use_reset in [true, false] {
    try {
      if use_reset {
        builder.register_in(domain, next, reset~)
      } else {
        builder.register_in(domain, next, initial=16UL)
      }
    } catch {
      @ir.IrError::ConstantOutOfRange(width~, value~) => {
        assert_eq(width, 4)
        assert_eq(value, 16UL)
      }
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected control value width rejection")
    }
  }
  assert_eq(builder.finish().nodes().length(), 3)
}

///|
test "existing register APIs remain explicit rising-edge wrappers" {
  let builder = @wire.ModuleBuilder::new("Compatibility")
  let clock = builder.input("clock", @wire.clock())
  let next = builder.input("next", @wire.uint(8))
  let direct = builder.register(clock, next)
  let feedback = builder.register_state(clock, @wire.uint(8))
  builder.connect_next(feedback, feedback.value())
  let canonical = builder.finish()
  for index in [2, 3] {
    guard canonical.nodes()[index].kind() is Register(spec) else {
      fail("expected register")
    }
    assert_eq(spec.domain().clock(), clock.id())
    assert_eq(spec.domain().edge(), Rising)
    assert_eq(spec.reset(), None)
    assert_eq(spec.enable(), None)
    assert_eq(spec.initial(), None)
  }
  assert_eq(direct.id(), @ir.NodeId::new(2))
}
