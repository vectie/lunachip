///|
fn cdc_bit() -> @ir.SignalType raise @ir.IrError {
  Bits(@ir.Width::new(1))
}

///|
fn bit_synchronizer_module(
  source_domain? : @ir.CdcSourceDomain,
  destination? : @ir.ClockDomainId,
  first_next? : @ir.NodeId,
  first_enable? : @ir.NodeId,
  first_reset? : @ir.ResetSpec,
  expose_first? : Bool = false,
) -> @ir.Module raise @ir.IrError {
  let clock_source = @ir.NodeId::new(0)
  let clock_destination = @ir.NodeId::new(1)
  let reset = @ir.NodeId::new(2)
  let source = @ir.NodeId::new(3)
  let first = @ir.NodeId::new(4)
  let second = @ir.NodeId::new(5)
  let source_clock = @ir.ClockDomain::rising(clock_source)
  let destination_clock = @ir.ClockDomain::rising(clock_destination)
  let reset_spec = @ir.ResetSpec::new(reset, 0UL)
  let primitive = @ir.BitSynchronizerPrimitive::checked(
    @ir.CdcPrimitiveId::new(0),
    "sync🔥",
    source_domain.unwrap_or(SourceDomain(source_clock.id())),
    source,
    destination.unwrap_or(destination_clock.id()),
    [first, second],
    reset=reset_spec,
  )
  let outputs : Array[@ir.OutputPort] = [
    @ir.OutputPort::new("synchronized", cdc_bit(), second),
  ]
  if expose_first {
    outputs.push(@ir.OutputPort::new("unsafe_stage", cdc_bit(), first))
  }
  @ir.Module::checked_with_metadata(
    "BitSynchronizer",
    [source_clock, destination_clock],
    [
      @ir.Node::new(clock_source, Clock, Input("clock_source")),
      @ir.Node::new(clock_destination, Clock, Input("clock_destination")),
      @ir.Node::new(reset, Reset, Input("reset")),
      @ir.Node::new(source, cdc_bit(), Input("source")),
      @ir.Node::new(
        first,
        cdc_bit(),
        Register(
          @ir.RegisterSpec::new(
            destination_clock,
            first_next.unwrap_or(source),
            reset=first_reset.unwrap_or(reset_spec),
            enable?=first_enable,
          ),
        ),
      ),
      @ir.Node::new(
        second,
        cdc_bit(),
        Register(
          @ir.RegisterSpec::new(destination_clock, first, reset=reset_spec),
        ),
      ),
    ],
    [],
    outputs,
    @ir.ModuleMetadata::checked_complete([], [], [], [], [
      BitSynchronizer(primitive),
    ]),
  )
}

///|
test "bit synchronizer metadata retains an exact checked structural chain" {
  let hardware_module = bit_synchronizer_module()
  let primitives = hardware_module.cdc_primitives()
  assert_eq(primitives.length(), 1)
  guard primitives[0] is BitSynchronizer(spec) else {
    fail("expected bit synchronizer primitive")
  }
  assert_eq(spec.id().ordinal(), 0)
  assert_eq(spec.name(), "sync🔥")
  assert_eq(spec.source_domain(), SourceDomain(@ir.ClockDomainId::new(0)))
  assert_eq(spec.source().ordinal(), 3)
  assert_eq(spec.destination().ordinal(), 1)
  assert_eq(spec.stages().map(node => node.ordinal()), [4, 5])
  assert_eq(spec.output().ordinal(), 5)
  assert_eq(spec.reset(), Some(@ir.ResetSpec::new(@ir.NodeId::new(2), 0UL)))
}

