///|
fn canonical(x : Float) -> UInt32 {
  if x.is_nan() {
    0x7fc00000U
  } else {
    x.reinterpret_as_uint()
  }
}

///|
fn evaluate(
  s : @sim.Simulator,
  a : UInt32,
  b : UInt32,
  width : Int32,
) -> UInt32 raise {
  s.set_input("a", @wave.LogicValue::from_uint64(width~, value=a.to_uint64()))
  s.set_input("b", @wave.LogicValue::from_uint64(width~, value=b.to_uint64()))
  s.settle()
  let result = s.output("result")
  assert_true(result.is_fully_known())
  result.value_bits().to_uint()
}

///|
test "BF16 products match native FP32 for special values and all encodings against boundaries" {
  let s = @sim.Simulator::prepare(@floating_point.bf16_multiplier())
  let boundaries = [
    0U, 0x8000U, 1U, 0x7fU, 0x80U, 0x3eabU, 0x3f80U, 0xbf80U, 0x7f7fU, 0xff7fU, 0x7f80U,
    0xff80U, 0x7f81U, 0xffc0U,
  ]
  for code in 0..<65536 {
    let a = code.reinterpret_as_uint()
    // Each encoding sees a deterministic boundary operand; the full cross
    // product of directed boundaries is also checked below.
    let b = boundaries[code % boundaries.length()]
    assert_eq(
      evaluate(s, a, b, 16),
      canonical(
        Float::reinterpret_from_uint(a << 16) *
        Float::reinterpret_from_uint(b << 16),
      ),
    )
  }
  for a in boundaries {
    for b in boundaries {
      assert_eq(
        evaluate(s, a, b, 16),
        canonical(
          Float::reinterpret_from_uint(a << 16) *
          Float::reinterpret_from_uint(b << 16),
        ),
      )
    }
  }
  let mut random = 0x13ba9137U
  for _ in 0..<100000 {
    random = random * 1664525U + 1013904223U
    let a = random >> 16
    random = random * 1664525U + 1013904223U
    let b = random >> 16
    assert_eq(
      evaluate(s, a, b, 16),
      canonical(
        Float::reinterpret_from_uint(a << 16) *
        Float::reinterpret_from_uint(b << 16),
      ),
    )
  }
}

///|
test "FP32 addition matches native FP32 for cancellation rounding subnormals specials and seeded raw bits" {
  let s = @sim.Simulator::prepare(@floating_point.fp32_adder())
  let edges = [
    0U, 0x80000000U, 1U, 0x7fffffU, 0x800000U, 0x800001U, 0x80800000U, 0x3f800000U,
    0xbf800000U, 0x33800000U, 0x34000000U, 0x3f800001U, 0x7f7fffffU, 0xff7fffffU,
    0x7f800000U, 0xff800000U, 0x7f800001U, 0x7fc00000U,
  ]
  for a in edges {
    for b in edges {
      assert_eq(
        evaluate(s, a, b, 32),
        canonical(
          Float::reinterpret_from_uint(a) + Float::reinterpret_from_uint(b),
        ),
      )
    }
  }
  let mut random = 0x9183acfeU
  for i in 0..<100000 {
    random = random * 1664525U + 1013904223U
    let a = random
    random = random * 1664525U + 1013904223U
    let b = match i % 4 {
      0 => a ^ 0x80000000U
      1 => (a ^ 0x80000000U) + (random & 0xffU)
      _ => random
    }
    assert_eq(
      evaluate(s, a, b, 32),
      canonical(
        Float::reinterpret_from_uint(a) + Float::reinterpret_from_uint(b),
      ),
    )
  }
}
