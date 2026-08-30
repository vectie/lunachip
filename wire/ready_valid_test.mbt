///|
test "ready valid directions validate exact controls payload and ownership" {
  let builder = @wire.ModuleBuilder::new("ReadyValid")
  let valid = builder.input("valid", @wire.bits(1))
  let ready = builder.input("ready", @wire.bits(1))
  let payload0 = builder.input("payload0", @wire.uint(8))
  let payload1 = builder.input("payload1", @wire.uint(8))
  let payload = @aggregate.Aggregate::record([
    ("first", @aggregate.Aggregate::leaf(payload0)),
    (
      "lanes",
      @aggregate.Aggregate::vector([
        @aggregate.Aggregate::leaf(payload1),
        @aggregate.Aggregate::leaf(payload1),
      ]),
    ),
  ])
  let forward = builder.ready_valid_forward(valid, payload)
  let backward = builder.ready_valid_backward(ready)
  assert_eq(forward.valid().id(), valid.id())
  assert_eq(
    forward.payload().flatten().map(leaf => leaf.value().id().ordinal()),
    [2, 3, 3],
  )
  assert_eq(backward.ready().id(), ready.id())

  let wide_control = builder.input("wide_control", @wire.bits(2))
  try builder.ready_valid_forward(wide_control, payload) catch {
    @ir.IrError::ExpectedOneBit(node~) =>
      assert_eq(node, wide_control.id().ordinal())
    error => fail("unexpected valid width error: \{Repr(error)}")
  } noraise {
    _ => fail("expected exact valid width rejection")
  }
  try builder.ready_valid_backward(wide_control) catch {
    @ir.IrError::ExpectedOneBit(node~) =>
      assert_eq(node, wide_control.id().ordinal())
    error => fail("unexpected ready width error: \{Repr(error)}")
  } noraise {
    _ => fail("expected exact ready width rejection")
  }

  let foreign_builder = @wire.ModuleBuilder::new("Foreign")
  let foreign_control = foreign_builder.input("foreign_control", @wire.bits(1))
  let foreign = foreign_builder.input("foreign", @wire.uint(8))
  try builder.ready_valid_forward(foreign_control, payload) catch {
    @wire.WireError::ForeignSignal => ()
    error => fail("unexpected foreign valid error: \{Repr(error)}")
  } noraise {
    _ => fail("expected foreign valid rejection")
  }
  try builder.ready_valid_backward(foreign_control) catch {
    @wire.WireError::ForeignSignal => ()
    error => fail("unexpected foreign ready error: \{Repr(error)}")
  } noraise {
    _ => fail("expected foreign ready rejection")
  }
  try
    builder.ready_valid_forward(valid, @aggregate.Aggregate::leaf(foreign))
  catch {
    @wire.WireError::ForeignSignal => ()
    error => fail("unexpected foreign payload error: \{Repr(error)}")
  } noraise {
    _ => fail("expected foreign payload rejection")
  }
}

///|
test "ready valid payload rejects non-data leaves and heterogeneous vectors" {
  let builder = @wire.ModuleBuilder::new("InvalidPayload")
  let valid = builder.input("valid", @wire.bits(1))
  let clock = builder.input("clock", @wire.clock())
  try
    builder.ready_valid_forward(valid, @aggregate.Aggregate::leaf(clock))
  catch {
    @ir.IrError::TypeMismatch(operation~) =>
      assert_eq(operation, "ready_valid_payload")
    error => fail("unexpected non-data payload error: \{Repr(error)}")
  } noraise {
    _ => fail("expected non-data payload rejection")
  }

  let narrow = builder.input("narrow", @wire.uint(8))
  let wide = builder.input("wide", @wire.uint(16))
  let heterogeneous = @aggregate.Aggregate::vector([
    @aggregate.Aggregate::leaf(narrow),
    @aggregate.Aggregate::leaf(wide),
  ])
  try builder.ready_valid_forward(valid, heterogeneous) catch {
    @ir.IrError::HeterogeneousAggregateVector(binding~, depth~, index~) => {
      assert_eq(binding, 0)
      assert_eq(depth, 0)
      assert_eq(index, 1)
    }
    error => fail("unexpected heterogeneous payload error: \{Repr(error)}")
  } noraise {
    _ => fail("expected heterogeneous payload rejection")
  }
}
