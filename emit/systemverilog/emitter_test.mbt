///|
fn node_id(ordinal : Int) -> @ir.NodeId raise @ir.IrError {
  @ir.NodeId::new(ordinal)
}

///|
fn u(width : Int) -> @ir.SignalType raise @ir.IrError {
  UInt(@ir.Width::new(width))
}

///|
fn s(width : Int) -> @ir.SignalType raise @ir.IrError {
  SInt(@ir.Width::new(width))
}

///|
fn b(width : Int) -> @ir.SignalType raise @ir.IrError {
  Bits(@ir.Width::new(width))
}

///|
fn all_combinational_operations() -> @ir.Module raise @ir.IrError {
  let nodes = [
    @ir.Node::new(node_id(0), u(8), Input("a")),
    @ir.Node::new(node_id(1), u(8), Input("b")),
    @ir.Node::new(node_id(2), u(3), Input("amount")),
    @ir.Node::new(node_id(3), s(8), Input("sa")),
    @ir.Node::new(node_id(4), s(8), Input("sb")),
    @ir.Node::new(node_id(5), b(1), Input("select")),
    @ir.Node::new(node_id(6), u(8), Constant(42UL)),
    @ir.Node::new(node_id(7), u(8), Add(node_id(0), node_id(1))),
    @ir.Node::new(node_id(8), u(8), Sub(node_id(0), node_id(1))),
    @ir.Node::new(node_id(9), u(8), MulLow(node_id(0), node_id(1))),
    @ir.Node::new(node_id(10), u(16), MulFull(node_id(0), node_id(1))),
    @ir.Node::new(node_id(11), u(8), BitAnd(node_id(0), node_id(1))),
    @ir.Node::new(node_id(12), u(8), BitOr(node_id(0), node_id(1))),
    @ir.Node::new(node_id(13), u(8), BitXor(node_id(0), node_id(1))),
    @ir.Node::new(node_id(14), u(8), BitNot(node_id(0))),
    @ir.Node::new(node_id(15), b(1), Equal(node_id(0), node_id(1))),
    @ir.Node::new(node_id(16), b(1), LessThan(node_id(0), node_id(1))),
    @ir.Node::new(node_id(17), b(1), LessEqual(node_id(0), node_id(1))),
    @ir.Node::new(node_id(18), b(1), LessThan(node_id(3), node_id(4))),
    @ir.Node::new(
      node_id(19),
      u(8),
      ShiftLeft(value=node_id(0), amount=node_id(2)),
    ),
    @ir.Node::new(
      node_id(20),
      u(8),
      LogicalShiftRight(value=node_id(0), amount=node_id(2)),
    ),
    @ir.Node::new(
      node_id(21),
      s(8),
      ArithmeticShiftRight(value=node_id(3), amount=node_id(2)),
    ),
    @ir.Node::new(node_id(22), b(4), Slice(value=node_id(0), msb=7, lsb=4)),
    @ir.Node::new(
      node_id(23),
      b(16),
      Concat(most_significant=node_id(0), least_significant=node_id(1)),
    ),
    @ir.Node::new(node_id(24), u(12), ZeroExtend(node_id(0))),
    @ir.Node::new(node_id(25), s(12), SignExtend(node_id(3))),
    @ir.Node::new(node_id(26), u(4), Truncate(node_id(0))),
    @ir.Node::new(node_id(27), b(8), Reinterpret(node_id(0))),
    @ir.Node::new(
      node_id(28),
      u(8),
      Mux(select=node_id(5), when_true=node_id(0), when_false=node_id(1)),
    ),
  ]
  let outputs : Array[@ir.OutputPort] = []
  for index in 6..<nodes.length() {
    outputs.push(
      @ir.OutputPort::new(
        "n\{index}",
        nodes[index].signal_type(),
        node_id(index),
      ),
    )
  }
  @ir.Module::checked("Combinational", nodes, outputs)
}

