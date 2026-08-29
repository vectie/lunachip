///|
fn reach_node_id(ordinal : Int) -> @ir.NodeId raise @ir.IrError {
  @ir.NodeId::new(ordinal)
}

///|
fn reach_u(width : Int) -> @ir.SignalType raise @ir.IrError {
  UInt(@ir.Width::new(width))
}

///|
fn reach_b(width : Int) -> @ir.SignalType raise @ir.IrError {
  Bits(@ir.Width::new(width))
}

///|
test "dead internal combinational node fails closed" {
  let hardware_module = @ir.Module::checked(
    "DeadCombinational",
    [
      @ir.Node::new(reach_node_id(0), reach_u(8), Input("input")),
      @ir.Node::new(reach_node_id(1), reach_u(8), Constant(1UL)),
      @ir.Node::new(
        reach_node_id(2),
        reach_u(8),
        Add(reach_node_id(0), reach_node_id(1)),
      ),
    ],
    [
      @ir.OutputPort::new("input_live", reach_u(8), reach_node_id(0)),
      @ir.OutputPort::new("constant_live", reach_u(8), reach_node_id(1)),
    ],
  )
  try
    @systemverilog.emit_design(
      @ir.Design::single("dead-combinational", hardware_module),
    )
  catch {
    @systemverilog.UnreachableNode(module_name~, node~) => {
      assert_eq(module_name, "DeadCombinational")
      assert_eq(node, 2)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected dead-node rejection")
  }
}

///|
test "unused input fails closed" {
  let hardware_module = @ir.Module::checked(
    "UnusedInput",
    [
      @ir.Node::new(reach_node_id(0), reach_u(8), Input("unused")),
      @ir.Node::new(reach_node_id(1), reach_u(8), Constant(7UL)),
    ],
    [@ir.OutputPort::new("value", reach_u(8), reach_node_id(1))],
  )
  try
    @systemverilog.emit_design(
      @ir.Design::single("unused-input", hardware_module),
    )
  catch {
    @systemverilog.UnreachableNode(module_name~, node~) => {
      assert_eq(module_name, "UnusedInput")
      assert_eq(node, 0)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unused-input rejection")
  }
}

///|
test "reachable register closes over clock reset enable and next state" {
  let clock = reach_node_id(0)
  let reset = reach_node_id(1)
  let enable = reach_node_id(2)
  let state = reach_node_id(3)
  let one = reach_node_id(4)
  let next = reach_node_id(5)
  let hardware_module = @ir.Module::checked(
    "LiveSequentialClosure",
    [
      @ir.Node::new(clock, Clock, Input("clock")),
      @ir.Node::new(reset, Reset, Input("reset")),
      @ir.Node::new(enable, reach_b(1), Input("enable")),
      @ir.Node::new(
        state,
        reach_u(8),
        Register(
          @ir.RegisterSpec::new(
            @ir.ClockDomain::rising(clock),
            next,
            reset=@ir.ResetSpec::new(reset, 0UL),
            enable~,
          ),
        ),
      ),
      @ir.Node::new(one, reach_u(8), Constant(1UL)),
      @ir.Node::new(next, reach_u(8), Add(state, one)),
    ],
    [@ir.OutputPort::new("state", reach_u(8), state)],
  )
  let emitted = @systemverilog.emit_design(
    @ir.Design::single("live-sequential", hardware_module),
  )
  let source = emitted.modules()[0].source()
  assert_true(source.contains("always_ff @(posedge lc_n0)"))
  assert_true(source.contains("lc_n1 ? 8'h0 : (lc_n2 ? lc_n5 : lc_n3)"))
  assert_true(source.contains("assign lc_n5 = lc_fn_add_w8(lc_n3, lc_n4);"))
  assert_eq(emitted.manifest().mappings().length(), 11)
}

///|
test "empty module remains emit-able" {
  let hardware_module = @ir.Module::checked("Empty", [], [])
  let emitted = @systemverilog.emit_design(
    @ir.Design::single("empty", hardware_module),
  )
  assert_eq(emitted.modules().length(), 1)
  assert_true(
    emitted.modules()[0].source().contains("module lc_m0_b45_b6d_b70_b74_b79"),
  )
}
