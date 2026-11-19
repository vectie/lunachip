///|
test "ordered MAC rounds before adding, preserves cancellation order and resets in flight" {
  let sim = @sim.Simulator::prepare(@qwen_layer.ordered_bf16_mac_lane())
  let k = @qwen_layer.ORDERED_MAC_ROW_SLOTS
  let n = @qwen_layer.ORDERED_MAC_EDGES
  let expected : Map[Int32, UInt64] = Map([])
  for edge in 0..<180 {
    let (on, first, a, w, value) : (Bool, Bool, UInt64, UInt64, UInt64) = if edge ==
      1 {
      (true, true, 0x4b800000UL, 0x3f80UL, 0x4b800000UL)
    } else if edge == 1 + k {
      (true, false, 0x3f800000UL, 0x3f80UL, 0x4b800000UL)
    } else if edge == 1 + 2 * k {
      (true, false, 0xcb800000UL, 0x3f80UL, 0UL)
    } else if edge == 2 {
      (true, true, 0xbf800000UL, 0x3f80UL, 0xbf800000UL)
    } else if edge == 2 + 2 * k {
      // Product rounds to 1; a fused multiply/add would leave -2^-28.
      (true, false, 0x3f7e03f8UL, 0x3f81UL, 0UL)
    } else if edge == 3 {
      (true, true, 3UL, 0x3f00UL, 2UL)
    } else if edge == 4 || edge == 93 {
      (true, false, 0x3f800000UL, 0x3f80UL, 0x3f800000UL)
    } else {
      (false, true, 0UL, 0x7fc1UL, 0UL)
    }
    let reset = edge == 0 || edge == 80
    if reset {
      expected.clear()
    }
    if on {
      expected[edge + n - 1] = value
    }
    for
      (name, width, v) in [
        ("clock", 1, 0UL),
        ("reset", 1, if reset { 1UL } else { 0UL }),
        ("valid", 1, if on { 1UL } else { 0UL }),
        ("first", 1, if first { 1UL } else { 0UL }),
        ("activation", 32, a),
        ("weight", 16, w),
      ] {
      sim.set_input(name, @wave.LogicValue::from_uint64(width~, value=v))
    }
    sim.rising_edge("clock")
    let valid = sim.output("result_valid")
    assert_true(valid.is_fully_known())
    match expected.get(edge) {
      Some(bits) => {
        assert_eq(valid.value_bits(), 1UL)
        let x = sim.output("result")
        assert_true(x.is_fully_known())
        assert_eq(x.value_bits(), bits)
      }
      None => assert_eq(valid.value_bits(), 0UL)
    }
  }
}
