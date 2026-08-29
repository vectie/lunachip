///|
test "exact add and subtract preserve determined bits" {
  let one = @semantics.LogicValue::one(width=4)
  let unknown = @semantics.LogicValue::unknown(width=4)
  inspect(one.add(one).to_bit_string(), content="0010")
  inspect(one.sub(one).to_bit_string(), content="0000")
  inspect(unknown.add(one).to_bit_string(), content="xxxx")
}

///|
test "multiplication is exact for known values and zero dominates X" {
  let three = @semantics.LogicValue::from_uint64(width=4, value=3UL)
  let five = @semantics.LogicValue::from_uint64(width=4, value=5UL)
  inspect(three.mul_low(five).to_uint64(), content="15")
  inspect(three.mul_full(five).to_uint64(), content="15")
  let minus_two = @semantics.LogicValue::from_uint64(width=4, value=0xeUL)
  inspect(minus_two.mul_full_signed(three).to_uint64(), content="250")
  inspect(
    @semantics.LogicValue::zero(width=4)
    .mul_low(@semantics.LogicValue::unknown(width=4))
    .to_bit_string(),
    content="0000",
  )
}

///|
test "unknown mux select retains bits equal in both branches" {
  let select = @semantics.LogicValue::unknown(width=1)
  let left = @semantics.LogicValue::from_uint64(width=4, value=0xaUL)
  let right = @semantics.LogicValue::from_uint64(width=4, value=0xbUL)
  inspect(select.mux(left, right).to_bit_string(), content="101x")
}

///|
test "comparisons retain three-state uncertainty" {
  let two = @semantics.LogicValue::from_uint64(width=4, value=2UL)
  let three = @semantics.LogicValue::from_uint64(width=4, value=3UL)
  inspect(two.less_than_unsigned(three).to_bit_string(), content="1")
  inspect(three.less_than_unsigned(two).to_bit_string(), content="0")
  inspect(two.equal_value(two).to_bit_string(), content="1")
  inspect(
    two.equal_value(@semantics.LogicValue::unknown(width=4)).to_bit_string(),
    content="x",
  )
}

///|
test "shifts, slices, concatenation, and resize are explicit" {
  let value = @semantics.LogicValue::from_uint64(width=4, value=0xbUL)
  let one = @semantics.LogicValue::one(width=2)
  inspect(value.shift_left(one).to_bit_string(), content="0110")
  inspect(value.logical_shift_right(one).to_bit_string(), content="0101")
  inspect(value.arithmetic_shift_right(one).to_bit_string(), content="1101")
  inspect(value.slice(msb=2, lsb=1).to_bit_string(), content="01")
  inspect(value.concat(one).to_bit_string(), content="101101")
  inspect(value.zero_extend(6).to_bit_string(), content="001011")
  inspect(value.sign_extend(6).to_bit_string(), content="111011")
  inspect(value.truncate(2).to_bit_string(), content="11")
}
