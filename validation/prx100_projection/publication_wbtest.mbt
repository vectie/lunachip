///|
test "next tile runs while old partial DDR writes stall; both result banks survive" {
  let b = bench()
  let (a, w, p, sums) = fixture(4, 103)
  store_codes(b, 0x100000U, w)
  store_codes(b, 0x200000U, a)
  b.configure(4)
  assert_eq(b.write(16UL, 1UL), 0UL)
  for _ in 0..<2500 {
    if b.observe("state") == 11UL {
      break
    }
    b.step()
  }
  assert_eq(b.observe("state"), 11UL)
  b.environment(stalled=true)
  for _ in 0..<1600 {
    b.step()
  }
  assert_eq(b.observe("retired"), 4UL)
  assert_eq(b.observe("partials"), 0UL)
  assert_eq(value(b.core, "producer_count"), 8UL)
  assert_eq(value(b.core, "consumer_count"), 8UL)
  assert_eq(value(b.core, "completion_valid"), 1UL)
  assert_eq(value(b.core, "completion_id"), 5UL)
  assert_eq(value(b.sim, "completion_ready"), 0UL)
  assert_true(b.collection_requests.length() > 0)
  b.environment()
  b.finish_job(4, p, sums)
}

///|
test "independent result read progresses without corrupting a held tagged BRAM response" {
  let b = bench()
  let (a, w, _, _) = fixture(1, 109)
  store_codes(b, 0x100000U, w)
  store_codes(b, 0x200000U, a)
  b.configure(1)
  assert_eq(b.write(16UL, 1UL), 0UL)
  for _ in 0..<2000 {
    if value(b.sim, "completion_ready") == 1UL {
      break
    }
    b.step()
  }
  for node in b.inputs {
    if node.kind() is Input(name) && name.has_prefix("c_") {
      b.set(name, node.signal_type().width().bits(), 0UL)
    }
  }
  b.set("ddr_request_ready", 1, 1UL)
  b.set("ddr_response_valid", 1, 0UL)
  b.set("c_producer_count", 32, 4UL)
  b.set("c_consumer_count", 32, 4UL)
  // Legal result write followed by a held operand read on the actual port.
  b.set("c_memory_request_valid", 1, 1UL)
  b.set("c_memory_request_write", 1, 1UL)
  b.set("c_memory_request_address", 32, 1024UL)
  b.set("c_memory_request_bytes", 3, 4UL)
  b.set("c_memory_request_mask", 4, 15UL)
  b.set("c_memory_request_data", 32, 77UL)
  b.sim.rising_edge("clock")
  b.set("c_memory_request_valid", 1, 0UL)
  b.set("c_memory_response_ready", 1, 1UL)
  b.sim.rising_edge("clock")
  b.set("c_memory_response_ready", 1, 0UL)
  b.set("c_memory_request_valid", 1, 1UL)
  b.set("c_memory_request_write", 1, 0UL)
  b.set("c_memory_request_address", 32, 256UL)
  b.set("c_memory_request_bytes", 3, 1UL)
  b.set("c_memory_request_mask", 4, 1UL)
  b.set("c_memory_request_data", 32, 0UL)
  b.set("c_memory_request_tag", 32, 991UL)
  b.sim.rising_edge("clock")
  b.set("c_memory_request_valid", 1, 0UL)
  b.set("c_completion_valid", 1, 1UL)
  for i in 0..<4 {
    b.set("c_completion_id", 32, (i + 1).to_uint64())
    b.set("c_completion_bytes_completed", 32, [16UL, 128UL, 0UL, 32UL][i])
    b.sim.rising_edge("clock")
  }
  b.set("c_completion_valid", 1, 0UL)
  b.sim.rising_edge("clock")
  for _ in 0..<16 {
    b.sim.rising_edge("clock")
    assert_true([9UL, 10UL, 11UL, 12UL].contains(b.observe("state")))
    assert_eq(value(b.sim, "memory_response_valid"), 1UL)
    assert_eq(value(b.sim, "memory_response_tag"), 991UL)
    assert_eq(
      value(b.sim, "memory_response_data"),
      (a[0].reinterpret_as_uint() & 255U).to_uint64(),
    )
  }
  assert_eq(b.observe("state"), 12UL)
  assert_eq(value(b.sim, "ddr_request_data"), 77UL)
  b.set("c_memory_response_ready", 1, 1UL)
  b.sim.rising_edge("clock")
  b.set("c_memory_response_ready", 1, 0UL)
  assert_eq(value(b.sim, "memory_response_valid"), 0UL)
  assert_eq(b.observe("state"), 12UL)
  assert_eq(value(b.sim, "ddr_request_data"), 77UL)
  // The lookahead C read is still enabled in state12. It must neither block
  // the next core byte request nor replace that request's registered output.
  b.set("c_memory_request_valid", 1, 1UL)
  b.set("c_memory_request_address", 32, 257UL)
  b.set("c_memory_request_tag", 32, 992UL)
  assert_eq(value(b.sim, "memory_request_ready"), 1UL)
  b.sim.rising_edge("clock")
  b.set("c_memory_request_valid", 1, 0UL)
  for _ in 0..<3 {
    assert_eq(value(b.sim, "memory_response_valid"), 1UL)
    assert_eq(value(b.sim, "memory_response_tag"), 992UL)
    assert_eq(value(b.sim, "memory_response_fault"), 0UL)
    assert_eq(
      value(b.sim, "memory_response_data"),
      (a[1].reinterpret_as_uint() & 255U).to_uint64(),
    )
    assert_eq(value(b.sim, "ddr_request_data"), 77UL)
    b.sim.rising_edge("clock")
  }
}
