///|
test "close/far FP32 addition preserves raw-bit CPU rounding and cancellation" {
  let s = @sim.Simulator::prepare(@qwen_layer.feedback_adder())
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
    let expected = Float::reinterpret_from_uint(a) +
      Float::reinterpret_from_uint(b)
    let actual = s.output("result")
    assert_true(actual.is_fully_known())
    assert_eq(
      actual.value_bits().to_uint(),
      if expected.is_nan() {
        0x7fc00000U
      } else {
        expected.reinterpret_as_uint()
      },
      msg="a=\{a} b=\{b}",
    )
  }
  let edge = [
    0U, 0x80000000U, 1U, 0x7fffffU, 0x800000U, 0x800001U, 0x3f800000U, 0xbf800000U,
    0x3f800001U, 0x33800000U, 0x7f7fffffU, 0xff7fffffU, 0x7f800000U, 0xff800000U,
    0x7fc00000U, 0x7f800001U,
  ]
  for a in edge {
    for b in edge {
      check(a, b)
    }
  }
  let mut seed = 0x71dc8e93U
  for _ in 0..<50000 {
    seed = seed * 1664525U + 1013904223U
    let a = seed
    seed = seed * 1664525U + 1013904223U
    check(a, seed)
    let exponent = (a >> 23) & 255U
    for delta in 0..<4 {
      let e = if exponent >= delta.reinterpret_as_uint() {
        exponent - delta.reinterpret_as_uint()
      } else {
        0U
      }
      check(
        a,
        ((a ^ 0x80000000U) & 0x80000000U) | (e << 23) | (seed & 0x7fffffU),
      )
    }
  }
  // Exact and near cancellation across every finite exponent and the
  // subnormal/normal boundary, including ties and sign reversal.
  for e in 0..<255 {
    for mantissa in [0U, 1U, 2U, 0x3fffffU, 0x7ffffeU, 0x7fffffU] {
      let a = (e.reinterpret_as_uint() << 23) | mantissa
      for delta in [0U, 1U, 2U, 3U, 7U, 15U] {
        if a >= delta {
          check(a, (a - delta) | 0x80000000U)
          check(a | 0x80000000U, a - delta)
        }
      }
    }
  }
}

///|
test "single-edge ordered feedback holds, resets and accumulates every edge" {
  let s = @sim.Simulator::prepare(@qwen_layer.feedback_accumulator())
  fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
    s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  }
  set("clock", 1, 0UL)
  let mut sum = 0.0F
  let mut seed = 0xc3218da7U
  for i in 0..<20000 {
    seed = seed * 1664525U + 1013904223U
    let value = if i % 7 == 0 {
      sum.reinterpret_as_uint() ^ 0x80000000U
    } else {
      seed
    }
    let reset = i % 97 == 0
    let valid = i % 11 != 3
    set("reset", 1, if reset { 1UL } else { 0UL })
    set("valid", 1, if valid { 1UL } else { 0UL })
    set("value", 32, value.to_uint64())
    if reset {
      sum = 0.0F
    } else if valid {
      sum = sum + Float::reinterpret_from_uint(value)
    }
    s.rising_edge("clock")
    let expected = if sum.is_nan() {
      0x7fc00000U
    } else {
      sum.reinterpret_as_uint()
    }
    let actual = s.output("sum")
    assert_true(actual.is_fully_known())
    assert_eq(actual.value_bits().to_uint(), expected)
  }
}
