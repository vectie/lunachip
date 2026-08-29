///|
fn numeric_type(width : Int, signed : Bool) -> @ir.SignalType raise {
  let checked = @ir.Width::new(width)
  if signed {
    SInt(checked)
  } else {
    UInt(checked)
  }
}

///|
fn bits_type(width : Int) -> @ir.SignalType raise {
  Bits(@ir.Width::new(width))
}

///|
fn binary_operation_module(
  name : String,
  operand_type : @ir.SignalType,
  result_type : @ir.SignalType,
  operation : (@ir.NodeId, @ir.NodeId) -> @ir.NodeKind,
) -> @ir.Module raise {
  let lhs = @ir.NodeId::new(0)
  let rhs = @ir.NodeId::new(1)
  let result = @ir.NodeId::new(2)
  @ir.Module::checked(
    name,
    [
      @ir.Node::new(lhs, operand_type, Input("lhs")),
      @ir.Node::new(rhs, operand_type, Input("rhs")),
      @ir.Node::new(result, result_type, operation(lhs, rhs)),
    ],
    [@ir.OutputPort::new("result", result_type, result)],
  )
}

///|
fn unary_operation_module(
  name : String,
  input_type : @ir.SignalType,
  result_type : @ir.SignalType,
  operation : (@ir.NodeId) -> @ir.NodeKind,
) -> @ir.Module raise {
  let input = @ir.NodeId::new(0)
  let result = @ir.NodeId::new(1)
  @ir.Module::checked(
    name,
    [
      @ir.Node::new(input, input_type, Input("input")),
      @ir.Node::new(result, result_type, operation(input)),
    ],
    [@ir.OutputPort::new("result", result_type, result)],
  )
}

///|
fn set_binary_inputs(
  simulator : @sim.Simulator,
  width : Int,
  lhs : UInt64,
  rhs : UInt64,
) -> Unit raise {
  simulator.set_input("lhs", @wave.LogicValue::from_uint64(width~, value=lhs))
  simulator.set_input("rhs", @wave.LogicValue::from_uint64(width~, value=rhs))
  simulator.settle()
}

///|
fn result_uint64(simulator : @sim.Simulator) -> UInt64 raise {
  simulator.output("result").to_uint64()
}

///|
fn signed_small(raw : Int, width : Int) -> Int {
  let sign = 1 << (width - 1)
  if (raw & sign) == 0 {
    raw
  } else {
    raw - (1 << width)
  }
}

///|
test "exhaustively executes 3-bit arithmetic and unsigned comparisons" {
  let u3 = numeric_type(3, false)
  let bit = bits_type(1)
  let add = @sim.Simulator::prepare(
    binary_operation_module("Add", u3, u3, (lhs, rhs) => Add(lhs, rhs)),
  )
  let sub = @sim.Simulator::prepare(
    binary_operation_module("Sub", u3, u3, (lhs, rhs) => Sub(lhs, rhs)),
  )
  let mul_low = @sim.Simulator::prepare(
    binary_operation_module("MulLow", u3, u3, (lhs, rhs) => MulLow(lhs, rhs)),
  )
  let mul_full = @sim.Simulator::prepare(
    binary_operation_module("MulFull", u3, numeric_type(6, false), (lhs, rhs) => {
      MulFull(lhs, rhs)
    }),
  )
  let equal = @sim.Simulator::prepare(
    binary_operation_module("Equal", u3, bit, (lhs, rhs) => Equal(lhs, rhs)),
  )
  let less = @sim.Simulator::prepare(
    binary_operation_module("LessThan", u3, bit, (lhs, rhs) => {
      LessThan(lhs, rhs)
    }),
  )
  let less_equal = @sim.Simulator::prepare(
    binary_operation_module("LessEqual", u3, bit, (lhs, rhs) => {
      LessEqual(lhs, rhs)
    }),
  )
  for lhs in 0..<8 {
    for rhs in 0..<8 {
      let left = lhs.to_uint64()
      let right = rhs.to_uint64()
      set_binary_inputs(add, 3, left, right)
      set_binary_inputs(sub, 3, left, right)
      set_binary_inputs(mul_low, 3, left, right)
      set_binary_inputs(mul_full, 3, left, right)
      set_binary_inputs(equal, 3, left, right)
      set_binary_inputs(less, 3, left, right)
      set_binary_inputs(less_equal, 3, left, right)
      assert_eq(result_uint64(add), ((lhs + rhs) & 7).to_uint64())
      assert_eq(result_uint64(sub), ((lhs + 8 - rhs) & 7).to_uint64())
      assert_eq(result_uint64(mul_low), ((lhs * rhs) & 7).to_uint64())
      assert_eq(result_uint64(mul_full), (lhs * rhs).to_uint64())
      assert_eq(result_uint64(equal), if lhs == rhs { 1UL } else { 0UL })
      assert_eq(result_uint64(less), if lhs < rhs { 1UL } else { 0UL })
      assert_eq(result_uint64(less_equal), if lhs <= rhs { 1UL } else { 0UL })
    }
  }
}

