///|
test "default memory aperture retains the explicit legacy graph" {
  assert_true(
    @qwen_layer.layer_machine() == @qwen_layer.layer_machine(memory=MiB256),
  )
  assert_true(
    @qwen_layer.feedback_layer_machine(delivery=true) ==
    @qwen_layer.feedback_layer_machine(delivery=true, memory=MiB256),
  )
}

///|
test "2GiB aperture preserves scalar parallel and packed matrix addresses under stalls" {
  // A non-multiple of four exercises the scalar fallback in the same module.
  parallel_case(3, 64, memory=GiB2, ddr_base=0x40000000U)
  parallel_case(8, 192, memory=GiB2, ddr_base=0x70000000U)
  parallel_case(8, 192, overlap=true, memory=GiB2, ddr_base=0x10000000U)
  // Last legal byte is 0x7fffffff. Exercise following-group prefetch and the
  // eight-word transport across several row groups/stripes at that boundary.
  parallel_case(
    32,
    192,
    overlap=true,
    wide=true,
    batch=true,
    throughput=true,
    eight_row=true,
    sixteen_row=true,
    packed_weights=true,
    feedback=true,
    delivery=true,
    memory=GiB2,
    ddr_base=0x7fffd000U,
  )
  parallel_case(
    16,
    128,
    packed_flag=false,
    overlap=true,
    wide=true,
    batch=true,
    throughput=true,
    eight_row=true,
    sixteen_row=true,
    packed_weights=true,
    feedback=true,
    delivery=true,
    memory=GiB2,
    ddr_base=0x7ffff000U,
  )
}

///|
fn memory_set(
  s : @sim.Simulator,
  name : String,
  width : Int32,
  value : UInt64,
) -> Unit raise {
  s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
}

///|
fn memory_get(s : @sim.Simulator, name : String) -> UInt64 raise {
  let value = s.output(name)
  assert_true(value.is_fully_known())
  value.value_bits()
}

///|
fn memory_sim(hw : @ir.Module) -> @sim.Simulator raise {
  let s = @sim.Simulator::prepare(hw)
  for node in hw.nodes() {
    if node.kind() is Input(name) {
      memory_set(s, name, node.signal_type().width().bits(), 0UL)
    }
  }
  s
}

///|
fn memory_program(
  s : @sim.Simulator,
  rows : Array[Array[UInt32]],
) -> Unit raise {
  memory_set(s, "reset", 1, 1UL)
  s.rising_edge("clock")
  memory_set(s, "reset", 1, 0UL)
  memory_set(s, "memory_healthy", 1, 1UL)
  memory_set(s, "program_write", 1, 1UL)
  for i, row in rows {
    for j, data in row {
      memory_set(s, "program_address", 15, (i * 16 + j).to_uint64())
      memory_set(s, "program_data", 32, data.to_uint64())
      s.rising_edge("clock")
    }
  }
  memory_set(s, "program_write", 1, 0UL)
  memory_set(s, "program_count", 12, rows.length().to_uint64())
  memory_set(s, "start", 1, 1UL)
  s.rising_edge("clock")
  memory_set(s, "start", 1, 0UL)
}

