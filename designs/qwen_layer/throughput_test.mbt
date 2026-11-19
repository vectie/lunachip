///|
test "sixteen ordered lanes preserve four batch stripes warm starts and fallback" {
  parallel_case(32, 192, overlap=true, wide=true, batch=true, throughput=true)
  parallel_case(
    16,
    128,
    overlap=true,
    wide=true,
    batch=true,
    throughput=true,
    reset_mid=true,
  )
  parallel_case(16, 64, overlap=true, wide=true, batch=true, throughput=true)
  parallel_case(8, 64, overlap=true, wide=true, batch=true, throughput=true)
  parallel_case(4, 64, overlap=true, wide=true, batch=true, throughput=true)
  parallel_case(3, 64, overlap=true, wide=true, batch=true, throughput=true)
  parallel_case(
    16,
    64,
    dst=0,
    overlap=true,
    wide=true,
    batch=true,
    throughput=true,
  )
}

///|
test "sixteen lanes reject stripe faults malformed LAST and lost health" {
  for fault in 1..<=5 {
    parallel_case(
      16,
      128,
      overlap=true,
      wide=true,
      batch=true,
      throughput=true,
      fault~,
    )
  }
}

///|
test "parallel normalization FP32 add matches raw-bit CPU RNE including edge cases" {
  let sim = @sim.Simulator::prepare(@qwen_layer.throughput_adder())
  let edge = [
    0U, 0x80000000U, 1U, 0x7fffffU, 0x800000U, 0x3f800000U, 0xbf800000U, 0x7f7fffffU,
    0x7f800000U, 0xff800000U, 0x7fc00000U,
  ]
  let mut seed = 0x57ae4391U
  for i in 0..<20000 {
    seed = seed * 1664525U + 1013904223U
    let a = if i < edge.length() * edge.length() {
      edge[i / edge.length()]
    } else {
      seed
    }
    seed = seed * 1664525U + 1013904223U
    let b = if i < edge.length() * edge.length() {
      edge[i % edge.length()]
    } else {
      seed
    }
    sim.set_input(
      "a",
      @wave.LogicValue::from_uint64(width=32, value=a.to_uint64()),
    )
    sim.set_input(
      "b",
      @wave.LogicValue::from_uint64(width=32, value=b.to_uint64()),
    )
    sim.settle()
    let expected = Float::reinterpret_from_uint(a) +
      Float::reinterpret_from_uint(b)
    let actual = sim.output("result")
    assert_true(actual.is_fully_known())
    assert_eq(
      actual.value_bits().to_uint(),
      if expected.is_nan() {
        0x7fc00000U
      } else {
        expected.reinterpret_as_uint()
      },
    )
  }
}

///|
test "full-width parallel-normalized FP32 product retains RNE and gradual underflow" {
  let sim = @sim.Simulator::prepare(@qwen_layer.fp32_multiplier(fast=true))
  let edges = [
    0U, 0x80000000U, 1U, 0x7fffffU, 0x800000U, 0x3f800000U, 0xbf800000U, 0x7f7fffffU,
    0x7f800000U, 0xff800000U, 0x7fc00000U,
  ]
  let mut seed = 0x327fac19U
  for i in 0..<20000 {
    seed = seed * 1664525U + 1013904223U
    let a = if i < edges.length() * edges.length() {
      edges[i / edges.length()]
    } else {
      seed
    }
    seed = seed * 1664525U + 1013904223U
    let b = if i < edges.length() * edges.length() {
      edges[i % edges.length()]
    } else {
      seed
    }
    sim.set_input(
      "a",
      @wave.LogicValue::from_uint64(width=32, value=a.to_uint64()),
    )
    sim.set_input(
      "b",
      @wave.LogicValue::from_uint64(width=32, value=b.to_uint64()),
    )
    sim.settle()
    let expected = Float::reinterpret_from_uint(a) *
      Float::reinterpret_from_uint(b)
    let actual = sim.output("result")
    assert_true(actual.is_fully_known())
    assert_eq(
      actual.value_bits().to_uint(),
      if expected.is_nan() {
        0x7fc00000U
      } else {
        expected.reinterpret_as_uint()
      },
    )
  }
}
