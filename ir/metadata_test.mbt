///|
fn metadata_uint(width : Int32) -> @ir.SignalType raise @ir.IrError {
  UInt(@ir.Width::new(width))
}

///|
fn metadata_bits(width : Int32) -> @ir.SignalType raise @ir.IrError {
  Bits(@ir.Width::new(width))
}

///|
fn parameter(
  name : String,
  value : @ir.ParameterValue,
) -> @ir.ModuleParameter raise @ir.IrError {
  @ir.ModuleParameter::checked(name, value)
}

///|
fn one_leaf_binding(
  id : Int32,
  kind : @ir.AggregateBindingKind,
  root : String,
  signal_type : @ir.SignalType,
  target : @ir.AggregateLeafTarget,
) -> @ir.AggregateBinding raise @ir.IrError {
  @ir.AggregateBinding::checked(
    @ir.AggregateBindingId::new(id),
    kind,
    root,
    @aggregate.Aggregate::leaf(signal_type),
    [target],
  )
}

///|
test "module parameters snapshot and canonicalize exact UTF-8 names" {
  let parameters = [
    parameter("𐀀", Text("supplementary")),
    parameter("z", Boolean(true)),
    parameter("", Signed(-7L)),
    parameter("a", Unsigned(9UL)),
    parameter("type", SignalTypeValue(metadata_uint(13))),
  ]
  let metadata = @ir.ModuleMetadata::checked(parameters, [])
  parameters[0] = parameter("mutated", Text("changed"))
  assert_eq(metadata.parameters().map(item => item.name()), [
    "a", "type", "z", "", "𐀀",
  ])
  assert_eq(metadata.parameters().map(item => item.value()), [
    Unsigned(9UL),
    SignalTypeValue(metadata_uint(13)),
    Boolean(true),
    Signed(-7L),
    Text("supplementary"),
  ])
  assert_false(metadata.is_empty())
  assert_true(@ir.ModuleMetadata::empty().is_empty())
}

///|
test "parameter names are nonempty and unique" {
  try parameter("", Boolean(false)) catch {
    EmptyName(kind~) => assert_eq(kind, "parameter")
    error => fail("unexpected empty parameter error: \{Repr(error)}")
  } noraise {
    _ => fail("expected empty parameter rejection")
  }
  try
    @ir.ModuleMetadata::checked(
      [parameter("same", Boolean(false)), parameter("same", Boolean(true))],
      [],
    )
  catch {
    DuplicateName(kind~, name~) => {
      assert_eq(kind, "parameter")
      assert_eq(name, "same")
    }
    error => fail("unexpected duplicate parameter error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate parameter rejection")
  }
}

///|
fn nested_metadata_shape() -> @aggregate.Aggregate[@ir.SignalType] raise {
  let lane = @aggregate.Aggregate::record([
    ("valid", @aggregate.Aggregate::leaf(metadata_bits(1))),
    ("payload🔥", @aggregate.Aggregate::leaf(metadata_uint(8))),
  ])
  @aggregate.Aggregate::record([
    ("header", @aggregate.Aggregate::leaf(metadata_uint(4))),
    ("通道", @aggregate.Aggregate::vector([lane, lane])),
  ])
}

///|
test "aggregate binding retains nested paths types endpoints and snapshots" {
  let endpoints : Array[@ir.AggregateLeafTarget] = [
    Node(@ir.NodeId::new(0)),
    Node(@ir.NodeId::new(1)),
    Node(@ir.NodeId::new(2)),
    Node(@ir.NodeId::new(3)),
    Node(@ir.NodeId::new(4)),
  ]
  let binding = @ir.AggregateBinding::checked(
    @ir.AggregateBindingId::new(0),
    InputPort,
    "请求🔥",
    nested_metadata_shape(),
    endpoints,
  )
  endpoints[0] = Node(@ir.NodeId::new(99))
  assert_eq(binding.id().ordinal(), 0)
  assert_eq(binding.kind(), InputPort)
  assert_eq(binding.root(), "请求🔥")
  assert_eq(binding.shape(), nested_metadata_shape())
  let leaves = binding.leaves()
  assert_eq(leaves.map(leaf => leaf.ordinal()), [0, 1, 2, 3, 4])
  assert_eq(leaves.map(leaf => leaf.signal_type()), [
    metadata_uint(4),
    metadata_bits(1),
    metadata_uint(8),
    metadata_bits(1),
    metadata_uint(8),
  ])
  assert_eq(leaves[0].path().segments(), [Field("header")])
  assert_eq(leaves[1].path().segments(), [
    Field("通道"),
    Index(0),
    Field("valid"),
  ])
  assert_eq(leaves[4].path().segments(), [
    Field("通道"),
    Index(1),
    Field("payload🔥"),
  ])
  assert_eq(leaves[0].target(), Node(@ir.NodeId::new(0)))
}

