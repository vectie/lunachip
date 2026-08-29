///|
fn register_spec(
  clock : @ir.NodeId,
  next : @ir.NodeId,
  reset? : @ir.ResetSpec,
  enable? : @ir.NodeId,
  initial? : UInt64,
) -> @ir.RegisterSpec {
  @ir.RegisterSpec::new(
    @ir.ClockDomain::rising(clock),
    next,
    reset?,
    enable?,
    initial?,
  )
}

///|
test "register spec exposes explicit rising domain and X initialization" {
  let clock = @ir.NodeId::new(2)
  let next = @ir.NodeId::new(7)
  let spec = register_spec(clock, next)
  assert_eq(spec.domain().clock(), clock)
  assert_eq(spec.domain().edge(), Rising)
  assert_eq(spec.next(), next)
  assert_eq(spec.reset(), None)
  assert_eq(spec.enable(), None)
  assert_eq(spec.initial(), None)
}

///|
test "register action is exactly reset then enable then hold" {
  let clock = @ir.NodeId::new(0)
  let reset = @ir.ResetSpec::new(@ir.NodeId::new(1), 19UL)
  let enable = @ir.NodeId::new(2)
  let controlled = register_spec(clock, @ir.NodeId::new(3), reset~, enable~)
  assert_eq(controlled.action(true, true), LoadReset)
  assert_eq(controlled.action(true, false), LoadReset)
  assert_eq(controlled.action(false, true), LoadNext)
  assert_eq(controlled.action(false, false), Hold)
  let unconditional = register_spec(clock, @ir.NodeId::new(4))
  assert_eq(unconditional.action(false, false), LoadNext)
}

///|
test "module accepts prior reset and enable controls with later feedback" {
  let clock = @ir.NodeId::new(0)
  let reset = @ir.NodeId::new(1)
  let enable = @ir.NodeId::new(2)
  let state = @ir.NodeId::new(3)
  let one = @ir.NodeId::new(4)
  let next = @ir.NodeId::new(5)
  let eight = @ir.SignalType::UInt(@ir.Width::new(8))
  let enable_type = @ir.SignalType::Bits(@ir.Width::new(1))
  let spec = register_spec(
    clock,
    next,
    reset=@ir.ResetSpec::new(reset, 7UL),
    enable~,
  )
  let hardware_module = @ir.Module::checked(
    "ControlledCounter",
    [
      @ir.Node::new(clock, Clock, Input("clock")),
      @ir.Node::new(reset, Reset, Input("reset")),
      @ir.Node::new(enable, enable_type, Input("enable")),
      @ir.Node::new(state, eight, Register(spec)),
      @ir.Node::new(one, eight, Constant(1UL)),
      @ir.Node::new(next, eight, Add(state, one)),
    ],
    [],
  )
  assert_eq(hardware_module.nodes()[3].kind(), Register(spec))
}

///|
test "module rejects a non-clock domain signal" {
  let not_clock = @ir.NodeId::new(0)
  let state = @ir.NodeId::new(1)
  let one = @ir.SignalType::UInt(@ir.Width::new(1))
  try
    @ir.Module::checked(
      "BadClock",
      [
        @ir.Node::new(not_clock, one, Input("not_clock")),
        @ir.Node::new(state, one, Register(register_spec(not_clock, state))),
      ],
      [],
    )
  catch {
    ExpectedClock(node~) => assert_eq(node, 0)
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected clock type rejection")
  }
}

///|
test "module rejects a non-reset reset control" {
  let clock = @ir.NodeId::new(0)
  let not_reset = @ir.NodeId::new(1)
  let state = @ir.NodeId::new(2)
  let one = @ir.SignalType::UInt(@ir.Width::new(1))
  let bits = @ir.SignalType::Bits(@ir.Width::new(1))
  let spec = register_spec(
    clock,
    state,
    reset=@ir.ResetSpec::new(not_reset, 0UL),
  )
  try
    @ir.Module::checked(
      "BadReset",
      [
        @ir.Node::new(clock, Clock, Input("clock")),
        @ir.Node::new(not_reset, bits, Input("not_reset")),
        @ir.Node::new(state, one, Register(spec)),
      ],
      [],
    )
  catch {
    ExpectedReset(node~) => assert_eq(node, 1)
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected reset type rejection")
  }
}

///|
test "module rejects a wide enable control" {
  let clock = @ir.NodeId::new(0)
  let enable = @ir.NodeId::new(1)
  let state = @ir.NodeId::new(2)
  let eight = @ir.SignalType::UInt(@ir.Width::new(8))
  let spec = register_spec(clock, state, enable~)
  try
    @ir.Module::checked(
      "BadEnable",
      [
        @ir.Node::new(clock, Clock, Input("clock")),
        @ir.Node::new(enable, eight, Input("enable")),
        @ir.Node::new(state, eight, Register(spec)),
      ],
      [],
    )
  catch {
    ExpectedEnable(node~) => assert_eq(node, 1)
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected enable type rejection")
  }
}

///|
test "module rejects reset and enable forward references" {
  let clock = @ir.NodeId::new(0)
  let state = @ir.NodeId::new(1)
  let later = @ir.NodeId::new(2)
  let eight = @ir.SignalType::UInt(@ir.Width::new(8))
  for
    kind in [
      @ir.NodeKind::Register(
        register_spec(clock, state, reset=@ir.ResetSpec::new(later, 0UL)),
      ),
      Register(register_spec(clock, state, enable=later)),
    ] {
    try
      @ir.Module::checked(
        "ForwardControl",
        [
          @ir.Node::new(clock, Clock, Input("clock")),
          @ir.Node::new(state, eight, kind),
          @ir.Node::new(later, Reset, Input("later")),
        ],
        [],
      )
    catch {
      ForwardReference(node~, operand~) => {
        assert_eq(node, 1)
        assert_eq(operand, 2)
      }
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected forward control rejection")
    }
  }
}

///|
test "module rejects reset and initial values wider than state" {
  let clock = @ir.NodeId::new(0)
  let reset = @ir.NodeId::new(1)
  let state = @ir.NodeId::new(2)
  let four = @ir.SignalType::UInt(@ir.Width::new(4))
  for
    spec in [
      register_spec(clock, state, reset=@ir.ResetSpec::new(reset, 16UL)),
      register_spec(clock, state, initial=16UL),
    ] {
    try
      @ir.Module::checked(
        "WideControlValue",
        [
          @ir.Node::new(clock, Clock, Input("clock")),
          @ir.Node::new(reset, Reset, Input("reset")),
          @ir.Node::new(state, four, Register(spec)),
        ],
        [],
      )
    catch {
      ConstantOutOfRange(width~, value~) => {
        assert_eq(width, 4)
        assert_eq(value, 16UL)
      }
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected raw-value width rejection")
    }
  }
}

///|
test "module rejects a next-state type mismatch" {
  let clock = @ir.NodeId::new(0)
  let state = @ir.NodeId::new(1)
  let next = @ir.NodeId::new(2)
  let eight = @ir.SignalType::UInt(@ir.Width::new(8))
  let sixteen = @ir.SignalType::UInt(@ir.Width::new(16))
  try
    @ir.Module::checked(
      "BadNext",
      [
        @ir.Node::new(clock, Clock, Input("clock")),
        @ir.Node::new(state, eight, Register(register_spec(clock, next))),
        @ir.Node::new(next, sixteen, Constant(0UL)),
      ],
      [],
    )
  catch {
    WidthMismatch(operation~, expected~, actual~) => {
      assert_eq(operation, "register")
      assert_eq(expected, 8)
      assert_eq(actual, 16)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected next-state type rejection")
  }
}
