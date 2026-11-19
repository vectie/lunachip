///|
test "pipelined 24x8 significand emits one exact 32-bit product on every filled edge" {
  check_significand_product(false)
}

///|
test "full integer product preserves all 24x8 bits and thirteen-edge latency" {
  check_significand_product(true)
}

///|
fn check_significand_product(full_product : Bool) -> Unit raise {
  let sim = @sim.Simulator::prepare(
    @qwen_layer.significand_product_pipeline(full_product~),
  )
  fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
    sim.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  }
  set("clock", 1, 0UL)
  let expected : Array[UInt64] = []
  let mut seed = 1U
  for i in 0..<4108 {
    seed = seed * 1664525U + 1013904223U
    let a = match i / 256 % 8 {
      0 => 0UL
      1 => 0xffffffUL
      2 => 1UL << (i % 24)
      3 => 0xffffffUL ^ (1UL << (i % 24))
      _ => (seed >> 8).to_uint64()
    }
    let w = (i % 256).to_uint64()
    expected.push(a * w)
    set("activation", 24, a)
    set("weight", 8, w)
    sim.rising_edge("clock")
    if i >= 12 {
      let product = sim.output("result")
      assert_true(product.is_fully_known())
      assert_eq(product.value_bits(), expected[i - 12])
    }
  }
}
