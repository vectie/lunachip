///|
fn deep_add_machine(
  deep_fp32_add : Bool,
  eager_weight_reads~ : Bool = false,
  state_scratch_mux~ : Bool = false,
) -> @ir.Module raise {
  @qwen_layer.interleaved_layer_machine(
    memory=GiB2,
    pipelined_vectors=true,
    wide512=true,
    rows64=true,
    banked64=true,
    prefetch256=true,
    scalar_lines=true,
    store_bursts=true,
    stream_unary=true,
    staged_decode=true,
    stream_reductions=true,
    paired_rows=true,
    full_rows=true,
    dual_read=true,
    indirect_bf16=true,
    bounded_add=true,
    deep_batch=true,
    strided_rows=true,
    ordered_array=true,
    staged_add_inputs=true,
    group64_rows=true,
    stripe512=true,
    prefetch_row_blocks=true,
    staged_unary_inputs=true,
    staged_reduction_term=true,
    staged_scalar_add=true,
    staged_scalar_alignment=true,
    deep_fp32_add~,
    compact_multiply_pack=deep_fp32_add,
    staged_multiply_product=deep_fp32_add,
    incremental_row_address=deep_fp32_add,
    registered_multiply_inputs=deep_fp32_add,
    eager_weight_reads~,
    state_scratch_mux~,
  )
}

///|
test "deep FP32 pipelines preserve dependent vectors reductions nonlinear faults and aliases" {
  let modules = [false, true].map(deep => deep_add_machine(deep))
  let units = modules.map(m => @sim.Simulator::prepare(m))
  fn put(
    s : @sim.Simulator,
    name : String,
    width : Int32,
    value : UInt64,
  ) -> Unit raise {
    s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  }
  fn get(s : @sim.Simulator, name : String) -> UInt64 raise {
    let value = s.output(name)
    assert_true(value.is_fully_known(), msg=name)
    value.value_bits()
  }
  for k, s in units {
    for node in modules[k].nodes() {
      if node.kind() is Input(name) {
        put(s, name, node.signal_type().width().bits(), 0UL)
      }
    }
  }
  fn run(
    s : @sim.Simulator,
    op : UInt32,
    n : UInt32,
    dst : UInt32,
    bad : Bool,
    interrupt : Bool,
  ) -> (Array[UInt64], UInt64, UInt64) raise {
    put(s, "reset", 1, 1UL)
    s.rising_edge("clock")
    put(s, "reset", 1, 0UL)
    put(s, "memory_healthy", 1, 1UL)
    put(s, "scratch_read", 1, 0UL)
    put(s, "scratch_write", 1, 1UL)
    for address in 0..<80 {
      let bits = if bad && address == 10 {
        0x7fc00001U
      } else {
        Float::from_double(0.25 + (address % 17).to_double() / 8.0).reinterpret_as_uint()
      }
      put(s, "scratch_address", 15, address.to_uint64())
      put(s, "scratch_data", 32, bits.to_uint64())
      s.rising_edge("clock")
    }
    put(s, "scratch_write", 1, 0UL)
    let program : Array[Array[UInt32]] = []
    emit(program, op, dst, 8U, 32U, if op == 5U { 2U } else { n }, k=n)
    emit(program, 2U, 64U, dst, 32U, 1U)
    emit(program, 0U, 0U, 0U, 0U, 0U)
    put(s, "program_write", 1, 1UL)
    for i, row in program {
      for j, word in row {
        put(s, "program_address", 15, (i * 16 + j).to_uint64())
        put(s, "program_data", 32, word.to_uint64())
        s.rising_edge("clock")
      }
    }
    put(s, "program_write", 1, 0UL)
    put(s, "program_count", 12, 3UL)
    put(s, "start", 1, 1UL)
    s.rising_edge("clock")
    put(s, "start", 1, 0UL)
    let mut cycles = 0
    while get(s, "busy") == 1UL && cycles < 2500 {
      s.rising_edge("clock")
      cycles += 1
      if interrupt && get(s, "state") == 24UL {
        // Kill a streamed nonlinear launch before its delayed write commits.
        for _ in 0..<6 {
          s.rising_edge("clock")
        }
        put(s, "reset", 1, 1UL)
        s.rising_edge("clock")
        put(s, "reset", 1, 0UL)
        break
      }
    }
    assert_true(cycles < 2500)
    assert_eq(get(s, "busy"), 0UL)
    let error = get(s, "error")
    let retired = get(s, "instructions")
    for _ in 0..<180 {
      s.rising_edge("clock")
    }
    assert_eq(get(s, "error"), error)
    assert_eq(get(s, "instructions"), retired)
    put(s, "reset", 1, 1UL)
    s.rising_edge("clock")
    put(s, "reset", 1, 0UL)
    put(s, "scratch_read", 1, 1UL)
    let data = Array::makei(80, address => {
      put(s, "scratch_read_address", 15, address.to_uint64())
      s.rising_edge("clock")
      assert_eq(get(s, "scratch_read_valid"), 1UL)
      get(s, "scratch_read_data")
    })
    (data, error, retired)
  }
  for op in [1U, 2U, 3U, 5U, 6U, 7U, 9U, 10U, 11U, 12U, 13U] {
    for (n, dst) in [(3U, 9U), (9U, 8U), (9U, 48U)] {
      let base = run(units[0], op, n, dst, false, false)
      let deep = run(units[1], op, n, dst, false, false)
      assert_eq(deep, base, msg="op=\{op} n=\{n} dst=\{dst}")
      assert_eq(deep.1, 0UL)
    }
  }
  for op in [9U, 10U, 11U] {
    for dst in [9U, 48U] {
      assert_eq(
        run(units[1], op, 9U, dst, true, false),
        run(units[0], op, 9U, dst, true, false),
      )
    }
  }
  for op in [9U, 11U] {
    assert_eq(
      run(units[1], op, 9U, 48U, false, true),
      run(units[0], op, 9U, 48U, false, true),
    )
    assert_eq(
      run(units[1], op, 9U, 48U, false, false),
      run(units[0], op, 9U, 48U, false, false),
    )
  }
}

