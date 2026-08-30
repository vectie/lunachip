///|
fn every_node_kind_module() -> @ir.Module raise @ir.IrError {
  let u8 = cdc_uint(8)
  let u16 = cdc_uint(16)
  let s8 = cdc_sint(8)
  let s16 = cdc_sint(16)
  let bit = cdc_bits(1)
  let domain_a = @ir.ClockDomain::rising(@ir.NodeId::new(0))
  let domain_b = @ir.ClockDomain::rising(@ir.NodeId::new(3))
  let nodes = [
    @ir.Node::new(@ir.NodeId::new(0), Clock, Input("clock_a")),
    @ir.Node::new(@ir.NodeId::new(1), u8, Input("a")),
    @ir.Node::new(@ir.NodeId::new(2), u8, Input("async")),
    @ir.Node::new(@ir.NodeId::new(3), Clock, Input("clock_b")),
    @ir.Node::new(@ir.NodeId::new(4), u8, Input("b")),
    @ir.Node::new(@ir.NodeId::new(5), bit, Input("select")),
    @ir.Node::new(@ir.NodeId::new(6), s8, Input("signed")),
    @ir.Node::new(@ir.NodeId::new(7), u8, Constant(0UL)),
    @ir.Node::new(
      @ir.NodeId::new(8),
      u8,
      Add(@ir.NodeId::new(1), @ir.NodeId::new(1)),
    ),
    @ir.Node::new(
      @ir.NodeId::new(9),
      u8,
      Sub(@ir.NodeId::new(1), @ir.NodeId::new(1)),
    ),
    @ir.Node::new(
      @ir.NodeId::new(10),
      u8,
      MulLow(@ir.NodeId::new(1), @ir.NodeId::new(1)),
    ),
    @ir.Node::new(
      @ir.NodeId::new(11),
      u16,
      MulFull(@ir.NodeId::new(1), @ir.NodeId::new(1)),
    ),
    @ir.Node::new(
      @ir.NodeId::new(12),
      u8,
      BitAnd(@ir.NodeId::new(1), @ir.NodeId::new(2)),
    ),
    @ir.Node::new(
      @ir.NodeId::new(13),
      u8,
      BitOr(@ir.NodeId::new(1), @ir.NodeId::new(2)),
    ),
    @ir.Node::new(
      @ir.NodeId::new(14),
      u8,
      BitXor(@ir.NodeId::new(1), @ir.NodeId::new(4)),
    ),
    @ir.Node::new(@ir.NodeId::new(15), u8, BitNot(@ir.NodeId::new(2))),
    @ir.Node::new(
      @ir.NodeId::new(16),
      bit,
      Equal(@ir.NodeId::new(1), @ir.NodeId::new(4)),
    ),
    @ir.Node::new(
      @ir.NodeId::new(17),
      bit,
      LessThan(@ir.NodeId::new(1), @ir.NodeId::new(4)),
    ),
    @ir.Node::new(
      @ir.NodeId::new(18),
      bit,
      LessEqual(@ir.NodeId::new(1), @ir.NodeId::new(4)),
    ),
    @ir.Node::new(
      @ir.NodeId::new(19),
      u8,
      ShiftLeft(value=@ir.NodeId::new(1), amount=@ir.NodeId::new(1)),
    ),
    @ir.Node::new(
      @ir.NodeId::new(20),
      u8,
      LogicalShiftRight(value=@ir.NodeId::new(2), amount=@ir.NodeId::new(1)),
    ),
    @ir.Node::new(
      @ir.NodeId::new(21),
      s8,
      ArithmeticShiftRight(value=@ir.NodeId::new(6), amount=@ir.NodeId::new(1)),
    ),
    @ir.Node::new(
      @ir.NodeId::new(22),
      cdc_bits(4),
      Slice(value=@ir.NodeId::new(2), msb=3, lsb=0),
    ),
    @ir.Node::new(
      @ir.NodeId::new(23),
      cdc_bits(16),
      Concat(
        most_significant=@ir.NodeId::new(1),
        least_significant=@ir.NodeId::new(4),
      ),
    ),
    @ir.Node::new(@ir.NodeId::new(24), u16, ZeroExtend(@ir.NodeId::new(2))),
    @ir.Node::new(@ir.NodeId::new(25), s16, SignExtend(@ir.NodeId::new(6))),
    @ir.Node::new(@ir.NodeId::new(26), u8, Truncate(@ir.NodeId::new(24))),
    @ir.Node::new(
      @ir.NodeId::new(27),
      cdc_bits(8),
      Reinterpret(@ir.NodeId::new(2)),
    ),
    @ir.Node::new(
      @ir.NodeId::new(28),
      u8,
      Mux(
        select=@ir.NodeId::new(5),
        when_true=@ir.NodeId::new(12),
        when_false=@ir.NodeId::new(4),
      ),
    ),
    @ir.Node::new(
      @ir.NodeId::new(29),
      u8,
      Register(@ir.RegisterSpec::new(domain_a, @ir.NodeId::new(1))),
    ),
  ]
  @ir.Module::checked_with_metadata(
    "EveryNodeKind",
    [domain_b, domain_a],
    nodes,
    [],
    [],
    cdc_metadata(
      [
        cdc_input_timing(1, SampledIn(domain_a.id())),
        cdc_input_timing(2, Asynchronous),
        cdc_input_timing(4, SampledIn(domain_b.id())),
        cdc_input_timing(5, Asynchronous),
        cdc_input_timing(6, SampledIn(domain_a.id())),
      ],
      [],
    ),
  )
}

