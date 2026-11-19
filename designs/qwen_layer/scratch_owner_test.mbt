///|
test "scratch ownership preserves host vector unary fault and reset writes" {
  let modules = [false, true].map(state_scratch_mux => {
    deep_add_machine(true, eager_weight_reads=true, state_scratch_mux~)
  })
  let units = modules.map(m => @sim.Simulator::prepare(m))
  fn put(name : String, width : Int32, value : UInt64) -> Unit raise {
    for s in units {
      s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
    }
  }
  fn get(name : String) -> UInt64 raise {
    let value = units[0].output(name)
    assert_true(value.is_fully_known(), msg=name)
    value.value_bits()
  }
  let seen = Array::make(32, false)
  fn edge() -> Unit raise {
    for s in units {
      s.rising_edge("clock")
    }
    for
      name in [
        "state", "busy", "fault", "error", "instructions", "scratch_read_valid",
        "scratch_read_data",
      ] {
      assert_eq(units[1].output(name), units[0].output(name), msg=name)
    }
    let state = units[0].output("state")
    if state.is_fully_known() {
      seen[state.value_bits().to_int()] = true
    }
  }
  for node in modules[0].nodes() {
    if node.kind() is Input(name) {
      put(name, node.signal_type().width().bits(), 0UL)
    }
  }
  for
    (op, n, dst, bad, interrupt) in [
      (1U, 9U, 48U, false, false),
      (2U, 9U, 8U, false, false),
      (3U, 9U, 48U, false, false),
      (9U, 9U, 48U, false, false),
      (9U, 64U, 8U, false, false),
      (10U, 64U, 8U, false, false),
      (11U, 64U, 8U, false, false),
      (9U, 9U, 48U, true, false),
      (11U, 64U, 8U, false, true),
    ] {
    put("scratch_write", 1, 0UL)
    put("scratch_read", 1, 0UL)
    put("reset", 1, 1UL)
    edge()
    put("reset", 1, 0UL)
    put("memory_healthy", 1, 1UL)
    put("scratch_write", 1, 1UL)
    for address in 0..<80 {
      let bits = if bad && address == 10 {
        0x7fc00001U
      } else {
        Float::from_double(0.25 + (address % 17).to_double() / 8.0).reinterpret_as_uint()
      }
      put("scratch_address", 15, address.to_uint64())
      put("scratch_data", 32, bits.to_uint64())
      edge()
    }
    put("scratch_write", 1, 0UL)
    let program : Array[Array[UInt32]] = []
    emit(program, op, dst, 8U, 32U, n)
    emit(program, 2U, 72U, dst, 32U, 1U)
    emit(program, 0U, 0U, 0U, 0U, 0U)
    put("program_write", 1, 1UL)
    for i, row in program {
      for j, word in row {
        put("program_address", 15, (i * 16 + j).to_uint64())
        put("program_data", 32, word.to_uint64())
        edge()
      }
    }
    put("program_write", 1, 0UL)
    put("program_count", 12, 3UL)
    put("start", 1, 1UL)
    edge()
    put("start", 1, 0UL)
    let mut cycles = 0
    let mut interrupted = false
    while get("busy") == 1UL && cycles < 2500 {
      let state = get("state")
      // An external writer must not steal the scratch port from an executing
      // vector or nonlinear operator. Address79 is a readback canary.
      put(
        "scratch_write",
        1,
        if [24UL, 28UL, 29UL, 30UL, 31UL].contains(state) {
          1UL
        } else {
          0UL
        },
      )
      put("scratch_address", 15, 79UL)
      put("scratch_data", 32, 0xdead0000UL)
      edge()
      cycles += 1
      if interrupt && state == 24UL {
        put("scratch_write", 1, 0UL)
        put("reset", 1, 1UL)
        edge()
        put("reset", 1, 0UL)
        interrupted = true
        break
      }
    }
    put("scratch_write", 1, 0UL)
    assert_true(cycles < 2500)
    assert_eq(interrupted, interrupt)
    assert_eq(get("busy"), 0UL)
    if !bad {
      assert_eq(get("error"), 0UL)
    } else {
      assert_true(get("error") != 0UL)
    }
    // Delayed arithmetic may still be in flight after a fault/reset. It must
    // not cause a late write or change the retired instruction count.
    let error = get("error")
    let retired = get("instructions")
    for _ in 0..<100 {
      edge()
    }
    assert_eq(get("error"), error)
    assert_eq(get("instructions"), retired)
    put("reset", 1, 1UL)
    edge()
    put("reset", 1, 0UL)
    put("scratch_read", 1, 1UL)
    for address in 0..<80 {
      put("scratch_read_address", 15, address.to_uint64())
      edge()
      assert_eq(get("scratch_read_valid"), 1UL)
      assert_true(units[0].output("scratch_read_data").is_fully_known())
      if address == 79 {
        let canary = Float::from_double(0.25 + (79 % 17).to_double() / 8.0).reinterpret_as_uint()
        assert_eq(get("scratch_read_data"), canary.to_uint64())
      }
    }
  }
  for state in [0, 14, 24, 28, 29, 31] {
    assert_true(seen[state], msg="missing scratch owner state \{state}")
  }
}
