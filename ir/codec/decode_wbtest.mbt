///|
test "codec integer parsing preserves signed and unsigned limits" {
  assert_eq(parse_int(1, "node", "2147483647"), 2147483647)
  assert_eq(parse_int(1, "node", "-2147483648"), -2147483647 - 1)
  assert_eq(
    parse_uint64(2, "constant", "18446744073709551615"),
    0xFFFFFFFFFFFFFFFFUL,
  )
  assert_eq(
    parse_int64(3, "signed parameter", "9223372036854775807"),
    9223372036854775807L,
  )
  assert_eq(
    parse_int64(3, "signed parameter", "-9223372036854775808"),
    -9223372036854775807L - 1L,
  )
  try parse_int(4, "node", "2147483648") catch {
    InvalidInteger(line~, field~, value~) => {
      assert_eq(line, 4)
      assert_eq(field, "node")
      assert_eq(value, "2147483648")
    }
    error => fail("unexpected integer error: \{Repr(error)}")
  } noraise {
    _ => fail("expected signed overflow rejection")
  }
  try parse_uint64(5, "constant", "18446744073709551616") catch {
    InvalidInteger(..) => ()
    error => fail("unexpected unsigned error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unsigned overflow rejection")
  }
}