///|
test "every current combinational NodeKind propagates exact provenance" {
  let analysis = @cdc.analyze_module(every_node_kind_module())
  for node in [8, 9, 10, 11, 19, 21, 25, 29] {
    let found = analysis.node(@ir.NodeId::new(node)).unwrap()
    assert_false(found.provenance().has_asynchronous())
    assert_eq(cdc_ordinals(found.provenance().domains()), [0])
  }
  for node in [15, 22, 24, 26, 27] {
    let found = analysis.node(@ir.NodeId::new(node)).unwrap()
    assert_true(found.provenance().has_asynchronous())
    assert_true(found.provenance().domains().is_empty())
  }
  for node in [12, 13, 20] {
    let found = analysis.node(@ir.NodeId::new(node)).unwrap()
    assert_true(found.provenance().has_asynchronous())
    assert_eq(cdc_ordinals(found.provenance().domains()), [0])
  }
  for node in [14, 16, 17, 18, 23] {
    let found = analysis.node(@ir.NodeId::new(node)).unwrap()
    assert_false(found.provenance().has_asynchronous())
    assert_eq(cdc_ordinals(found.provenance().domains()), [0, 3])
  }
  let mux = analysis.node(@ir.NodeId::new(28)).unwrap()
  assert_true(mux.provenance().has_asynchronous())
  assert_eq(cdc_ordinals(mux.provenance().domains()), [0, 3])
  assert_eq(cdc_path_ordinals(mux.asynchronous_witness().unwrap()), [5, 28])
  let equality = analysis.node(@ir.NodeId::new(16)).unwrap()
  assert_eq(
    equality.domain_witnesses().map(item => cdc_path_ordinals(item.witness())),
    [[1, 16], [4, 16]],
  )
  assert_true(
    analysis.node(@ir.NodeId::new(7)).unwrap().provenance().is_neutral(),
  )
}

