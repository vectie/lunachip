///|
/// Stable failures raised while constructing or combining bounded logic values.
pub(all) suberror LogicValueError {
  InvalidWidth(Int)
  WidthMismatch(left~ : Int, right~ : Int)
  BitIndexOutOfBounds(index~ : Int, width~ : Int)
  InvalidSlice(msb~ : Int, lsb~ : Int, width~ : Int)
  InvalidResize(from~ : Int, to~ : Int, operation~ : String)
  ResultWidthTooLarge(operation~ : String, width~ : Int)
  ExpectedOneBit(width~ : Int)
  ContainsUnknownBits
} derive(Debug, Eq)

///|
/// One four-state simulation bit in LunaWave's initial `0`, `1`, `X` subset.
///
/// High-impedance `Z` is deliberately absent until resolved nets are introduced.
pub(all) enum LogicBit {
  Zero
  One
  Unknown
} derive(Debug, Eq)

///|
/// A width-bounded logic value represented by value bits and a known-bit mask.
///
/// A set bit in `known_mask` means the corresponding bit in `value_bits` is
/// either zero or one. A clear bit means unknown. Bits outside `width` and
/// value bits marked unknown are canonicalized to zero.
pub struct LogicValue {
  priv width : Int
  priv value_bits : UInt64
  priv known_mask : UInt64
} derive(Debug, Eq)

///|
fn checked_width_mask(width : Int) -> UInt64 raise LogicValueError {
  if width < 1 || width > 64 {
    raise InvalidWidth(width)
  }
  if width == 64 {
    0xffffffffffffffffUL
  } else {
    (1UL << width) - 1UL
  }
}

///|
fn require_same_width(
  left : LogicValue,
  right : LogicValue,
) -> UInt64 raise LogicValueError {
  if left.width != right.width {
    raise WidthMismatch(left=left.width, right=right.width)
  }
  checked_width_mask(left.width)
}

///|
/// Constructs a canonical value from explicit value and known masks.
///
/// Inputs are always masked to `width`. Unknown value bits are cleared so two
/// semantically identical values have the same representation.
pub fn LogicValue::from_masks(
  width~ : Int,
  value_bits~ : UInt64,
  known_mask~ : UInt64,
) -> LogicValue raise LogicValueError {
  let mask = checked_width_mask(width)
  let known = known_mask & mask
  { width, value_bits: value_bits & known, known_mask: known }
}

///|
/// Constructs a fully-known value, truncating bits above `width`.
pub fn LogicValue::from_uint64(
  width~ : Int,
  value~ : UInt64,
) -> LogicValue raise LogicValueError {
  let mask = checked_width_mask(width)
  { width, value_bits: value & mask, known_mask: mask }
}

///|
/// Constructs a fully-known numeric zero.
pub fn LogicValue::zero(width~ : Int) -> LogicValue raise LogicValueError {
  LogicValue::from_uint64(width~, value=0UL)
}

///|
/// Constructs a fully-known numeric one.
pub fn LogicValue::one(width~ : Int) -> LogicValue raise LogicValueError {
  LogicValue::from_uint64(width~, value=1UL)
}

///|
/// Constructs a value whose in-width bits are all unknown.
pub fn LogicValue::unknown(width~ : Int) -> LogicValue raise LogicValueError {
  ignore(checked_width_mask(width))
  { width, value_bits: 0UL, known_mask: 0UL }
}

///|
pub fn LogicValue::width(self : LogicValue) -> Int {
  self.width
}

///|
/// Returns the mask containing one bit for every bit inside the value width.
pub fn LogicValue::width_mask(self : LogicValue) -> UInt64 {
  if self.width == 64 {
    0xffffffffffffffffUL
  } else {
    (1UL << self.width) - 1UL
  }
}

///|
/// Returns canonical value bits. Bits that are unknown are always zero here.
pub fn LogicValue::value_bits(self : LogicValue) -> UInt64 {
  self.value_bits
}

///|
pub fn LogicValue::known_mask(self : LogicValue) -> UInt64 {
  self.known_mask
}

