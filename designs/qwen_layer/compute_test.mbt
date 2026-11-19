///|
test "BF16 weight pipeline retains every encoding FP32 RNE streaming and reset" {
  let s = @sim.Simulator::prepare(@qwen_layer.bf16_weight_multiplier())
  fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
    s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  }
  set("clock", 1, 0UL)
  set("reset", 1, 1UL)
  set("a", 32, 0UL)
  set("b", 16, 0UL)
  s.rising_edge("clock")
  let expected : Array[UInt32] = [0U, 0U, 0U]
  let edges = [
    0U, 0x80000000U, 1U, 0x7fffffU, 0x800000U, 0x3f800000U, 0xbf800000U, 0x7f7fffffU,
    0x7f800000U, 0xff800000U, 0x7fc00000U,
  ]
  let mut seed = 0x728adb19U
  let weight_edges = [
    0U, 0x8000U, 1U, 0x7fU, 0x80U, 0x3f80U, 0xbf80U, 0x7f7fU, 0x7f80U, 0xff80U, 0x7fc0U,
    0x7f81U, 0xffffU,
  ]
  for i in 0..<66000 {
    seed = seed * 1664525U + 1013904223U
    let special = i >= 65538 &&
      i < 65538 + edges.length() * weight_edges.length()
    let a = if special {
      edges[(i - 65538) / weight_edges.length()]
    } else {
      seed
    }
    let weight = if special {
      weight_edges[(i - 65538) % weight_edges.length()]
    } else {
      (i % 65536).reinterpret_as_uint()
    }
    let value = Float::reinterpret_from_uint(a) *
      Float::reinterpret_from_uint(weight << 16)
    let reset = i >= 65800 && (i % 7 == 2 || i % 7 == 3)
    if reset {
      for j in 0..<3 {
        expected[j] = 0U
      }
    } else {
      expected[2] = expected[1]
      expected[1] = expected[0]
      expected[0] = if value.is_nan() {
        0x7fc00000U
      } else {
        value.reinterpret_as_uint()
      }
    }
    set("reset", 1, if reset { 1UL } else { 0UL })
    set("a", 32, a.to_uint64())
    set("b", 16, weight.to_uint64())
    s.rising_edge("clock")
    let actual = s.output("result")
    assert_true(actual.is_fully_known())
    assert_eq(
      actual.value_bits().to_uint(),
      expected[2],
      msg="BF16 encoding/stream/reset cycle \{i}",
    )
  }
}

///|
test "thirty-two BF16 rows retain ordered accumulation batches and fallback" {
  for (n, k) in [(64, 192), (32, 64), (16, 64), (3, 64)] {
    parallel_case(
      n,
      k,
      overlap=true,
      wide=true,
      batch=true,
      throughput=true,
      compute=true,
    )
  }
  parallel_case(
    32,
    64,
    dst=0,
    cycle_limit=60000,
    overlap=true,
    wide=true,
    batch=true,
    throughput=true,
    compute=true,
  )
  parallel_case(
    32,
    128,
    reset_mid=true,
    overlap=true,
    wide=true,
    batch=true,
    throughput=true,
    compute=true,
  )
}

///|
test "thirty-two rows fault and health loss drain without late commits" {
  for fault in 1..<=5 {
    parallel_case(
      32,
      128,
      fault~,
      overlap=true,
      wide=true,
      batch=true,
      throughput=true,
      compute=true,
    )
  }
}