///|
test "exhaustively executes signed full multiply and comparisons" {
  let s3 = numeric_type(3, true)
  let bit = bits_type(1)
  let mul_full = @sim.Simulator::prepare(
    binary_operation_module("SignedMulFull", s3, numeric_type(6, true), (
      lhs,
      rhs,
    ) => MulFull(lhs, rhs)),
  )
  let less = @sim.Simulator::prepare(
    binary_operation_module("SignedLessThan", s3, bit, (lhs, rhs) => {
      LessThan(lhs, rhs)
    }),
  )
  let less_equal = @sim.Simulator::prepare(
    binary_operation_module("SignedLessEqual", s3, bit, (lhs, rhs) => {
      LessEqual(lhs, rhs)
    }),
  )
  for lhs_raw in 0..<8 {
    for rhs_raw in 0..<8 {
      let lhs = signed_small(lhs_raw, 3)
      let rhs = signed_small(rhs_raw, 3)
      set_binary_inputs(mul_full, 3, lhs_raw.to_uint64(), rhs_raw.to_uint64())
      set_binary_inputs(less, 3, lhs_raw.to_uint64(), rhs_raw.to_uint64())
      set_binary_inputs(less_equal, 3, lhs_raw.to_uint64(), rhs_raw.to_uint64())
      let product = lhs * rhs
      let product_bits = if product < 0 { product + 64 } else { product }
      assert_eq(result_uint64(mul_full), product_bits.to_uint64())
      assert_eq(result_uint64(less), if lhs < rhs { 1UL } else { 0UL })
      assert_eq(result_uint64(less_equal), if lhs <= rhs { 1UL } else { 0UL })
    }
  }
}

///|
fn next_test_word(value : UInt64) -> UInt64 {
  value * 6364136223846793005UL + 1442695040888963407UL
}

///|
test "seeded 8-bit operation stream agrees with mathematical oracles" {
  let u8 = numeric_type(8, false)
  let s8 = numeric_type(8, true)
  let bit = bits_type(1)
  let add = @sim.Simulator::prepare(
    binary_operation_module("RandomAdd", u8, u8, (lhs, rhs) => Add(lhs, rhs)),
  )
  let mul_full = @sim.Simulator::prepare(
    binary_operation_module("RandomMulFull", s8, numeric_type(16, true), (
      lhs,
      rhs,
    ) => MulFull(lhs, rhs)),
  )
  let less = @sim.Simulator::prepare(
    binary_operation_module("RandomLess", s8, bit, (lhs, rhs) => {
      LessThan(lhs, rhs)
    }),
  )
  let mut state = 0x4c554e4143484950UL
  for _ in 0..<256 {
    state = next_test_word(state)
    let lhs_raw = (state & 0xffUL).to_int()
    state = next_test_word(state)
    let rhs_raw = (state & 0xffUL).to_int()
    set_binary_inputs(add, 8, lhs_raw.to_uint64(), rhs_raw.to_uint64())
    set_binary_inputs(mul_full, 8, lhs_raw.to_uint64(), rhs_raw.to_uint64())
    set_binary_inputs(less, 8, lhs_raw.to_uint64(), rhs_raw.to_uint64())
    assert_eq(result_uint64(add), ((lhs_raw + rhs_raw) & 255).to_uint64())
    let lhs = signed_small(lhs_raw, 8)
    let rhs = signed_small(rhs_raw, 8)
    let product = lhs * rhs
    let product_bits = if product < 0 { product + 65536 } else { product }
    assert_eq(result_uint64(mul_full), product_bits.to_uint64())
    assert_eq(result_uint64(less), if lhs < rhs { 1UL } else { 0UL })
  }
}