///|
test "golden emits every stable combinational operation" {
  let design = @ir.Design::single(
    "combinational",
    all_combinational_operations(),
  )
  inspect(
    @systemverilog.emit_design(design).source(),
    content=(
      #|`default_nettype none
      #|// LunaChip conservative SystemVerilog-2017 backend v1
      #|// Uninitialized registers intentionally have no initializer.
      #|
      #|module lc_m0_b43_b6f_b6d_b62_b69_b6e_b61_b74_b69_b6f_b6e_b61_b6c (
      #|  input logic [7:0] lc_i0_b61,
      #|  input logic [7:0] lc_i1_b62,
      #|  input logic [2:0] lc_i2_b61_b6d_b6f_b75_b6e_b74,
      #|  input logic signed [7:0] lc_i3_b73_b61,
      #|  input logic signed [7:0] lc_i4_b73_b62,
      #|  input logic lc_i5_b73_b65_b6c_b65_b63_b74,
      #|  output logic [7:0] lc_o0_b6e_b36,
      #|  output logic [7:0] lc_o1_b6e_b37,
      #|  output logic [7:0] lc_o2_b6e_b38,
      #|  output logic [7:0] lc_o3_b6e_b39,
      #|  output logic [15:0] lc_o4_b6e_b31_b30,
      #|  output logic [7:0] lc_o5_b6e_b31_b31,
      #|  output logic [7:0] lc_o6_b6e_b31_b32,
      #|  output logic [7:0] lc_o7_b6e_b31_b33,
      #|  output logic [7:0] lc_o8_b6e_b31_b34,
      #|  output logic lc_o9_b6e_b31_b35,
      #|  output logic lc_o10_b6e_b31_b36,
      #|  output logic lc_o11_b6e_b31_b37,
      #|  output logic lc_o12_b6e_b31_b38,
      #|  output logic [7:0] lc_o13_b6e_b31_b39,
      #|  output logic [7:0] lc_o14_b6e_b32_b30,
      #|  output logic signed [7:0] lc_o15_b6e_b32_b31,
      #|  output logic [3:0] lc_o16_b6e_b32_b32,
      #|  output logic [15:0] lc_o17_b6e_b32_b33,
      #|  output logic [11:0] lc_o18_b6e_b32_b34,
      #|  output logic signed [11:0] lc_o19_b6e_b32_b35,
      #|  output logic [3:0] lc_o20_b6e_b32_b36,
      #|  output logic [7:0] lc_o21_b6e_b32_b37,
      #|  output logic [7:0] lc_o22_b6e_b32_b38
      #|);
      #|
      #|  logic [7:0] lc_n0;
      #|  logic [7:0] lc_n1;
      #|  logic [2:0] lc_n2;
      #|  logic signed [7:0] lc_n3;
      #|  logic signed [7:0] lc_n4;
      #|  logic lc_n5;
      #|  logic [7:0] lc_n6;
      #|  logic [7:0] lc_n7;
      #|  logic [7:0] lc_n8;
      #|  logic [7:0] lc_n9;
      #|  logic [15:0] lc_n10;
      #|  logic [7:0] lc_n11;
      #|  logic [7:0] lc_n12;
      #|  logic [7:0] lc_n13;
      #|  logic [7:0] lc_n14;
      #|  logic lc_n15;
      #|  logic lc_n16;
      #|  logic lc_n17;
      #|  logic lc_n18;
      #|  logic [7:0] lc_n19;
      #|  logic [7:0] lc_n20;
      #|  logic signed [7:0] lc_n21;
      #|  logic [3:0] lc_n22;
      #|  logic [15:0] lc_n23;
      #|  logic [11:0] lc_n24;
      #|  logic signed [11:0] lc_n25;
      #|  logic [3:0] lc_n26;
      #|  logic [7:0] lc_n27;
      #|  logic [7:0] lc_n28;
      #|
      #|  function automatic logic [7:0] lc_fn_add_w8(
      #|    input logic [7:0] a,
      #|    input logic [7:0] b
      #|  );
      #|    logic carry;
      #|    integer i;
      #|    begin
      #|      carry = 1'b0;
      #|      for (i = 0; i < 8; i = i + 1) begin
      #|        lc_fn_add_w8[i] = a[i] ^ b[i] ^ carry;
      #|        carry = (a[i] & b[i]) | (a[i] & carry) | (b[i] & carry);
      #|      end
      #|    end
      #|  endfunction
      #|  function automatic logic [7:0] lc_fn_sub_w8(
      #|    input logic [7:0] a,
      #|    input logic [7:0] b
      #|  );
      #|    logic borrow;
      #|    integer i;
      #|    begin
      #|      borrow = 1'b0;
      #|      for (i = 0; i < 8; i = i + 1) begin
      #|        lc_fn_sub_w8[i] = a[i] ^ b[i] ^ borrow;
      #|        borrow = (~a[i] & (b[i] | borrow)) | (b[i] & borrow);
      #|      end
      #|    end
      #|  endfunction
      #|  function automatic logic lc_fn_eq_w8(
      #|    input logic [7:0] a,
      #|    input logic [7:0] b
      #|  );
      #|    logic mismatch;
      #|    logic unknown;
      #|    integer i;
      #|    begin
      #|      mismatch = 1'b0;
      #|      unknown = 1'b0;
      #|      for (i = 0; i < 8; i = i + 1) begin
      #|        case ({a[i], b[i]})
      #|          2'b00, 2'b11: begin end
      #|          2'b01, 2'b10: mismatch = 1'b1;
      #|          default: unknown = 1'b1;
      #|        endcase
      #|      end
      #|      if (mismatch) lc_fn_eq_w8 = 1'b0;
      #|      else if (unknown) lc_fn_eq_w8 = 1'bx;
      #|      else lc_fn_eq_w8 = 1'b1;
      #|    end
      #|  endfunction
      #|  function automatic logic lc_fn_lt_u_w8(
      #|    input logic [7:0] a,
      #|    input logic [7:0] b
      #|  );
      #|    logic decided;
      #|    integer i;
      #|    begin
      #|      lc_fn_lt_u_w8 = 1'b0;
      #|      decided = 1'b0;
      #|      for (i = 7; i >= 0; i = i - 1) begin
      #|        if (!decided) begin
      #|          case ({a[i], b[i]})
      #|            2'b01: begin lc_fn_lt_u_w8 = 1'b1; decided = 1'b1; end
      #|            2'b10: begin lc_fn_lt_u_w8 = 1'b0; decided = 1'b1; end
      #|            2'b00, 2'b11: begin end
      #|            default: begin lc_fn_lt_u_w8 = 1'bx; decided = 1'b1; end
      #|          endcase
      #|        end
      #|      end
      #|    end
      #|  endfunction
      #|  function automatic logic lc_fn_lt_s_w8(
      #|    input logic [7:0] a,
      #|    input logic [7:0] b
      #|  );
      #|    logic decided;
      #|    integer i;
      #|    begin
      #|      lc_fn_lt_s_w8 = 1'b0;
      #|      decided = 1'b0;
      #|      case ({a[7], b[7]})
      #|        2'b10: begin lc_fn_lt_s_w8 = 1'b1; decided = 1'b1; end
      #|        2'b01: begin lc_fn_lt_s_w8 = 1'b0; decided = 1'b1; end
      #|        2'b00, 2'b11: begin end
      #|        default: begin lc_fn_lt_s_w8 = 1'bx; decided = 1'b1; end
      #|      endcase
      #|      for (i = 6; i >= 0; i = i - 1) begin
      #|        if (!decided) begin
      #|          case ({a[i], b[i]})
      #|            2'b01: begin lc_fn_lt_s_w8 = 1'b1; decided = 1'b1; end
      #|            2'b10: begin lc_fn_lt_s_w8 = 1'b0; decided = 1'b1; end
      #|            2'b00, 2'b11: begin end
      #|            default: begin lc_fn_lt_s_w8 = 1'bx; decided = 1'b1; end
      #|          endcase
      #|        end
      #|      end
      #|    end
      #|  endfunction
      #|  assign lc_n0 = lc_i0_b61;
      #|  assign lc_n1 = lc_i1_b62;
      #|  assign lc_n2 = lc_i2_b61_b6d_b6f_b75_b6e_b74;
      #|  assign lc_n3 = lc_i3_b73_b61;
      #|  assign lc_n4 = lc_i4_b73_b62;
      #|  assign lc_n5 = lc_i5_b73_b65_b6c_b65_b63_b74;
      #|  assign lc_n6 = 8'h2a;
      #|  assign lc_n7 = lc_fn_add_w8(lc_n0, lc_n1);
      #|  assign lc_n8 = lc_fn_sub_w8(lc_n0, lc_n1);
      #|  assign lc_n9 = ((lc_n0 == 8'h0) || (lc_n1 == 8'h0)) ? 8'h0 : (lc_n0 * lc_n1);
      #|  assign lc_n10 = ((lc_n0 == 8'h0) || (lc_n1 == 8'h0)) ? 16'h0 : ({8'h0, lc_n0} * {8'h0, lc_n1});
      #|  assign lc_n11 = lc_n0 & lc_n1;
      #|  assign lc_n12 = lc_n0 | lc_n1;
      #|  assign lc_n13 = lc_n0 ^ lc_n1;
      #|  assign lc_n14 = ~lc_n0;
      #|  assign lc_n15 = lc_fn_eq_w8(lc_n0, lc_n1);
      #|  assign lc_n16 = lc_fn_lt_u_w8(lc_n0, lc_n1);
      #|  assign lc_n17 = ~lc_fn_lt_u_w8(lc_n1, lc_n0);
      #|  assign lc_n18 = lc_fn_lt_s_w8(lc_n3, lc_n4);
      #|  assign lc_n19 = lc_n0 << lc_n2;
      #|  assign lc_n20 = $unsigned(lc_n0) >> lc_n2;
      #|  assign lc_n21 = $signed(lc_n3) >>> lc_n2;
      #|  assign lc_n22 = lc_n0[7:4];
      #|  assign lc_n23 = {lc_n0, lc_n1};
      #|  assign lc_n24 = {4'h0, lc_n0};
      #|  assign lc_n25 = {{4{lc_n3[7]}}, lc_n3};
      #|  assign lc_n26 = lc_n0[3:0];
      #|  assign lc_n27 = lc_n0;
      #|  assign lc_n28 = lc_n5 ? lc_n0 : lc_n1;
      #|  assign lc_o0_b6e_b36 = lc_n6;
      #|  assign lc_o1_b6e_b37 = lc_n7;
      #|  assign lc_o2_b6e_b38 = lc_n8;
      #|  assign lc_o3_b6e_b39 = lc_n9;
      #|  assign lc_o4_b6e_b31_b30 = lc_n10;
      #|  assign lc_o5_b6e_b31_b31 = lc_n11;
      #|  assign lc_o6_b6e_b31_b32 = lc_n12;
      #|  assign lc_o7_b6e_b31_b33 = lc_n13;
      #|  assign lc_o8_b6e_b31_b34 = lc_n14;
      #|  assign lc_o9_b6e_b31_b35 = lc_n15;
      #|  assign lc_o10_b6e_b31_b36 = lc_n16;
      #|  assign lc_o11_b6e_b31_b37 = lc_n17;
      #|  assign lc_o12_b6e_b31_b38 = lc_n18;
      #|  assign lc_o13_b6e_b31_b39 = lc_n19;
      #|  assign lc_o14_b6e_b32_b30 = lc_n20;
      #|  assign lc_o15_b6e_b32_b31 = lc_n21;
      #|  assign lc_o16_b6e_b32_b32 = lc_n22;
      #|  assign lc_o17_b6e_b32_b33 = lc_n23;
      #|  assign lc_o18_b6e_b32_b34 = lc_n24;
      #|  assign lc_o19_b6e_b32_b35 = lc_n25;
      #|  assign lc_o20_b6e_b32_b36 = lc_n26;
      #|  assign lc_o21_b6e_b32_b37 = lc_n27;
      #|  assign lc_o22_b6e_b32_b38 = lc_n28;
      #|endmodule
      #|
      #|`default_nettype wire
      #|
    ),
  )
}

