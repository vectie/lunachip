///|
// Shared ordered microprograms: extraction preserves the legacy construction order.
fn unary_programs() -> Array[
  Array[(Int32, Int32, Int32, Int32, UInt32, UInt32, Bool)],
] {
  let programs : Array[
    Array[(Int32, Int32, Int32, Int32, UInt32, UInt32, Bool)],
  ] = []
  let reciprocal : Array[(Int32, Int32, Int32, Int32, UInt32, UInt32, Bool)] = []
  for _ in 0..<4 {
    reciprocal.push((2, 0, 0, 1, 0U, 0U, false))
    reciprocal.push((2, 1, -1, 2, 0x40000000U, 0U, true))
    reciprocal.push((1, 0, 1, 2, 0U, 0U, false))
  }
  programs.push(reciprocal)
  let rsqrt : Array[(Int32, Int32, Int32, Int32, UInt32, UInt32, Bool)] = [
    (2, 0, 0, -1, 0U, 0x3f000000U, false),
  ]
  for _ in 0..<4 {
    rsqrt.push((3, 0, 1, 1, 0U, 0U, false))
    rsqrt.push((3, 0, 2, 3, 0U, 0U, false))
    rsqrt.push((3, 1, -1, 3, 0x3fc00000U, 0U, true))
    rsqrt.push((1, 0, 1, 3, 0U, 0U, false))
  }
  programs.push(rsqrt)
  let exponential : Array[(Int32, Int32, Int32, Int32, UInt32, UInt32, Bool)] = [
    (2, 0, 0, -1, 0U, 0x3c800000U, false),
  ]
  for
    c in [
      1.0 / 5040.0,
      1.0 / 720.0,
      1.0 / 120.0,
      1.0 / 24.0,
      1.0 / 6.0,
      0.5,
      1.0,
      1.0,
    ] {
    exponential.push((3, 0, 1, 2, 0U, 0U, false))
    exponential.push(
      (1, 1, 3, -1, 0U, Float::from_double(c).reinterpret_as_uint(), false),
    )
  }
  for _ in 0..<6 {
    exponential.push((1, 0, 1, 1, 0U, 0U, false))
  }
  programs.push(exponential)
  programs
}
