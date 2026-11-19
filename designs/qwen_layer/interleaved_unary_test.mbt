///|
test "interleaved nonlinear contexts match the ordered scalar unit bit for bit" {
  let scalar = @sim.Simulator::prepare(
    @qwen_layer.unary_operator(fast=true, short=true),
  )
  let vector = @sim.Simulator::prepare(@qwen_layer.interleaved_unary_operator())
  fn put(
    s : @sim.Simulator,
    name : String,
    width : Int32,
    value : UInt64,
  ) -> Unit raise {
    s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  }
  fn get(s : @sim.Simulator, name : String) -> UInt64 raise {
    let v = s.output(name)
    assert_true(v.is_fully_known())
    v.value_bits()
  }
  for s in [scalar, vector] {
    put(s, "clock", 1, 0UL)
    put(s, "reset", 1, 1UL)
    put(s, "start", 1, 0UL)
    put(s, "mode", 2, 0UL)
  }
  put(scalar, "value", 32, 0UL)
  for i in 0..<4 {
    put(vector, "value" + i.to_string(), 32, 0UL)
  }
  for s in [scalar, vector] {
    s.rising_edge("clock")
    put(s, "reset", 1, 0UL)
  }
  fn reference(mode : UInt64, bits : UInt32) -> (UInt64, UInt64) raise {
    put(scalar, "mode", 2, mode)
    put(scalar, "value", 32, bits.to_uint64())
    put(scalar, "start", 1, 1UL)
    scalar.rising_edge("clock")
    put(scalar, "start", 1, 0UL)
    let mut cycles = 0
    while get(scalar, "busy") == 1UL && cycles < 100 {
      scalar.rising_edge("clock")
      cycles += 1
    }
    assert_eq(get(scalar, "busy"), 0UL)
    assert_eq(get(scalar, "done"), 1UL)
    (get(scalar, "result"), get(scalar, "error"))
  }
  let mut random = 0x319ac741U
  for mode in 0UL..<4UL {
    for case in 0..<100 {
      let bits = Array::makei(4, lane => {
        random = random * 1664525U + 1013904223U
        if case < 5 {
          [
            0U, 0x80000000U, 1U, 0x007fffffU, 0x1f800000U, 0x5f800000U, 0x1f7fffffU,
            0x5f800001U, 0x7f800000U, 0xff800000U, 0x7fc00000U, 0xff800001U, 0x42000000U,
            0xc2000000U, 0x42000001U, 0xc2000001U, 0x3f800000U, 0xbf800000U, 0x40800000U,
            0x3e800000U,
          ][case * 4 + lane]
        } else if mode == 3UL {
          Float::from_double((random % 65537U).to_double() / 1024.0 - 32.0).reinterpret_as_uint()
        } else {
          ((random % 129U + 63U) << 23) | (random & 0x7fffffU)
        }
      })
      let expected = bits.map(x => reference(mode, x))
      put(vector, "mode", 2, mode)
      for i in 0..<4 {
        put(vector, "value" + i.to_string(), 32, bits[i].to_uint64())
      }
      put(vector, "start", 1, 1UL)
      vector.rising_edge("clock")
      put(vector, "mode", 2, (mode + 1UL) & 3UL)
      for i in 0..<4 {
        put(vector, "value" + i.to_string(), 32, 0x7fc00000UL)
      }
      let mut cycles = 0
      while get(vector, "busy") == 1UL && cycles < 110 {
        vector.rising_edge("clock")
        cycles += 1
      }
      put(vector, "start", 1, 0UL)
      assert_eq(get(vector, "busy"), 0UL)
      assert_eq(get(vector, "done"), 1UL)
      assert_true(
        cycles == 0 ||
        cycles ==
        (match mode {
          1UL => 51
          2UL => 71
          _ => 95
        }),
      )
      for i in 0..<4 {
        assert_eq(
          (
            get(vector, "result" + i.to_string()),
            get(vector, "error" + i.to_string()),
          ),
          expected[i],
        )
      }
      for _ in 0..<3 {
        vector.rising_edge("clock")
        assert_eq(get(vector, "done"), 1UL)
      }
    }
  }
  for offset in [1, 2, 3, 4, 7, 47, 91, 94] {
    put(vector, "mode", 2, 3UL)
    for i in 0..<4 {
      put(vector, "value" + i.to_string(), 32, 0x3f800000UL)
    }
    put(vector, "start", 1, 1UL)
    vector.rising_edge("clock")
    put(vector, "start", 1, 0UL)
    for _ in 0..<offset {
      vector.rising_edge("clock")
    }
    assert_eq(get(vector, "busy"), 1UL)
    put(vector, "reset", 1, 1UL)
    vector.rising_edge("clock")
    put(vector, "reset", 1, 0UL)
    for _ in 0..<8 {
      assert_eq(get(vector, "busy"), 0UL)
      assert_eq(get(vector, "done"), 0UL)
      vector.rising_edge("clock")
    }
  }
}
