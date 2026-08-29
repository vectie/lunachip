///|
fn make_adder(outputs_reversed : Bool) -> @ir.Module raise {
  let ty = @ir.SignalType::UInt(@ir.Width::new(8))
  let a = @ir.NodeId::new(0)
  let b = @ir.NodeId::new(1)
  let sum = @ir.NodeId::new(2)
  let nodes = [
    @ir.Node::new(a, ty, Input("a")),
    @ir.Node::new(b, ty, Input("b")),
    @ir.Node::new(sum, ty, Add(a, b)),
  ]
  let sum_output = @ir.OutputPort::new("sum", ty, sum)
  let carry_output = @ir.OutputPort::new("carry", ty, a)
  let outputs = if outputs_reversed {
    [carry_output, sum_output]
  } else {
    [sum_output, carry_output]
  }
  @ir.Module::checked("Adder", nodes, outputs)
}

///|
fn make_zero() -> @ir.Module raise {
  let ty = @ir.SignalType::UInt(@ir.Width::new(8))
  let zero = @ir.NodeId::new(0)
  @ir.Module::checked("Zero", [@ir.Node::new(zero, ty, Constant(0UL))], [
    @ir.OutputPort::new("z", ty, zero),
  ])
}

///|
fn make_fixture(reverse_construction : Bool) -> @ir.Design raise {
  let adder = make_adder(reverse_construction)
  let zero = make_zero()
  let modules = if reverse_construction { [zero, adder] } else { [adder, zero] }
  @ir.Design::checked("codec-fixture", modules, "Adder")
}

///|
const GOLDEN : String =
  #|LUNACHIP-IR 1
  #|DESIGN 636f6465632d66697874757265
  #|TOP 4164646572
  #|MODULES 2
  #|MODULE 4164646572
  #|NODES 3
  #|NODE 0 uint:8 input 61
  #|NODE 1 uint:8 input 62
  #|NODE 2 uint:8 add 0 1
  #|OUTPUTS 2
  #|OUTPUT 6361727279 uint:8 0
  #|OUTPUT 73756d uint:8 2
  #|ENDMODULE
  #|MODULE 5a65726f
  #|NODES 1
  #|NODE 0 uint:8 const 0
  #|OUTPUTS 1
  #|OUTPUT 7a uint:8 0
  #|ENDMODULE
  #|END
  #|

///|
test "golden canonical bytes and round trip are stable" {
  let canonical = @codec.serialize(make_fixture(false))
  assert_eq(canonical, GOLDEN)
  let decoded = @codec.parse(canonical)
  assert_eq(@codec.serialize(decoded), canonical)
}

///|
test "module and output construction order do not change bytes or digest" {
  let first = make_fixture(false)
  let second = make_fixture(true)
  assert_eq(@codec.serialize(first), @codec.serialize(second))
  let first_digest = @codec.content_digest(first)
  let second_digest = @codec.content_digest(second)
  assert_eq(first_digest, second_digest)
  inspect(first_digest.algorithm(), content="fnv1a-64")
  inspect(first_digest.to_hex(), content="73efc4fffd94161e")
}

///|
test "utf8 names are byte encoded and round trip" {
  let ty = @ir.SignalType::Bits(@ir.Width::new(1))
  let input = @ir.NodeId::new(0)
  let hardware_module = @ir.Module::checked(
    "月",
    [@ir.Node::new(input, ty, Input("信号"))],
    [@ir.OutputPort::new("出", ty, input)],
  )
  let design = @ir.Design::single("芯片", hardware_module)
  let canonical = @codec.serialize(design)
  assert_false(canonical.contains("月"))
  assert_eq(@codec.serialize(@codec.parse(canonical)), canonical)
}

