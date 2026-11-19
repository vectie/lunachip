///|
test "shared unary input stage preserves every visible edge" {
  let units = [false, true].map(staged => {
    @sim.Simulator::prepare(
      @qwen_layer.interleaved_unary_operator(
        bounded=true,
        staged_add_inputs=staged,
      ),
    )
  })
  fn put(name : String, width : Int32, value : UInt64) -> Unit raise {
    for unit in units {
      unit.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
    }
  }
  let outputs = ["busy", "done"]
  for i in 0..<4 {
    outputs.push("error" + i.to_string())
    outputs.push("result" + i.to_string())
  }
  fn edge() -> Unit raise {
    for unit in units {
      unit.rising_edge("clock")
    }
    for port in outputs {
      let a = units[0].output(port)
      let b = units[1].output(port)
      assert_true(a.is_fully_known() && b.is_fully_known())
      assert_eq(a.value_bits(), b.value_bits(), msg=port)
    }
  }
  put("clock", 1, 0UL)
  put("start", 1, 0UL)
  put("mode", 2, 0UL)
  for i in 0..<4 {
    put("value" + i.to_string(), 32, 0UL)
  }
  put("reset", 1, 1UL)
  edge()
  put("reset", 1, 0UL)
  for mode in [1UL, 2UL, 3UL] {
    for limit in [9, 110] {
      put("mode", 2, mode)
      for i, bits in [0x3e99a1f3UL, 0x405a6421UL, 0xbe012245UL, 0x7fc00001UL] {
        put("value" + i.to_string(), 32, bits)
      }
      put("start", 1, 1UL)
      edge()
      put("start", 1, 0UL)
      put("mode", 2, 0UL)
      for _ in 0..<limit {
        edge()
      }
      let finished = units[1].output("done").value_bits()
      assert_eq(finished, if limit == 110 { 1UL } else { 0UL })
      put("reset", 1, 1UL)
      edge()
      put("reset", 1, 0UL)
    }
  }
}
