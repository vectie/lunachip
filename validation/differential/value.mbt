///|
/// A normalized digital symbol. Differential validation intentionally knows
/// only representation, never the operation semantics that produced a value.
pub(all) enum LogicBit {
  Zero
  One
  Unknown
} derive(Debug, Eq)

///|
pub fn LogicBit::to_text(self : LogicBit) -> String {
  match self {
    Zero => "0"
    One => "1"
    Unknown => "X"
  }
}

///|
/// A width-bearing, MSB-first canonical `0/1/X` value.
pub struct NormalizedValue {
  canonical : String
} derive(Debug, Eq)

///|
/// Parse an MSB-first value. Lowercase `x` is accepted and normalized to `X`.
pub fn NormalizedValue::parse(
  text : String,
) -> NormalizedValue raise DifferentialError {
  if text.length() == 0 {
    raise EmptyValue
  }
  let output = StringBuilder(size_hint=text.length())
  for index, symbol in text {
    match symbol {
      '0' => output.write_char('0')
      '1' => output.write_char('1')
      'X' | 'x' => output.write_char('X')
      _ => raise InvalidValueSymbol(index~, symbol~)
    }
  }
  { canonical: output.to_string(), }
}

///|
/// Normalize separate MSB-first bit and known planes.
///
/// An unknown position is canonicalized to `X` regardless of its bit-plane
/// payload, preventing backend-specific garbage in unknown bits from creating
/// false mismatches.
pub fn NormalizedValue::from_planes(
  bits : String,
  known : String,
) -> NormalizedValue raise DifferentialError {
  if bits.length() == 0 {
    raise EmptyValue
  }
  if bits.length() != known.length() {
    raise PlaneWidthMismatch(bits=bits.length(), known=known.length())
  }
  let output = StringBuilder(size_hint=bits.length())
  for index in 0..<bits.length() {
    let bit = bits[index]
    let known_bit = known[index]
    if bit != '0' && bit != '1' {
      raise InvalidPlaneSymbol(plane="bits", index~, symbol=bit)
    }
    if known_bit != '0' && known_bit != '1' {
      raise InvalidPlaneSymbol(plane="known", index~, symbol=known_bit)
    }
    if known_bit == '0' {
      output.write_char('X')
    } else if bit == '0' {
      output.write_char('0')
    } else {
      output.write_char('1')
    }
  }
  { canonical: output.to_string(), }
}

///|
pub fn NormalizedValue::width(self : NormalizedValue) -> Int {
  self.canonical.length()
}

///|
pub fn NormalizedValue::to_text(self : NormalizedValue) -> String {
  self.canonical
}

///|
/// Canonical MSB-first value plane. Unknown payload bits are always zero.
pub fn NormalizedValue::value_bits(self : NormalizedValue) -> String {
  let output = StringBuilder(size_hint=self.canonical.length())
  for symbol in self.canonical {
    output.write_char(if symbol == '1' { '1' } else { '0' })
  }
  output.to_string()
}

///|
/// Canonical MSB-first known plane (`1` known, `0` unknown).
pub fn NormalizedValue::known_mask(self : NormalizedValue) -> String {
  let output = StringBuilder(size_hint=self.canonical.length())
  for symbol in self.canonical {
    output.write_char(if symbol == 'X' { '0' } else { '1' })
  }
  output.to_string()
}

///|
/// Read a bit by its MSB-first index.
pub fn NormalizedValue::bit_from_msb(
  self : NormalizedValue,
  index : Int,
) -> LogicBit? {
  if index < 0 || index >= self.canonical.length() {
    return None
  }
  match self.canonical[index] {
    '0' => Some(Zero)
    '1' => Some(One)
    _ => Some(Unknown)
  }
}

///|
/// The stable first reason two normalized values differ.
pub(all) enum ValueDifference {
  Width(expected~ : Int, actual~ : Int)
  Bit(index_from_msb~ : Int, expected~ : LogicBit, actual~ : LogicBit)
} derive(Debug, Eq)

///|
pub fn NormalizedValue::difference(
  expected : NormalizedValue,
  actual : NormalizedValue,
) -> ValueDifference? {
  if expected.width() != actual.width() {
    return Some(Width(expected=expected.width(), actual=actual.width()))
  }
  for index in 0..<expected.width() {
    let expected_bit = expected.bit_from_msb(index).unwrap()
    let actual_bit = actual.bit_from_msb(index).unwrap()
    if expected_bit != actual_bit {
      return Some(
        Bit(index_from_msb=index, expected=expected_bit, actual=actual_bit),
      )
    }
  }
  None
}

///|
pub extend LogicBit with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend LogicBit with Eq::{not_equal, equal}

///|
pub extend NormalizedValue with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend NormalizedValue with Eq::{not_equal, equal}

///|
pub extend ValueDifference with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ValueDifference with Eq::{not_equal, equal}
