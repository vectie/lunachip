///|
test "matrix oracle has independent rectangular row-major results" {
  assert_eq(
    @flux_tile.matmul_int8_oracle(
      [1, 2, 3, -4, 5, -6],
      [7, 8, -9, 10, 11, -12],
      rows=2,
      columns=2,
      reduction=3,
    ),
    [22, -8, -139, 90],
  )
}

///|
test "matrix oracle preserves signed INT8 extremes" {
  assert_eq(
    @flux_tile.matmul_int8_oracle(
      [-128, 127],
      [-128, 127],
      rows=2,
      columns=2,
      reduction=1,
    ),
    [16384, -16256, -16256, 16129],
  )
  assert_eq(
    @flux_tile.matmul_int8_oracle(
      Array::make(4096, -128),
      Array::make(4096, -128),
      rows=1,
      columns=1,
      reduction=4096,
    ),
    [67108864],
  )
}

///|
test "matrix oracle preserves identity and ignores no padded values" {
  let identity = Array::make(64, 0)
  let values = Array::make(64, 0)
  for row in 0..<8 {
    identity[row * 8 + row] = 1
    for column in 0..<8 {
      values[row * 8 + column] = row * 8 + column - 32
    }
  }
  assert_eq(
    @flux_tile.matmul_int8_oracle(
      identity,
      values,
      rows=8,
      columns=8,
      reduction=8,
    ),
    values,
  )
  assert_eq(
    @flux_tile.matmul_int8_oracle(
      values,
      identity,
      rows=8,
      columns=8,
      reduction=8,
    ),
    values,
  )
}

///|
test "matrix oracle rejects every dimension outside its provisional bounds" {
  for
    (rows, columns, reduction, expected_name, expected_value, maximum) in [
      (0, 1, 1, "rows", 0, 8),
      (9, 1, 1, "rows", 9, 8),
      (1, -1, 1, "columns", -1, 8),
      (1, 9, 1, "columns", 9, 8),
      (1, 1, 0, "reduction", 0, 4096),
      (1, 1, 4097, "reduction", 4097, 4096),
    ] {
    try
      @flux_tile.matmul_int8_oracle([], [], rows~, columns~, reduction~)
    catch {
      InvalidDimension(name~, value~, maximum=actual_max) => {
        assert_eq(name, expected_name)
        assert_eq(value, expected_value)
        assert_eq(actual_max, maximum)
      }
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("invalid dimensions accepted")
    }
  }
}

///|
test "matrix oracle rejects mismatched lengths and out-of-range INT8" {
  for
    (left, right, operand, expected, actual) in [
      ([1], [2, 3], "left", 2, 1),
      ([1, 2], [3], "right", 2, 1),
      ([1, 2, 3], [4, 5], "left", 2, 3),
    ] {
    try
      @flux_tile.matmul_int8_oracle(left, right, rows=1, columns=1, reduction=2)
    catch {
      InvalidLength(
        operand=actual_operand,
        expected=actual_expected,
        actual=actual_length
      ) => {
        assert_eq(actual_operand, operand)
        assert_eq(actual_expected, expected)
        assert_eq(actual_length, actual)
      }
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("invalid length accepted")
    }
  }
  for
    (left, right, operand, index, value) in [
      ([-129, 1], [1, 1], "left", 0, -129),
      ([1, 1], [1, 128], "right", 1, 128),
    ] {
    try
      @flux_tile.matmul_int8_oracle(left, right, rows=1, columns=1, reduction=2)
    catch {
      InvalidInt8(
        operand=actual_operand,
        index=actual_index,
        value=actual_value
      ) => {
        assert_eq(actual_operand, operand)
        assert_eq(actual_index, index)
        assert_eq(actual_value, value)
      }
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("invalid INT8 accepted")
    }
  }
}
