///|
fn wire_nested_shape() -> @aggregate.Aggregate[@ir.SignalType] raise {
  let lane = @aggregate.Aggregate::record([
    ("valid", @aggregate.Aggregate::leaf(@wire.bits(1))),
    ("payload🔥", @aggregate.Aggregate::leaf(@wire.uint(8))),
  ])
  @aggregate.Aggregate::record([
    ("header", @aggregate.Aggregate::leaf(@wire.uint(4))),
    ("通道", @aggregate.Aggregate::vector([lane, lane])),
  ])
}

///|
test "nested Unicode aggregate lowering preserves shape paths timing and codec" {
  let builder = @wire.ModuleBuilder::new("Aggregate")
  let clock_a = builder.input("clock_a", @wire.clock())
  ignore(builder.constant(@wire.bits(1), 0UL))
  let clock_b = builder.input("clock_b", @wire.clock())
  let domain_a = builder.rising_edge(clock_a)
  let domain_b = builder.rising_edge(clock_b)
  builder.parameter("𐀀", Text("月🔥"))
  builder.parameter("a", Unsigned(2UL))
  let shape = wire_nested_shape()
  let inputs = builder.aggregate_input(
    "请求🔥",
    shape,
    timing=SampledIn(domain_b.id()),
  )
  let outputs = builder.aggregate_output(
    "响应",
    shape,
    timing=ProducedIn(domain_b.id()),
  )
  builder.connect_aggregate(outputs, inputs)
  let canonical = builder.finish()
  assert_eq(canonical.domains().map(domain => domain.id().ordinal()), [0, 2])
  assert_eq(canonical.parameters().map(parameter => parameter.name()), [
    "a", "𐀀",
  ])
  assert_eq(canonical.aggregate_bindings().length(), 2)
  assert_eq(canonical.aggregate_bindings()[0].shape(), shape)
  assert_eq(canonical.aggregate_bindings()[1].shape(), shape)
  let input_leaves = inputs.flatten()
  let rebuilt = shape.reconstruct_like(input_leaves.map(leaf => leaf.value()))
  assert_eq(
    rebuilt.flatten().map(leaf => leaf.value().id().ordinal()),
    input_leaves.map(leaf => leaf.value().id().ordinal()),
  )
  assert_eq(canonical.aggregate_bindings()[0].leaves()[1].path().segments(), [
    Field("通道"),
    Index(0),
    Field("valid"),
  ])
  let input_names : Array[String] = []
  for node in canonical.nodes() {
    match node.kind() {
      Input(name) if name.has_prefix("__lcagg1_") => input_names.push(name)
      _ => ()
    }
  }
  assert_eq(input_names[0], "__lcagg1_e8afb7e6b182f09f94a5_f686561646572")
  assert_eq(
    input_names[1],
    "__lcagg1_e8afb7e6b182f09f94a5_fe9809ae98193_i0_f76616c6964",
  )
  assert_eq(canonical.input_timings().length(), 5)
  assert_true(
    canonical
    .input_timings()
    .all(binding => binding.timing() == SampledIn(domain_b.id())),
  )
  assert_eq(canonical.output_timings().length(), 5)
  assert_true(
    canonical
    .output_timings()
    .all(binding => binding.timing() == ProducedIn(domain_b.id())),
  )
  let design = @wire.single_design("aggregate", canonical)
  let encoded = @codec.serialize(design)
  assert_true(encoded.has_prefix("LUNACHIP-IR 4\n"))
  assert_eq(@codec.serialize(@codec.parse(encoded)), encoded)
  // The explicitly requested but otherwise unused sparse domain is retained.
  assert_eq(domain_a.id().ordinal(), 0)
}

///|
test "physical aggregate names are injective across adversarial path segments" {
  let shape = @aggregate.Aggregate::record([
    ("i0", @aggregate.Aggregate::leaf(0)),
    (
      "vector",
      @aggregate.Aggregate::vector([
        @aggregate.Aggregate::leaf(1),
        @aggregate.Aggregate::leaf(2),
      ]),
    ),
    ("vector_i0", @aggregate.Aggregate::leaf(3)),
    ("é", @aggregate.Aggregate::leaf(4)),
    ("é", @aggregate.Aggregate::leaf(5)),
  ])
  let names = shape
    .flatten()
    .map(leaf => @wire.aggregate_leaf_name("__lcagg1_a_f62", leaf.path()))
  let seen : Map[String, Unit] = Map([])
  for name in names {
    assert_false(seen.contains(name))
    seen[name] = ()
  }
  assert_eq(names.length(), 6)
  assert_true(names[0].contains("_f6930"))
  assert_true(names[1].contains("_f766563746f72_i0"))
  assert_true(names[3].contains("_f766563746f725f6930"))
  assert_true(names[4] != names[5])
}

