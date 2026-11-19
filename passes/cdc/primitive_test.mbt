///|
fn primitive_metadata(
  inputs : ArrayView[@ir.InputTimingBinding],
  outputs : ArrayView[@ir.OutputTimingBinding],
  primitives : ArrayView[@ir.CdcPrimitive],
) -> @ir.ModuleMetadata raise @ir.IrError {
  @ir.ModuleMetadata::checked_complete([], [], inputs, outputs, primitives)
}

///|
fn bit_synchronizer_fixture(
  stage_count : Int32,
  declared : @ir.CdcSourceDomain,
  timing : @ir.InputTiming?,
  source_is_constant : Bool,
  rogue_consumer~ : Bool = false,
) -> @ir.Module raise @ir.IrError {
  let source_clock_node = @ir.NodeId::new(0)
  let source = @ir.NodeId::new(1)
  let other_clock_node = @ir.NodeId::new(4)
  let destination_clock_node = @ir.NodeId::new(5)
  let source_clock = @ir.ClockDomain::rising(source_clock_node)
  let other_clock = @ir.ClockDomain::rising(other_clock_node)
  let destination_clock = @ir.ClockDomain::rising(destination_clock_node)
  let nodes : Array[@ir.Node] = [
    @ir.Node::new(source_clock_node, Clock, Input("clock_source")),
    @ir.Node::new(
      source,
      cdc_bits(1),
      if source_is_constant {
        Constant(1UL)
      } else {
        Input("source")
      },
    ),
    @ir.Node::new(@ir.NodeId::new(2), cdc_bits(1), Constant(0UL)),
    @ir.Node::new(@ir.NodeId::new(3), cdc_bits(1), Constant(0UL)),
    @ir.Node::new(other_clock_node, Clock, Input("clock_other")),
    @ir.Node::new(destination_clock_node, Clock, Input("clock_destination")),
  ]
  let stages : Array[@ir.NodeId] = []
  for index in 0..<stage_count {
    let stage = @ir.NodeId::new(6 + index)
    let next = if index == 0 { source } else { stages[index - 1] }
    nodes.push(
      @ir.Node::new(
        stage,
        cdc_bits(1),
        Register(@ir.RegisterSpec::new(destination_clock, next)),
      ),
    )
    stages.push(stage)
  }
  if rogue_consumer {
    let rogue = @ir.NodeId::new(nodes.length())
    nodes.push(
      @ir.Node::new(
        rogue,
        cdc_bits(1),
        Register(@ir.RegisterSpec::new(destination_clock, source)),
      ),
    )
  }
  let primitive = @ir.BitSynchronizerPrimitive::checked(
    @ir.CdcPrimitiveId::new(0),
    "bit_sync",
    declared,
    source,
    destination_clock.id(),
    stages,
  )
  let input_timings : Array[@ir.InputTimingBinding] = []
  match timing {
    Some(value) => input_timings.push(cdc_input_timing(1, value))
    None => ()
  }
  @ir.Module::checked_with_metadata(
    "BitSynchronizerFixture",
    [destination_clock, source_clock, other_clock],
    nodes,
    [],
    [
      @ir.OutputPort::new(
        "synchronized",
        cdc_bits(1),
        stages[stages.length() - 1],
      ),
    ],
    primitive_metadata(
      input_timings,
      [cdc_output_timing("synchronized", ProducedIn(destination_clock.id()))],
      [BitSynchronizer(primitive)],
    ),
  )
}

///|
test "exact asynchronous and timed bit synchronizers accept two to four stages" {
  for stage_count in 2..<5 {
    let asynchronous = bit_synchronizer_fixture(
      stage_count,
      AsynchronousSource,
      Some(Asynchronous),
      false,
    )
    @cdc.validate_module(asynchronous)
    let async_analysis = @cdc.analyze_module(asynchronous)
    for stage in 6..<(6 + stage_count) {
      let provenance = async_analysis
        .node(@ir.NodeId::new(stage))
        .unwrap()
        .provenance()
      assert_false(provenance.has_asynchronous())
      assert_eq(cdc_ordinals(provenance.domains()), [5])
    }

    let timed = bit_synchronizer_fixture(
      stage_count,
      SourceDomain(@ir.ClockDomainId::new(0)),
      Some(SampledIn(@ir.ClockDomainId::new(0))),
      false,
    )
    @cdc.validate_module(timed)
    let timed_analysis = @cdc.analyze_module(timed)
    for stage in 6..<(6 + stage_count) {
      assert_eq(
        cdc_ordinals(
          timed_analysis
          .node(@ir.NodeId::new(stage))
          .unwrap()
          .provenance()
          .domains(),
        ),
        [5],
      )
    }
  }
}

