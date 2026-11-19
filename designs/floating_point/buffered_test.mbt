///|
test "buffered FP load commits all lanes together and preserves FP order and busy ownership" {
  let h = @floating_point.buffered_dot_product()
  assert_eq(h.memories().length(), 8)
  let s = @sim.Simulator::prepare(h)
  fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
    s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  }
  fn output(name : String) -> UInt64 raise {
    let v = s.output(name)
    assert_true(v.is_fully_known())
    v.value_bits()
  }
  for n in h.nodes() {
    if n.kind() is Input(name) {
      set(name, n.signal_type().width().bits(), 0UL)
    }
  }
  set("reset", 1, 1UL)
  s.rising_edge("clock")
  set("reset", 1, 0UL)
  let activations : Array[UInt32] = []
  let weights : Array[Array[UInt32]] = Array::makei(8, _ => [])
  let mut random = 0x17102026U
  for k in 0..<1024 {
    random = random * 1664525U + 1013904223U
    let a = ((random >> 8) & 0x807fU) | (((random >> 16) % 16U + 119U) << 7)
    activations.push(a)
    set("load", 1, 1UL)
    set("write_address", 10, k.to_uint64())
    set("write_activation", 16, a.to_uint64())
    for lane in 0..<8 {
      random = random * 1664525U + 1013904223U
      let w = ((random >> 8) & 0x807fU) | (((random >> 16) % 16U + 119U) << 7)
      weights[lane].push(w)
      set("write_weight_" + lane.to_string(), 16, w.to_uint64())
    }
    s.rising_edge("clock")
  }
  for length in [1, 2, 3, 16, 1023, 1024, 1024] {
    set("load", 1, 0UL)
    set("start", 1, 1UL)
    set("length", 11, length.to_uint64())
    s.rising_edge("clock")
    for cycle in 0..<(4 * length + 4) {
      assert_eq(output("busy"), 1UL)
      set("start", 1, if cycle % 3 == 0 { 1UL } else { 0UL })
      set("length", 11, 0UL)
      set("load", 1, 1UL)
      set("write_activation", 16, 0UL)
      for lane in 0..<8 {
        set("write_weight_" + lane.to_string(), 16, 0UL)
      }
      s.rising_edge("clock")
    }
    assert_eq(output("busy"), 0UL)
    assert_eq(output("done"), 1UL)
    assert_eq(output("error"), 0UL)
    assert_eq(output("cycles"), (4 * length + 4).to_uint64())
    for lane in 0..<8 {
      let mut sum : Float = 0.0
      for k in 0..<length {
        let product = Float::reinterpret_from_uint(activations[k] << 16) *
          Float::reinterpret_from_uint(weights[lane][k] << 16)
        sum = sum + product
      }
      assert_eq(
        output("result_" + lane.to_string()),
        sum.reinterpret_as_uint().to_uint64(),
      )
    }
  }
  set("load", 1, 0UL)
  set("start", 1, 1UL)
  for length in [0UL, 1025UL, 2047UL] {
    set("length", 11, length)
    s.rising_edge("clock")
    assert_eq(output("error"), 1UL)
    assert_eq(output("busy"), 0UL)
  }
  set("length", 11, 1024UL)
  s.rising_edge("clock")
  set("start", 1, 0UL)
  for _ in 0..<7 {
    s.rising_edge("clock")
  }
  set("reset", 1, 1UL)
  s.rising_edge("clock")
  set("reset", 1, 0UL)
  for _ in 0..<12 {
    s.rising_edge("clock")
  }
  assert_eq(output("busy"), 0UL)
  assert_eq(output("done"), 0UL)
  for lane in 0..<8 {
    assert_eq(output("result_" + lane.to_string()), 0UL)
  }
}

///|
test "inactive operand bank loads during compute and simultaneous opposite-bank START is safe" {
  let h = @floating_point.buffered_dot_product()
  let s = @sim.Simulator::prepare(h)
  fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
    s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  }
  fn output(name : String) -> UInt64 raise {
    let x = s.output(name)
    assert_true(x.is_fully_known())
    x.value_bits()
  }
  fn weights() -> Unit raise {
    for lane in 0..<8 {
      set(
        "write_weight_" + lane.to_string(),
        16,
        0x3f00UL + lane.to_uint64() * 128UL,
      )
    }
  }
  fn verify(length : Int32, negative : Bool) -> Unit raise {
    for lane in 0..<8 {
      let w = Float::reinterpret_from_uint(
        (0x3f00U + lane.reinterpret_as_uint() * 128U) << 16,
      )
      let expected = (if negative {
          -Float::from_int(length)
        } else {
          Float::from_int(length)
        }) *
        w
      assert_eq(
        output("result_" + lane.to_string()),
        expected.reinterpret_as_uint().to_uint64(),
      )
    }
  }
  fn drain(length : Int32) -> Unit raise {
    set("start", 1, 0UL)
    set("load", 1, 0UL)
    for _ in 0..<(4 * length + 4) {
      if output("busy") == 0UL {
        break
      }
      s.rising_edge("clock")
    }
    assert_eq(output("done"), 1UL)
    assert_eq(output("busy"), 0UL)
    assert_eq(output("error"), 0UL)
    assert_eq(output("cycles"), (4 * length + 4).to_uint64())
  }
  for n in h.nodes() {
    if n.kind() is Input(name) {
      set(name, n.signal_type().width().bits(), 0UL)
    }
  }
  set("reset", 1, 1UL)
  s.rising_edge("clock")
  set("reset", 1, 0UL)
  weights()
  set("load", 1, 1UL)
  set("write_activation", 16, 0x3f80UL)
  for k in 0..<1024 {
    set("write_address", 10, k.to_uint64())
    s.rising_edge("clock")
  }
  set("load", 1, 0UL)
  set("length", 11, 1024UL)
  set("start", 1, 1UL)
  s.rising_edge("clock")
  set("start", 1, 0UL)
  set("load", 1, 1UL)
  set("write_bank", 1, 1UL)
  set("write_activation", 16, 0xbf80UL)
  for k in 0..<1024 {
    set("write_address", 10, k.to_uint64())
    s.rising_edge("clock")
    assert_eq(output("busy"), 1UL)
  }
  drain(1024)
  verify(1024, false)
  set("start_bank", 1, 1UL)
  set("start", 1, 1UL)
  s.rising_edge("clock")
  drain(1024)
  verify(1024, true)
  set("start_bank", 1, 0UL)
  set("start", 1, 1UL)
  set("load", 1, 1UL)
  set("write_bank", 1, 1UL)
  set("write_address", 10, 0UL)
  set("write_activation", 16, 0UL)
  set("length", 11, 16UL)
  s.rising_edge("clock")
  drain(16)
  verify(16, false)
  set("start_bank", 1, 1UL)
  set("start", 1, 1UL)
  s.rising_edge("clock")
  drain(16)
  verify(15, true)
  set("start_bank", 1, 0UL)
  set("write_bank", 1, 0UL)
  set("start", 1, 1UL)
  set("load", 1, 1UL)
  s.rising_edge("clock")
  assert_eq(output("error"), 1UL)
  assert_eq(output("busy"), 0UL)
  set("load", 1, 0UL)
  s.rising_edge("clock")
  drain(16)
  verify(16, false)
}