///|
test "deep shared unary contexts preserve raw results and six-edge dependency spacing" {
  let units = [false, true].map(deep_add => {
    @sim.Simulator::prepare(
      @qwen_layer.interleaved_unary_operator(
        bounded=true,
        staged_add_inputs=true,
        deep_add~,
        compact_pack=deep_add,
        staged_product=deep_add,
        registered_inputs=deep_add,
      ),
    )
  })
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
  let mut random = 0x782f3812U
  for mode in [1UL, 2UL, 3UL] {
    for trial in 0..<20 {
      let values = Array::makei(4, i => {
        random = random * 1664525U + 1013904223U
        if trial < 3 {
          [
            0U, 0x80000000U, 0x1f800000U, 0x5f800000U, 0x7f800000U, 0xff800000U,
            0x7fc00001U, 0x3f800000U, 0x42000000U, 0xc2000000U, 0x42000001U, 0xc2000001U,
          ][trial * 4 + i]
        } else if mode == 3UL {
          Float::from_double((random % 65537U).to_double() / 1024.0 - 32.0).reinterpret_as_uint()
        } else {
          ((random % 129U + 63U) << 23) | (random & 0x7fffffU)
        }
      })
      let results = Array::makei(2, k => {
        let s = units[k]
        put(s, "clock", 1, 0UL)
        put(s, "start", 1, 0UL)
        put(s, "mode", 2, mode)
        for i, v in values {
          put(s, "value" + i.to_string(), 32, v.to_uint64())
        }
        put(s, "reset", 1, 1UL)
        s.rising_edge("clock")
        put(s, "reset", 1, 0UL)
        put(s, "start", 1, 1UL)
        s.rising_edge("clock")
        put(s, "start", 1, 0UL)
        put(s, "mode", 2, 0UL)
        let mut edges = 0
        while get(s, "busy") == 1UL && edges < 160 {
          s.rising_edge("clock")
          edges += 1
        }
        assert_eq(get(s, "busy"), 0UL)
        assert_eq(get(s, "done"), 1UL)
        let instructions = if mode == 1UL {
          12
        } else if mode == 2UL {
          17
        } else {
          23
        }
        assert_true(
          edges == 0 || edges == instructions * (if k == 1 { 6 } else { 4 }) + 3,
          msg="mode=\{mode} variant=\{k} edges=\{edges}",
        )
        Array::makei(4, i => {
          (get(s, "result" + i.to_string()), get(s, "error" + i.to_string()))
        })
      })
      assert_eq(results[1], results[0], msg="mode=\{mode} trial=\{trial}")
    }
  }
  let s = units[1]
  for offset in [1, 3, 4, 5, 6, 7, 137, 140] {
    put(s, "mode", 2, 3UL)
    for i in 0..<4 {
      put(s, "value" + i.to_string(), 32, 0x3f000000UL)
    }
    put(s, "start", 1, 1UL)
    s.rising_edge("clock")
    put(s, "start", 1, 0UL)
    for _ in 0..<offset {
      s.rising_edge("clock")
    }
    assert_eq(get(s, "busy"), 1UL)
    put(s, "reset", 1, 1UL)
    s.rising_edge("clock")
    put(s, "reset", 1, 0UL)
    for _ in 0..<10 {
      assert_eq(get(s, "busy"), 0UL)
      assert_eq(get(s, "done"), 0UL)
      s.rising_edge("clock")
    }
  }
}
