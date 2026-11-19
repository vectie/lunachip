///|
test "eight lanes preserve sequential order and reject busy writes across pipeline drain and reset" {
  let s = @sim.Simulator::prepare(@floating_point.parallel_dot_product())
  fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
    s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  }
  fn out(name : String) -> UInt64 raise {
    let v = s.output(name)
    assert_true(v.is_fully_known())
    v.value_bits()
  }
  set("clock", 1, 0UL)
  set("reset", 1, 1UL)
  for
    (name, width) in [
      ("load", 1),
      ("start", 1),
      ("length", 11),
      ("write_address", 10),
      ("write_lane", 3),
      ("write_data", 32),
    ] {
    set(name, width, 0UL)
  }
  s.rising_edge("clock")
  set("reset", 1, 0UL)
  let words : Array[Array[UInt32]] = []
  let mut random = 19261U
  let edges = [
    0x3f803f80U, 0xbf803f80U, 0x3f000080U, 0x7f803f80U, 0x7f800000U, 0x7f7f7f7fU,
    0xbf800000U, 0x3f803f01U,
  ]
  for lane in 0..<8 {
    let row : Array[UInt32] = []
    for i in 0..<1024 {
      random = random * 1664525U + 1013904223U
      let a = ((random >> 8) & 0x807fU) | (((random >> 16) % 20U + 117U) << 7)
      random = random * 1664525U + 1013904223U
      let w = ((random >> 8) & 0x807fU) | (((random >> 16) % 20U + 117U) << 7)
      let word = if i == 0 { edges[lane] } else { a | (w << 16) }
      row.push(word)
      set("load", 1, 1UL)
      set("write_lane", 3, lane.to_uint64())
      set("write_address", 10, i.to_uint64())
      set("write_data", 32, word.to_uint64())
      s.rising_edge("clock")
    }
    words.push(row)
  }
  for count in [1, 2, 3, 16, 1024, 1024] {
    set("load", 1, 0UL)
    set("length", 11, count.to_uint64())
    set("start", 1, 1UL)
    s.rising_edge("clock")
    for i in 0..<(5 * count + 4) {
      assert_eq(out("busy"), 1UL)
      set("start", 1, if i % 3 == 0 { 1UL } else { 0UL })
      set("length", 11, 0UL)
      set("load", 1, 1UL)
      set("write_data", 32, 0UL)
      s.rising_edge("clock")
    }
    assert_eq(out("busy"), 0UL)
    assert_eq(out("done"), 1UL)
    assert_eq(out("cycles"), (5 * count + 4).to_uint64())
    for lane in 0..<8 {
      let mut sum : Float = 0.0
      for k in 0..<count {
        let word = words[lane][k]
        sum = sum +
          Float::reinterpret_from_uint((word & 65535U) << 16) *
          Float::reinterpret_from_uint(word & 0xffff0000U)
      }
      let bits = if sum.is_nan() {
        0x7fc00000U
      } else {
        sum.reinterpret_as_uint()
      }
      assert_eq(out("result_" + lane.to_string()), bits.to_uint64())
    }
  }
  set("load", 1, 0UL)
  for count in [0UL, 1025UL, 2047UL] {
    set("length", 11, count)
    set("start", 1, 1UL)
    s.rising_edge("clock")
    assert_eq(out("error"), 1UL)
    assert_eq(out("busy"), 0UL)
  }
  set("length", 11, 1024UL)
  s.rising_edge("clock")
  set("start", 1, 0UL)
  for _ in 0..<8 {
    s.rising_edge("clock")
  }
  set("reset", 1, 1UL)
  s.rising_edge("clock")
  set("reset", 1, 0UL)
  for _ in 0..<12 {
    s.rising_edge("clock")
  }
  assert_eq(out("busy"), 0UL)
  assert_eq(out("done"), 0UL)
  for lane in 0..<8 {
    assert_eq(out("result_" + lane.to_string()), 0UL)
  }
}
