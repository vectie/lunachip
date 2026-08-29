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
  #|LUNACHIP-IR 2
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
  inspect(first_digest.to_hex(), content="6d2a955c6cd55f19")
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
test "every current-schema node operation round trips" {
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
      Register(
        @ir.RegisterSpec::new(
          @ir.ClockDomain::rising(ids[0]),
          ids[6],
          initial=1UL,
        ),
      ),
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
  try @codec.parse("LUNACHIP-IR 5\n") catch {
    UnsupportedVersion(version) => inspect(version, content="5")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unsupported version")
  }
}

///|
test "schema two preserves explicit register controls" {
  let clock = @ir.NodeId::new(0)
  let reset = @ir.NodeId::new(1)
  let enable = @ir.NodeId::new(2)
  let next = @ir.NodeId::new(3)
  let state = @ir.NodeId::new(4)
  let one = @ir.Width::new(1)
  let eight = @ir.SignalType::UInt(@ir.Width::new(8))
  let spec = @ir.RegisterSpec::new(
    @ir.ClockDomain::rising(clock),
    next,
    reset=@ir.ResetSpec::new(reset, 7UL),
    enable~,
    initial=9UL,
  )
  let hardware_module = @ir.Module::checked(
    "Controlled",
    [
      @ir.Node::new(clock, Clock, Input("clock")),
      @ir.Node::new(reset, Reset, Input("reset")),
      @ir.Node::new(enable, Bits(one), Input("enable")),
      @ir.Node::new(next, eight, Input("next")),
      @ir.Node::new(state, eight, Register(spec)),
    ],
    [@ir.OutputPort::new("state", eight, state)],
  )
  let canonical = @codec.serialize(
    @ir.Design::single("controlled", hardware_module),
  )
  assert_true(canonical.contains("reg 0 3 1 7 2 9"))
  assert_eq(@codec.serialize(@codec.parse(canonical)), canonical)
}

///|
test "canonical schema one registers upgrade without losing state" {
  let legacy =
    #|LUNACHIP-IR 1
    #|DESIGN 6c6567616379
    #|TOP 4c6567616379
    #|MODULES 1
    #|MODULE 4c6567616379
    #|NODES 3
    #|NODE 0 clock input 636c6f636b
    #|NODE 1 uint:8 input 6e657874
    #|NODE 2 uint:8 reg 0 1 some 5
    #|OUTPUTS 1
    #|OUTPUT 7374617465 uint:8 2
    #|ENDMODULE
    #|END
    #|
  let upgraded = @codec.serialize(@codec.parse(legacy))
  assert_true(upgraded.has_prefix("LUNACHIP-IR 2\n"))
  assert_true(upgraded.contains("reg 0 1 - - - 5"))
}