///|
fn shift_module(kind : String, signed : Bool) -> @ir.Module raise {
  let value_type = numeric_type(4, signed)
  let amount_type = numeric_type(3, false)
  let value = @ir.NodeId::new(0)
  let amount = @ir.NodeId::new(1)
  let result = @ir.NodeId::new(2)
  let operation : @ir.NodeKind = match kind {
    "left" => ShiftLeft(value~, amount~)
    "logical" => LogicalShiftRight(value~, amount~)
    _ => ArithmeticShiftRight(value~, amount~)
  }
  @ir.Module::checked(
    "Shift",
    [
      @ir.Node::new(value, value_type, Input("value")),
      @ir.Node::new(amount, amount_type, Input("amount")),
      @ir.Node::new(result, value_type, operation),
    ],
    [@ir.OutputPort::new("result", value_type, result)],
  )
}

///|
fn set_shift_inputs(
  simulator : @sim.Simulator,
  value : Int,
  amount : Int,
) -> Unit raise {
  simulator.set_input(
    "value",
    @wave.LogicValue::from_uint64(width=4, value=value.to_uint64()),
  )
  simulator.set_input(
    "amount",
    @wave.LogicValue::from_uint64(width=3, value=amount.to_uint64()),
  )
  simulator.settle()
}

///|
test "exhaustively executes logical and arithmetic shifts" {
  let left = @sim.Simulator::prepare(shift_module("left", false))
  let logical = @sim.Simulator::prepare(shift_module("logical", false))
  let arithmetic = @sim.Simulator::prepare(shift_module("arithmetic", true))
  for raw in 0..<16 {
    for amount in 0..<8 {
      set_shift_inputs(left, raw, amount)
      set_shift_inputs(logical, raw, amount)
      set_shift_inputs(arithmetic, raw, amount)
      let expected_left = if amount >= 4 { 0 } else { (raw << amount) & 15 }
      let expected_logical = if amount >= 4 { 0 } else { raw >> amount }
      let signed = signed_small(raw, 4)
      let shifted = if amount >= 4 {
        if signed < 0 {
          -1
        } else {
          0
        }
      } else {
        signed >> amount
      }
      let expected_arithmetic = if shifted < 0 { shifted + 16 } else { shifted }
      assert_eq(result_uint64(left), expected_left.to_uint64())
      assert_eq(result_uint64(logical), expected_logical.to_uint64())
      assert_eq(result_uint64(arithmetic), expected_arithmetic.to_uint64())
    }
  }
}

