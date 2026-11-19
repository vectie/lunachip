///|
test "completed core tile waits for the next operand region under DDR stalls" {
  let b = bench()
  let (a, w, p, sums) = fixture(2, 61)
  store_codes(b, 0x100000U, w)
  store_codes(b, 0x200000U, a)
  b.configure(2)
  assert_eq(b.write(16UL, 1UL), 0UL)
  for _ in 0..<2000 {
    if value(b.sim, "completion_ready") == 1UL {
      break
    }
    b.step()
  }
  assert_eq(value(b.sim, "completion_ready"), 1UL)
  b.environment(stalled=true)
  for _ in 0..<1100 {
    b.step()
  }
  assert_eq(b.read(48UL), 4UL)
  assert_eq(b.read(108UL), 4UL)
  assert_eq(b.read(112UL), 4UL)
  assert_eq(b.read(44UL), 0UL)
  assert_eq(b.read(52UL), 0UL)
  assert_eq(b.read(100UL), 2UL)
  assert_eq(b.read(116UL), 7UL)
  b.environment()
  b.finish_job(2, p, sums)
  assert_eq(b.overlapped_reads.length(), 2)
}

///|
test "prefetch writes preserve a held tagged core byte response" {
  let b = bench()
  let (a, w, _, _) = fixture(2, 71)
  store_codes(b, 0x100000U, w)
  store_codes(b, 0x200000U, a)
  b.configure(2)
  assert_eq(b.write(16UL, 1UL), 0UL)
  for _ in 0..<2000 {
    if value(b.sim, "completion_ready") == 1UL {
      break
    }
    b.step()
  }
  assert_eq(value(b.sim, "completion_ready"), 1UL)
  // Isolate the actual target at a quiescent shared-core port boundary.
  for node in b.inputs {
    if node.kind() is Input(name) && name.has_prefix("c_") {
      b.set(name, node.signal_type().width().bits(), 0UL)
    }
  }
  b.set("ddr_request_ready", 1, 1UL)
  b.set("ddr_response_valid", 1, 0UL)
  for _ in 0..<3 {
    b.sim.rising_edge("clock")
  }
  b.set("c_memory_request_valid", 1, 1UL)
  b.set("c_memory_request_bytes", 3, 1UL)
  b.set("c_memory_request_mask", 4, 1UL)
  b.set("c_memory_request_address", 32, 256UL)
  b.set("c_memory_request_tag", 32, 987UL)
  b.sim.rising_edge("clock")
  b.set("c_memory_request_valid", 1, 0UL)
  assert_eq(value(b.sim, "memory_response_valid"), 1UL)
  assert_eq(
    value(b.sim, "memory_response_data"),
    (a[0].reinterpret_as_uint() & 255U).to_uint64(),
  )
  b.set("ddr_response_valid", 1, 1UL)
  b.set("ddr_response_data", 32, 0x87654321UL)
  b.set(
    "ddr_response_last",
    1,
    if b.observe("ddr_beat") == 3UL {
      1UL
    } else {
      0UL
    },
  )
  b.sim.rising_edge("clock")
  b.set("ddr_response_valid", 1, 0UL)
  for _ in 0..<8 {
    b.sim.rising_edge("clock")
    assert_eq(value(b.sim, "memory_response_valid"), 1UL)
    assert_eq(value(b.sim, "memory_response_tag"), 987UL)
    assert_eq(value(b.sim, "memory_response_fault"), 0UL)
    assert_eq(
      value(b.sim, "memory_response_data"),
      (a[0].reinterpret_as_uint() & 255U).to_uint64(),
    )
  }
}
