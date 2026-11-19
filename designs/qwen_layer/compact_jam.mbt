///|
// Each constant right shift folds its own discarded bits into bit zero.
// This avoids reconstructing the original operand through a second variable
// shifter. Any 11-bit distance >=32 reduces the entire 27-bit operand to sticky.
fn compact_jam27(
  b : @wire.ModuleBuilder,
  x : @wire.Signal,
  amount : @wire.Signal,
) -> @wire.Signal raise {
  assert_eq(x.signal_type(), @wire.uint(27))
  assert_eq(amount.signal_type(), @wire.uint(11))
  let mut value = x
  for i in 0..<5 {
    let distance = 1 << i
    let shifted = b.logical_shift_right(value, u(b, 5, distance.to_uint64()))
    let lost = b.not_equal(
      field(b, value, distance - 1, 0),
      u(b, distance, 0UL),
    )
    value = b.mux(
      bit(b, amount, i),
      b.bit_or(shifted, b.zero_extend(b.reinterpret(lost, @wire.uint(1)), 27)),
      value,
    )
  }
  let oversized = b.not_equal(field(b, amount, 10, 5), u(b, 6, 0UL))
  b.mux(
    oversized,
    b.zero_extend(
      b.reinterpret(b.not_equal(x, u(b, 27, 0UL)), @wire.uint(1)),
      27,
    ),
    value,
  )
}