///|
fn controlled_register_module(
  initial? : UInt64,
) -> @ir.Module raise @ir.IrError {
  let clock = node_id(0)
  let reset = node_id(1)
  let enable = node_id(2)
  let state = node_id(3)
  let one = node_id(4)
  let next = node_id(5)
  let spec = @ir.RegisterSpec::new(
    @ir.ClockDomain::rising(clock),
    next,
    reset=@ir.ResetSpec::new(reset, 9UL),
    enable~,
    initial?,
  )
  @ir.Module::checked(
    "Controlled",
    [
      @ir.Node::new(clock, Clock, Input("clock")),
      @ir.Node::new(reset, Reset, Input("reset")),
      @ir.Node::new(enable, b(1), Input("enable")),
      @ir.Node::new(state, u(8), Register(spec)),
      @ir.Node::new(one, u(8), Constant(1UL)),
      @ir.Node::new(next, u(8), Add(state, one)),
    ],
    [@ir.OutputPort::new("state", u(8), state)],
  )
}

///|
test "golden emits synchronous reset then enable then hold" {
  let design = @ir.Design::single("controlled", controlled_register_module())
  inspect(
    @systemverilog.emit_design(design).source(),
    content=(
      #|`default_nettype none
      #|// LunaChip conservative SystemVerilog-2017 backend v1
      #|// Uninitialized registers intentionally have no initializer.
      #|
      #|module lc_m0_b43_b6f_b6e_b74_b72_b6f_b6c_b6c_b65_b64 (
      #|  input logic lc_i0_b63_b6c_b6f_b63_b6b,
      #|  input logic lc_i1_b72_b65_b73_b65_b74,
      #|  input logic lc_i2_b65_b6e_b61_b62_b6c_b65,
      #|  output logic [7:0] lc_o0_b73_b74_b61_b74_b65
      #|);
      #|
      #|  logic lc_n0;
      #|  logic lc_n1;
      #|  logic lc_n2;
      #|  logic [7:0] lc_n3;
      #|  logic [7:0] lc_n4;
      #|  logic [7:0] lc_n5;
      #|
      #|  function automatic logic [7:0] lc_fn_add_w8(
      #|    input logic [7:0] a,
      #|    input logic [7:0] b
      #|  );
      #|    logic carry;
      #|    integer i;
      #|    begin
      #|      carry = 1'b0;
      #|      for (i = 0; i < 8; i = i + 1) begin
      #|        lc_fn_add_w8[i] = a[i] ^ b[i] ^ carry;
      #|        carry = (a[i] & b[i]) | (a[i] & carry) | (b[i] & carry);
      #|      end
      #|    end
      #|  endfunction
      #|  assign lc_n0 = lc_i0_b63_b6c_b6f_b63_b6b;
      #|  assign lc_n1 = lc_i1_b72_b65_b73_b65_b74;
      #|  assign lc_n2 = lc_i2_b65_b6e_b61_b62_b6c_b65;
      #|  always_ff @(posedge lc_n0) begin
      #|    lc_n3 <= lc_n1 ? 8'h9 : (lc_n2 ? lc_n5 : lc_n3);
      #|  end
      #|  assign lc_n4 = 8'h1;
      #|  assign lc_n5 = lc_fn_add_w8(lc_n3, lc_n4);
      #|  assign lc_o0_b73_b74_b61_b74_b65 = lc_n3;
      #|endmodule
      #|
      #|`default_nettype wire
      #|
    ),
  )
}