///|
fn expect_primitive_source_mismatch(
  hardware_module : @ir.Module,
  declared : @ir.CdcSourceDomain,
  asynchronous : Bool,
  domains : Array[Int32],
  witness : Array[Int32]?,
) -> Unit raise {
  try @cdc.validate_module(hardware_module) catch {
    PrimitiveSourceMismatch(
      primitive~,
      source~,
      declared=actual_declaration,
      actual~,
      witness=actual_witness,
      ..
    ) => {
      assert_eq(primitive.ordinal(), 0)
      assert_eq(source.ordinal(), 1)
      assert_eq(actual_declaration, declared)
      assert_eq(actual.has_asynchronous(), asynchronous)
      assert_eq(cdc_ordinals(actual.domains()), domains)
      assert_eq(actual_witness.map(item => cdc_path_ordinals(item)), witness)
    }
    error => fail("unexpected primitive-source error: \{Repr(error)}")
  } noraise {
    _ => fail("expected primitive-source rejection")
  }
}

///|
test "primitive source declarations must exactly match asynchronous or timed provenance" {
  expect_primitive_source_mismatch(
    bit_synchronizer_fixture(
      2,
      SourceDomain(@ir.ClockDomainId::new(0)),
      Some(Asynchronous),
      false,
    ),
    SourceDomain(@ir.ClockDomainId::new(0)),
    true,
    [],
    Some([1]),
  )
  expect_primitive_source_mismatch(
    bit_synchronizer_fixture(
      2,
      AsynchronousSource,
      Some(SampledIn(@ir.ClockDomainId::new(0))),
      false,
    ),
    AsynchronousSource,
    false,
    [0],
    Some([1]),
  )
  expect_primitive_source_mismatch(
    bit_synchronizer_fixture(
      2,
      SourceDomain(@ir.ClockDomainId::new(4)),
      Some(SampledIn(@ir.ClockDomainId::new(0))),
      false,
    ),
    SourceDomain(@ir.ClockDomainId::new(4)),
    false,
    [0],
    Some([1]),
  )
}

///|
test "neutral primitive sources fail closed without inventing a witness" {
  expect_primitive_source_mismatch(
    bit_synchronizer_fixture(2, AsynchronousSource, None, true),
    AsynchronousSource,
    false,
    [],
    None,
  )
}

///|
fn mixed_source_primitive() -> @ir.Module raise @ir.IrError {
  let source_clock_node = @ir.NodeId::new(0)
  let asynchronous = @ir.NodeId::new(1)
  let timed = @ir.NodeId::new(2)
  let mixed = @ir.NodeId::new(3)
  let filler = @ir.NodeId::new(4)
  let destination_clock_node = @ir.NodeId::new(5)
  let first = @ir.NodeId::new(6)
  let second = @ir.NodeId::new(7)
  let source_clock = @ir.ClockDomain::rising(source_clock_node)
  let destination_clock = @ir.ClockDomain::rising(destination_clock_node)
  let primitive = @ir.BitSynchronizerPrimitive::checked(
    @ir.CdcPrimitiveId::new(0),
    "mixed_source",
    AsynchronousSource,
    mixed,
    destination_clock.id(),
    [first, second],
  )
  @ir.Module::checked_with_metadata(
    "MixedPrimitiveSource",
    [destination_clock, source_clock],
    [
      @ir.Node::new(source_clock_node, Clock, Input("clock_source")),
      @ir.Node::new(asynchronous, cdc_bits(1), Input("asynchronous")),
      @ir.Node::new(timed, cdc_bits(1), Input("timed")),
      @ir.Node::new(mixed, cdc_bits(1), BitOr(asynchronous, timed)),
      @ir.Node::new(filler, cdc_bits(1), Constant(0UL)),
      @ir.Node::new(destination_clock_node, Clock, Input("clock_destination")),
      @ir.Node::new(
        first,
        cdc_bits(1),
        Register(@ir.RegisterSpec::new(destination_clock, mixed)),
      ),
      @ir.Node::new(
        second,
        cdc_bits(1),
        Register(@ir.RegisterSpec::new(destination_clock, first)),
      ),
    ],
    [],
    [@ir.OutputPort::new("synchronized", cdc_bits(1), second)],
    primitive_metadata(
      [
        cdc_input_timing(1, Asynchronous),
        cdc_input_timing(2, SampledIn(source_clock.id())),
      ],
      [cdc_output_timing("synchronized", ProducedIn(destination_clock.id()))],
      [BitSynchronizer(primitive)],
    ),
  )
}