///|
test "2GiB external descriptors reject aperture crossings wraparound and malformed extents" {
  for memory in [@qwen_layer.MiB256, GiB2] {
    let limit = memory.capacity_bytes()
    for
      hw in [
        @qwen_layer.layer_machine(memory~),
        @qwen_layer.parallel_layer_machine(memory~),
        @qwen_layer.feedback_layer_machine(delivery=true, memory~),
      ] {
      let s = memory_sim(hw)
      for
        (op, n, k, address, valid) in [
          (14U, 1U, 0U, limit - 4UL, true),
          (15U, 1U, 0U, limit - 4UL, true),
          (4U, 1U, 64U, limit - 128UL, true),
          (4U, 16U, 64U, limit - 2048UL, true),
          (14U, 1U, 0U, limit, false),
          (15U, 1U, 0U, limit, false),
          (14U, 2U, 0U, limit - 4UL, false),
          (15U, 2U, 0U, limit - 4UL, false),
          (4U, 2U, 64U, limit - 128UL, false),
          (4U, 16U, 128U, limit - 2048UL, false),
          (14U, 2U, 0U, 0xfffffffcUL, false),
          (15U, 2U, 0U, 0xfffffffcUL, false),
          (4U, 2U, 64U, 0xffffff80UL, false),
          (4U, 0x80000000U, 64U, 0UL, false),
          (4U, 16U, 0x80000000U, 0UL, false),
          (14U, 1U, 0U, limit - 3UL, false),
          (4U, 1U, 64U, limit - 132UL, false),
        ] {
        let program : Array[Array[UInt32]] = []
        emit(program, op, 1024U, 0U, 0U, n, k~, ddr=address.to_uint())
        memory_program(s, program)
        let mut requested = false
        for _ in 0..<60 {
          if memory_get(s, "ddr_request_valid") == 1UL {
            requested = true
            assert_true(valid)
            assert_eq(memory_get(s, "ddr_request_address"), address)
            assert_eq(
              s.output("ddr_request_address").width(),
              memory.address_width(),
            )
            break
          }
          s.rising_edge("clock")
        }
        assert_eq(requested, valid)
        assert_eq(memory_get(s, "fault"), if valid { 0UL } else { 1UL })
        assert_eq(memory_get(s, "error"), if valid { 0UL } else { 1UL })
        assert_eq(memory_get(s, "ddr_beats"), 0UL)
      }
    }
  }
}

///|
test "2GiB scalar DMA loads the last two words and stores high addresses without aliasing" {
  let s = memory_sim(@qwen_layer.layer_machine(memory=GiB2))
  let program : Array[Array[UInt32]] = []
  emit(program, 14U, 1024U, 0U, 0U, 2U, ddr=0x7ffffff8U)
  emit(program, 15U, 0U, 1024U, 0U, 2U, ddr=0x40000000U)
  emit(program, 0U, 0U, 0U, 0U, 0U)
  memory_program(s, program)
  let values = [0x3f800000UL, 0xc0200000UL]
  let mut request = 0
  let mut pending : UInt64? = None
  let mut held : (UInt64, UInt64)? = None
  for cycle in 0..<400 {
    memory_set(s, "ddr_response_valid", 1, 0UL)
    if pending is Some(data) {
      memory_set(s, "ddr_response_valid", 1, 1UL)
      memory_set(s, "ddr_response_data", 32, data)
      memory_set(s, "ddr_response_last", 1, 1UL)
      pending = None
    }
    let ready = cycle % 4 == 3
    memory_set(s, "ddr_request_ready", 1, if ready { 1UL } else { 0UL })
    s.settle()
    if memory_get(s, "ddr_request_valid") == 1UL {
      let address = memory_get(s, "ddr_request_address")
      let data = memory_get(s, "ddr_request_data")
      if held is Some((previous_address, previous_data)) {
        assert_eq(address, previous_address)
        assert_eq(data, previous_data)
      }
      held = if ready { None } else { Some((address, data)) }
      assert_true(request < 4)
      assert_eq(memory_get(s, "ddr_request_burst"), 0UL)
      assert_eq(memory_get(s, "ddr_request_line"), 0UL)
      assert_eq(
        memory_get(s, "ddr_request_write"),
        if request < 2 {
          0UL
        } else {
          1UL
        },
      )
      assert_eq(
        address,
        if request < 2 {
          0x7ffffff8UL + request.to_uint64() * 4UL
        } else {
          0x40000000UL + (request - 2).to_uint64() * 4UL
        },
      )
      if request >= 2 {
        assert_eq(data, values[request - 2])
      }
      if ready {
        pending = Some(if request < 2 { values[request] } else { 0UL })
        request += 1
      }
    }
    s.rising_edge("clock")
    assert_eq(memory_get(s, "fault"), 0UL)
    if memory_get(s, "done") == 1UL {
      break
    }
  }
  assert_eq(request, 4)
  assert_eq(memory_get(s, "done"), 1UL)
  assert_eq(memory_get(s, "error"), 0UL)
  assert_eq(memory_get(s, "ddr_beats"), 4UL)
}
