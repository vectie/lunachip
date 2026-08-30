///|
fn checked_synchronizer_module(
  stages : Int,
  asynchronous : Bool,
  with_reset : Bool,
) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("CheckedSynchronizer")
  let source_clock = builder.input("source_clock", @wire.clock())
  let source_domain = builder.rising_edge(source_clock)
  let source = builder.input("source", @wire.bits(1))
  ignore(builder.constant(@wire.bits(1), 0UL))
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let destination = builder.rising_edge(destination_clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  builder.input_timing(
    source,
    if asynchronous {
      Asynchronous
    } else {
      SampledIn(source_domain.id())
    },
  )
  builder.input_timing(reset_signal, SampledIn(destination.id()))
  let synchronized = if asynchronous {
    if with_reset {
      builder.bit_synchronizer("sync🔥", source, destination, stages, reset~)
    } else {
      builder.bit_synchronizer("sync🔥", source, destination, stages)
    }
  } else if with_reset {
    builder.bit_synchronizer(
      "sync🔥",
      source,
      destination,
      stages,
      source_domain~,
      reset~,
    )
  } else {
    builder.bit_synchronizer(
      "sync🔥",
      source,
      destination,
      stages,
      source_domain~,
    )
  }
  let output = builder.output("synchronized", @wire.bits(1))
  builder.output_timing(output, ProducedIn(destination.id()))
  builder.connect(output, synchronized)
  builder.finish()
}

///|
test "bit synchronizer constructs deterministic sparse two through four stage chains" {
  for stage_count in [2, 3, 4] {
    let hardware_module = checked_synchronizer_module(stage_count, false, true)
    assert_eq(hardware_module.domains().map(domain => domain.id().ordinal()), [
      0, 3,
    ])
    assert_eq(hardware_module.cdc_primitives().length(), 1)
    let BitSynchronizer(spec) = hardware_module.cdc_primitives()[0]
    assert_eq(spec.id().ordinal(), 0)
    assert_eq(spec.name(), "sync🔥")
    assert_eq(spec.source_domain(), SourceDomain(@ir.ClockDomainId::new(0)))
    assert_eq(spec.source().ordinal(), 1)
    assert_eq(spec.destination().ordinal(), 3)
    assert_eq(
      spec.stages().map(stage => stage.ordinal()),
      [
        for index in 0..<stage_count => index + 5
      ],
    )
    assert_eq(spec.output().ordinal(), stage_count + 4)
    assert_eq(spec.reset(), Some(@ir.ResetSpec::new(@ir.NodeId::new(4), 0UL)))
    for index, stage in spec.stages() {
      guard hardware_module.nodes()[stage.ordinal()].kind()
        is Register(register) else {
        fail("expected ordinary destination register")
      }
      assert_eq(register.domain().id().ordinal(), 3)
      assert_eq(
        register.next().ordinal(),
        if index == 0 {
          1
        } else {
          stage.ordinal() - 1
        },
      )
      assert_eq(register.enable(), None)
      assert_eq(register.reset(), spec.reset())
    }
  }
}

///|
test "asynchronous source no-reset contract and codec roundtrip are deterministic" {
  let first = checked_synchronizer_module(2, true, false)
  let second = checked_synchronizer_module(2, true, false)
  let BitSynchronizer(spec) = first.cdc_primitives()[0]
  assert_eq(spec.source_domain(), AsynchronousSource)
  assert_eq(spec.reset(), None)
  let first_design = @wire.single_design("wire-sync", first)
  let second_design = @wire.single_design("wire-sync", second)
  let encoded = @codec.serialize(first_design)
  assert_eq(encoded, @codec.serialize(second_design))
  assert_eq(@codec.serialize(@codec.parse(encoded)), encoded)
}

///|
test "bit synchronizer rejects width stage count name and equal domains before mutation" {
  let builder = @wire.ModuleBuilder::new("InvalidSynchronizer")
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let bit = builder.input("bit", @wire.bits(1))
  let wide = builder.input("wide", @wire.bits(2))
  try builder.bit_synchronizer("wide", wide, domain, 2) catch {
    @ir.IrError::ExpectedOneBit(node~) => assert_eq(node, 2)
    error => fail("unexpected synchronizer width error: \{Repr(error)}")
  } noraise {
    _ => fail("expected exact one-bit source rejection")
  }
  for invalid_count in [1, 5] {
    try builder.bit_synchronizer("count", bit, domain, invalid_count) catch {
      @ir.IrError::InvalidBitSynchronizerStageCount(primitive~, actual~) => {
        assert_eq(primitive, 0)
        assert_eq(actual, invalid_count)
      }
      error => fail("unexpected synchronizer stage error: \{Repr(error)}")
    } noraise {
      _ => fail("expected stage-count rejection")
    }
  }
  try builder.bit_synchronizer("", bit, domain, 2) catch {
    @ir.IrError::EmptyName(kind~) => assert_eq(kind, "CDC primitive")
    error => fail("unexpected synchronizer name error: \{Repr(error)}")
  } noraise {
    _ => fail("expected empty-name rejection")
  }
  try
    builder.bit_synchronizer("equal", bit, domain, 2, source_domain=domain)
  catch {
    @ir.IrError::EqualCdcPrimitiveDomains(primitive~, domain~) => {
      assert_eq(primitive, 0)
      assert_eq(domain, 0)
    }
    error => fail("unexpected equal-domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected equal-domain rejection")
  }
  // All validation above precedes register or metadata mutation.
  assert_eq(builder.input("after_failures", @wire.bits(1)).id().ordinal(), 3)
}

