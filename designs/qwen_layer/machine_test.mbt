///|
fn emit(
  program : Array[Array[UInt32]],
  op : UInt32,
  dst : UInt32,
  a : UInt32,
  b : UInt32,
  n : UInt32,
  k~ : UInt32 = 0U,
  bs~ : UInt32 = 1U,
  br~ : UInt32 = 0U,
  ddr~ : UInt32 = 0U,
  imm~ : UInt32 = 0U,
  flags~ : UInt32 = 0U,
) -> Unit {
  program.push([
    op, dst, a, b, n, k, bs, br, ddr, imm, flags, 0U, 0U, 0U, 0U, 0U,
  ])
}

///|
test "layer instruction machine executes vectors nonlinear reductions local and DDR matrices plus DMA" {
  let s = @sim.Simulator::prepare(@qwen_layer.layer_machine())
  fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
    s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  }
  fn get(name : String) -> UInt64 raise {
    let v = s.output(name)
    assert_true(v.is_fully_known())
    v.value_bits()
  }
  for
    (name, width) in [
      ("clock", 1),
      ("reset", 1),
      ("start", 1),
      ("program_count", 12),
      ("program_write", 1),
      ("program_address", 15),
      ("program_data", 32),
      ("program_read", 1),
      ("program_read_address", 15),
      ("scratch_write", 1),
      ("scratch_address", 15),
      ("scratch_data", 32),
      ("scratch_read", 1),
      ("scratch_read_address", 15),
      ("memory_healthy", 1),
      ("ddr_request_ready", 1),
      ("ddr_response_valid", 1),
      ("ddr_response_data", 32),
      ("ddr_response_fault", 2),
      ("ddr_response_last", 1),
    ] {
    set(name, width, 0UL)
  }
  set("reset", 1, 1UL)
  s.rising_edge("clock")
  set("reset", 1, 0UL)
  set("memory_healthy", 1, 1UL)
  set("ddr_request_ready", 1, 1UL)
  set("scratch_write", 1, 1UL)
  for i in 0..<128 {
    set("scratch_address", 15, i.to_uint64())
    let value : Float = if i == 100 { 2.0 } else { Float::from_int(i) / 64.0 }
    set("scratch_data", 32, value.reinterpret_as_uint().to_uint64())
    s.rising_edge("clock")
  }
  set("scratch_write", 1, 0UL)
  let program : Array[Array[UInt32]] = []
  emit(program, 1U, 256U, 0U, 0U, 4U)
  emit(program, 2U, 260U, 0U, 0U, 4U, imm=0x40000000U, flags=2U)
  emit(program, 3U, 264U, 0U, 100U, 4U, flags=1U)
  emit(program, 6U, 268U, 0U, 0U, 4U)
  emit(program, 7U, 269U, 0U, 0U, 4U)
  emit(program, 8U, 270U, 0U, 0U, 4U)
  emit(program, 5U, 272U, 0U, 4U, 2U, k=4U, br=4U)
  emit(program, 4U, 280U, 0U, 0U, 2U, k=64U, ddr=0x1000U)
  emit(program, 9U, 290U, 100U, 0U, 1U)
  emit(program, 10U, 291U, 100U, 0U, 1U)
  emit(program, 11U, 292U, 0U, 0U, 1U)
  emit(program, 12U, 293U, 1U, 0U, 1U)
  emit(program, 13U, 294U, 1U, 100U, 1U)
  emit(program, 14U, 296U, 0U, 0U, 2U, ddr=0x4000U)
  emit(program, 15U, 0U, 256U, 0U, 4U, ddr=0x8000U)
  emit(program, 0U, 0U, 0U, 0U, 0U)
  set("program_write", 1, 1UL)
  for i, row in program {
    for j, v in row {
      set("program_address", 15, (i * 16 + j).to_uint64())
      set("program_data", 32, v.to_uint64())
      s.rising_edge("clock")
    }
  }
  set("program_write", 1, 0UL)
  set("program_count", 12, program.length().to_uint64())
  set("start", 1, 1UL)
  s.rising_edge("clock")
  set("start", 1, 0UL)
  let pending : Array[(UInt64, Bool)] = []
  let stored : Array[UInt32] = []
  let mut cycles = 0
  while get("busy") == 1UL && cycles < 10000 {
    set("ddr_response_valid", 1, 0UL)
    if pending.length() > 0 {
      let (data, last) = pending.remove(0)
      set("ddr_response_valid", 1, 1UL)
      set("ddr_response_data", 32, data)
      set("ddr_response_last", 1, if last { 1UL } else { 0UL })
    }
    s.settle()
    if get("ddr_request_valid") == 1UL {
      let address = get("ddr_request_address")
      if get("ddr_request_write") == 1UL {
        assert_true(address >= 0x8000UL && address < 0x8010UL)
        stored.push(get("ddr_request_data").to_uint())
        pending.push((0UL, true))
      } else if get("ddr_request_burst") == 1UL {
        assert_true(address == 0x1000UL || address == 0x1080UL)
        let packed = if address == 0x1000UL {
          0x3f803f80UL
        } else {
          0x40004000UL
        }
        for i in 0..<32 {
          pending.push((packed, i == 31))
        }
      } else {
        assert_true(address == 0x4000UL || address == 0x4004UL)
        pending.push(
          (if address == 0x4000UL { 0x40400000UL } else { 0x40800000UL }, true),
        )
      }
    }
    s.rising_edge("clock")
    cycles += 1
  }
  assert_true(cycles < 10000)
  assert_eq(get("done"), 1UL)
  assert_eq(get("fault"), 0UL)
  assert_eq(get("error"), 0UL)
  assert_eq(pending.length(), 0)
  fn read(address : Int32) -> Float raise {
    set("scratch_read", 1, 1UL)
    set("scratch_read_address", 15, address.to_uint64())
    s.rising_edge("clock")
    assert_eq(get("scratch_read_valid"), 1UL)
    Float::reinterpret_from_uint(get("scratch_read_data").to_uint())
  }
  for i in 0..<4 {
    let value = Float::from_int(i) / 64.0
    assert_eq(read(256 + i), value)
    assert_eq(read(260 + i), value + 2.0)
    assert_eq(read(264 + i), value * 2.0)
    assert_eq(stored[i], value.reinterpret_as_uint())
  }
  assert_eq(read(268), 6.0 / 64.0)
  assert_eq(read(269), 14.0 / 4096.0)
  assert_eq(read(270), 3.0 / 64.0)
  assert_eq(read(272), (0.0 * 4.0 + 1.0 * 5.0 + 2.0 * 6.0 + 3.0 * 7.0) / 4096.0)
  assert_eq(
    read(273),
    (0.0 * 8.0 + 1.0 * 9.0 + 2.0 * 10.0 + 3.0 * 11.0) / 4096.0,
  )
  assert_eq(read(280), 31.5)
  assert_eq(read(281), 63.0)
  assert_true((read(290).to_double() - 0.5).abs() < 0.000001)
  assert_true((read(291).to_double() - 1.0 / 2.0.sqrt()).abs() < 0.000001)
  assert_true((read(292).to_double() - 1.0).abs() < 0.00002)
  assert_eq(read(293), -1.0 / 64.0)
  assert_eq(read(294), 1.0 / 64.0)
  assert_eq(read(296), 3.0)
  assert_eq(read(297), 4.0)
}
