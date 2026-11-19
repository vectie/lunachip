///|
fn exercise_streaming_add(bounded : Bool) -> Unit raise {
  let s = @sim.Simulator::prepare(@qwen_layer.pipelined_adder(bounded~))
  fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
    s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  }
  fn result() -> UInt32 raise {
    let v = s.output("result")
    assert_true(v.is_fully_known())
    v.value_bits().to_uint()
  }
  set("clock", 1, 0UL)
  set("reset", 1, 1UL)
  set("a", 32, 0UL)
  set("b", 32, 0UL)
  s.rising_edge("clock")
  assert_eq(result(), 0U)
  set("reset", 1, 0UL)
  let edge = [
    0U, 0x80000000U, 1U, 0x7fffffU, 0x800000U, 0x3f800000U, 0xbf800000U, 0x7f7fffffU,
    0x7f800000U, 0xff800000U, 0x7fc00000U,
  ]
  let expected : Array[UInt32] = []
  let mut seed = 0x239cb81dU
  for i in 0..<20001 {
    seed = seed * 1664525U + 1013904223U
    let a = if i < edge.length() * edge.length() {
      edge[i / edge.length()]
    } else {
      seed
    }
    seed = seed * 1664525U + 1013904223U
    let c = if i < edge.length() * edge.length() {
      edge[i % edge.length()]
    } else {
      seed
    }
    let sum = Float::reinterpret_from_uint(a) + Float::reinterpret_from_uint(c)
    expected.push(
      if sum.is_nan() {
        0x7fc00000U
      } else {
        sum.reinterpret_as_uint()
      },
    )
    set("a", 32, a.to_uint64())
    set("b", 32, c.to_uint64())
    s.rising_edge("clock")
    assert_eq(result(), if i == 0 { 0U } else { expected[i - 1] })
  }
  set("reset", 1, 1UL)
  s.rising_edge("clock")
  assert_eq(result(), 0U)
  set("reset", 1, 0UL)
  set("a", 32, 0x3f800000UL)
  set("b", 32, 0x3f800000UL)
  s.rising_edge("clock")
  assert_eq(result(), 0U)
  s.rising_edge("clock")
  assert_eq(result(), 0x40000000U)
}

///|
test "two-edge FP32 adder accepts raw inputs each edge and flushes on reset" {
  exercise_streaming_add(false)
}

///|
test "bounded cancellation normalization preserves ordered terms and reset bubbles" {
  exercise_streaming_add(true)
}
