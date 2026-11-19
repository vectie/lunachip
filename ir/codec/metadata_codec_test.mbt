///|
fn metadata_shape() -> @aggregate.Aggregate[@ir.SignalType] raise {
  let bits1 : @ir.SignalType = Bits(@ir.Width::new(1))
  let uint8 : @ir.SignalType = UInt(@ir.Width::new(8))
  let lane = @aggregate.Aggregate::record([
    ("valid", @aggregate.Aggregate::leaf(bits1)),
    ("payload🔥", @aggregate.Aggregate::leaf(uint8)),
  ])
  @aggregate.Aggregate::record([
    ("header", @aggregate.Aggregate::leaf(UInt(@ir.Width::new(4)))),
    ("通道", @aggregate.Aggregate::vector([lane, lane])),
  ])
}

///|
fn metadata_design(reverse_parameters~ : Bool = false) -> @ir.Design raise {
  let clock = @ir.NodeId::new(0)
  let header = @ir.NodeId::new(1)
  let valid0 = @ir.NodeId::new(2)
  let payload0 = @ir.NodeId::new(3)
  let valid1 = @ir.NodeId::new(4)
  let payload1 = @ir.NodeId::new(5)
  let constant = @ir.NodeId::new(6)
  let domain = @ir.ClockDomain::rising(clock)
  let bits1 : @ir.SignalType = Bits(@ir.Width::new(1))
  let uint4 : @ir.SignalType = UInt(@ir.Width::new(4))
  let uint8 : @ir.SignalType = UInt(@ir.Width::new(8))
  let parameters = [
    @ir.ModuleParameter::checked("𐀀", Text("月🔥")),
    @ir.ModuleParameter::checked("z", Unsigned(9UL)),
    @ir.ModuleParameter::checked("", Signed(-7L)),
    @ir.ModuleParameter::checked(
      "type",
      SignalTypeValue(UInt(@ir.Width::new(13))),
    ),
    @ir.ModuleParameter::checked("empty", Text("")),
    @ir.ModuleParameter::checked("a", Boolean(false)),
  ]
  if reverse_parameters {
    for index in 0..<(parameters.length() / 2) {
      let opposite = parameters.length() - index - 1
      let saved = parameters[index]
      parameters[index] = parameters[opposite]
      parameters[opposite] = saved
    }
  }
  let input_binding = @ir.AggregateBinding::checked(
    @ir.AggregateBindingId::new(0),
    InputPort,
    "request🔥",
    metadata_shape(),
    [Node(header), Node(valid0), Node(payload0), Node(valid1), Node(payload1)],
  )
  let output_binding = @ir.AggregateBinding::checked(
    @ir.AggregateBindingId::new(1),
    OutputPort,
    "response",
    @aggregate.Aggregate::leaf(uint8),
    [Output("result")],
  )
  let metadata = @ir.ModuleMetadata::checked_with_timing(
    parameters,
    [input_binding, output_binding],
    [
      @ir.InputTimingBinding::new(header, Asynchronous),
      @ir.InputTimingBinding::new(valid0, SampledIn(domain.id())),
      @ir.InputTimingBinding::new(payload0, SampledIn(domain.id())),
      @ir.InputTimingBinding::new(valid1, SampledIn(domain.id())),
      @ir.InputTimingBinding::new(payload1, SampledIn(domain.id())),
    ],
    [
      @ir.OutputTimingBinding::checked("static_out", Static),
      @ir.OutputTimingBinding::checked("result", ProducedIn(domain.id())),
      @ir.OutputTimingBinding::checked("async_out", Asynchronous),
    ],
  )
  let hardware_module = @ir.Module::checked_with_metadata(
    "Meta",
    [domain],
    [
      @ir.Node::new(clock, Clock, Input("clock")),
      @ir.Node::new(header, uint4, Input("header")),
      @ir.Node::new(valid0, bits1, Input("valid0")),
      @ir.Node::new(payload0, uint8, Input("payload0")),
      @ir.Node::new(valid1, bits1, Input("valid1")),
      @ir.Node::new(payload1, uint8, Input("payload1")),
      @ir.Node::new(constant, uint8, Constant(0UL)),
    ],
    [],
    [
      @ir.OutputPort::new("result", uint8, payload1),
      @ir.OutputPort::new("static_out", uint8, constant),
      @ir.OutputPort::new("async_out", uint4, header),
    ],
    metadata,
  )
  @ir.Design::single("metadata-fixture", hardware_module)
}