///|
test "executes slice, concatenation, resize, and reinterpret nodes" {
  let b4 = bits_type(4)
  let s4 = numeric_type(4, true)
  let slice = @sim.Simulator::prepare(
    unary_operation_module("Slice", b4, bits_type(2), value => {
      Slice(value~, msb=2, lsb=1)
    }),
  )
  let zero_extend = @sim.Simulator::prepare(
    unary_operation_module("ZeroExtend", b4, bits_type(6), value => {
      ZeroExtend(value)
    }),
  )
  let sign_extend = @sim.Simulator::prepare(
    unary_operation_module("SignExtend", s4, numeric_type(6, true), value => {
      SignExtend(value)
    }),
  )
  let truncate = @sim.Simulator::prepare(
    unary_operation_module("Truncate", b4, bits_type(2), value => {
      Truncate(value)
    }),
  )
  let reinterpret = @sim.Simulator::prepare(
    unary_operation_module("Reinterpret", s4, numeric_type(4, false), value => {
      Reinterpret(value)
    }),
  )
  for raw in 0..<16 {
    let value = @wave.LogicValue::from_uint64(width=4, value=raw.to_uint64())
    for simulator in [slice, zero_extend, sign_extend, truncate, reinterpret] {
      simulator.set_input("input", value)
      simulator.settle()
    }
    assert_eq(result_uint64(slice), ((raw >> 1) & 3).to_uint64())
    assert_eq(result_uint64(zero_extend), raw.to_uint64())
    let expected_sign = if (raw & 8) == 0 { raw } else { raw | 48 }
    assert_eq(result_uint64(sign_extend), expected_sign.to_uint64())
    assert_eq(result_uint64(truncate), (raw & 3).to_uint64())
    assert_eq(result_uint64(reinterpret), raw.to_uint64())
  }

  let high = @ir.NodeId::new(0)
  let low = @ir.NodeId::new(1)
  let result = @ir.NodeId::new(2)
  let concat_module = @ir.Module::checked(
    "Concat",
    [
      @ir.Node::new(high, bits_type(2), Input("lhs")),
      @ir.Node::new(low, bits_type(3), Input("rhs")),
      @ir.Node::new(
        result,
        bits_type(5),
        Concat(most_significant=high, least_significant=low),
      ),
    ],
    [@ir.OutputPort::new("result", bits_type(5), result)],
  )
  let concat = @sim.Simulator::prepare(concat_module)
  concat.set_input("lhs", @wave.LogicValue::from_uint64(width=2, value=2UL))
  concat.set_input("rhs", @wave.LogicValue::from_uint64(width=3, value=5UL))
  concat.settle()
  assert_eq(result_uint64(concat), 21UL)
}

///|
test "delegates unknown-value behavior for every operation family" {
  let u4 = numeric_type(4, false)
  let bit = bits_type(1)
  let unknown = @wave.LogicValue::unknown(width=4)
  let zero = @wave.LogicValue::zero(width=4)
  let add = @sim.Simulator::prepare(
    binary_operation_module("AddX", u4, u4, (lhs, rhs) => Add(lhs, rhs)),
  )
  add.set_input("lhs", unknown)
  add.set_input("rhs", zero)
  add.settle()
  assert_eq(add.output("result").to_bit_string(), "xxxx")

  let mul = @sim.Simulator::prepare(
    binary_operation_module("MulX", u4, u4, (lhs, rhs) => MulLow(lhs, rhs)),
  )
  mul.set_input("lhs", unknown)
  mul.set_input("rhs", zero)
  mul.settle()
  assert_eq(mul.output("result").to_bit_string(), "0000")

  let equal = @sim.Simulator::prepare(
    binary_operation_module("EqualX", u4, bit, (lhs, rhs) => Equal(lhs, rhs)),
  )
  equal.set_input(
    "lhs",
    @wave.LogicValue::from_masks(
      width=4,
      value_bits=0b0001UL,
      known_mask=0b0001UL,
    ),
  )
  equal.set_input("rhs", zero)
  equal.settle()
  assert_eq(equal.output("result").to_bit_string(), "0")

  let less = @sim.Simulator::prepare(
    binary_operation_module("LessX", u4, bit, (lhs, rhs) => LessThan(lhs, rhs)),
  )
  less.set_input("lhs", unknown)
  less.set_input("rhs", zero)
  less.settle()
  assert_eq(less.output("result").to_bit_string(), "x")

  let shift = @sim.Simulator::prepare(shift_module("left", false))
  shift.set_input("value", zero)
  shift.set_input("amount", @wave.LogicValue::unknown(width=3))
  shift.settle()
  assert_eq(shift.output("result").to_bit_string(), "xxxx")

  let sliced = @sim.Simulator::prepare(
    unary_operation_module("SliceX", bits_type(4), bits_type(2), value => {
      Slice(value~, msb=2, lsb=1)
    }),
  )
  sliced.set_input(
    "input",
    @wave.LogicValue::from_masks(
      width=4,
      value_bits=0b0100UL,
      known_mask=0b1101UL,
    ),
  )
  sliced.settle()
  assert_eq(sliced.output("result").to_bit_string(), "1x")
}
