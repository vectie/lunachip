///|
fn exercise_wide_matrix(
  b : Bench,
  rows : Int32,
  columns~ : Int32 = 128,
  base~ : UInt64 = 0x40000f80UL,
  cancellation~ : Bool = false,
) -> Unit raise {
  b.reset()
  let destination = columns.max(1024)
  let levels = if rows == 64 { 4 } else { 5 }
  fn activation(col : Int32) -> Float {
    if cancellation {
      [16777216.0F, 1.0F, -16777216.0F, -0.25F, 0.5F][col % 5]
    } else {
      Float::from_int(1 + col % 3)
    }
  }
  for col in 0..<columns {
    let a = activation(col)
    b.write(
      0x40000UL + col.to_uint64() * 4UL,
      a.reinterpret_as_uint().to_uint64(),
    )
  }
  for r in 0..<rows {
    for pair in 0..<(columns / 2) {
      fn bf(col : Int32) -> UInt32 {
        Float::from_int((r + 1) * (1 + col % levels)).reinterpret_as_uint() >>
        16
      }
      b.memory[base + (r * (columns / 2) + pair).to_uint64() * 4UL] = (bf(
        pair * 2,
      ) |
      (bf(pair * 2 + 1) << 16)).to_uint64()
    }
  }
  b.upload(
    [
      ..row(
        4U,
        destination.reinterpret_as_uint(),
        0U,
        rows.reinterpret_as_uint(),
        k=columns.reinterpret_as_uint(),
        ddr=base.to_uint(),
      ),
      ..row(0U, 0U, 0U, 0U),
    ],
  )
  b.write(0x10UL, 1UL)
  b.complete(polls=500 + columns * ((rows + 15) / 16))
  assert_eq(b.read(0x30UL), rows.to_uint64() * columns.to_uint64())
  assert_eq(b.read(0x34UL), rows.to_uint64() * columns.to_uint64() / 2UL)
  for r in 0..<rows {
    let mut sum = 0.0F
    for col in 0..<columns {
      let original = Float::from_int((r + 1) * (1 + col % levels))
      let stored = Float::reinterpret_from_uint(
        original.reinterpret_as_uint() & 0xffff0000U,
      )
      sum += activation(col) * stored
    }
    assert_eq(
      b.read(0x40000UL + (destination + r).to_uint64() * 4UL),
      sum.reinterpret_as_uint().to_uint64(),
    )
  }
}
