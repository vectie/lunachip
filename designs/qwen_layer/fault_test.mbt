///|
test "layer rejects malformed descriptors before issuing DDR and reset clears sticky faults" {
  let hw = @qwen_layer.layer_machine()
  let s = @sim.Simulator::prepare(hw)
  fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
    s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  }
  fn get(name : String) -> UInt64 raise {
    let v = s.output(name)
    assert_true(v.is_fully_known())
    v.value_bits()
  }
  for node in hw.nodes() {
    if node.kind() is Input(name) {
      set(name, node.signal_type().width().bits(), 0UL)
    }
  }
  let valid = [
    4UL, 0UL, 0UL, 0UL, 1UL, 64UL, 1UL, 1UL, 0UL, 0UL, 0UL, 0UL, 0UL, 0UL, 0UL, 0UL,
  ]
  // Opcode, zero/oversize shape, address bounds, stride, flags, DDR range,
  // alignment and every reserved word are independently rejected.
  for
    (field, value) in [
      (0, 16UL),
      (4, 0UL),
      (4, 4097UL),
      (1, 32768UL),
      (2, 32767UL),
      (3, 32768UL),
      (5, 63UL),
      (6, 32769UL),
      (7, 32769UL),
      (8, 4UL),
      (8, 0x10000000UL),
      (10, 3UL),
      (11, 1UL),
      (12, 1UL),
      (13, 1UL),
      (14, 1UL),
      (15, 1UL),
    ] {
    set("reset", 1, 1UL)
    s.rising_edge("clock")
    set("reset", 1, 0UL)
    assert_eq(get("fault"), 0UL)
    assert_eq(get("error"), 0UL)
    set("memory_healthy", 1, 1UL)
    set("ddr_request_ready", 1, 1UL)
    set("program_write", 1, 1UL)
    for i, base in valid {
      set("program_address", 15, i.to_uint64())
      set("program_data", 32, if i == field { value } else { base })
      s.rising_edge("clock")
    }
    set("program_write", 1, 0UL)
    set("program_count", 12, 1UL)
    set("start", 1, 1UL)
    s.rising_edge("clock")
    set("start", 1, 0UL)
    for _ in 0..<50 {
      assert_eq(get("ddr_request_valid"), 0UL)
      s.rising_edge("clock")
    }
    assert_eq(get("fault"), 1UL)
    assert_eq(get("error"), 1UL)
    assert_eq(get("busy"), 0UL)
    set("start", 1, 1UL)
    for _ in 0..<3 {
      s.rising_edge("clock")
      assert_eq(get("fault"), 1UL)
      assert_eq(get("ddr_request_valid"), 0UL)
    }
    set("start", 1, 0UL)
  }
  set("reset", 1, 1UL)
  s.rising_edge("clock")
  assert_eq(get("fault"), 0UL)
}

///|
test "layer faults on premature burst LAST before using partial weight data" {
  let hw = @qwen_layer.layer_machine()
  let s = @sim.Simulator::prepare(hw)
  fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
    s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  }
  fn get(name : String) -> UInt64 raise {
    let v = s.output(name)
    assert_true(v.is_fully_known())
    v.value_bits()
  }
  for node in hw.nodes() {
    if node.kind() is Input(name) {
      set(name, node.signal_type().width().bits(), 0UL)
    }
  }
  set("reset", 1, 1UL)
  s.rising_edge("clock")
  set("reset", 1, 0UL)
  set("memory_healthy", 1, 1UL)
  set("ddr_request_ready", 1, 1UL)
  let row = [
    4UL, 0UL, 0UL, 0UL, 1UL, 64UL, 1UL, 1UL, 0UL, 0UL, 0UL, 0UL, 0UL, 0UL, 0UL, 0UL,
  ]
  set("program_write", 1, 1UL)
  for i, x in row {
    set("program_address", 15, i.to_uint64())
    set("program_data", 32, x)
    s.rising_edge("clock")
  }
  set("program_write", 1, 0UL)
  set("program_count", 12, 1UL)
  set("start", 1, 1UL)
  s.rising_edge("clock")
  set("start", 1, 0UL)
  let mut issued = false
  for _ in 0..<50 {
    if get("ddr_request_valid") == 1UL {
      assert_eq(get("ddr_request_burst"), 1UL)
      issued = true
      s.rising_edge("clock")
      break
    }
    s.rising_edge("clock")
  }
  assert_true(issued)
  set("ddr_response_valid", 1, 1UL)
  set("ddr_response_last", 1, 1UL)
  set("ddr_response_data", 32, 0x3f803f80UL)
  s.rising_edge("clock")
  set("ddr_response_valid", 1, 0UL)
  assert_eq(get("fault"), 1UL)
  assert_eq(get("products"), 0UL)
  assert_eq(get("ddr_request_valid"), 0UL)
  assert_true(get("error") != 0UL)
}
