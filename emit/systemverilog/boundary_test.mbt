///|
fn boundary_node_id(ordinal : Int) -> @ir.NodeId raise @ir.IrError {
  @ir.NodeId::new(ordinal)
}

///|
fn boundary_u(width : Int) -> @ir.SignalType raise @ir.IrError {
  UInt(@ir.Width::new(width))
}

///|
fn boundary_s(width : Int) -> @ir.SignalType raise @ir.IrError {
  SInt(@ir.Width::new(width))
}

///|
fn boundary_b(width : Int) -> @ir.SignalType raise @ir.IrError {
  Bits(@ir.Width::new(width))
}

///|
fn boundary_module() -> @ir.Module raise @ir.IrError {
  let nodes = [
    @ir.Node::new(boundary_node_id(0), boundary_u(64), Input("a64")),
    @ir.Node::new(boundary_node_id(1), boundary_u(64), Input("b64")),
    @ir.Node::new(boundary_node_id(2), boundary_s(64), Input("sa64")),
    @ir.Node::new(boundary_node_id(3), boundary_s(64), Input("sb64")),
    @ir.Node::new(boundary_node_id(4), boundary_u(1), Input("a1")),
    @ir.Node::new(boundary_node_id(5), boundary_u(1), Input("b1")),
    @ir.Node::new(boundary_node_id(6), boundary_s(1), Input("sa1")),
    @ir.Node::new(boundary_node_id(7), boundary_s(1), Input("sb1")),
    @ir.Node::new(boundary_node_id(8), boundary_u(1), Input("amount1")),
    @ir.Node::new(
      boundary_node_id(9),
      boundary_u(64),
      MulLow(boundary_node_id(0), boundary_node_id(1)),
    ),
    @ir.Node::new(
      boundary_node_id(10),
      boundary_u(128),
      MulFull(boundary_node_id(0), boundary_node_id(1)),
    ),
    @ir.Node::new(
      boundary_node_id(11),
      boundary_s(64),
      MulLow(boundary_node_id(2), boundary_node_id(3)),
    ),
    @ir.Node::new(
      boundary_node_id(12),
      boundary_s(128),
      MulFull(boundary_node_id(2), boundary_node_id(3)),
    ),
    @ir.Node::new(
      boundary_node_id(13),
      boundary_u(1),
      Add(boundary_node_id(4), boundary_node_id(5)),
    ),
    @ir.Node::new(
      boundary_node_id(14),
      boundary_u(2),
      MulFull(boundary_node_id(4), boundary_node_id(5)),
    ),
    @ir.Node::new(
      boundary_node_id(15),
      boundary_b(1),
      LessThan(boundary_node_id(6), boundary_node_id(7)),
    ),
    @ir.Node::new(
      boundary_node_id(16),
      boundary_s(1),
      ArithmeticShiftRight(
        value=boundary_node_id(6),
        amount=boundary_node_id(8),
      ),
    ),
  ]
  let outputs : Array[@ir.OutputPort] = []
  for index in 9..<nodes.length() {
    outputs.push(
      @ir.OutputPort::new(
        "out\{index}",
        nodes[index].signal_type(),
        boundary_node_id(index),
      ),
    )
  }
  @ir.Module::checked("Boundary", nodes, outputs)
}

///|
test "width-one and width-64 signed full products are explicitly sized" {
  let emitted = @systemverilog.emit_design(
    @ir.Design::single("boundary", boundary_module()),
  )
  assert_eq(emitted.modules().length(), 1)
  let artifact = emitted.modules()[0]
  assert_eq(artifact.filename(), "\{artifact.identifier()}.sv")
  let source = artifact.source()
  assert_true(source.contains("logic signed lc_n6;"))
  assert_true(source.contains("function automatic logic [0:0] lc_fn_add_w1("))
  assert_true(source.contains("for (i = -1; i >= 0; i = i - 1) begin"))
  assert_true(source.contains("({64'h0, lc_n0} * {64'h0, lc_n1})"))
  assert_true(
    source.contains(
      "$signed({{64{lc_n2[63]}}, lc_n2}) * $signed({{64{lc_n3[63]}}, lc_n3})",
    ),
  )
  assert_true(source.contains("output logic [127:0]"))
  assert_true(source.contains("output logic signed [127:0]"))
}
