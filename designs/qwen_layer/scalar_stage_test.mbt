///|
test "scalar alignment and normalization preserve retirement cycles aliases and raw results" {
  let modules = [(false, false), (true, false), (true, true)].map(flags => {
    let (staged_scalar_add, staged_scalar_alignment) = flags
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
      staged_scalar_add~,
      staged_scalar_alignment~,
    )
  })
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
  fn same() -> Unit raise {
    for
      name in [
        "busy", "done", "fault", "error", "pc", "state", "opcode", "cycles_low",
        "cycles_high", "instructions", "products", "ddr_beats",
      ] {
      for i in 1..<engines.length() {
        assert_eq(get(engines[i], name), get(engines[0], name), msg=name)
      }
    }
  }
  for k, s in engines {
    for node in modules[k].nodes() {
      if node.kind() is Input(name) {
        set(s, name, node.signal_type().width().bits(), 0UL)
      }
    }
  }
  let patterns : Array[Array[UInt32]] = [
    [
      0x3f800000U, 0xbf800000U, 0x33800000U, 0x3f800001U, 1U, 0x007fffffU, 0x00800000U,
      0x80000000U, 0U,
    ],
    [
      0x7f7fffffU, 0xff7fffffU, 0x3f000000U, 0xbf000000U, 0x7f800000U, 0xff800000U,
      0x7fc00000U, 0x80000001U, 0x80800000U,
    ],
  ]
  // Alias offsets force the scalar ADD path; short reductions exercise total
  // and sum_value. Longer reductions also protect the unchanged streamed path.
  for pattern in patterns {
    for op in [2U, 3U, 5U, 6U, 7U, 8U] {
      for n in [1U, 3U, 9U] {
        for s in engines {
          set(s, "reset", 1, 1UL)
          s.rising_edge("clock")
          set(s, "reset", 1, 0UL)
          set(s, "memory_healthy", 1, 1UL)
          set(s, "scratch_read", 1, 0UL)
          set(s, "scratch_write", 1, 1UL)
          for address in 0..<48 {
            set(s, "scratch_address", 15, address.to_uint64())
            set(s, "scratch_data", 32, pattern[address % 9].to_uint64())
            s.rising_edge("clock")
          }
          set(s, "scratch_write", 1, 0UL)
          let program : Array[Array[UInt32]] = []
          emit(program, op, 9U, 8U, 24U, if op == 5U { 1U } else { n }, k=n)
          // A dependent scalar instruction catches a stale normalization stage.
          emit(program, 2U, 40U, 9U, 24U, 1U)
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
          set(s, "program_count", 12, program.length().to_uint64())
          set(s, "start", 1, 1UL)
          s.rising_edge("clock")
          set(s, "start", 1, 0UL)
        }
        same()
        let mut cycles = 0
        while get(engines[0], "busy") == 1UL && cycles < 2000 {
          for s in engines {
            s.rising_edge("clock")
          }
          cycles += 1
          same()
        }
        assert_true(cycles < 2000)
        assert_eq(get(engines[0], "done") + get(engines[0], "fault"), 1UL)
        for s in engines {
          set(s, "reset", 1, 1UL)
          s.rising_edge("clock")
          set(s, "reset", 1, 0UL)
          set(s, "scratch_read", 1, 1UL)
        }
        for address in 0..<48 {
          for s in engines {
            set(s, "scratch_read_address", 15, address.to_uint64())
            s.rising_edge("clock")
            assert_eq(get(s, "scratch_read_valid"), 1UL)
          }
          for i in 1..<engines.length() {
            assert_eq(
              get(engines[i], "scratch_read_data"),
              get(engines[0], "scratch_read_data"),
              msg="variant=\{i} op=\{op} n=\{n} address=\{address}",
            )
          }
        }
      }
    }
  }
}
