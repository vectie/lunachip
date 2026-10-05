///|
/// Invalid input to the independent, row-major FluxTile matrix oracle.
pub(all) suberror MatrixOracleError {
  InvalidDimension(name~ : String, value~ : Int, maximum~ : Int)
  InvalidLength(operand~ : String, expected~ : Int, actual~ : Int)
  InvalidInt8(operand~ : String, index~ : Int, value~ : Int)
} derive(Debug, Eq)

///|
fn validate_oracle_operand(
  operand : String,
  values : Array[Int],
  expected : Int,
) -> Unit raise MatrixOracleError {
  if values.length() != expected {
    raise InvalidLength(operand~, expected~, actual=values.length())
  }
  for index in 0..<values.length() {
    let value = values[index]
    if value < -128 || value > 127 {
      raise InvalidInt8(operand~, index~, value~)
    }
  }
}

///|
/// Computes `left × right` independently of the hardware graph and simulator.
///
/// Both operands and the result are row-major. `left` has `rows × reduction`
/// elements and `right` has `reduction × columns` elements. Rows and columns
/// are in `1..=8`; the provisional reduction limit is `1..=4096`. Each operand
/// element is a signed INT8 value, and each result starts at zero.
///
/// The accumulator contract is signed INT32 with modular arithmetic. This
/// reference uses wider host arithmetic, then explicitly takes the low 32 bits.
/// With the current bounds, the exact magnitude is at most `4096 × 16384`, so
/// neither host arithmetic nor the INT32 result overflows. The implementation
/// deliberately does not reuse LunaWave operations or systolic scheduling.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @flux_tile.matmul_int8_oracle(
///       [2, -3],
///       [4, 5],
///       rows=1,
///       columns=1,
///       reduction=2,
///     ),
///     [-7],
///   )
/// }
/// ```
pub fn matmul_int8_oracle(
  left : Array[Int],
  right : Array[Int],
  rows~ : Int,
  columns~ : Int,
  reduction~ : Int,
) -> Array[Int] raise MatrixOracleError {
  for
    (name, value, maximum) in [
      ("rows", rows, 8),
      ("columns", columns, 8),
      ("reduction", reduction, 4096),
    ] {
    if value < 1 || value > maximum {
      raise InvalidDimension(name~, value~, maximum~)
    }
  }
  validate_oracle_operand("left", left, rows * reduction)
  validate_oracle_operand("right", right, reduction * columns)
  let result = Array::make(rows * columns, 0)
  for row in 0..<rows {
    for column in 0..<columns {
      let mut sum = 0L
      for k in 0..<reduction {
        sum += left[row * reduction + k].to_int64() *
          right[k * columns + column].to_int64()
      }
      result[row * columns + column] = sum.to_int()
    }
  }
  result
}

///|
pub extend MatrixOracleError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MatrixOracleError with Eq::{not_equal, equal}