///|
test "schema two rejects a half-present reset pair" {
  let malformed =
    #|LUNACHIP-IR 2
    #|DESIGN 626164
    #|TOP 426164
    #|MODULES 1
    #|MODULE 426164
    #|NODES 3
    #|NODE 0 clock input 636c6f636b
    #|NODE 1 uint:8 input 6e657874
    #|NODE 2 uint:8 reg 0 1 - 0 - -
    #|OUTPUTS 0
    #|ENDMODULE
    #|END
    #|
  try @codec.parse(malformed) catch {
    UnexpectedLine(expected~, ..) =>
      inspect(expected, content="register reset pair or - -")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected malformed reset rejection")
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

///|
fn reset_to_data_design() -> @ir.Design raise {
  let reset = @ir.NodeId::new(0)
  let asserted = @ir.NodeId::new(1)
  let hardware_module = @ir.Module::checked(
    "ResetView",
    [
      @ir.Node::new(reset, Reset, Input("reset")),
      @ir.Node::new(asserted, Bits(@ir.Width::new(1)), Reinterpret(reset)),
    ],
    [@ir.OutputPort::new("asserted", Bits(@ir.Width::new(1)), asserted)],
  )
  @ir.Design::single("reset-view", hardware_module)
}

///|
test "reset-to-data conversion is versioned as schema 3" {
  let canonical = @codec.serialize(reset_to_data_design())
  assert_true(canonical.has_prefix("LUNACHIP-IR 3\n"))
  assert_true(canonical.contains("MEMORIES 0\n"))
  assert_eq(@codec.serialize(@codec.parse(canonical)), canonical)
  let mislabeled_schema_two = canonical
    .replace(old="LUNACHIP-IR 3\n", new="LUNACHIP-IR 2\n")
    .replace(old="MEMORIES 0\n", new="")
  try @codec.parse(mislabeled_schema_two) catch {
    FeatureRequiresSchema3("reset-to-data reinterpret") => ()
    error => fail("unexpected schema extension error: \{Repr(error)}")
  } noraise {
    _ => fail("expected schema-2 reset conversion rejection")
  }
}

///|
fn multi_domain_design() -> @ir.Design raise {
  let clock_a = @ir.NodeId::new(0)
  let clock_b = @ir.NodeId::new(1)
  let next_a = @ir.NodeId::new(2)
  let next_b = @ir.NodeId::new(3)
  let state_a = @ir.NodeId::new(4)
  let state_b = @ir.NodeId::new(5)
  let ty : @ir.SignalType = UInt(@ir.Width::new(8))
  let hardware_module = @ir.Module::checked(
    "DualClock",
    [
      @ir.Node::new(clock_a, Clock, Input("clock_a")),
      @ir.Node::new(clock_b, Clock, Input("clock_b")),
      @ir.Node::new(next_a, ty, Input("next_a")),
      @ir.Node::new(next_b, ty, Input("next_b")),
      @ir.Node::new(
        state_a,
        ty,
        Register(
          @ir.RegisterSpec::new(@ir.ClockDomain::rising(clock_a), next_a),
        ),
      ),
      @ir.Node::new(
        state_b,
        ty,
        Register(
          @ir.RegisterSpec::new(@ir.ClockDomain::rising(clock_b), next_b),
        ),
      ),
    ],
    [
      @ir.OutputPort::new("state_a", ty, state_a),
      @ir.OutputPort::new("state_b", ty, state_b),
    ],
  )
  @ir.Design::single("dual-clock", hardware_module)
}

///|
test "multiple clock domains select schema four and round trip" {
  let canonical = @codec.serialize(multi_domain_design())
  assert_true(canonical.has_prefix("LUNACHIP-IR 4\n"))
  assert_true(canonical.contains("DOMAINS 2\n"))
  assert_true(canonical.contains("DOMAIN 0 0 rising\n"))
  assert_true(canonical.contains("DOMAIN 1 1 rising\n"))
  assert_true(canonical.contains("reg 0 2 - - - - - -"))
  assert_true(canonical.contains("reg 1 3 - - - - - -"))
  let decoded = @codec.parse(canonical)
  assert_eq(decoded.top_module().unwrap().domains().length(), 2)
  assert_eq(@codec.serialize(decoded), canonical)
}

///|
test "schema four rejects unknown and noncanonical domain references" {
  let canonical = @codec.serialize(multi_domain_design())
  let unknown = canonical.replace(
    old="NODE 4 uint:8 reg 0 2",
    new="NODE 4 uint:8 reg 9 2",
  )
  try @codec.parse(unknown) catch {
    UnknownClockDomain(id~, ..) => assert_eq(id, 9)
    error => fail("unexpected unknown-domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unknown domain rejection")
  }
  let noncanonical = canonical
    .replace(old="DOMAIN 1 1 rising", new="DOMAIN 7 1 rising")
    .replace(old="NODE 5 uint:8 reg 1 3", new="NODE 5 uint:8 reg 7 3")
  try @codec.parse(noncanonical) catch {
    IrRejected(reason~) =>
      assert_true(reason.contains("NonCanonicalClockDomainId"))
    error => fail("unexpected noncanonical-domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected noncanonical domain rejection")
  }
}

///|
test "multi-domain semantics cannot be mislabeled as schema two" {
  let mislabeled =
    #|LUNACHIP-IR 2
    #|DESIGN 6475616c2d636c6f636b
    #|TOP 4475616c436c6f636b
    #|MODULES 1
    #|MODULE 4475616c436c6f636b
    #|NODES 6
    #|NODE 0 clock input 636c6f636b5f61
    #|NODE 1 clock input 636c6f636b5f62
    #|NODE 2 uint:8 input 6e6578745f61
    #|NODE 3 uint:8 input 6e6578745f62
    #|NODE 4 uint:8 reg 0 2 - - - -
    #|NODE 5 uint:8 reg 1 3 - - - -
    #|OUTPUTS 2
    #|OUTPUT 73746174655f61 uint:8 4
    #|OUTPUT 73746174655f62 uint:8 5
    #|ENDMODULE
    #|END
    #|
  try @codec.parse(mislabeled) catch {
    FeatureRequiresSchema4(_) => ()
    error => fail("unexpected mislabeled-schema error: \{Repr(error)}")
  } noraise {
    _ => fail("expected schema-four feature rejection")
  }
}

///|
test "schema four cannot over-version a legacy one-domain design" {
  let over_versioned =
    #|LUNACHIP-IR 4
    #|DESIGN 6f76657276657273696f6e
    #|TOP 4f6e65436c6f636b
    #|MODULES 1
    #|MODULE 4f6e65436c6f636b
    #|DOMAINS 1
    #|DOMAIN 0 0 rising
    #|NODES 3
    #|NODE 0 clock input 636c6f636b
    #|NODE 1 uint:8 input 6e657874
    #|NODE 2 uint:8 reg 0 1 - - - - - -
    #|MEMORIES 0
    #|OUTPUTS 1
    #|OUTPUT 7374617465 uint:8 2
    #|ENDMODULE
    #|END
    #|
  try @codec.parse(over_versioned) catch {
    NonCanonical => ()
    error => fail("unexpected over-version error: \{Repr(error)}")
  } noraise {
    _ => fail("expected over-versioned schema-four rejection")
  }
}

///|
test "unsupported reset modes and polarities cannot enter schema four" {
  let template =
    #|LUNACHIP-IR 4
    #|DESIGN 7265736574
    #|TOP 5265736574
    #|MODULES 1
    #|MODULE 5265736574
    #|DOMAINS 1
    #|DOMAIN 0 0 rising
    #|NODES 4
    #|NODE 0 clock input 636c6f636b
    #|NODE 1 reset input 7265736574
    #|NODE 2 uint:8 input 6e657874
    #|NODE 3 uint:8 reg 0 2 1 0 MODE POLARITY - -
    #|MEMORIES 0
    #|OUTPUTS 1
    #|OUTPUT 7374617465 uint:8 3
    #|ENDMODULE
    #|END
    #|
  let asynchronous = template
    .replace(old="MODE", new="asynchronous")
    .replace(old="POLARITY", new="active_high")
  try @codec.parse(asynchronous) catch {
    IrRejected(reason~) =>
      assert_true(reason.contains("UnsupportedAsynchronousReset"))
    error => fail("unexpected async reset error: \{Repr(error)}")
  } noraise {
    _ => fail("expected asynchronous reset rejection")
  }
  let active_low = template
    .replace(old="MODE", new="synchronous")
    .replace(old="POLARITY", new="active_low")
  try @codec.parse(active_low) catch {
    IrRejected(reason~) =>
      assert_true(reason.contains("UnsupportedResetPolarity"))
    error => fail("unexpected active-low error: \{Repr(error)}")
  } noraise {
    _ => fail("expected active-low reset rejection")
  }
}
