///|
test "low and highest2GiB windows reject aliases and faults, preserve terminal state" {
  for high in [false, true] {
    let b = bench(high)
    exercise(b)
    assert_eq(b.cases.length(), 15)
  }
}
