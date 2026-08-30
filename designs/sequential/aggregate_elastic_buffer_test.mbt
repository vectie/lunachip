///|
fn elastic_payload_shape() -> @aggregate.Aggregate[@ir.SignalType] raise {
  let lane = @aggregate.Aggregate::record([
    ("valid", @aggregate.Aggregate::leaf(@wire.bits(1))),
    ("数据🔥", @aggregate.Aggregate::leaf(@wire.uint(8))),
  ])
  @aggregate.Aggregate::record([
    ("header", @aggregate.Aggregate::leaf(@wire.uint(4))),
    ("通道", @aggregate.Aggregate::vector([lane, lane])),
  ])
}

///|
fn drive_elastic_bit(
  simulator : @sim.Simulator,
  name : String,
  value : UInt64,
) -> Unit raise {
  simulator.set_input(name, @wave.LogicValue::from_uint64(width=1, value~))
}

///|
fn elastic_leaf_names(
  root : String,
  shape : @aggregate.Aggregate[@ir.SignalType],
) -> Array[String] raise {
  let names : Array[String] = []
  for leaf in shape.flatten() {
    names.push(@wire.aggregate_leaf_name(root, leaf.path()))
  }
  names
}

///|
fn drive_elastic_payload(
  simulator : @sim.Simulator,
  shape : @aggregate.Aggregate[@ir.SignalType],
  values : ArrayView[UInt64],
) -> Unit raise {
  let leaves = shape.flatten()
  let names = elastic_leaf_names("in_payload", shape)
  assert_eq(values.length(), leaves.length())
  for index in 0..<leaves.length() {
    simulator.set_input(
      names[index],
      @wave.LogicValue::from_uint64(
        width=leaves[index].value().width().bits(),
        value=values[index],
      ),
    )
  }
}

///|
fn observe_elastic_payload(
  simulator : @sim.Simulator,
  shape : @aggregate.Aggregate[@ir.SignalType],
) -> Array[String] raise {
  elastic_leaf_names("out_payload", shape).map(name => {
    simulator.output(name).to_bit_string()
  })
}

///|
test "aggregate elastic buffer resets fills blocks refills and drains" {
  let shape = elastic_payload_shape()
  let simulator = @sim.Simulator::prepare(
    @sequential.aggregate_elastic_buffer(shape),
  )
  let first = [10UL, 1UL, 42UL, 0UL, 99UL]
  let second = [3UL, 0UL, 17UL, 1UL, 201UL]
  drive_elastic_bit(simulator, "reset", 1UL)
  drive_elastic_bit(simulator, "in_valid", 0UL)
  drive_elastic_bit(simulator, "out_ready", 0UL)
  drive_elastic_payload(simulator, shape, [0UL, 0UL, 0UL, 0UL, 0UL])
  simulator.rising_edge("clock")
  assert_eq(simulator.output("in_ready").to_uint64(), 1UL)
  assert_eq(simulator.output("out_valid").to_uint64(), 0UL)
  assert_true(
    observe_elastic_payload(simulator, shape).all(value => value.contains("x")),
  )

  drive_elastic_bit(simulator, "reset", 0UL)
  drive_elastic_bit(simulator, "in_valid", 1UL)
  drive_elastic_payload(simulator, shape, first)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("in_ready").to_uint64(), 0UL)
  assert_eq(simulator.output("out_valid").to_uint64(), 1UL)
  let held = observe_elastic_payload(simulator, shape)
  assert_eq(held, ["1010", "1", "00101010", "0", "01100011"])

  // Full and blocked: changing producer payload does not change stored data.
  drive_elastic_payload(simulator, shape, second)
  simulator.rising_edge("clock")
  assert_eq(observe_elastic_payload(simulator, shape), held)

  // A consumed entry can be replaced atomically on the same edge.
  drive_elastic_bit(simulator, "out_ready", 1UL)
  simulator.settle()
  assert_eq(simulator.output("in_ready").to_uint64(), 1UL)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("out_valid").to_uint64(), 1UL)
  assert_eq(observe_elastic_payload(simulator, shape), [
    "0011", "0", "00010001", "1", "11001001",
  ])

  // Draining without a simultaneous input leaves the buffer empty.
  drive_elastic_bit(simulator, "in_valid", 0UL)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("in_ready").to_uint64(), 1UL)
  assert_eq(simulator.output("out_valid").to_uint64(), 0UL)
  assert_eq(observe_elastic_payload(simulator, shape), [
    "0011", "0", "00010001", "1", "11001001",
  ])
}