///|
pub fn LogicValue::unknown_mask(self : LogicValue) -> UInt64 {
  self.width_mask() ^ self.known_mask
}

///|
pub fn LogicValue::is_fully_known(self : LogicValue) -> Bool {
  self.known_mask == self.width_mask()
}

///|
pub fn LogicValue::is_fully_unknown(self : LogicValue) -> Bool {
  self.known_mask == 0UL
}

///|
/// Returns the numeric representation when every bit is known.
pub fn LogicValue::to_uint64(self : LogicValue) -> UInt64 raise LogicValueError {
  if !self.is_fully_known() {
    raise ContainsUnknownBits
  }
  self.value_bits
}

///|
/// Reads one bit, with bit zero denoting the least-significant bit.
pub fn LogicValue::bit_at(
  self : LogicValue,
  index : Int,
) -> LogicBit raise LogicValueError {
  if index < 0 || index >= self.width {
    raise BitIndexOutOfBounds(index~, width=self.width)
  }
  let bit = 1UL << index
  if (self.known_mask & bit) == 0UL {
    Unknown
  } else if (self.value_bits & bit) == 0UL {
    Zero
  } else {
    One
  }
}

///|
/// Returns a deterministic most-significant-bit-first representation.
pub fn LogicValue::to_bit_string(self : LogicValue) -> String {
  let output = StringBuilder(size_hint=self.width)
  for offset in 0..<self.width {
    let index = self.width - offset - 1
    let bit = 1UL << index
    if (self.known_mask & bit) == 0UL {
      output.write_char('x')
    } else if (self.value_bits & bit) == 0UL {
      output.write_char('0')
    } else {
      output.write_char('1')
    }
  }
  output.to_string()
}

///|
/// Four-state bitwise negation. Unknown bits remain unknown.
pub fn LogicValue::bit_not(self : LogicValue) -> LogicValue {
  {
    width: self.width,
    value_bits: (self.value_bits ^ self.width_mask()) & self.known_mask,
    known_mask: self.known_mask,
  }
}

///|
/// Four-state bitwise conjunction.
///
/// A known zero dominates an unknown operand; a one is known only when both
/// operands are known one.
pub fn LogicValue::bit_and(
  self : LogicValue,
  other : LogicValue,
) -> LogicValue raise LogicValueError {
  let mask = require_same_width(self, other)
  let self_zero = self.known_mask & (self.value_bits ^ mask)
  let other_zero = other.known_mask & (other.value_bits ^ mask)
  let ones = self.known_mask &
    self.value_bits &
    other.known_mask &
    other.value_bits
  let known = self_zero | other_zero | ones
  { width: self.width, value_bits: ones, known_mask: known }
}

///|
/// Four-state bitwise disjunction.
///
/// A known one dominates an unknown operand; a zero is known only when both
/// operands are known zero.
pub fn LogicValue::bit_or(
  self : LogicValue,
  other : LogicValue,
) -> LogicValue raise LogicValueError {
  let mask = require_same_width(self, other)
  let self_one = self.known_mask & self.value_bits
  let other_one = other.known_mask & other.value_bits
  let self_zero = self.known_mask & (self.value_bits ^ mask)
  let other_zero = other.known_mask & (other.value_bits ^ mask)
  let ones = self_one | other_one
  let known = ones | (self_zero & other_zero)
  { width: self.width, value_bits: ones, known_mask: known }
}

///|
/// Four-state bitwise exclusive-or. A result bit is known only when both input
/// bits are known.
pub fn LogicValue::bit_xor(
  self : LogicValue,
  other : LogicValue,
) -> LogicValue raise LogicValueError {
  ignore(require_same_width(self, other))
  let known = self.known_mask & other.known_mask
  {
    width: self.width,
    value_bits: (self.value_bits ^ other.value_bits) & known,
    known_mask: known,
  }
}

///|
/// Performs exact four-state equality after checking operand widths.
pub fn LogicValue::case_equal(
  self : LogicValue,
  other : LogicValue,
) -> Bool raise LogicValueError {
  ignore(require_same_width(self, other))
  self.value_bits == other.value_bits && self.known_mask == other.known_mask
}