///|
test "aggregate shapes enforce homogeneity exact endpoints depth and leaves" {
  let id = @ir.AggregateBindingId::new(0)
  let heterogeneous = @aggregate.Aggregate::vector([
    @aggregate.Aggregate::leaf(metadata_uint(8)),
    @aggregate.Aggregate::leaf(metadata_uint(16)),
  ])
  try
    @ir.AggregateBinding::checked(
      id,
      InputPort,
      "heterogeneous",
      heterogeneous,
      [Node(@ir.NodeId::new(0)), Node(@ir.NodeId::new(1))],
    )
  catch {
    HeterogeneousAggregateVector(binding~, depth~, index~) => {
      assert_eq(binding, 0)
      assert_eq(depth, 0)
      assert_eq(index, 1)
    }
    error => fail("unexpected heterogeneous Vec error: \{Repr(error)}")
  } noraise {
    _ => fail("expected heterogeneous Vec rejection")
  }
  try
    @ir.AggregateBinding::checked(
      id,
      InputPort,
      "count",
      @aggregate.Aggregate::leaf(metadata_uint(8)),
      [],
    )
  catch {
    AggregateEndpointCountMismatch(binding~, expected~, actual~) => {
      assert_eq(binding, 0)
      assert_eq(expected, 1)
      assert_eq(actual, 0)
    }
    error => fail("unexpected endpoint count error: \{Repr(error)}")
  } noraise {
    _ => fail("expected endpoint count rejection")
  }
  let mut deep = @aggregate.Aggregate::leaf(metadata_uint(1))
  for _ in 0..<65 {
    deep = @aggregate.Aggregate::vector([deep])
  }
  try @ir.AggregateBinding::checked(id, Internal, "deep", deep, []) catch {
    AggregateDepthLimitExceeded(binding~, maximum~, actual~) => {
      assert_eq(binding, 0)
      assert_eq(maximum, 64)
      assert_eq(actual, 65)
    }
    error => fail("unexpected aggregate depth error: \{Repr(error)}")
  } noraise {
    _ => fail("expected aggregate depth rejection")
  }
  let wide = @aggregate.Aggregate::vector(
    Array::make(65537, @aggregate.Aggregate::leaf(metadata_bits(1))),
  )
  try @ir.AggregateBinding::checked(id, Internal, "wide", wide, []) catch {
    AggregateLeafLimitExceeded(binding~, maximum~, minimum~) => {
      assert_eq(binding, 0)
      assert_eq(maximum, 65536)
      assert_eq(minimum, 65537)
    }
    error => fail("unexpected aggregate leaf error: \{Repr(error)}")
  } noraise {
    _ => fail("expected aggregate leaf rejection")
  }
}

///|
test "binding ids roots and endpoint ownership are canonical and unique" {
  try @ir.AggregateBindingId::new(-1) catch {
    InvalidAggregateBindingId(id) => assert_eq(id, -1)
    error => fail("unexpected binding id error: \{Repr(error)}")
  } noraise {
    _ => fail("expected invalid binding id")
  }
  let first = one_leaf_binding(
    0,
    InputPort,
    "first",
    metadata_uint(8),
    Node(@ir.NodeId::new(0)),
  )
  let second_same_node = one_leaf_binding(
    1,
    InputPort,
    "second",
    metadata_uint(8),
    Node(@ir.NodeId::new(0)),
  )
  try @ir.ModuleMetadata::checked([], [second_same_node]) catch {
    NonSequentialAggregateBindingId(expected~, actual~) => {
      assert_eq(expected, 0)
      assert_eq(actual, 1)
    }
    error => fail("unexpected binding sequence error: \{Repr(error)}")
  } noraise {
    _ => fail("expected binding sequence rejection")
  }
  let duplicate_root = one_leaf_binding(
    1,
    InputPort,
    "first",
    metadata_uint(8),
    Node(@ir.NodeId::new(1)),
  )
  try @ir.ModuleMetadata::checked([], [first, duplicate_root]) catch {
    DuplicateName(kind~, name~) => {
      assert_eq(kind, "aggregate root")
      assert_eq(name, "first")
    }
    error => fail("unexpected duplicate root error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate root rejection")
  }
  try @ir.ModuleMetadata::checked([], [first, second_same_node]) catch {
    DuplicateAggregateNodeEndpoint(node~) => assert_eq(node, 0)
    error => fail("unexpected duplicate node endpoint error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate node endpoint rejection")
  }
  let output_first = one_leaf_binding(
    0,
    OutputPort,
    "out-a",
    metadata_uint(8),
    Output("same"),
  )
  let output_second = one_leaf_binding(
    1,
    OutputPort,
    "out-b",
    metadata_uint(8),
    Output("same"),
  )
  try @ir.ModuleMetadata::checked([], [output_first, output_second]) catch {
    DuplicateAggregateOutputEndpoint(name) => assert_eq(name, "same")
    error => fail("unexpected duplicate output endpoint error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate output endpoint rejection")
  }
}

///|
fn module_with_metadata(
  nodes : ArrayView[@ir.Node],
  outputs : ArrayView[@ir.OutputPort],
  binding : @ir.AggregateBinding,
) -> @ir.Module raise @ir.IrError {
  @ir.Module::checked_with_metadata(
    "Metadata",
    [],
    nodes,
    [],
    outputs,
    @ir.ModuleMetadata::checked([], [binding]),
  )
}

