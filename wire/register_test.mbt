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