///|
test "mixed primitive sources cannot masquerade as asynchronous" {
  try @cdc.validate_module(mixed_source_primitive()) catch {
    @cdc.PrimitiveSourceMismatch(actual~, witness~, ..) => {
      assert_true(actual.has_asynchronous())
      assert_eq(cdc_ordinals(actual.domains()), [0])
      assert_eq(cdc_path_ordinals(witness.unwrap()), [1, 3])
    }
    error => fail("unexpected mixed primitive error: \{Repr(error)}")
  } noraise {
    _ => fail("expected mixed primitive-source rejection")
  }
}

///|
fn chained_sparse_synchronizers() -> @ir.Module raise @ir.IrError {
  let clock_a_node = @ir.NodeId::new(0)
  let source = @ir.NodeId::new(1)
  let clock_b_node = @ir.NodeId::new(5)
  let b_first = @ir.NodeId::new(6)
  let b_second = @ir.NodeId::new(7)
  let clock_c_node = @ir.NodeId::new(10)
  let c_first = @ir.NodeId::new(11)
  let c_second = @ir.NodeId::new(12)
  let domain_a = @ir.ClockDomain::rising(clock_a_node)
  let domain_b = @ir.ClockDomain::rising(clock_b_node)
  let domain_c = @ir.ClockDomain::rising(clock_c_node)
  let first_primitive = @ir.BitSynchronizerPrimitive::checked(
    @ir.CdcPrimitiveId::new(0),
    "a_to_b",
    SourceDomain(domain_a.id()),
    source,
    domain_b.id(),
    [b_first, b_second],
  )
  let second_primitive = @ir.BitSynchronizerPrimitive::checked(
    @ir.CdcPrimitiveId::new(1),
    "b_to_c",
    SourceDomain(domain_b.id()),
    b_second,
    domain_c.id(),
    [c_first, c_second],
  )
  @ir.Module::checked_with_metadata(
    "ChainedSparseSynchronizers",
    [domain_c, domain_a, domain_b],
    [
      @ir.Node::new(clock_a_node, Clock, Input("clock_a")),
      @ir.Node::new(source, cdc_bits(1), Input("source")),
      @ir.Node::new(@ir.NodeId::new(2), cdc_bits(1), Constant(0UL)),
      @ir.Node::new(@ir.NodeId::new(3), cdc_bits(1), Constant(0UL)),
      @ir.Node::new(@ir.NodeId::new(4), cdc_bits(1), Constant(0UL)),
      @ir.Node::new(clock_b_node, Clock, Input("clock_b")),
      @ir.Node::new(
        b_first,
        cdc_bits(1),
        Register(@ir.RegisterSpec::new(domain_b, source)),
      ),
      @ir.Node::new(
        b_second,
        cdc_bits(1),
        Register(@ir.RegisterSpec::new(domain_b, b_first)),
      ),
      @ir.Node::new(@ir.NodeId::new(8), cdc_bits(1), Constant(0UL)),
      @ir.Node::new(@ir.NodeId::new(9), cdc_bits(1), Constant(0UL)),
      @ir.Node::new(clock_c_node, Clock, Input("clock_c")),
      @ir.Node::new(
        c_first,
        cdc_bits(1),
        Register(@ir.RegisterSpec::new(domain_c, b_second)),
      ),
      @ir.Node::new(
        c_second,
        cdc_bits(1),
        Register(@ir.RegisterSpec::new(domain_c, c_first)),
      ),
    ],
    [],
    [@ir.OutputPort::new("synchronized", cdc_bits(1), c_second)],
    primitive_metadata(
      [cdc_input_timing(1, SampledIn(domain_a.id()))],
      [cdc_output_timing("synchronized", ProducedIn(domain_c.id()))],
      [BitSynchronizer(first_primitive), BitSynchronizer(second_primitive)],
    ),
  )
}

