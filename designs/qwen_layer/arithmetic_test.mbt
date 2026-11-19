///|
test "new full FP32 multiplication agrees on boundaries and seeded raw bits" {
  let s = @sim.Simulator::prepare(@qwen_layer.fp32_multiplier())
  let edges = [
    0U, 0x80000000U, 1U, 0x7fffffU, 0x800000U, 0x3f800000U, 0xbf800000U, 0x3f800001U,
    0x33800000U, 0x7f7fffffU, 0xff7fffffU, 0x7f800000U, 0xff800000U, 0x7fc00000U,
  ]
  fn check(a : UInt32, b : UInt32) -> Unit raise {
    s.set_input(
      "a",
      @wave.LogicValue::from_uint64(width=32, value=a.to_uint64()),
    )
    s.set_input(
      "b",
      @wave.LogicValue::from_uint64(width=32, value=b.to_uint64()),
    )
    s.settle()
    let expected = Float::reinterpret_from_uint(a) *
      Float::reinterpret_from_uint(b)
    assert_eq(
      s.output("result").value_bits().to_uint(),
      if expected.is_nan() {
        0x7fc00000U
      } else {
        expected.reinterpret_as_uint()
      },
    )
  }
  for a in edges {
    for b in edges {
      check(a, b)
    }
  }
  let mut seed = 0x9af20461U
  for _ in 0..<20000 {
    seed = seed * 1664525U + 1013904223U
    let a = seed
    seed = seed * 1664525U + 1013904223U
    check(a, seed)
  }
}