///|
test "bit synchronizer rejects foreign signal domain and reset ownership" {
  let builder = @wire.ModuleBuilder::new("Local")
  let local_domain = builder.rising_edge(
    builder.input("local_clock", @wire.clock()),
  )
  let local_bit = builder.input("local_bit", @wire.bits(1))
  let foreign = @wire.ModuleBuilder::new("Foreign")
  let foreign_domain = foreign.rising_edge(
    foreign.input("foreign_clock", @wire.clock()),
  )
  let foreign_bit = foreign.input("foreign_bit", @wire.bits(1))
  let foreign_reset = foreign.synchronous_reset(
    foreign.input("foreign_reset", @wire.reset()),
    0UL,
  )
  let local_reset = builder.synchronous_reset(
    builder.input("local_reset", @wire.reset()),
    2UL,
  )
  try builder.bit_synchronizer("source", foreign_bit, local_domain, 2) catch {
    @wire.WireError::ForeignSignal => ()
    error => fail("unexpected foreign source error: \{Repr(error)}")
  } noraise {
    _ => fail("expected foreign source rejection")
  }
  try
    builder.bit_synchronizer("destination", local_bit, foreign_domain, 2)
  catch {
    @wire.WireError::ForeignClockDomain => ()
    error => fail("unexpected foreign destination error: \{Repr(error)}")
  } noraise {
    _ => fail("expected foreign destination rejection")
  }
  try
    builder.bit_synchronizer(
      "source-domain",
      local_bit,
      local_domain,
      2,
      source_domain=foreign_domain,
    )
  catch {
    @wire.WireError::ForeignClockDomain => ()
    error => fail("unexpected foreign source-domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected foreign source-domain rejection")
  }
  try
    builder.bit_synchronizer(
      "reset",
      local_bit,
      local_domain,
      2,
      reset=foreign_reset,
    )
  catch {
    @wire.WireError::ForeignReset => ()
    error => fail("unexpected foreign reset error: \{Repr(error)}")
  } noraise {
    _ => fail("expected foreign reset rejection")
  }
  try builder.synchronous_reset(local_bit, 0UL) catch {
    @ir.IrError::ExpectedReset(node~) =>
      assert_eq(node, local_bit.id().ordinal())
    error => fail("unexpected reset type error: \{Repr(error)}")
  } noraise {
    _ => fail("expected reset type rejection")
  }
  try
    builder.bit_synchronizer(
      "reset-value",
      local_bit,
      local_domain,
      2,
      reset=local_reset,
    )
  catch {
    @ir.IrError::ConstantOutOfRange(width~, value~) => {
      assert_eq(width, 1)
      assert_eq(value, 2UL)
    }
    error => fail("unexpected reset-value error: \{Repr(error)}")
  } noraise {
    _ => fail("expected one-bit reset-value rejection")
  }
}

///|
test "duplicate synchronizer names are rejected canonically" {
  let builder = @wire.ModuleBuilder::new("DuplicateSynchronizer")
  let source = builder.input("source", @wire.bits(1))
  let clock = builder.input("clock", @wire.clock())
  let destination = builder.rising_edge(clock)
  builder.input_timing(source, Asynchronous)
  ignore(builder.bit_synchronizer("same", source, destination, 2))
  ignore(builder.bit_synchronizer("same", source, destination, 2))
  try builder.finish() catch {
    @ir.IrError::DuplicateCdcPrimitiveName(name) => assert_eq(name, "same")
    error => fail("unexpected duplicate synchronizer error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate synchronizer-name rejection")
  }
}

///|
test "public finish wraps canonical CDC admission errors without an escape" {
  let builder = @wire.ModuleBuilder::new("UnsafeRawCrossing")
  let source_clock = builder.input("source_clock", @wire.clock())
  let source_domain = builder.rising_edge(source_clock)
  let source = builder.input("source", @wire.bits(1))
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let destination = builder.rising_edge(destination_clock)
  builder.input_timing(source, SampledIn(source_domain.id()))
  let unsafe_state = builder.register_in(destination, source)
  let output = builder.output("unsafe", @wire.bits(1))
  builder.output_timing(output, ProducedIn(destination.id()))
  builder.connect(output, unsafe_state)
  try builder.finish() catch {
    @wire.WireError::CdcRejected(
      UnsafeDependency(sink=RegisterNext(node), destination=domain, ..)
    ) => {
      assert_eq(node, unsafe_state.id())
      assert_eq(domain, destination.id())
    }
    error => fail("unexpected wrapped CDC error: \{Repr(error)}")
  } noraise {
    _ => fail("expected raw crossing rejection at public finish")
  }
}

///|
test "declared synchronizer source class must match explicit port timing" {
  let builder = @wire.ModuleBuilder::new("MismatchedSynchronizerSource")
  let source_clock = builder.input("source_clock", @wire.clock())
  let source_domain = builder.rising_edge(source_clock)
  let source = builder.input("source", @wire.bits(1))
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let destination = builder.rising_edge(destination_clock)
  builder.input_timing(source, SampledIn(source_domain.id()))
  // Omitted source_domain declares asynchronous, intentionally mismatching
  // the explicit timed input so canonical admission must reject it.
  ignore(builder.bit_synchronizer("mismatch", source, destination, 2))
  try builder.finish() catch {
    @wire.WireError::CdcRejected(
      PrimitiveSourceMismatch(primitive~, source=node, declared~, ..)
    ) => {
      assert_eq(primitive.ordinal(), 0)
      assert_eq(node, source.id())
      assert_eq(declared, AsynchronousSource)
    }
    error => fail("unexpected source-class error: \{Repr(error)}")
  } noraise {
    _ => fail("expected primitive source-class rejection")
  }
}
