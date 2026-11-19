///|
test "BRAM dot captures count rejects invalid jobs ignores busy writes and resets mid job" {
  let s = @sim.Simulator::prepare(@floating_point.dot_product())
  fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
    s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  }
  fn step() -> Unit raise {
    s.rising_edge("clock")
  }
  fn out(name : String) -> UInt64 raise {
    let v = s.output(name)
    assert_true(v.is_fully_known())
    v.value_bits()
  }
  set("clock", 1, 0UL)
  set("reset", 1, 1UL)
  set("load", 1, 0UL)
  set("start", 1, 0UL)
  set("length", 11, 0UL)
  set("write_address", 10, 0UL)
  set("write_data", 32, 0UL)
  step()
  set("reset", 1, 0UL)
  let mut random = 1001U
  let words : Array[UInt32] = []
  for i in 0..<1024 {
    random = random * 1664525U + 1013904223U
    let a = ((random >> 8) & 0x807fU) | (((random >> 16) % 20U + 117U) << 7)
    random = random * 1664525U + 1013904223U
    let b = ((random >> 8) & 0x807fU) | (((random >> 16) % 20U + 117U) << 7)
    let word = a | (b << 16)
    words.push(word)
    set("load", 1, 1UL)
    set("write_address", 10, i.to_uint64())
    set("write_data", 32, word.to_uint64())
    step()
  }
  set("load", 1, 0UL)
  for count in [1, 2, 3, 16, 1024, 1024] {
    set("length", 11, count.to_uint64())
    set("start", 1, 1UL)
    step()
    set("start", 1, 0UL)
    // Changing length, load and start while running cannot corrupt ownership.
    set("length", 11, 0UL)
    set("load", 1, 1UL)
    set("write_data", 32, 0UL)
    let mut expected : Float = 0.0
    for i in 0..<count {
      let word = words[i]
      let product = Float::reinterpret_from_uint((word & 65535U) << 16) *
        Float::reinterpret_from_uint(word & 0xffff0000U)
      expected = expected + product
    }
    for i in 0..<(4 * count) {
      assert_eq(out("busy"), 1UL)
      set("start", 1, if i % 3 == 0 { 1UL } else { 0UL })
      step()
    }
    assert_eq(out("busy"), 0UL)
    assert_eq(out("done"), 1UL)
    assert_eq(out("result"), expected.reinterpret_as_uint().to_uint64())
    assert_eq(out("cycles"), (4 * count).to_uint64())
    set("load", 1, 0UL)
    set("start", 1, 0UL)
  }
  for count in [0UL, 1025UL, 2047UL] {
    set("length", 11, count)
    set("start", 1, 1UL)
    step()
    assert_eq(out("busy"), 0UL)
    assert_eq(out("error"), 1UL)
    assert_eq(out("done"), 0UL)
  }
  set("length", 11, 1024UL)
  step()
  set("start", 1, 0UL)
  for _ in 0..<7 {
    step()
  }
  set("reset", 1, 1UL)
  step()
  assert_eq(out("busy"), 0UL)
  assert_eq(out("done"), 0UL)
  assert_eq(out("error"), 0UL)
  assert_eq(out("result"), 0UL)
}
