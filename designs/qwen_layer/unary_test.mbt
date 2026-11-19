///|
test "FP32 nonlinear iterations have bounded error and explicit invalid/clipped results" {
  let reference : Array[(UInt32, Int32)] = []
  for (fast, short) in [(false, false), (true, false), (true, true)] {
    let cursor = [0]
    let s = @sim.Simulator::prepare(@qwen_layer.unary_operator(fast~, short~))
    fn set(name : String, width : Int32, v : UInt64) -> Unit raise {
      s.set_input(name, @wave.LogicValue::from_uint64(width~, value=v))
    }
    fn get(name : String) -> UInt64 raise {
      let v = s.output(name)
      assert_true(v.is_fully_known())
      v.value_bits()
    }
    set("clock", 1, 0UL)
    set("reset", 1, 1UL)
    set("start", 1, 0UL)
    set("mode", 2, 0UL)
    set("value", 32, 0UL)
    s.rising_edge("clock")
    set("reset", 1, 0UL)
    fn run(mode : Int32, x : Float, error : UInt64) -> Float raise {
      set("mode", 2, mode.to_uint64())
      set("value", 32, x.reinterpret_as_uint().to_uint64())
      set("start", 1, 1UL)
      s.rising_edge("clock")
      set("start", 1, 0UL)
      // Active operations own captured input/mode. Busy starts cannot replace it.
      set("value", 32, 0x7fc00000UL)
      set("mode", 2, 0UL)
      let mut steps = 0
      while get("busy") == 1UL && steps < (if fast { 128 } else { 32 }) {
        s.rising_edge("clock")
        steps += 1
      }
      assert_true(steps <= (if fast { 115 } else { 23 }))
      assert_eq(get("busy"), 0UL)
      assert_eq(get("done"), 1UL)
      assert_eq(get("error"), error)
      let bits = get("result").to_uint()
      if fast {
        let (expected, old_steps) = reference[cursor[0]]
        assert_eq(bits, expected)
        assert_eq(
          steps,
          if short && old_steps > 0 {
            match mode {
              1 => 40
              2 => 60
              _ => 76
            }
          } else {
            old_steps * 5
          },
        )
      } else {
        reference.push((bits, steps))
      }
      cursor[0] += 1
      Float::reinterpret_from_uint(bits)
    }
    for i in -128..<=128 {
      let x = Float::from_double(i.to_double() / 4.0)
      let y = run(3, x, 0UL).to_double()
      let expected = @math.exp(x.to_double())
      assert_true((y - expected).abs() <= expected * 0.00002 + 1.0e-12)
    }
    for i in -64..<=64 {
      let x = Float::from_double(@math.exp(i.to_double() / 4.0))
      for mode in [1, 2] {
        let y = run(mode, x, 0UL).to_double()
        let expected = if mode == 1 {
          1.0 / x.to_double()
        } else {
          1.0 / x.to_double().sqrt()
        }
        assert_true((y - expected).abs() <= expected * 0.000001)
      }
    }
    assert_eq(run(3, -33.0, 0UL).reinterpret_as_uint(), 0U)
    assert_eq(run(3, 33.0, 0UL).reinterpret_as_uint(), 0x7f800000U)
    for mode in [0, 1, 2] {
      for bits in [0U, 0xbf800000U, 0x7fc00000U, 1U] {
        assert_true(run(mode, Float::reinterpret_from_uint(bits), 1UL).is_nan())
      }
    }
    for offset in 1..<=5 {
      set("reset", 1, 0UL)
      set("mode", 2, 3UL)
      set("value", 32, 0x3f800000UL)
      set("start", 1, 1UL)
      s.rising_edge("clock")
      set("start", 1, 0UL)
      for _ in 0..<offset {
        s.rising_edge("clock")
      }
      assert_eq(get("busy"), 1UL)
      set("reset", 1, 1UL)
      s.rising_edge("clock")
      assert_eq(get("busy"), 0UL)
      assert_eq(get("done"), 0UL)
      set("reset", 1, 0UL)
      for _ in 0..<8 {
        s.rising_edge("clock")
        assert_eq(get("busy"), 0UL)
        assert_eq(get("done"), 0UL)
      }
      ignore(run(3, 0.5, 0UL))
    }
    assert_eq(cursor[0], reference.length())
  }
}