///|
test "aggregate connections reject exact shape and type mismatches atomically" {
  let shape_builder = @wire.ModuleBuilder::new("ShapeMismatch")
  let signal = shape_builder.input("signal", @wire.uint(8))
  let sink = shape_builder.output("sink", @wire.uint(8))
  let outputs = @aggregate.Aggregate::record([
    ("left", @aggregate.Aggregate::leaf(sink)),
  ])
  let drivers = @aggregate.Aggregate::record([
    ("right", @aggregate.Aggregate::leaf(signal)),
  ])
  try shape_builder.connect_aggregate(outputs, drivers) catch {
    @wire.WireError::AggregateShapeMismatch => ()
    error => fail("unexpected aggregate shape error: \{Repr(error)}")
  } noraise {
    _ => fail("expected aggregate shape mismatch")
  }
  // A failed preflight did not drive the sink; scalar recovery remains valid.
  shape_builder.connect(sink, signal)
  ignore(shape_builder.finish())

  let type_builder = @wire.ModuleBuilder::new("TypeMismatch")
  let wide = type_builder.input("wide", @wire.uint(16))
  let narrow = type_builder.output("narrow", @wire.uint(8))
  try
    type_builder.connect_aggregate(
      @aggregate.Aggregate::leaf(narrow),
      @aggregate.Aggregate::leaf(wide),
    )
  catch {
    @ir.IrError::WidthMismatch(operation~, expected~, actual~) => {
      assert_eq(operation, "connect_aggregate")
      assert_eq(expected, 8)
      assert_eq(actual, 16)
    }
    error => fail("unexpected aggregate type error: \{Repr(error)}")
  } noraise {
    _ => fail("expected aggregate type mismatch")
  }
  let zero = type_builder.constant(@wire.uint(8), 0UL)
  type_builder.connect(narrow, zero)
  ignore(type_builder.finish())
}

///|
test "aggregate bindings reject duplicate roots and illegal internal roles" {
  let duplicate = @wire.ModuleBuilder::new("Duplicate")
  ignore(
    duplicate.aggregate_input("same", @aggregate.Aggregate::leaf(@wire.uint(8))),
  )
  try
    duplicate.aggregate_output(
      "same",
      @aggregate.Aggregate::leaf(@wire.uint(8)),
    )
  catch {
    @wire.WireError::DuplicateAggregateBinding(root) => assert_eq(root, "same")
    error => fail("unexpected duplicate aggregate error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate aggregate binding")
  }

  let role = @wire.ModuleBuilder::new("Role")
  let external = role.input("external", @wire.uint(8))
  role.bind_internal_aggregate("state", @aggregate.Aggregate::leaf(external))
  try role.finish() catch {
    @ir.IrError::AggregateEndpointRoleMismatch(kind=Internal, ..) => ()
    error => fail("unexpected aggregate role error: \{Repr(error)}")
  } noraise {
    _ => fail("expected illegal internal aggregate role")
  }
}

///|
test "public construction requires complete timing before CDC admission" {
  let incomplete = @wire.ModuleBuilder::new("Incomplete")
  let clock = incomplete.input("clock", @wire.clock())
  let domain = incomplete.rising_edge(clock)
  let timed = incomplete.input("timed", @wire.uint(8))
  ignore(incomplete.input("missing", @wire.uint(8)))
  incomplete.input_timing(timed, SampledIn(domain.id()))
  try incomplete.finish() catch {
    @ir.IrError::MissingInputTiming(input) => assert_eq(input, 2)
    error => fail("unexpected incomplete timing error: \{Repr(error)}")
  } noraise {
    _ => fail("expected complete timing requirement")
  }

  let legacy = @wire.ModuleBuilder::new("LegacyMultiClock")
  let clock_a = legacy.input("clock_a", @wire.clock())
  let clock_b = legacy.input("clock_b", @wire.clock())
  let next_a = legacy.input("next_a", @wire.uint(8))
  let next_b = legacy.input("next_b", @wire.uint(8))
  ignore(legacy.register(clock_a, next_a))
  ignore(legacy.register(clock_b, next_b))
  try legacy.finish() catch {
    @wire.WireError::CdcRejected(TimingUnavailable(module_name~)) =>
      assert_eq(module_name, "LegacyMultiClock")
    error => fail("unexpected public CDC admission error: \{Repr(error)}")
  } noraise {
    _ => fail("expected legacy multi-domain public construction rejection")
  }
}