///|
test "multiple chained synchronizers retain sparse destination provenance" {
  let hardware_module = chained_sparse_synchronizers()
  @cdc.validate_module(hardware_module)
  let analysis = @cdc.analyze_module(hardware_module)
  for stage in [6, 7] {
    assert_eq(
      cdc_ordinals(
        analysis.node(@ir.NodeId::new(stage)).unwrap().provenance().domains(),
      ),
      [5],
    )
  }
  for stage in [11, 12] {
    assert_eq(
      cdc_ordinals(
        analysis.node(@ir.NodeId::new(stage)).unwrap().provenance().domains(),
      ),
      [10],
    )
  }
}

///|
test "a primitive declaration does not waive another source consumer" {
  try
    @cdc.validate_module(
      bit_synchronizer_fixture(
        2,
        AsynchronousSource,
        Some(Asynchronous),
        false,
        rogue_consumer=true,
      ),
    )
  catch {
    @cdc.UnsafeDependency(sink=RegisterNext(node), witness~, ..) => {
      assert_eq(node.ordinal(), 8)
      assert_eq(cdc_path_ordinals(witness), [1, 8])
    }
    error => fail("unexpected rogue-consumer error: \{Repr(error)}")
  } noraise {
    _ => fail("expected non-primitive consumer rejection")
  }
}

///|
fn undeclared_per_bit_reconvergence() -> @ir.Module raise @ir.IrError {
  let source_clock_node = @ir.NodeId::new(0)
  let bus = @ir.NodeId::new(1)
  let low = @ir.NodeId::new(2)
  let high = @ir.NodeId::new(3)
  let filler = @ir.NodeId::new(4)
  let destination_clock_node = @ir.NodeId::new(5)
  let low_first = @ir.NodeId::new(6)
  let low_second = @ir.NodeId::new(7)
  let high_first = @ir.NodeId::new(8)
  let high_second = @ir.NodeId::new(9)
  let joined = @ir.NodeId::new(10)
  let source_clock = @ir.ClockDomain::rising(source_clock_node)
  let destination_clock = @ir.ClockDomain::rising(destination_clock_node)
  @ir.Module::checked_with_metadata(
    "UndeclaredPerBitReconvergence",
    [destination_clock, source_clock],
    [
      @ir.Node::new(source_clock_node, Clock, Input("clock_source")),
      @ir.Node::new(bus, cdc_bits(2), Input("bus")),
      @ir.Node::new(low, cdc_bits(1), Slice(value=bus, msb=0, lsb=0)),
      @ir.Node::new(high, cdc_bits(1), Slice(value=bus, msb=1, lsb=1)),
      @ir.Node::new(filler, cdc_bits(1), Constant(0UL)),
      @ir.Node::new(destination_clock_node, Clock, Input("clock_destination")),
      @ir.Node::new(
        low_first,
        cdc_bits(1),
        Register(@ir.RegisterSpec::new(destination_clock, low)),
      ),
      @ir.Node::new(
        low_second,
        cdc_bits(1),
        Register(@ir.RegisterSpec::new(destination_clock, low_first)),
      ),
      @ir.Node::new(
        high_first,
        cdc_bits(1),
        Register(@ir.RegisterSpec::new(destination_clock, high)),
      ),
      @ir.Node::new(
        high_second,
        cdc_bits(1),
        Register(@ir.RegisterSpec::new(destination_clock, high_first)),
      ),
      @ir.Node::new(
        joined,
        cdc_bits(2),
        Concat(most_significant=high_second, least_significant=low_second),
      ),
    ],
    [],
    [@ir.OutputPort::new("joined", cdc_bits(2), joined)],
    primitive_metadata(
      [cdc_input_timing(1, SampledIn(source_clock.id()))],
      [cdc_output_timing("joined", ProducedIn(destination_clock.id()))],
      [],
    ),
  )
}

///|
test "undeclared per-bit chains and reconvergence receive no heuristic waiver" {
  try @cdc.validate_module(undeclared_per_bit_reconvergence()) catch {
    @cdc.UnsafeDependency(sink=RegisterNext(node), witness~, ..) => {
      assert_eq(node.ordinal(), 6)
      assert_eq(cdc_path_ordinals(witness), [1, 2, 6])
    }
    error => fail("unexpected per-bit crossing error: \{Repr(error)}")
  } noraise {
    _ => fail("expected undeclared per-bit crossing rejection")
  }
}
