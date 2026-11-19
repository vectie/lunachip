///|
test "registered arithmetic streams preserve latency and FP32 rounding" {
  let b = @wire.ModuleBuilder::new("fp_pipeline_test")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  b.input_timing(rs, SampledIn(d.id()))
  let reset = b.synchronous_reset(rs, 0UL)
  fn input(name : String) -> @wire.Signal raise {
    let x = b.input(name, @wire.uint(32))
    b.input_timing(x, SampledIn(d.id()))
    x
  }
  let a = input("a")
  let c = input("b")
  let mul = multiply_pipeline(
    b,
    d,
    reset,
    field(b, a, 15, 0),
    field(b, c, 15, 0),
  )
  let sum = b.register_in(d, add_pipeline(b, d, reset, a, c), reset~)
  for (name, x) in [("mul", mul), ("sum", sum)] {
    let p = b.output(name, @wire.uint(32))
    b.output_timing(p, ProducedIn(d.id()))
    b.connect(p, x)
  }
  let s = @sim.Simulator::prepare(b.finish())
  fn set(name : String, width : Int32, value : UInt32) -> Unit raise {
    s.set_input(
      name,
      @wave.LogicValue::from_uint64(width~, value=value.to_uint64()),
    )
  }
  fn canon(x : Float) -> UInt32 {
    if x.is_nan() {
      0x7fc00000U
    } else {
      x.reinterpret_as_uint()
    }
  }
  set("clock", 1, 0U)
  set("reset", 1, 1U)
  set("a", 32, 0U)
  set("b", 32, 0U)
  s.rising_edge("clock")
  set("reset", 1, 0U)
  let edges = [
    0U, 0x80000000U, 1U, 0x7fffffU, 0x800000U, 0x3f800000U, 0xbf800000U, 0x33800000U,
    0x7f7fffffU, 0xff7fffffU, 0x7f800000U, 0xff800000U, 0x7fc00000U, 0x7f800001U,
  ]
  let bf = [
    0U, 0x8000U, 1U, 0x7fU, 0x80U, 0x3f80U, 0xbf80U, 0x7f7fU, 0x7f80U, 0xff80U, 0x7f81U,
  ]
  let sums : Array[UInt32] = []
  let products : Array[UInt32] = []
  let mut random = 0xabc78124U
  for i in 0..<20200 {
    random = random * 1664525U + 1013904223U
    let a = if i < 196 {
      edges[i / 14]
    } else if i < 317 {
      bf[(i - 196) / 11]
    } else {
      random
    }
    random = random * 1664525U + 1013904223U
    let c = if i < 196 {
      edges[i % 14]
    } else if i < 317 {
      bf[(i - 196) % 11]
    } else if i % 4 == 0 {
      a ^ 0x80000000U
    } else {
      random
    }
    products.push(
      canon(
        Float::reinterpret_from_uint((a & 65535U) << 16) *
        Float::reinterpret_from_uint((c & 65535U) << 16),
      ),
    )
    sums.push(
      canon(Float::reinterpret_from_uint(a) + Float::reinterpret_from_uint(c)),
    )
    set("a", 32, a)
    set("b", 32, c)
    s.rising_edge("clock")
    if i >= 2 {
      assert_eq(s.output("mul").value_bits(), products[i - 2].to_uint64())
    }
    if i >= 4 {
      assert_eq(s.output("sum").value_bits(), sums[i - 4].to_uint64())
    }
  }
}
