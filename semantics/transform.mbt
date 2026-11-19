///|
/// Hardware equality: known false on any known mismatch, known true only when
/// every bit is known and equal, otherwise unknown.
pub fn LogicValue::equal_value(
  self : LogicValue,
  other : LogicValue,
) -> LogicValue raise LogicValueError {
  let mask = require_same_width(self, other)
  let known_mismatches = self.known_mask &
    other.known_mask &
    (self.value_bits ^ other.value_bits)
  if known_mismatches != 0UL {
    LogicValue::zero(width=1)
  } else if self.known_mask == mask && other.known_mask == mask {
    LogicValue::one(width=1)
  } else {
    LogicValue::unknown(width=1)
  }
}

///|
/// Select one branch with conservative unknown-select merging.
pub fn LogicValue::mux(
  self : LogicValue,
  when_true : LogicValue,
  when_false : LogicValue,
) -> LogicValue raise LogicValueError {
  if self.width != 1 {
    raise ExpectedOneBit(width=self.width)
  }
  ignore(require_same_width(when_true, when_false))
  match self.bit_at(0) {
    One => when_true
    Zero => when_false
    Unknown => {
      let agreeing = when_true.known_mask &
        when_false.known_mask &
        (when_true.value_bits ^ when_false.value_bits ^ when_true.width_mask())
      LogicValue::from_masks(
        width=when_true.width,
        value_bits=when_true.value_bits,
        known_mask=agreeing,
      )
    }
  }
}

///|
pub fn LogicValue::less_than_unsigned(
  self : LogicValue,
  other : LogicValue,
) -> LogicValue raise LogicValueError {
  ignore(require_same_width(self, other))
  for offset in 0..<self.width {
    let index = self.width - offset - 1
    match (self.bit_at(index), other.bit_at(index)) {
      (Zero, One) => return LogicValue::one(width=1)
      (One, Zero) => return LogicValue::zero(width=1)
      (Unknown, _) | (_, Unknown) => return LogicValue::unknown(width=1)
      _ => ()
    }
  }
  LogicValue::zero(width=1)
}

///|
pub fn LogicValue::less_than_signed(
  self : LogicValue,
  other : LogicValue,
) -> LogicValue raise LogicValueError {
  ignore(require_same_width(self, other))
  let sign_index = self.width - 1
  match (self.bit_at(sign_index), other.bit_at(sign_index)) {
    (One, Zero) => LogicValue::one(width=1)
    (Zero, One) => LogicValue::zero(width=1)
    (Unknown, _) | (_, Unknown) => LogicValue::unknown(width=1)
    _ => self.less_than_unsigned(other)
  }
}

///|
fn LogicValue::checked_shift_amount(
  self : LogicValue,
  amount : LogicValue,
) -> Int32? raise LogicValueError {
  if !amount.is_fully_known() {
    None
  } else {
    let raw = amount.to_uint64()
    if raw >= self.width.to_uint64() {
      Some(self.width)
    } else {
      Some(raw.to_int())
    }
  }
}

///|
pub fn LogicValue::shift_left(
  self : LogicValue,
  amount : LogicValue,
) -> LogicValue raise LogicValueError {
  match self.checked_shift_amount(amount) {
    None => LogicValue::unknown(width=self.width)
    Some(shift) if shift >= self.width => LogicValue::zero(width=self.width)
    Some(shift) => {
      let fill = if shift == 0 { 0UL } else { (1UL << shift) - 1UL }
      LogicValue::from_masks(
        width=self.width,
        value_bits=self.value_bits << shift,
        known_mask=(self.known_mask << shift) | fill,
      )
    }
  }
}

///|
pub fn LogicValue::logical_shift_right(
  self : LogicValue,
  amount : LogicValue,
) -> LogicValue raise LogicValueError {
  match self.checked_shift_amount(amount) {
    None => LogicValue::unknown(width=self.width)
    Some(shift) if shift >= self.width => LogicValue::zero(width=self.width)
    Some(shift) => {
      let upper_fill = if shift == 0 {
        0UL
      } else {
        self.width_mask() ^ ((1UL << (self.width - shift)) - 1UL)
      }
      LogicValue::from_masks(
        width=self.width,
        value_bits=self.value_bits >> shift,
        known_mask=(self.known_mask >> shift) | upper_fill,
      )
    }
  }
}