///|
test "bit synchronizer construction checks identity count and ownership" {
  for count in [1, 5] {
    let stages = Array::make(count, @ir.NodeId::new(10))
    for index in 0..<count {
      stages[index] = @ir.NodeId::new(10 + index)
    }
    try
      @ir.BitSynchronizerPrimitive::checked(
        @ir.CdcPrimitiveId::new(0),
        "bad",
        AsynchronousSource,
        @ir.NodeId::new(1),
        @ir.ClockDomainId::new(0),
        stages,
      )
    catch {
      InvalidBitSynchronizerStageCount(primitive~, actual~) => {
        assert_eq(primitive, 0)
        assert_eq(actual, count)
      }
      error => fail("unexpected stage-count error: \{Repr(error)}")
    } noraise {
      _ => fail("expected stage-count rejection")
    }
  }
  try @ir.CdcPrimitiveId::new(-1) catch {
    InvalidCdcPrimitiveId(id) => assert_eq(id, -1)
    error => fail("unexpected primitive ID error: \{Repr(error)}")
  } noraise {
    _ => fail("expected primitive ID rejection")
  }
  try
    @ir.BitSynchronizerPrimitive::checked(
      @ir.CdcPrimitiveId::new(0),
      "duplicate",
      AsynchronousSource,
      @ir.NodeId::new(1),
      @ir.ClockDomainId::new(0),
      [@ir.NodeId::new(2), @ir.NodeId::new(2)],
    )
  catch {
    DuplicateCdcPrimitiveStage(node~) => assert_eq(node, 2)
    error => fail("unexpected duplicate stage error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate stage rejection")
  }
  let valid = @ir.BitSynchronizerPrimitive::checked(
    @ir.CdcPrimitiveId::new(0),
    "limit",
    AsynchronousSource,
    @ir.NodeId::new(1),
    @ir.ClockDomainId::new(0),
    [@ir.NodeId::new(2), @ir.NodeId::new(3)],
  )
  try
    @ir.ModuleMetadata::checked_complete(
      [],
      [],
      [],
      [],
      Array::make(65537, BitSynchronizer(valid)),
    )
  catch {
    CdcPrimitiveLimitExceeded(maximum~, actual~) => {
      assert_eq(maximum, 65536)
      assert_eq(actual, 65537)
    }
    error => fail("unexpected primitive limit error: \{Repr(error)}")
  } noraise {
    _ => fail("expected primitive table limit rejection")
  }
}

///|
test "bit synchronizer validation rejects domains structure controls and fanout" {
  try
    bit_synchronizer_module(
      source_domain=SourceDomain(@ir.ClockDomainId::new(1)),
    )
  catch {
    EqualCdcPrimitiveDomains(primitive~, domain~) => {
      assert_eq(primitive, 0)
      assert_eq(domain, 1)
    }
    error => fail("unexpected equal-domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected equal-domain rejection")
  }
  try bit_synchronizer_module(destination=@ir.ClockDomainId::new(99)) catch {
    UnknownCdcPrimitiveDomain(primitive~, domain~) => {
      assert_eq(primitive, 0)
      assert_eq(domain, 99)
    }
    error => fail("unexpected destination error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unknown destination rejection")
  }
  try bit_synchronizer_module(first_next=@ir.NodeId::new(5)) catch {
    CdcPrimitiveStageNextMismatch(primitive~, stage~, expected~, actual~) => {
      assert_eq(primitive, 0)
      assert_eq(stage, 0)
      assert_eq(expected, 3)
      assert_eq(actual, 5)
    }
    error => fail("unexpected next-state error: \{Repr(error)}")
  } noraise {
    _ => fail("expected stage-next rejection")
  }
  try bit_synchronizer_module(first_enable=@ir.NodeId::new(3)) catch {
    CdcPrimitiveStageHasEnable(primitive~, stage~, node~) => {
      assert_eq(primitive, 0)
      assert_eq(stage, 0)
      assert_eq(node, 4)
    }
    error => fail("unexpected enable error: \{Repr(error)}")
  } noraise {
    _ => fail("expected stage-enable rejection")
  }
  try
    bit_synchronizer_module(
      first_reset=@ir.ResetSpec::new(@ir.NodeId::new(2), 1UL),
    )
  catch {
    CdcPrimitiveStageResetMismatch(primitive~, stage~, node~) => {
      assert_eq(primitive, 0)
      assert_eq(stage, 0)
      assert_eq(node, 4)
    }
    error => fail("unexpected reset error: \{Repr(error)}")
  } noraise {
    _ => fail("expected stage-reset rejection")
  }
  try bit_synchronizer_module(expose_first=true) catch {
    CdcPrimitiveIntermediateFanout(primitive~, stage~, node~, consumer~) => {
      assert_eq(primitive, 0)
      assert_eq(stage, 0)
      assert_eq(node, 4)
      assert_eq(consumer, "output:unsafe_stage")
    }
    error => fail("unexpected fanout error: \{Repr(error)}")
  } noraise {
    _ => fail("expected intermediate fanout rejection")
  }
}
