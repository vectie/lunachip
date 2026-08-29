///|
test "elaborates a typed registered adder in call order" {
  let builder = @wire.ModuleBuilder::new("RegisteredAdder")
  let clock = builder.input("clock", @wire.clock())
  let ty = @wire.uint(8)
  let a = builder.input("a", ty)
  let b = builder.input("b", ty)
  let sum = builder.add(a, b)
  let registered = builder.register(clock, sum, initial=0UL)
  let result = builder.output("result", ty)
  builder.connect(result, registered)
  let canonical = builder.finish()
  let design = @wire.single_design("registered_adder", canonical)
  debug_inspect(
    canonical.nodes().map(node => node.id().ordinal()),
    content=(
      #|<ReadOnlyArray: [0, 1, 2, 3, 4]>
    ),
  )
  debug_inspect(
    canonical.nodes().map(node => node.kind()),
    content=(
      #|<ReadOnlyArray:
      #|  [
      #|    Input("clock"),
      #|    Input("a"),
      #|    Input("b"),
      #|    Add(NodeId(1), NodeId(2)),
      #|    Register(clock=NodeId(0), next=NodeId(3), initial=Some(0)),
      #|  ]>
    ),
  )
  assert_eq(design.top_name(), "RegisteredAdder")
}

///|
test "rejects width mismatches before appending a node" {
  let builder = @wire.ModuleBuilder::new("Bad")
  let a = builder.input("a", @wire.uint(8))
  let b = builder.input("b", @wire.uint(16))
  try builder.add(a, b) catch {
    @ir.IrError::WidthMismatch(operation~, expected~, actual~) => {
      inspect(operation, content="add")
      inspect(expected, content="8")
      inspect(actual, content="16")
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected width mismatch")
  }
  inspect(builder.finish().nodes().length(), content="2")
}

///|
test "uninterpreted bits support logic but reject arithmetic" {
  let builder = @wire.ModuleBuilder::new("Bits")
  let ty = @wire.bits(8)
  let a = builder.input("a", ty)
  let b = builder.input("b", ty)
  ignore(builder.bit_xor(a, b))
  try builder.add(a, b) catch {
    @ir.IrError::TypeMismatch(operation~) => inspect(operation, content="add")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected arithmetic type rejection")
  }
  ignore(builder.finish())
}

///|
test "enforces exactly one output driver" {
  let builder = @wire.ModuleBuilder::new("DrivenOnce")
  let ty = @wire.uint(8)
  let input = builder.input("input", ty)
  let output = builder.output("output", ty)
  builder.connect(output, input)
  try builder.connect(output, input) catch {
    @wire.WireError::DuplicateDriver(name) => inspect(name, content="output")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate-driver rejection")
  }
}

///|
test "rejects undriven outputs" {
  let builder = @wire.ModuleBuilder::new("Undriven")
  ignore(builder.output("out", @wire.uint(1)))
  try builder.finish() catch {
    @wire.WireError::UndrivenOutput(name) => inspect(name, content="out")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected undriven-output rejection")
  }
}

///|
test "rejects cross-builder signals" {
  let left = @wire.ModuleBuilder::new("Left")
  let right = @wire.ModuleBuilder::new("Right")
  let a = left.input("a", @wire.uint(8))
  let b = right.input("b", @wire.uint(8))
  try left.add(a, b) catch {
    @wire.WireError::ForeignSignal => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected foreign-signal rejection")
  }
}

///|
test "register state supports sequential feedback" {
  let builder = @wire.ModuleBuilder::new("Counter")
  let clock = builder.input("clock", @wire.clock())
  let ty = @wire.uint(8)
  let state = builder.register_state(clock, ty)
  let one = builder.constant(ty, 1UL)
  let next = builder.add(state.value(), one)
  builder.connect_next(state, next)
  let count = builder.output("count", ty)
  builder.connect(count, state.value())
  let canonical = builder.finish()
  debug_inspect(
    canonical.nodes().map(node => node.kind()),
    content=(
      #|<ReadOnlyArray:
      #|  [
      #|    Input("clock"),
      #|    Register(clock=NodeId(0), next=NodeId(3), initial=None),
      #|    Constant(1),
      #|    Add(NodeId(1), NodeId(2)),
      #|  ]>
    ),
  )
}

///|
test "register state requires exactly one next driver" {
  let builder = @wire.ModuleBuilder::new("MissingNext")
  let clock = builder.input("clock", @wire.clock())
  let state = builder.register_state(clock, @wire.uint(8), initial=0UL)
  try builder.finish() catch {
    @wire.WireError::UndrivenRegister(node) => inspect(node, content="1")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected undriven-register rejection")
  }
  builder.connect_next(state, state.value())
  try builder.connect_next(state, state.value()) catch {
    @wire.WireError::DuplicateNextDriver(node) => inspect(node, content="1")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate next-driver rejection")
  }
  ignore(builder.finish())
}