///|
pub fn LogicValue::arithmetic_shift_right(
  self : LogicValue,
  amount : LogicValue,
) -> LogicValue raise LogicValueError {
  match self.checked_shift_amount(amount) {
    None => LogicValue::unknown(width=self.width)
    Some(shift) => {
      let sign = self.bit_at(self.width - 1)
      if shift >= self.width {
        match sign {
          Zero => LogicValue::zero(width=self.width)
          One =>
            LogicValue::from_uint64(width=self.width, value=self.width_mask())
          Unknown => LogicValue::unknown(width=self.width)
        }
      } else {
        let upper_fill = if shift == 0 {
          0UL
        } else {
          self.width_mask() ^ ((1UL << (self.width - shift)) - 1UL)
        }
        let fill_value = if sign is One { upper_fill } else { 0UL }
        let fill_known = if sign is Unknown { 0UL } else { upper_fill }
        LogicValue::from_masks(
          width=self.width,
          value_bits=(self.value_bits >> shift) | fill_value,
          known_mask=(self.known_mask >> shift) | fill_known,
        )
      }
    }
  }
}

///|
pub fn LogicValue::slice(
  self : LogicValue,
  msb~ : Int32,
  lsb~ : Int32,
) -> LogicValue raise LogicValueError {
  if lsb < 0 || msb < lsb || msb >= self.width {
    raise InvalidSlice(msb~, lsb~, width=self.width)
  }
  let result_width = msb - lsb + 1
  LogicValue::from_masks(
    width=result_width,
    value_bits=self.value_bits >> lsb,
    known_mask=self.known_mask >> lsb,
  )
}

///|
pub fn LogicValue::concat(
  self : LogicValue,
  least_significant : LogicValue,
) -> LogicValue raise LogicValueError {
  let result_width = self.width + least_significant.width
  if result_width > 64 {
    raise ResultWidthTooLarge(operation="concat", width=result_width)
  }
  LogicValue::from_masks(
    width=result_width,
    value_bits=(self.value_bits << least_significant.width) |
      least_significant.value_bits,
    known_mask=(self.known_mask << least_significant.width) |
      least_significant.known_mask,
  )
}

///|
pub fn LogicValue::zero_extend(
  self : LogicValue,
  new_width : Int32,
) -> LogicValue raise LogicValueError {
  if new_width < self.width {
    raise InvalidResize(from=self.width, to=new_width, operation="zero_extend")
  }
  let result_mask = checked_width_mask(new_width)
  let upper_known = result_mask ^ self.width_mask()
  LogicValue::from_masks(
    width=new_width,
    value_bits=self.value_bits,
    known_mask=self.known_mask | upper_known,
  )
}

///|
pub fn LogicValue::sign_extend(
  self : LogicValue,
  new_width : Int32,
) -> LogicValue raise LogicValueError {
  if new_width < self.width {
    raise InvalidResize(from=self.width, to=new_width, operation="sign_extend")
  }
  let result_mask = checked_width_mask(new_width)
  let upper = result_mask ^ self.width_mask()
  match self.bit_at(self.width - 1) {
    Zero =>
      LogicValue::from_masks(
        width=new_width,
        value_bits=self.value_bits,
        known_mask=self.known_mask | upper,
      )
    One =>
      LogicValue::from_masks(
        width=new_width,
        value_bits=self.value_bits | upper,
        known_mask=self.known_mask | upper,
      )
    Unknown =>
      LogicValue::from_masks(
        width=new_width,
        value_bits=self.value_bits,
        known_mask=self.known_mask,
      )
  }
}

///|
pub fn LogicValue::truncate(
  self : LogicValue,
  new_width : Int32,
) -> LogicValue raise LogicValueError {
  if new_width > self.width {
    raise InvalidResize(from=self.width, to=new_width, operation="truncate")
  }
  LogicValue::from_masks(
    width=new_width,
    value_bits=self.value_bits,
    known_mask=self.known_mask,
  )
}