///|
const METADATA_GOLDEN : String =
  #|LUNACHIP-IR 4
  #|DESIGN 6d657461646174612d66697874757265
  #|TOP 4d657461
  #|MODULES 1
  #|MODULE 4d657461
  #|DOMAINS 1
  #|DOMAIN 0 0 rising
  #|PARAMETERS 6
  #|PARAMETER 61 boolean false
  #|PARAMETER 656d707479 text -
  #|PARAMETER 74797065 signal_type uint:13
  #|PARAMETER 7a unsigned 9
  #|PARAMETER ee8080 signed -7
  #|PARAMETER f0908080 text e69c88f09f94a5
  #|NODES 7
  #|NODE 0 clock input 636c6f636b
  #|NODE 1 uint:4 input 686561646572
  #|NODE 2 bits:1 input 76616c696430
  #|NODE 3 uint:8 input 7061796c6f616430
  #|NODE 4 bits:1 input 76616c696431
  #|NODE 5 uint:8 input 7061796c6f616431
  #|NODE 6 uint:8 const 0
  #|MEMORIES 0
  #|OUTPUTS 3
  #|OUTPUT 6173796e635f6f7574 uint:4 1
  #|OUTPUT 726573756c74 uint:8 5
  #|OUTPUT 7374617469635f6f7574 uint:8 6
  #|INPUT_TIMINGS 5
  #|INPUT_TIMING 1 asynchronous
  #|INPUT_TIMING 2 sampled_in 0
  #|INPUT_TIMING 3 sampled_in 0
  #|INPUT_TIMING 4 sampled_in 0
  #|INPUT_TIMING 5 sampled_in 0
  #|OUTPUT_TIMINGS 3
  #|OUTPUT_TIMING 6173796e635f6f7574 asynchronous
  #|OUTPUT_TIMING 726573756c74 produced_in 0
  #|OUTPUT_TIMING 7374617469635f6f7574 static
  #|AGGREGATES 2
  #|AGGREGATE 0 input 72657175657374f09f94a5
  #|SHAPE record 2
  #|FIELD 686561646572
  #|SHAPE leaf uint:4
  #|FIELD e9809ae98193
  #|SHAPE vector 2
  #|SHAPE record 2
  #|FIELD 76616c6964
  #|SHAPE leaf bits:1
  #|FIELD 7061796c6f6164f09f94a5
  #|SHAPE leaf uint:8
  #|ENDPOINTS 5
  #|ENDPOINT 0 node 1
  #|ENDPOINT 1 node 2
  #|ENDPOINT 2 node 3
  #|ENDPOINT 3 node 4
  #|ENDPOINT 4 node 5
  #|ENDAGGREGATE
  #|AGGREGATE 1 output 726573706f6e7365
  #|SHAPE leaf uint:8
  #|ENDPOINTS 1
  #|ENDPOINT 0 output 726573756c74
  #|ENDAGGREGATE
  #|PRIMITIVES 0
  #|ENDMODULE
  #|END
  #|

///|
test "schema four metadata has one exact full golden and round trips" {
  let canonical = @codec.serialize(metadata_design())
  assert_eq(canonical, METADATA_GOLDEN)
  let decoded = @codec.parse(canonical)
  assert_eq(@codec.serialize(decoded), canonical)
  let hardware_module = decoded.top_module().unwrap()
  assert_eq(hardware_module.parameters().length(), 6)
  assert_eq(hardware_module.input_timings().length(), 5)
  assert_eq(hardware_module.output_timings().length(), 3)
  assert_eq(hardware_module.aggregate_bindings().length(), 2)
  assert_eq(hardware_module.aggregate_bindings()[0].shape(), metadata_shape())
}

