///|
fn ordered_node_id(ordinal : Int) -> @ir.NodeId raise @ir.IrError {
  @ir.NodeId::new(ordinal)
}

///|
fn ordered_u(width : Int) -> @ir.SignalType raise @ir.IrError {
  UInt(@ir.Width::new(width))
}

///|
fn ordered_constant_module(
  name : String,
  value : UInt64,
) -> @ir.Module raise @ir.IrError {
  @ir.Module::checked(
    name,
    [@ir.Node::new(ordered_node_id(0), ordered_u(4), Constant(value))],
    [@ir.OutputPort::new("value", ordered_u(4), ordered_node_id(0))],
  )
}

///|
test "golden emission follows canonical construction order deterministically" {
  let design = @ir.Design::checked(
    "ordered",
    [
      ordered_constant_module("Second", 2UL),
      ordered_constant_module("First", 1UL),
    ],
    "First",
  )
  let first = @systemverilog.emit_design(design)
  let second = @systemverilog.emit_design(design)
  assert_eq(first, second)
  debug_inspect(
    first.modules().map(module_artifact => module_artifact.filename()),
    content=(
      #|<ReadOnlyArray:
      #|  ["lc_m0_b53_b65_b63_b6f_b6e_b64.sv", "lc_m1_b46_b69_b72_b73_b74.sv"]>
    ),
  )
  assert_false(
    first.modules()[0].source().contains(first.modules()[1].identifier()),
  )
  assert_false(
    first.modules()[1].source().contains(first.modules()[0].identifier()),
  )
  inspect(
    first.source(),
    content=(
      #|`default_nettype none
      #|// LunaChip conservative SystemVerilog-2017 backend v1
      #|// Uninitialized registers intentionally have no initializer.
      #|
      #|module lc_m0_b53_b65_b63_b6f_b6e_b64 (
      #|  output logic [3:0] lc_o0_b76_b61_b6c_b75_b65
      #|);
      #|
      #|  logic [3:0] lc_n0;
      #|
      #|  assign lc_n0 = 4'h2;
      #|  assign lc_o0_b76_b61_b6c_b75_b65 = lc_n0;
      #|endmodule
      #|
      #|module lc_m1_b46_b69_b72_b73_b74 (
      #|  output logic [3:0] lc_o0_b76_b61_b6c_b75_b65
      #|);
      #|
      #|  logic [3:0] lc_n0;
      #|
      #|  assign lc_n0 = 4'h1;
      #|  assign lc_o0_b76_b61_b6c_b75_b65 = lc_n0;
      #|endmodule
      #|
      #|`default_nettype wire
      #|
    ),
  )
  inspect(
    first.manifest().to_canonical_text(),
    content=(
      #|LUNACHIP-SYSTEMVERILOG-NAMES 1
      #|TOP 1
      #|REGISTER-INITIALIZATION implicit-four-state-x-reject-explicit
      #|MAP module 0 -1 53_65_63_6f_6e_64 lc_m0_b53_b65_b63_b6f_b6e_b64
      #|MAP node 0 0 - lc_n0
      #|MAP output 0 0 76_61_6c_75_65 lc_o0_b76_b61_b6c_b75_b65
      #|MAP module 1 -1 46_69_72_73_74 lc_m1_b46_b69_b72_b73_b74
      #|MAP node 1 0 - lc_n0
      #|MAP output 1 0 76_61_6c_75_65 lc_o0_b76_b61_b6c_b75_b65
      #|END
      #|
    ),
  )
}