///|
fn memory_read_provenance_module() -> @ir.Module raise @ir.IrError {
  let clock = @ir.NodeId::new(0)
  let address = @ir.NodeId::new(1)
  let result = @ir.NodeId::new(2)
  let domain = @ir.ClockDomain::rising(clock)
  let memory_id = @ir.MemoryId::new(0)
  let port_id = @ir.MemoryReadPortId::new(0)
  let read = @ir.MemoryReadPort::new(
    port_id,
    "read",
    domain,
    address,
    OneCycle,
    HoldLast,
    result,
  )
  let memory = @ir.MemorySpec::new(
    memory_id,
    "storage",
    cdc_uint(8),
    @ir.MemoryDepth::new(4),
    domain,
    [read],
    [],
    ReadOld,
    Reject,
    Fault,
  )
  @ir.Module::checked_with_metadata(
    "MemoryReadProvenance",
    [domain],
    [
      @ir.Node::new(clock, Clock, Input("clock")),
      @ir.Node::new(address, cdc_uint(2), Input("address")),
      @ir.Node::new(
        result,
        cdc_uint(8),
        MemoryRead(memory=memory_id, port=port_id),
      ),
    ],
    [memory],
    [@ir.OutputPort::new("result", cdc_uint(8), result)],
    cdc_metadata([cdc_input_timing(1, SampledIn(domain.id()))], [
      cdc_output_timing("result", ProducedIn(domain.id())),
    ]),
  )
}

///|
test "MemoryRead is an exact domain cut point with a stable origin" {
  let hardware_module = memory_read_provenance_module()
  let analysis = @cdc.analyze_module(hardware_module)
  let result = analysis.node(@ir.NodeId::new(2)).unwrap()
  assert_eq(cdc_ordinals(result.provenance().domains()), [0])
  assert_eq(
    result.domain_witnesses()[0].witness().origin(),
    MemoryReadState(
      node=@ir.NodeId::new(2),
      memory=@ir.MemoryId::new(0),
      port=@ir.MemoryReadPortId::new(0),
      domain=@ir.ClockDomainId::new(0),
    ),
  )
  @cdc.validate_module(hardware_module)
}

///|
test "legacy timing is explicit for zero one and multiple domains" {
  let u8 = cdc_uint(8)
  let zero = @ir.Module::checked(
    "LegacyZero",
    [
      @ir.Node::new(@ir.NodeId::new(0), u8, Input("value")),
      @ir.Node::new(@ir.NodeId::new(1), u8, BitNot(@ir.NodeId::new(0))),
    ],
    [@ir.OutputPort::new("result", u8, @ir.NodeId::new(1))],
  )
  let zero_analysis = @cdc.analyze_module(zero)
  assert_true(
    zero_analysis
    .node(@ir.NodeId::new(1))
    .unwrap()
    .provenance()
    .has_asynchronous(),
  )
  @cdc.validate_module(zero)

  let clock = @ir.NodeId::new(0)
  let value = @ir.NodeId::new(1)
  let state = @ir.NodeId::new(2)
  let domain = @ir.ClockDomain::rising(clock)
  let one = @ir.Module::checked(
    "LegacyOne",
    [
      @ir.Node::new(clock, Clock, Input("clock")),
      @ir.Node::new(value, u8, Input("value")),
      @ir.Node::new(state, u8, Register(@ir.RegisterSpec::new(domain, value))),
    ],
    [@ir.OutputPort::new("state", u8, state)],
  )
  assert_eq(
    cdc_ordinals(
      @cdc.analyze_module(one).node(value).unwrap().provenance().domains(),
    ),
    [0],
  )
  @cdc.validate_module(one)

  let clock_b = @ir.NodeId::new(1)
  let multi = @ir.Module::checked(
    "LegacyMulti",
    [
      @ir.Node::new(clock, Clock, Input("clock_a")),
      @ir.Node::new(clock_b, Clock, Input("clock_b")),
      @ir.Node::new(
        @ir.NodeId::new(2),
        u8,
        Register(
          @ir.RegisterSpec::new(
            @ir.ClockDomain::rising(clock),
            @ir.NodeId::new(3),
          ),
        ),
      ),
      @ir.Node::new(
        @ir.NodeId::new(3),
        u8,
        Register(
          @ir.RegisterSpec::new(
            @ir.ClockDomain::rising(clock_b),
            @ir.NodeId::new(2),
          ),
        ),
      ),
    ],
    [],
  )
  try @cdc.analyze_module(multi) catch {
    TimingUnavailable(module_name~) => assert_eq(module_name, "LegacyMulti")
    error => fail("unexpected legacy timing error: \{Repr(error)}")
  } noraise {
    _ => fail("expected multi-domain timing rejection")
  }
}
