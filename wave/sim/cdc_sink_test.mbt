///|
fn sim_cdc_uint() -> @ir.SignalType raise @ir.IrError {
  UInt(@ir.Width::new(8))
}

///|
fn sim_two_flop_crossing() -> @ir.Module raise @ir.IrError {
  let clock_a = @ir.NodeId::new(0)
  let clock_b = @ir.NodeId::new(1)
  let foreign = @ir.NodeId::new(2)
  let first = @ir.NodeId::new(3)
  let second = @ir.NodeId::new(4)
  let domain_a = @ir.ClockDomain::rising(clock_a)
  let domain_b = @ir.ClockDomain::rising(clock_b)
  let value_type = sim_cdc_uint()
  @ir.Module::checked_with_metadata(
    "SimTwoFlopCrossing",
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
}

///|
fn sim_timingless_multi_domain() -> @ir.Module raise @ir.IrError {
  let clock_a = @ir.NodeId::new(0)
  let clock_b = @ir.NodeId::new(1)
  let constant_a = @ir.NodeId::new(2)
  let constant_b = @ir.NodeId::new(3)
  let state_a = @ir.NodeId::new(4)
  let state_b = @ir.NodeId::new(5)
  let domain_a = @ir.ClockDomain::rising(clock_a)
  let domain_b = @ir.ClockDomain::rising(clock_b)
  let value_type = sim_cdc_uint()
  @ir.Module::checked_with_domains(
    "SimTiminglessMultiDomain",
    [domain_a, domain_b],
    [
      @ir.Node::new(clock_a, Clock, Input("clock_a")),
      @ir.Node::new(clock_b, Clock, Input("clock_b")),
      @ir.Node::new(constant_a, value_type, Constant(1UL)),
      @ir.Node::new(constant_b, value_type, Constant(2UL)),
      @ir.Node::new(
        state_a,
        value_type,
        Register(@ir.RegisterSpec::new(domain_a, constant_a)),
      ),
      @ir.Node::new(
        state_b,
        value_type,
        Register(@ir.RegisterSpec::new(domain_b, constant_b)),
      ),
    ],
    [],
    [
      @ir.OutputPort::new("state_a", value_type, state_a),
      @ir.OutputPort::new("state_b", value_type, state_b),
    ],
  )
}

///|
test "public simulator preparation rejects an ordinary two-flop crossing" {
  try @sim.Simulator::prepare(sim_two_flop_crossing()) catch {
    @sim.SimulatorError::CdcRejected(
      UnsafeDependency(sink=RegisterNext(node), ..)
    ) => assert_eq(node.ordinal(), 3)
    error => fail("unexpected simulator CDC error: \{Repr(error)}")
  } noraise {
    _ => fail("expected simulator CDC rejection")
  }
}

///|
test "public simulator preparation rejects timing-less multi-domain IR" {
  try @sim.Simulator::prepare(sim_timingless_multi_domain()) catch {
    @sim.SimulatorError::CdcRejected(TimingUnavailable(module_name~)) =>
      assert_eq(module_name, "SimTiminglessMultiDomain")
    error => fail("unexpected simulator timing error: \{Repr(error)}")
  } noraise {
    _ => fail("expected simulator timing rejection")
  }
}