///|
test "module validates aggregate endpoint roles existence and types" {
  let uint8 = metadata_uint(8)
  let bits1 = metadata_bits(1)
  let input_nodes = [@ir.Node::new(@ir.NodeId::new(0), uint8, Input("in"))]
  let valid_input = one_leaf_binding(
    0,
    InputPort,
    "input",
    uint8,
    Node(@ir.NodeId::new(0)),
  )
  let valid_module = module_with_metadata(input_nodes, [], valid_input)
  assert_eq(valid_module.aggregate_bindings().length(), 1)
  assert_true(valid_module.parameters().is_empty())
  assert_false(valid_module.metadata().is_empty())

  let constant_nodes = [@ir.Node::new(@ir.NodeId::new(0), uint8, Constant(0UL))]
  let wrong_input_role = one_leaf_binding(
    0,
    InputPort,
    "wrong-role",
    uint8,
    Node(@ir.NodeId::new(0)),
  )
  try module_with_metadata(constant_nodes, [], wrong_input_role) catch {
    AggregateEndpointRoleMismatch(binding~, leaf~, kind~) => {
      assert_eq(binding, 0)
      assert_eq(leaf, 0)
      assert_eq(kind, InputPort)
    }
    error => fail("unexpected input role error: \{Repr(error)}")
  } noraise {
    _ => fail("expected input role rejection")
  }
  let wrong_type = one_leaf_binding(
    0,
    InputPort,
    "wrong-type",
    bits1,
    Node(@ir.NodeId::new(0)),
  )
  try module_with_metadata(input_nodes, [], wrong_type) catch {
    AggregateEndpointTypeMismatch(binding~, leaf~, expected~, actual~) => {
      assert_eq(binding, 0)
      assert_eq(leaf, 0)
      assert_eq(expected, bits1)
      assert_eq(actual, uint8)
    }
    error => fail("unexpected endpoint type error: \{Repr(error)}")
  } noraise {
    _ => fail("expected endpoint type rejection")
  }
  let unknown_node = one_leaf_binding(
    0,
    InputPort,
    "unknown-node",
    uint8,
    Node(@ir.NodeId::new(9)),
  )
  try module_with_metadata(input_nodes, [], unknown_node) catch {
    UnknownAggregateEndpointNode(binding~, leaf~, node~) => {
      assert_eq(binding, 0)
      assert_eq(leaf, 0)
      assert_eq(node, 9)
    }
    error => fail("unexpected unknown node error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unknown node rejection")
  }
  let internal_input = one_leaf_binding(
    0,
    Internal,
    "internal-input",
    uint8,
    Node(@ir.NodeId::new(0)),
  )
  try module_with_metadata(input_nodes, [], internal_input) catch {
    AggregateEndpointRoleMismatch(kind=Internal, ..) => ()
    error => fail("unexpected internal role error: \{Repr(error)}")
  } noraise {
    _ => fail("expected internal input rejection")
  }
}

///|
test "output and internal aggregate roles bind exact ground identities" {
  let uint8 = metadata_uint(8)
  let node = @ir.Node::new(@ir.NodeId::new(0), uint8, Constant(7UL))
  let output = @ir.OutputPort::new("result", uint8, @ir.NodeId::new(0))
  let output_binding = one_leaf_binding(
    0,
    OutputPort,
    "response",
    uint8,
    Output("result"),
  )
  let output_module = module_with_metadata([node], [output], output_binding)
  assert_eq(
    output_module.aggregate_bindings()[0].leaves()[0].target(),
    Output("result"),
  )
  let internal_binding = one_leaf_binding(
    0,
    Internal,
    "state",
    uint8,
    Node(@ir.NodeId::new(0)),
  )
  let internal_module = module_with_metadata([node], [output], internal_binding)
  assert_eq(internal_module.aggregate_bindings().length(), 1)
  let unknown_output = one_leaf_binding(
    0,
    OutputPort,
    "unknown-output",
    uint8,
    Output("missing"),
  )
  try module_with_metadata([node], [output], unknown_output) catch {
    UnknownAggregateEndpointOutput(binding~, leaf~, output=name) => {
      assert_eq(binding, 0)
      assert_eq(leaf, 0)
      assert_eq(name, "missing")
    }
    error => fail("unexpected unknown output error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unknown output rejection")
  }
}

///|
test "legacy Module constructors delegate to empty metadata" {
  let module_from_checked = @ir.Module::checked("Empty", [], [])
  let module_from_memories = @ir.Module::checked_with_memories(
    "EmptyMemories",
    [],
    [],
    [],
  )
  let module_from_domains = @ir.Module::checked_with_domains(
    "EmptyDomains",
    [],
    [],
    [],
    [],
  )
  for
    hardware_module in [
      module_from_checked, module_from_memories, module_from_domains,
    ] {
    assert_true(hardware_module.metadata().is_empty())
    assert_true(hardware_module.parameters().is_empty())
    assert_true(hardware_module.aggregate_bindings().is_empty())
  }
}
