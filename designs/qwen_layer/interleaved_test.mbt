///|
test "interleaved layer preserves scalar aliases partial faults and tail batches" {
  let modules = [
    @qwen_layer.feedback_layer_machine(delivery=true),
    @qwen_layer.interleaved_layer_machine(),
  ]
  let engines = modules.map(hw => @sim.Simulator::prepare(hw))
  fn set(
    s : @sim.Simulator,
    name : String,
    width : Int32,
    v : UInt64,
  ) -> Unit raise {
    s.set_input(name, @wave.LogicValue::from_uint64(width~, value=v))
  }
  fn get(s : @sim.Simulator, name : String) -> UInt64 raise {
    let v = s.output(name)
    assert_true(v.is_fully_known())
    v.value_bits()
  }
  for k, s in engines {
    for node in modules[k].nodes() {
      if node.kind() is Input(name) {
        set(s, name, node.signal_type().width().bits(), 0UL)
      }
    }
    set(s, "reset", 1, 1UL)
    s.rising_edge("clock")
    set(s, "reset", 1, 0UL)
    set(s, "memory_healthy", 1, 1UL)
  }
  fn run(
    s : @sim.Simulator,
    op : UInt32,
    n : Int32,
    dst : Int32,
    invalid : Int32,
  ) -> (Array[UInt64], UInt64, Int32) raise {
    set(s, "reset", 1, 1UL)
    s.rising_edge("clock")
    set(s, "reset", 1, 0UL)
    set(s, "scratch_read", 1, 0UL)
    set(s, "scratch_write", 1, 1UL)
    for address in 0..<64 {
      set(s, "scratch_address", 15, address.to_uint64())
      let bits = if address == invalid + 8 && invalid >= 0 {
        0x7fc00000U
      } else {
        Float::from_double(0.5 + address.to_double() / 32.0).reinterpret_as_uint()
      }
      set(s, "scratch_data", 32, bits.to_uint64())
      s.rising_edge("clock")
    }
    set(s, "scratch_write", 1, 0UL)
    let program : Array[Array[UInt32]] = []
    emit(
      program,
      op,
      dst.reinterpret_as_uint(),
      8U,
      0U,
      n.reinterpret_as_uint(),
    )
    emit(program, 0U, 0U, 0U, 0U, 0U)
    set(s, "program_write", 1, 1UL)
    for i, row in program {
      for j, word in row {
        set(s, "program_address", 15, (i * 16 + j).to_uint64())
        set(s, "program_data", 32, word.to_uint64())
        s.rising_edge("clock")
      }
    }
    set(s, "program_write", 1, 0UL)
    set(s, "program_count", 12, 2UL)
    set(s, "start", 1, 1UL)
    s.rising_edge("clock")
    set(s, "start", 1, 0UL)
    let mut cycles = 0
    while get(s, "busy") == 1UL && cycles < 2000 {
      s.rising_edge("clock")
      cycles += 1
    }
    assert_true(cycles < 2000)
    let error = get(s, "error")
    assert_eq(get(s, "fault"), if error == 0UL { 0UL } else { 1UL })
    for _ in 0..<100 {
      s.rising_edge("clock")
      assert_eq(get(s, "error"), error)
    }
    set(s, "reset", 1, 1UL)
    s.rising_edge("clock")
    set(s, "reset", 1, 0UL)
    set(s, "scratch_read", 1, 1UL)
    let data = Array::makei(64, address => {
      set(s, "scratch_read_address", 15, address.to_uint64())
      s.rising_edge("clock")
      assert_eq(get(s, "scratch_read_valid"), 1UL)
      get(s, "scratch_read_data")
    })
    set(s, "scratch_read", 1, 0UL)
    (data, error, cycles)
  }
  for op in [9U, 10U, 11U] {
    for n in [1, 2, 3, 4, 5, 7, 8, 9] {
      for dst in [7, 8, 9, 32] {
        let (a, ae, ac) = run(engines[0], op, n, dst, -1)
        let (b, be, bc) = run(engines[1], op, n, dst, -1)
        assert_eq(b, a)
        assert_eq(be, ae)
        assert_eq(be, 0UL)
        if n >= 8 && (dst == 8 || dst == 32) {
          assert_true(bc * 2 < ac)
        }
      }
    }
    for bad in [0, 1, 2, 3, 4, 6, 8] {
      for dst in [7, 8, 9, 32] {
        let (a, ae, _) = run(engines[0], op, 9, dst, bad)
        let (b, be, _) = run(engines[1], op, 9, dst, bad)
        assert_eq(b, a)
        assert_eq(be, ae)
      }
    }
  }
}
