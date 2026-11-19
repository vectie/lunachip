///|
test "contiguous stripes preserve ordered results across groups chunks and stalls" {
  for (n, k) in [(32, 192), (16, 64), (32, 64), (48, 128)] {
    parallel_case(
      n,
      k,
      overlap=true,
      wide=true,
      batch=true,
      throughput=true,
      eight_row=true,
      sixteen_row=true,
      packed_weights=true,
    )
  }
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
  )
}

///|
test "contiguous stripes retain fault drainage and reset ownership" {
  for fault in 1..<=5 {
    parallel_case(
      16,
      128,
      fault~,
      overlap=true,
      wide=true,
      batch=true,
      throughput=true,
      eight_row=true,
      sixteen_row=true,
      packed_weights=true,
    )
  }
  parallel_case(
    32,
    64,
    reset_mid=true,
    overlap=true,
    wide=true,
    batch=true,
    throughput=true,
    eight_row=true,
    sixteen_row=true,
    packed_weights=true,
  )
  for fault in [3, 4, 5] {
    parallel_case(
      32,
      64,
      fault~,
      fault_response=135,
      overlap=true,
      wide=true,
      batch=true,
      throughput=true,
      eight_row=true,
      sixteen_row=true,
      packed_weights=true,
    )
  }
}

///|
test "packed descriptors reject unsupported shapes before external requests" {
  let hw = @qwen_layer.contiguous_layer_machine()
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
  for
    (n, k, dst, flags) in [
      (8UL, 64UL, 1024UL, 1UL),
      (16UL, 65UL, 1024UL, 1UL),
      (16UL, 64UL, 0UL, 1UL),
      (16UL, 64UL, 1024UL, 2UL),
    ] {
    set("reset", 1, 1UL)
    s.rising_edge("clock")
    set("reset", 1, 0UL)
    set("memory_healthy", 1, 1UL)
    set("ddr_request_ready", 1, 1UL)
    set("program_write", 1, 1UL)
    for
      i, x in [
        4UL, dst, 0UL, 0UL, n, k, 1UL, 1UL, 0x10000UL, 0UL, flags, 0UL, 0UL, 0UL,
        0UL, 0UL,
      ] {
      set("program_address", 15, i.to_uint64())
      set("program_data", 32, x)
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
    assert_eq(get("products"), 0UL)
    assert_eq(get("ddr_beats"), 0UL)
  }
}