///|
fn explicit_reset_module(
  mode : @ir.ResetMode,
  polarity : @ir.ResetPolarity,
) -> @ir.Module raise {
  let clock = node_id(0)
  let reset = node_id(1)
  let enable = node_id(2)
  let next = node_id(3)
  let state = node_id(4)
  let domain = @ir.ClockDomain::rising(clock)
  @ir.Module::checked_with_metadata(
    "ExplicitReset",
    [domain],
    [
      @ir.Node::new(clock, Clock, Input("clock")),
      @ir.Node::new(reset, Reset, Input("reset")),
      @ir.Node::new(enable, b(1), Input("enable")),
      @ir.Node::new(next, u(8), Input("next")),
      @ir.Node::new(
        state,
        u(8),
        Register(
          @ir.RegisterSpec::new(
            domain,
            next,
            reset=@ir.ResetSpec::explicit(reset, 9UL, mode, polarity),
            enable~,
          ),
        ),
      ),
    ],
    [],
    [@ir.OutputPort::new("state", u(8), state)],
    @ir.ModuleMetadata::checked_complete(
      [],
      [],
      [
        @ir.InputTimingBinding::new(
          reset,
          if mode is Asynchronous {
            Asynchronous
          } else {
            SampledIn(domain.id())
          },
        ),
        @ir.InputTimingBinding::new(enable, SampledIn(domain.id())),
        @ir.InputTimingBinding::new(next, SampledIn(domain.id())),
      ],
      [@ir.OutputTimingBinding::checked("state", ProducedIn(domain.id()))],
      [],
    ),
  )
}

