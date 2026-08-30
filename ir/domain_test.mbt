///|
test "clock-domain identifiers and tables are canonical" {
  let clock_a = @ir.NodeId::new(0)
  let clock_b = @ir.NodeId::new(1)
  let next_a = @ir.NodeId::new(2)
  let next_b = @ir.NodeId::new(3)
  let state_a = @ir.NodeId::new(4)
  let state_b = @ir.NodeId::new(5)
  let ty : @ir.SignalType = UInt(@ir.Width::new(8))
  let domain_a = @ir.ClockDomain::rising(clock_a)
  let domain_b = @ir.ClockDomain::rising(clock_b)
  let hardware_module = @ir.Module::checked(
    "DualClock",
    [
      @ir.Node::new(clock_a, Clock, Input("clock_a")),
      @ir.Node::new(clock_b, Clock, Input("clock_b")),
      @ir.Node::new(next_a, ty, Input("next_a")),
      @ir.Node::new(next_b, ty, Input("next_b")),
      @ir.Node::new(
        state_a,
        ty,
        Register(@ir.RegisterSpec::new(domain_a, next_a)),
      ),
      @ir.Node::new(
        state_b,
        ty,
        Register(@ir.RegisterSpec::new(domain_b, next_b)),
      ),
    ],
    [
      @ir.OutputPort::new("state_a", ty, state_a),
      @ir.OutputPort::new("state_b", ty, state_b),
    ],
  )
  assert_eq(hardware_module.domains().length(), 2)
  assert_eq(hardware_module.domains()[0].id().ordinal(), 0)
  assert_eq(hardware_module.domains()[1].id().ordinal(), 1)
  assert_eq(hardware_module.domain(domain_b.id()).unwrap().clock(), clock_b)
}

///|
test "duplicate domain definitions intern and conflicting ids reject" {
  let clock = @ir.NodeId::new(0)
  let domain = @ir.ClockDomain::rising(clock)
  let module_with_duplicate = @ir.Module::checked_with_domains(
    "Interned",
    [domain, domain],
    [@ir.Node::new(clock, Clock, Input("clock"))],
    [],
    [],
  )
  assert_eq(module_with_duplicate.domains().length(), 1)
  let other_clock = @ir.NodeId::new(1)
  let noncanonical = @ir.ClockDomain::new(domain.id(), other_clock, Rising)
  try
    @ir.Module::checked_with_domains(
      "BadDomain",
      [noncanonical],
      [
        @ir.Node::new(clock, Clock, Input("clock")),
        @ir.Node::new(other_clock, Clock, Input("other_clock")),
      ],
      [],
      [],
    )
  catch {
    NonCanonicalClockDomainId(expected~, actual~) => {
      assert_eq(expected, 1)
      assert_eq(actual, 0)
    }
    error => fail("unexpected domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected noncanonical domain rejection")
  }
}

///|
test "all explicit schema-four reset semantics validate" {
  let clock = @ir.NodeId::new(0)
  let reset = @ir.NodeId::new(1)
  let next = @ir.NodeId::new(2)
  let state = @ir.NodeId::new(3)
  let ty : @ir.SignalType = UInt(@ir.Width::new(8))
  let nodes_for = reset_spec => {
    [
      @ir.Node::new(clock, Clock, Input("clock")),
      @ir.Node::new(reset, Reset, Input("reset")),
      @ir.Node::new(next, ty, Input("next")),
      @ir.Node::new(
        state,
        ty,
        Register(
          @ir.RegisterSpec::new(
            @ir.ClockDomain::rising(clock),
            next,
            reset=reset_spec,
          ),
        ),
      ),
    ]
  }
  for mode in [@ir.ResetMode::Synchronous, Asynchronous] {
    for polarity in [@ir.ResetPolarity::ActiveHigh, ActiveLow] {
      let spec = @ir.ResetSpec::explicit(reset, 0UL, mode, polarity)
      let hardware_module = @ir.Module::checked(
        "ExplicitReset",
        nodes_for(spec),
        [],
      )
      guard hardware_module.nodes()[3].kind() is Register(found) else {
        fail("expected register")
      }
      assert_eq(found.reset(), Some(spec))
    }
  }
}

///|
test "negative clock-domain identifiers are checked" {
  try @ir.ClockDomainId::new(-1) catch {
    InvalidClockDomainId(id) => assert_eq(id, -1)
    error => fail("unexpected id error: \{Repr(error)}")
  } noraise {
    _ => fail("expected invalid domain id")
  }
}
