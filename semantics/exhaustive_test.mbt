///|
fn width_mask(width : Int) -> UInt64 {
  (1UL << width) - 1UL
}

///|
fn signed_value(raw : UInt64, width : Int) -> Int {
  let unsigned = raw.to_int()
  if (raw & (1UL << (width - 1))) == 0UL {
    unsigned
  } else {
    unsigned - (1 << width)
  }
}

///|
test "known arithmetic and comparisons are exhaustive through width four" {
  for width in 1..<=4 {
    let limit = 1 << width
    let mask = width_mask(width)
    for left_raw in 0..<limit {
      let left = @semantics.LogicValue::from_uint64(
        width~,
        value=left_raw.to_uint64(),
      )
      for right_raw in 0..<limit {
        let right = @semantics.LogicValue::from_uint64(
          width~,
          value=right_raw.to_uint64(),
        )
        assert_eq(
          left.add(right).to_uint64(),
          (left_raw.to_uint64() + right_raw.to_uint64()) & mask,
        )
        assert_eq(
          left.sub(right).to_uint64(),
          (left_raw.to_uint64() - right_raw.to_uint64()) & mask,
        )
        assert_eq(
          left.mul_low(right).to_uint64(),
          (left_raw.to_uint64() * right_raw.to_uint64()) & mask,
        )
        assert_eq(
          left.equal_value(right).to_uint64(),
          if left_raw == right_raw {
            1UL
          } else {
            0UL
          },
        )
        assert_eq(
          left.less_than_unsigned(right).to_uint64(),
          if left_raw < right_raw {
            1UL
          } else {
            0UL
          },
        )
        assert_eq(
          left.less_than_signed(right).to_uint64(),
          if signed_value(left_raw.to_uint64(), width) <
            signed_value(right_raw.to_uint64(), width) {
            1UL
          } else {
            0UL
          },
        )
      }
    }
  }
}

///|
test "known shifts are exhaustive through width four including overshift" {
  for width in 1..<=4 {
    let limit = 1 << width
    let mask = width_mask(width)
    for raw in 0..<limit {
      let value = @semantics.LogicValue::from_uint64(
        width~,
        value=raw.to_uint64(),
      )
      for amount_raw in 0..<=width {
        let amount = @semantics.LogicValue::from_uint64(
          width=3,
          value=amount_raw.to_uint64(),
        )
        let expected_left = if amount_raw >= width {
          0UL
        } else {
          (raw.to_uint64() << amount_raw) & mask
        }
        let expected_right = if amount_raw >= width {
          0UL
        } else {
          raw.to_uint64() >> amount_raw
        }
        assert_eq(value.shift_left(amount).to_uint64(), expected_left)
        assert_eq(value.logical_shift_right(amount).to_uint64(), expected_right)
      }
    }
  }
}