///|
test "every schema-one node operation round trips" {
  let clock = @ir.SignalType::Clock
  let u4 = @ir.SignalType::UInt(@ir.Width::new(4))
  let u8 = @ir.SignalType::UInt(@ir.Width::new(8))
  let u16 = @ir.SignalType::UInt(@ir.Width::new(16))
  let s8 = @ir.SignalType::SInt(@ir.Width::new(8))
  let s16 = @ir.SignalType::SInt(@ir.Width::new(16))
  let bits1 = @ir.SignalType::Bits(@ir.Width::new(1))
  let bits4 = @ir.SignalType::Bits(@ir.Width::new(4))
  let bits8 = @ir.SignalType::Bits(@ir.Width::new(8))
  let bits16 = @ir.SignalType::Bits(@ir.Width::new(16))
  let ids = Array::makei(28, @ir.NodeId::new)
  let nodes = [
    @ir.Node::new(ids[0], clock, Input("clock")),
    @ir.Node::new(ids[1], u8, Input("a")),
    @ir.Node::new(ids[2], u8, Input("b")),
    @ir.Node::new(ids[3], u4, Input("amount")),
    @ir.Node::new(ids[4], s8, Input("signed")),
    @ir.Node::new(ids[5], bits8, Input("raw")),
    @ir.Node::new(ids[6], u8, Add(ids[1], ids[2])),
    @ir.Node::new(ids[7], u8, Sub(ids[1], ids[2])),
    @ir.Node::new(ids[8], u8, MulLow(ids[1], ids[2])),
    @ir.Node::new(ids[9], u16, MulFull(ids[1], ids[2])),
    @ir.Node::new(ids[10], u8, BitAnd(ids[1], ids[2])),
    @ir.Node::new(ids[11], u8, BitOr(ids[1], ids[2])),
    @ir.Node::new(ids[12], u8, BitXor(ids[1], ids[2])),
    @ir.Node::new(ids[13], u8, BitNot(ids[1])),
    @ir.Node::new(ids[14], bits1, Equal(ids[1], ids[2])),
    @ir.Node::new(ids[15], bits1, LessThan(ids[1], ids[2])),
    @ir.Node::new(ids[16], bits1, LessEqual(ids[1], ids[2])),
    @ir.Node::new(ids[17], u8, ShiftLeft(value=ids[1], amount=ids[3])),
    @ir.Node::new(ids[18], u8, LogicalShiftRight(value=ids[1], amount=ids[3])),
    @ir.Node::new(
      ids[19],
      s8,
      ArithmeticShiftRight(value=ids[4], amount=ids[3]),
    ),
    @ir.Node::new(ids[20], bits4, Slice(value=ids[5], msb=7, lsb=4)),
    @ir.Node::new(
      ids[21],
      bits16,
      Concat(most_significant=ids[5], least_significant=ids[5]),
    ),
    @ir.Node::new(ids[22], u16, ZeroExtend(ids[1])),
    @ir.Node::new(ids[23], s16, SignExtend(ids[4])),
    @ir.Node::new(ids[24], u4, Truncate(ids[1])),
    @ir.Node::new(ids[25], bits8, Reinterpret(ids[1])),
    @ir.Node::new(
      ids[26],
      u8,
      Mux(select=ids[14], when_true=ids[1], when_false=ids[2]),
    ),
    @ir.Node::new(
      ids[27],
      u8,
      Register(clock=ids[0], next=ids[6], initial=Some(1UL)),
    ),
  ]
  let hardware_module = @ir.Module::checked("Operations", nodes, [
    @ir.OutputPort::new("result", u8, ids[27]),
  ])
  let canonical = @codec.serialize(
    @ir.Design::single("operations", hardware_module),
  )
  assert_eq(@codec.serialize(@codec.parse(canonical)), canonical)
}

///|
test "unsupported schema version is checked" {
  try @codec.parse("LUNACHIP-IR 2\n") catch {
    UnsupportedVersion(version) => inspect(version, content="2")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unsupported version")
  }
}

///|
test "malformed encoded name is rejected" {
  let malformed =
    #|LUNACHIP-IR 1
    #|DESIGN 4G
    #|TOP 41
    #|MODULES 0
    #|END
    #|
  try @codec.parse(malformed) catch {
    InvalidEncodedName(line~, value~) => {
      inspect(line, content="2")
      inspect(value, content="4G")
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected encoded name rejection")
  }
}

///|
test "noncanonical module order is rejected" {
  let noncanonical =
    #|LUNACHIP-IR 1
    #|DESIGN 636f6465632d66697874757265
    #|TOP 4164646572
    #|MODULES 2
    #|MODULE 5a65726f
    #|NODES 1
    #|NODE 0 uint:8 const 0
    #|OUTPUTS 1
    #|OUTPUT 7a uint:8 0
    #|ENDMODULE
    #|MODULE 4164646572
    #|NODES 3
    #|NODE 0 uint:8 input 61
    #|NODE 1 uint:8 input 62
    #|NODE 2 uint:8 add 0 1
    #|OUTPUTS 2
    #|OUTPUT 6361727279 uint:8 0
    #|OUTPUT 73756d uint:8 2
    #|ENDMODULE
    #|END
    #|
  try @codec.parse(noncanonical) catch {
    NonCanonical => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected noncanonical rejection")
  }
}

///|
test "missing final newline and invalid IR are rejected" {
  let without_newline = GOLDEN[0:GOLDEN.length() - 1].to_owned()
  try @codec.parse(without_newline) catch {
    UnexpectedEnd(_) | UnexpectedLine(..) => ()
    error => fail("unexpected missing-newline error: \{Repr(error)}")
  } noraise {
    _ => fail("expected missing final newline rejection")
  }
  let invalid_ir =
    #|LUNACHIP-IR 1
    #|DESIGN 426164
    #|TOP 426164
    #|MODULES 1
    #|MODULE 426164
    #|NODES 1
    #|NODE 0 uint:1 const 2
    #|OUTPUTS 0
    #|ENDMODULE
    #|END
    #|
  try @codec.parse(invalid_ir) catch {
    IrRejected(_) => ()
    error => fail("unexpected invalid-IR error: \{Repr(error)}")
  } noraise {
    _ => fail("expected checked IR rejection")
  }
}