///|
test "reset mode and polarity lower to exact sensitivity and priority" {
  for mode in [@ir.ResetMode::Synchronous, Asynchronous] {
    for polarity in [@ir.ResetPolarity::ActiveHigh, ActiveLow] {
      let source = @systemverilog.emit_design(
        @ir.Design::single(
          "explicit_reset",
          explicit_reset_module(mode, polarity),
        ),
      ).source()
      let sensitivity = match (mode, polarity) {
        (Synchronous, _) => "always_ff @(posedge lc_n0) begin"
        (Asynchronous, ActiveHigh) =>
          "always_ff @(posedge lc_n0 or posedge lc_n1) begin"
        (Asynchronous, ActiveLow) =>
          "always_ff @(posedge lc_n0 or negedge lc_n1) begin"
      }
      let condition = if polarity is ActiveHigh { "lc_n1" } else { "!lc_n1" }
      assert_true(source.contains(sensitivity))
      assert_true(
        source.contains(
          "lc_n4 <= \{condition} ? 8'h9 : (lc_n2 ? lc_n3 : lc_n4);",
        ),
      )
    }
  }
}

///|
test "explicit initial values fail closed" {
  let design = @ir.Design::single(
    "initialized",
    controlled_register_module(initial=3UL),
  )
  try @systemverilog.emit_design(design) catch {
    UnsupportedExplicitRegisterInitial(module_name~, node~, value~) => {
      assert_eq(module_name, "Controlled")
      assert_eq(node, 3)
      assert_eq(value, 3UL)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected explicit initialization rejection")
  }
}

///|
test "golden manifest separates Unicode reserved and encoded-looking names" {
  let hardware_module = @ir.Module::checked(
    "module",
    [
      @ir.Node::new(node_id(0), u(1), Input("μ")),
      @ir.Node::new(node_id(1), u(1), Input("_bce_bbc")),
      @ir.Node::new(node_id(2), u(1), BitOr(node_id(0), node_id(1))),
    ],
    [@ir.OutputPort::new("wire", u(1), node_id(2))],
  )
  let emitted = @systemverilog.emit_design(
    @ir.Design::single("reserved", hardware_module),
  )
  assert_false(emitted.source().contains("__"))
  for mapping in emitted.manifest().mappings() {
    assert_false(mapping.identifier().contains("__"))
  }
  inspect(
    emitted.source(),
    content=(
      #|`default_nettype none
      #|// LunaChip conservative SystemVerilog-2017 backend v1
      #|// Uninitialized registers intentionally have no initializer.
      #|
      #|module lc_m0_b6d_b6f_b64_b75_b6c_b65 (
      #|  input logic lc_i0_bce_bbc,
      #|  input logic lc_i1_b5f_b62_b63_b65_b5f_b62_b62_b63,
      #|  output logic lc_o0_b77_b69_b72_b65
      #|);
      #|
      #|  logic lc_n0;
      #|  logic lc_n1;
      #|  logic lc_n2;
      #|
      #|  assign lc_n0 = lc_i0_bce_bbc;
      #|  assign lc_n1 = lc_i1_b5f_b62_b63_b65_b5f_b62_b62_b63;
      #|  assign lc_n2 = lc_n0 | lc_n1;
      #|  assign lc_o0_b77_b69_b72_b65 = lc_n2;
      #|endmodule
      #|
      #|`default_nettype wire
      #|
    ),
  )
  inspect(
    emitted.manifest().to_canonical_text(),
    content=(
      #|LUNACHIP-SYSTEMVERILOG-NAMES 1
      #|TOP 0
      #|REGISTER-INITIALIZATION implicit-four-state-x-reject-explicit
      #|MAP module 0 -1 6d_6f_64_75_6c_65 lc_m0_b6d_b6f_b64_b75_b6c_b65
      #|MAP node 0 0 ce_bc lc_n0
      #|MAP input 0 0 ce_bc lc_i0_bce_bbc
      #|MAP node 0 1 5f_62_63_65_5f_62_62_63 lc_n1
      #|MAP input 0 1 5f_62_63_65_5f_62_62_63 lc_i1_b5f_b62_b63_b65_b5f_b62_b62_b63
      #|MAP node 0 2 - lc_n2
      #|MAP output 0 0 77_69_72_65 lc_o0_b77_b69_b72_b65
      #|END
      #|
    ),
  )
}
