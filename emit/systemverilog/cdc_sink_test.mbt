///|
fn emit_cdc_uint() -> @ir.SignalType raise @ir.IrError {
  UInt(@ir.Width::new(8))
}

///|
fn emit_two_flop_crossing() -> @ir.Design raise @ir.IrError {
  let clock_a = @ir.NodeId::new(0)
  let clock_b = @ir.NodeId::new(1)
  let foreign = @ir.NodeId::new(2)
  let first = @ir.NodeId::new(3)
  let second = @ir.NodeId::new(4)
  let domain_a = @ir.ClockDomain::rising(clock_a)
  let domain_b = @ir.ClockDomain::rising(clock_b)
  let value_type = emit_cdc_uint()
  let hardware_module = @ir.Module::checked_with_metadata(
    "EmitTwoFlopCrossing",
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
  @ir.Design::single("emit-two-flop", hardware_module)
}

///|
fn emit_timingless_multi_domain() -> @ir.Design raise @ir.IrError {
  let clock_a = @ir.NodeId::new(0)
  let clock_b = @ir.NodeId::new(1)
  let next_a = @ir.NodeId::new(2)
  let next_b = @ir.NodeId::new(3)
  let state_a = @ir.NodeId::new(4)
  let state_b = @ir.NodeId::new(5)
  let domain_a = @ir.ClockDomain::rising(clock_a)
  let domain_b = @ir.ClockDomain::rising(clock_b)
  let value_type = emit_cdc_uint()
  let hardware_module = @ir.Module::checked_with_domains(
    "EmitTiminglessMultiDomain",
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
  @ir.Design::single("emit-timingless", hardware_module)
}

///|
test "SystemVerilog emission rejects an ordinary two-flop crossing" {
  try @systemverilog.emit_design(emit_two_flop_crossing()) catch {
    @systemverilog.EmitError::CdcRejected(
      UnsafeDependency(sink=RegisterNext(node), ..)
    ) => assert_eq(node.ordinal(), 3)
    error => fail("unexpected emitter CDC error: \{Repr(error)}")
  } noraise {
    _ => fail("expected emitter CDC rejection")
  }
}

///|
test "SystemVerilog emission rejects timing-less multi-domain IR" {
  try @systemverilog.emit_design(emit_timingless_multi_domain()) catch {
    @systemverilog.EmitError::CdcRejected(TimingUnavailable(module_name~)) =>
      assert_eq(module_name, "EmitTiminglessMultiDomain")
    error => fail("unexpected emitter timing error: \{Repr(error)}")
  } noraise {
    _ => fail("expected emitter timing rejection")
  }
}
