///|
fn replay_cdc_uint() -> @ir.SignalType raise @ir.IrError {
  UInt(@ir.Width::new(8))
}

///|
fn replay_two_flop_crossing() -> @ir.Design raise @ir.IrError {
  let clock_a = @ir.NodeId::new(0)
  let clock_b = @ir.NodeId::new(1)
  let foreign = @ir.NodeId::new(2)
  let first = @ir.NodeId::new(3)
  let second = @ir.NodeId::new(4)
  let domain_a = @ir.ClockDomain::rising(clock_a)
  let domain_b = @ir.ClockDomain::rising(clock_b)
  let value_type = replay_cdc_uint()
  let hardware_module = @ir.Module::checked_with_metadata(
    "ReplayTwoFlopCrossing",
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
  @ir.Design::single("replay-two-flop", hardware_module)
}

///|
fn replay_timingless_multi_domain() -> @ir.Design raise @ir.IrError {
  let clock_a = @ir.NodeId::new(0)
  let clock_b = @ir.NodeId::new(1)
  let next_a = @ir.NodeId::new(2)
  let next_b = @ir.NodeId::new(3)
  let state_a = @ir.NodeId::new(4)
  let state_b = @ir.NodeId::new(5)
  let domain_a = @ir.ClockDomain::rising(clock_a)
  let domain_b = @ir.ClockDomain::rising(clock_b)
  let value_type = replay_cdc_uint()
  let hardware_module = @ir.Module::checked_with_domains(
    "ReplayTiminglessMultiDomain",
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
  @ir.Design::single("replay-timingless", hardware_module)
}

///|
fn replay_cdc_digest() -> @replay.ReplayDigest raise @replay.ReplayError {
  @replay.ReplayDigest::checked("fnv1a-64", "0000000000000000")
}

///|
fn replay_cdc_encode_text(value : String) -> String {
  let bytes = @utf8.encode(value)
  if bytes.is_empty() {
    return "-"
  }
  let builder = StringBuilder(size_hint=bytes.length() * 2)
  for byte in bytes {
    let encoded = byte.to_hex()
    if encoded.length() == 1 {
      builder.write_char('0')
    }
    builder.write_string(encoded)
  }
  builder.to_string()
}

///|
fn replay_cdc_legacy_source(design : @ir.Design) -> String {
  let canonical_ir = @codec.serialize(design)
  let ir_digest = @codec.content_digest(design)
  (
    #|LUNACHIP-REPLAY 1
    #|SEMANTICS 6c756e61636869702d73656d616e746963732f31
    #|OPTIONS 0
    #|
  ) +
  "IR \{ir_digest.algorithm()} \{ir_digest.to_hex()} \{replay_cdc_encode_text(canonical_ir)}\n" +
  (
    #|STIMULI 0
    #|STOP after_boundary 0
    #|TAPS 0
    #|EXPECTED fnv1a-64 0000000000000000
    #|END
    #|
  )
}

///|
test "replay checked construction rejects an ordinary two-flop crossing" {
  try
    @replay.ReplayBundle::checked(
      replay_two_flop_crossing(),
      "lunachip-semantics/1",
      [],
      [],
      AfterBoundary(0UL),
      [],
      replay_cdc_digest(),
    )
  catch {
    @replay.ReplayError::CdcRejected(
      UnsafeDependency(sink=RegisterNext(node), ..)
    ) => assert_eq(node.ordinal(), 3)
    error => fail("unexpected checked replay CDC error: \{Repr(error)}")
  } noraise {
    _ => fail("expected checked replay CDC rejection")
  }
}

///|
test "atomic replay construction rejects timing-less multi-domain IR" {
  try
    @replay.ReplayBundle::checked_atomic(
      replay_timingless_multi_domain(),
      "lunachip-semantics/2",
      [],
      1UL,
      [],
      AtTime(0UL),
      [],
      replay_cdc_digest(),
    )
  catch {
    @replay.ReplayError::CdcRejected(TimingUnavailable(module_name~)) =>
      assert_eq(module_name, "ReplayTiminglessMultiDomain")
    error => fail("unexpected atomic replay timing error: \{Repr(error)}")
  } noraise {
    _ => fail("expected atomic replay timing rejection")
  }
}

///|
test "legacy unsafe replay parses losslessly but execution fails closed" {
  let source = replay_cdc_legacy_source(replay_two_flop_crossing())
  let bundle = @replay.parse(source)
  assert_eq(@replay.serialize(bundle), source)
  try @replay.execute(bundle) catch {
    @replay.ReplayExecutionError::CdcRejected(
      UnsafeDependency(sink=RegisterNext(node), ..)
    ) => assert_eq(node.ordinal(), 3)
    error => fail("unexpected replay execution CDC error: \{Repr(error)}")
  } noraise {
    _ => fail("expected replay execution CDC rejection")
  }
}

///|
test "legacy timing-less multi-domain replay parses but cannot execute" {
  let source = replay_cdc_legacy_source(replay_timingless_multi_domain())
  let bundle = @replay.parse(source)
  assert_eq(@replay.serialize(bundle), source)
  try @replay.execute(bundle) catch {
    @replay.ReplayExecutionError::CdcRejected(TimingUnavailable(module_name~)) =>
      assert_eq(module_name, "ReplayTiminglessMultiDomain")
    error => fail("unexpected replay execution timing error: \{Repr(error)}")
  } noraise {
    _ => fail("expected replay execution timing rejection")
  }
}
