///|
fn bit_possibilities(bit : LogicBit) -> Int32 {
  match bit {
    Zero => 1
    One => 2
    Unknown => 3
  }
}

///|
fn LogicValue::binary_arithmetic(
  self : LogicValue,
  other : LogicValue,
  subtract : Bool,
) -> LogicValue raise LogicValueError {
  ignore(require_same_width(self, other))
  let mut result_bits = 0UL
  let mut known_mask = 0UL
  let mut carry_or_borrow = 1
  for bit_index in 0..<self.width {
    let left_values = bit_possibilities(self.bit_at(bit_index))
    let right_values = bit_possibilities(other.bit_at(bit_index))
    let mut result_values = 0
    let mut next_state = 0
    for left_bit in 0..<2 {
      if (left_values & (1 << left_bit)) != 0 {
        for right_bit in 0..<2 {
          if (right_values & (1 << right_bit)) != 0 {
            for state_bit in 0..<2 {
              if (carry_or_borrow & (1 << state_bit)) != 0 {
                if subtract {
                  let total = left_bit - right_bit - state_bit
                  let result_bit = if total < 0 { total + 2 } else { total }
                  result_values = result_values | (1 << result_bit)
                  let borrow = if total < 0 { 1 } else { 0 }
                  next_state = next_state | (1 << borrow)
                } else {
                  let total = left_bit + right_bit + state_bit
                  result_values = result_values | (1 << (total & 1))
                  next_state = next_state | (1 << (total >> 1))
                }
              }
            }
          }
        }
      }
    }
    let bit_mask = 1UL << bit_index
    if result_values == 1 {
      known_mask = known_mask | bit_mask
    } else if result_values == 2 {
      known_mask = known_mask | bit_mask
      result_bits = result_bits | bit_mask
    }
    carry_or_borrow = next_state
  }
  LogicValue::from_masks(width=self.width, value_bits=result_bits, known_mask~)
}

///|
/// Exact fixed-width modular addition over `0`, `1`, and `X` bits.
pub fn LogicValue::add(
  self : LogicValue,
  other : LogicValue,
) -> LogicValue raise LogicValueError {
  self.binary_arithmetic(other, false)
}

///|
/// Exact fixed-width modular subtraction over `0`, `1`, and `X` bits.
pub fn LogicValue::sub(
  self : LogicValue,
  other : LogicValue,
) -> LogicValue raise LogicValueError {
  self.binary_arithmetic(other, true)
}

///|
/// Return the low fixed-width product.
///
/// Fully known inputs are exact. A known zero dominates unknown input bits;
/// all other partially unknown products conservatively become unknown.
pub fn LogicValue::mul_low(
  self : LogicValue,
  other : LogicValue,
) -> LogicValue raise LogicValueError {
  ignore(require_same_width(self, other))
  if (self.is_fully_known() && self.value_bits == 0UL) ||
    (other.is_fully_known() && other.value_bits == 0UL) {
    return LogicValue::zero(width=self.width)
  }
  if !self.is_fully_known() || !other.is_fully_known() {
    return LogicValue::unknown(width=self.width)
  }
  LogicValue::from_uint64(
    width=self.width,
    value=self.value_bits * other.value_bits,
  )
}

///|
/// Return the full-width unsigned bit product of equal-width operands.
pub fn LogicValue::mul_full(
  self : LogicValue,
  other : LogicValue,
) -> LogicValue raise LogicValueError {
  ignore(require_same_width(self, other))
  let result_width = self.width * 2
  if result_width > 64 {
    raise ResultWidthTooLarge(operation="mul_full", width=result_width)
  }
  if (self.is_fully_known() && self.value_bits == 0UL) ||
    (other.is_fully_known() && other.value_bits == 0UL) {
    return LogicValue::zero(width=result_width)
  }
  if !self.is_fully_known() || !other.is_fully_known() {
    return LogicValue::unknown(width=result_width)
  }
  LogicValue::from_uint64(
    width=result_width,
    value=self.value_bits * other.value_bits,
  )
}

///|
fn LogicValue::signed_int64(self : LogicValue) -> Int64 {
  let extended = if self.width == 64 ||
    (self.value_bits & (1UL << (self.width - 1))) == 0UL {
    self.value_bits
  } else {
    self.value_bits | (self.width_mask() ^ 0xffffffffffffffffUL)
  }
  extended.reinterpret_as_int64()
}

///|
/// Return the full-width two's-complement product of equal-width operands.
pub fn LogicValue::mul_full_signed(
  self : LogicValue,
  other : LogicValue,
) -> LogicValue raise LogicValueError {
  ignore(require_same_width(self, other))
  let result_width = self.width * 2
  if result_width > 64 {
    raise ResultWidthTooLarge(operation="mul_full_signed", width=result_width)
  }
  if (self.is_fully_known() && self.value_bits == 0UL) ||
    (other.is_fully_known() && other.value_bits == 0UL) {
    return LogicValue::zero(width=result_width)
  }
  if !self.is_fully_known() || !other.is_fully_known() {
    return LogicValue::unknown(width=result_width)
  }
  LogicValue::from_uint64(
    width=result_width,
    value=(self.signed_int64() * other.signed_int64()).reinterpret_as_uint64(),
  )
}