///|
test "unknown controls never become a known transfer and remain conservative" {
  let shape = @aggregate.Aggregate::leaf(@wire.uint(8))
  let simulator = @sim.Simulator::prepare(
    @sequential.aggregate_elastic_buffer(shape),
  )
  drive_elastic_bit(simulator, "reset", 1UL)
  drive_elastic_bit(simulator, "in_valid", 0UL)
  drive_elastic_bit(simulator, "out_ready", 0UL)
  drive_elastic_payload(simulator, shape, [0UL])
  simulator.rising_edge("clock")
  drive_elastic_bit(simulator, "reset", 0UL)
  simulator.set_input("in_valid", @wave.LogicValue::unknown(width=1))
  drive_elastic_payload(simulator, shape, [0xa5UL])
  simulator.rising_edge("clock")
  assert_eq(simulator.output("out_valid").to_bit_string(), "x")
  assert_true(
    simulator
    .output(elastic_leaf_names("out_payload", shape)[0])
    .to_bit_string()
    .contains("x"),
  )
}

///|
test "aggregate elastic buffer metadata and codec are deterministic" {
  let shape = elastic_payload_shape()
  let first = @sequential.aggregate_elastic_buffer(shape)
  let second = @sequential.aggregate_elastic_buffer(shape)
  assert_eq(first.parameters().map(parameter => parameter.name()), [
    "capacity", "payload_leaves",
  ])
  assert_eq(first.parameters().map(parameter => parameter.value()), [
    Unsigned(1UL),
    Unsigned(5UL),
  ])
  assert_eq(first.aggregate_bindings().map(binding => binding.root()), [
    "in_payload", "buffer_storage", "out_payload",
  ])
  assert_eq(first.aggregate_bindings().map(binding => binding.kind()), [
    InputPort,
    Internal,
    OutputPort,
  ])
  assert_eq(first.aggregate_bindings()[0].shape(), shape)
  assert_eq(first.aggregate_bindings()[0].leaves()[4].path().segments(), [
    Field("通道"),
    Index(1),
    Field("数据🔥"),
  ])
  assert_eq(first.input_timings().length(), 8)
  assert_eq(first.output_timings().length(), 7)
  let first_design = @wire.single_design("aggregate-elastic", first)
  let second_design = @wire.single_design("aggregate-elastic", second)
  let encoded = @codec.serialize(first_design)
  assert_eq(encoded, @codec.serialize(second_design))
  assert_eq(@codec.serialize(@codec.parse(encoded)), encoded)
}

///|
test "aggregate elastic buffer rejects heterogeneous hardware Vec payload" {
  let invalid = @aggregate.Aggregate::vector([
    @aggregate.Aggregate::leaf(@wire.uint(8)),
    @aggregate.Aggregate::leaf(@wire.uint(16)),
  ])
  try @sequential.aggregate_elastic_buffer(invalid) catch {
    @ir.IrError::HeterogeneousAggregateVector(binding~, depth~, index~) => {
      assert_eq(binding, 0)
      assert_eq(depth, 0)
      assert_eq(index, 1)
    }
    error => fail("unexpected elastic payload shape error: \{Repr(error)}")
  } noraise {
    _ => fail("expected heterogeneous elastic payload rejection")
  }
}