///|
test "UTF-8 parameter order and metadata digest ignore construction order" {
  let first = metadata_design()
  let second = metadata_design(reverse_parameters=true)
  assert_eq(@codec.serialize(first), @codec.serialize(second))
  assert_eq(@codec.content_digest(first), @codec.content_digest(second))
  let names = @codec.parse(@codec.serialize(first))
    .top_module()
    .unwrap()
    .parameters()
    .map(parameter => parameter.name())
  assert_eq(names, ["a", "empty", "type", "z", "", "𐀀"])
}

///|
test "schema four metadata rejects noncanonical ordering and malformed counts" {
  let reordered = METADATA_GOLDEN.replace(
    old="PARAMETER 61 boolean false\nPARAMETER 656d707479 text -",
    new="PARAMETER 656d707479 text -\nPARAMETER 61 boolean false",
  )
  try @codec.parse(reordered) catch {
    NonCanonical => ()
    error => fail("unexpected reordered parameter error: \{Repr(error)}")
  } noraise {
    _ => fail("expected noncanonical parameter order rejection")
  }
  let bad_count = METADATA_GOLDEN.replace(old="ENDPOINTS 5", new="ENDPOINTS 4")
  try @codec.parse(bad_count) catch {
    UnexpectedLine(expected~, ..) => assert_eq(expected, "ENDAGGREGATE")
    error => fail("unexpected endpoint count error: \{Repr(error)}")
  } noraise {
    _ => fail("expected malformed endpoint count rejection")
  }
  let future_primitive = METADATA_GOLDEN.replace(
    old="PRIMITIVES 0",
    new="PRIMITIVES 1",
  )
  try @codec.parse(future_primitive) catch {
    UnexpectedLine(expected~, actual~, ..) => {
      assert_eq(expected, "PRIMITIVE id kind name")
      assert_eq(actual, "ENDMODULE")
    }
    error => fail("unexpected primitive count error: \{Repr(error)}")
  } noraise {
    _ => fail("expected nonzero provisional primitive table rejection")
  }
}

///|
test "schema four metadata rejects bad leaf types endpoints and timing" {
  let wrong_type = METADATA_GOLDEN.replace(
    old="SHAPE leaf uint:4",
    new="SHAPE leaf uint:5",
  )
  try @codec.parse(wrong_type) catch {
    IrRejected(reason~) =>
      assert_true(reason.contains("AggregateEndpointTypeMismatch"))
    error => fail("unexpected aggregate type error: \{Repr(error)}")
  } noraise {
    _ => fail("expected aggregate leaf type rejection")
  }
  let unknown_endpoint = METADATA_GOLDEN.replace(
    old="ENDPOINT 4 node 5",
    new="ENDPOINT 4 node 99",
  )
  try @codec.parse(unknown_endpoint) catch {
    IrRejected(reason~) =>
      assert_true(reason.contains("UnknownAggregateEndpointNode"))
    error => fail("unexpected aggregate endpoint error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unknown aggregate endpoint rejection")
  }
  let unknown_timing_domain = METADATA_GOLDEN.replace(
    old="INPUT_TIMING 2 sampled_in 0",
    new="INPUT_TIMING 2 sampled_in 9",
  )
  try @codec.parse(unknown_timing_domain) catch {
    IrRejected(reason~) =>
      assert_true(reason.contains("UnknownInputTimingDomain"))
    error => fail("unexpected input timing error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unknown timing domain rejection")
  }
}

///|
test "metadata forces schema four and a downgraded envelope is typed" {
  assert_true(@codec.serialize(metadata_design()).has_prefix("LUNACHIP-IR 4\n"))
  let downgraded = METADATA_GOLDEN.replace(
    old="LUNACHIP-IR 4",
    new="LUNACHIP-IR 3",
  )
  try @codec.parse(downgraded) catch {
    FeatureRequiresSchema4(feature) =>
      assert_eq(feature, "schema-4 module envelope")
    error => fail("unexpected downgrade error: \{Repr(error)}")
  } noraise {
    _ => fail("expected schema-four downgrade rejection")
  }
}
