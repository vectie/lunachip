///|
test "constructors mask and classify values" {
  let value = @wave.LogicValue::from_masks(
    width=4,
    value_bits=0xffUL,
    known_mask=0x5UL,
  )
  assert_eq(value.width(), 4)
  assert_eq(value.width_mask(), 0xfUL)
  assert_eq(value.value_bits(), 0x5UL)
  assert_eq(value.known_mask(), 0x5UL)
  assert_eq(value.unknown_mask(), 0xaUL)
  assert_eq(value.to_bit_string(), "x1x1")
  assert_false(value.is_fully_known())
  assert_false(value.is_fully_unknown())
  assert_eq(value.bit_at(0), One)
  assert_eq(value.bit_at(1), Unknown)
}

///|
test "zero one unknown and 64-bit boundaries" {
  let zero = @wave.LogicValue::zero(width=64)
  let one = @wave.LogicValue::one(width=64)
  let unknown = @wave.LogicValue::unknown(width=64)
  assert_eq(zero.width_mask(), 0xffffffffffffffffUL)
  assert_eq(zero.to_uint64(), 0UL)
  assert_eq(one.to_uint64(), 1UL)
  assert_true(zero.is_fully_known())
  assert_true(unknown.is_fully_unknown())
  assert_eq(unknown.to_bit_string().length(), 64)
}

///|
test "bitwise operators propagate and resolve unknowns" {
  let unknown = @wave.LogicValue::unknown(width=4)
  let zeros = @wave.LogicValue::zero(width=4)
  let ones = @wave.LogicValue::from_uint64(width=4, value=0xfUL)
  assert_eq(unknown.bit_and(zeros).to_bit_string(), "0000")
  assert_eq(unknown.bit_and(ones).to_bit_string(), "xxxx")
  assert_eq(unknown.bit_or(ones).to_bit_string(), "1111")
  assert_eq(unknown.bit_or(zeros).to_bit_string(), "xxxx")
  assert_eq(ones.bit_xor(zeros).to_bit_string(), "1111")
  assert_eq(ones.bit_not().to_bit_string(), "0000")
}

///|
test "exact equality distinguishes unknown masks" {
  let first = @wave.LogicValue::from_masks(
    width=4,
    value_bits=0xfUL,
    known_mask=0x3UL,
  )
  let same = @wave.LogicValue::from_masks(
    width=4,
    value_bits=0x3UL,
    known_mask=0x3UL,
  )
  let different = @wave.LogicValue::from_masks(
    width=4,
    value_bits=0x3UL,
    known_mask=0x7UL,
  )
  assert_true(first.case_equal(same))
  assert_false(first.case_equal(different))
  assert_eq(first, same)
}

///|
test "invalid widths and width mismatches are checked" {
  try @wave.LogicValue::zero(width=0) catch {
    InvalidWidth(width) => assert_eq(width, 0)
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected invalid width")
  }
  let left = @wave.LogicValue::zero(width=4)
  let right = @wave.LogicValue::zero(width=5)
  try left.bit_and(right) catch {
    WidthMismatch(left~, right~) => {
      assert_eq(left, 4)
      assert_eq(right, 5)
    }
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected width mismatch")
  }
}

///|
test "unknown conversion and invalid bit access are checked" {
  let value = @wave.LogicValue::unknown(width=2)
  try value.to_uint64() catch {
    ContainsUnknownBits => ()
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected unknown-bit error")
  }
  try value.bit_at(2) catch {
    BitIndexOutOfBounds(index~, width~) => {
      assert_eq(index, 2)
      assert_eq(width, 2)
    }
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected bounds error")
  }
}

///|
test "cycle counter is deterministic and overflow checked" {
  let cycle = @wave.CycleCounter::zero().advance(41UL).next()
  assert_eq(cycle.value(), 42UL)
  let maximum = @wave.CycleCounter::from_uint64(0xffffffffffffffffUL)
  try maximum.next() catch {
    CycleOverflow => ()
  } noraise {
    _ => fail("expected cycle overflow")
  }
}
