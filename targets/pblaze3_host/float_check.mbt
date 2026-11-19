///|
pub(all) struct FloatComparison {
  words : Int32
  exact_words : Int32
  maximum_absolute_error : Double
  maximum_relative_error_above_floor : Double
} derive(Debug, ToJson)

///|
pub extend FloatComparison with @debug.Debug::{to_repr}

///|
pub extend FloatComparison with ToJson::{to_json}

///|
fn float_word(bytes : Bytes, index : Int32) -> UInt32 {
  let p = index * 4
  bytes[p].to_uint() |
  (bytes[p + 1].to_uint() << 8) |
  (bytes[p + 2].to_uint() << 16) |
  (bytes[p + 3].to_uint() << 24)
}

///|
/// Existing PRX100 CPU tolerance, unchanged: 1e-4 + 1e-4 * abs(reference).
/// NaN and infinities are rejected on both sides before arithmetic.
pub fn compare_fp32(
  expected : Bytes,
  actual : Bytes,
) -> FloatComparison raise HostError {
  check_chunk(expected.length())
  if expected.length() == 0 || expected.length() % 4 != 0 {
    raise InvalidChunk(length=expected.length())
  }
  if expected.length() != actual.length() {
    raise InvalidIoCount(
      operation="compare-fp32",
      actual=actual.length(),
      requested=expected.length(),
    )
  }
  let mut exact_words = 0
  let mut maximum_absolute_error = 0.0
  let mut maximum_relative_error_above_floor = 0.0
  let words = expected.length() / 4
  for index in 0..<words {
    let expected_bits = float_word(expected, index)
    let actual_bits = float_word(actual, index)
    if (expected_bits & 0x7f800000) == 0x7f800000 {
      raise NonfiniteFloat(index~, reference=true)
    }
    if (actual_bits & 0x7f800000) == 0x7f800000 {
      raise NonfiniteFloat(index~, reference=false)
    }
    let reference = Float::reinterpret_from_uint(expected_bits).to_double()
    let value = Float::reinterpret_from_uint(actual_bits).to_double()
    let error = (reference - value).abs()
    if error > 0.0001 + 0.0001 * reference.abs() {
      raise FloatMismatch(index~, expected=reference, actual=value)
    }
    maximum_absolute_error = maximum_absolute_error.max(error)
    maximum_relative_error_above_floor = maximum_relative_error_above_floor.max(
      error / reference.abs().max(0.000001),
    )
    if expected_bits == actual_bits {
      exact_words += 1
    }
  }
  {
    words,
    exact_words,
    maximum_absolute_error,
    maximum_relative_error_above_floor,
  }
}
