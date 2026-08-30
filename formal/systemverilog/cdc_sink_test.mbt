///|
fn formal_cdc_uint() -> @ir.SignalType raise @ir.IrError {
  UInt(@ir.Width::new(8))
}

///|
fn formal_two_flop_crossing() -> @ir.Design raise @ir.IrError {
  let clock_a = @ir.NodeId::new(0)
  let clock_b = @ir.NodeId::new(1)
  let foreign = @ir.NodeId::new(2)
  let first = @ir.NodeId::new(3)
  let second = @ir.NodeId::new(4)
  let domain_a = @ir.ClockDomain::rising(clock_a)
  let domain_b = @ir.ClockDomain::rising(clock_b)
  let value_type = formal_cdc_uint()
  let hardware_module = @ir.Module::checked_with_metadata(
    "FormalTwoFlopCrossing",
    [domain_a, domain_b],
    [
      @ir.Node::new(clock_a, Clock, Input("clock_a")),
      @ir.Node::new(clock_b, Clock, Input("clock_b")),
      @ir.Node::new(foreign, value_type, Input("foreign")),
      @ir.Node::new(
        first,
        value_type,
        Register(@ir.RegisterSpec::new(domain_a, foreign)),
      ),
      @ir.Node::new(
        second,
        value_type,
        Register(@ir.RegisterSpec::new(domain_a, first)),
      ),
    ],
    [],
    [@ir.OutputPort::new("state", value_type, second)],
    @ir.ModuleMetadata::checked_with_timing(
      [],
      [],
      [@ir.InputTimingBinding::new(foreign, SampledIn(domain_b.id()))],
      [@ir.OutputTimingBinding::checked("state", ProducedIn(domain_a.id()))],
    ),
  )
  @ir.Design::single("formal-two-flop", hardware_module)
}

///|
fn formal_timingless_multi_domain() -> @ir.Design raise @ir.IrError {
  let clock_a = @ir.NodeId::new(0)
  let clock_b = @ir.NodeId::new(1)
  let next_a = @ir.NodeId::new(2)
  let next_b = @ir.NodeId::new(3)
  let state_a = @ir.NodeId::new(4)
  let state_b = @ir.NodeId::new(5)
  let domain_a = @ir.ClockDomain::rising(clock_a)
  let domain_b = @ir.ClockDomain::rising(clock_b)
  let value_type = formal_cdc_uint()
  let hardware_module = @ir.Module::checked_with_domains(
    "FormalTiminglessMultiDomain",
    [domain_a, domain_b],
    [
      @ir.Node::new(clock_a, Clock, Input("clock_a")),
      @ir.Node::new(clock_b, Clock, Input("clock_b")),
      @ir.Node::new(next_a, value_type, Constant(1UL)),
      @ir.Node::new(next_b, value_type, Constant(2UL)),
      @ir.Node::new(
        state_a,
        value_type,
        Register(@ir.RegisterSpec::new(domain_a, next_a)),
      ),
      @ir.Node::new(
        state_b,
        value_type,
        Register(@ir.RegisterSpec::new(domain_b, next_b)),
      ),
    ],
    [],
    [
      @ir.OutputPort::new("state_a", value_type, state_a),
      @ir.OutputPort::new("state_b", value_type, state_b),
    ],
  )
  @ir.Design::single("formal-timingless", hardware_module)
}

///|
fn formal_safe_emission() -> @rtl.EmittedDesign raise {
  @rtl.emit_design(fixture_design())
}

///|
test "formal binding derivation rejects an ordinary two-flop crossing" {
  let design = formal_two_flop_crossing()
  let path = @systemverilog.TopModulePath::checked(
    design, "FormalTwoFlopCrossing",
  )
  try
    @systemverilog.derive_bindings(
      design,
      formal_safe_emission(),
      path,
      fixture_plan(),
    )
  catch {
    @systemverilog.IntegrationError::CdcRejected(
      UnsafeDependency(sink=RegisterNext(node), ..)
    ) => assert_eq(node.ordinal(), 3)
    error => fail("unexpected formal binding CDC error: \{Repr(error)}")
  } noraise {
    _ => fail("expected formal binding CDC rejection")
  }
}

///|
test "formal binding derivation rejects timing-less multi-domain IR" {
  let design = formal_timingless_multi_domain()
  let path = @systemverilog.TopModulePath::checked(
    design, "FormalTiminglessMultiDomain",
  )
  try
    @systemverilog.derive_bindings(
      design,
      formal_safe_emission(),
      path,
      fixture_plan(),
    )
  catch {
    @systemverilog.IntegrationError::CdcRejected(
      TimingUnavailable(module_name~)
    ) => assert_eq(module_name, "FormalTiminglessMultiDomain")
    error => fail("unexpected formal binding timing error: \{Repr(error)}")
  } noraise {
    _ => fail("expected formal binding timing rejection")
  }
}

///|
test "formal integration rejects an ordinary two-flop crossing" {
  let design = formal_two_flop_crossing()
  let path = @systemverilog.TopModulePath::checked(
    design, "FormalTwoFlopCrossing",
  )
  try
    @systemverilog.integrate(
      design,
      formal_safe_emission(),
      path,
      fixture_plan(),
    )
  catch {
    @systemverilog.IntegrationError::CdcRejected(
      UnsafeDependency(sink=RegisterNext(node), ..)
    ) => assert_eq(node.ordinal(), 3)
    error => fail("unexpected formal integration CDC error: \{Repr(error)}")
  } noraise {
    _ => fail("expected formal integration CDC rejection")
  }
}

///|
test "formal integration rejects timing-less multi-domain IR" {
  let design = formal_timingless_multi_domain()
  let path = @systemverilog.TopModulePath::checked(
    design, "FormalTiminglessMultiDomain",
  )
  try
    @systemverilog.integrate(
      design,
      formal_safe_emission(),
      path,
      fixture_plan(),
    )
  catch {
    @systemverilog.IntegrationError::CdcRejected(
      TimingUnavailable(module_name~)
    ) => assert_eq(module_name, "FormalTiminglessMultiDomain")
    error => fail("unexpected formal integration timing error: \{Repr(error)}")
  } noraise {
    _ => fail("expected formal integration timing rejection")
  }
}
