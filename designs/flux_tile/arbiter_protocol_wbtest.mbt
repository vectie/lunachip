///|
test "arbiter snapshots stable offers before acceptance and exposes one owner only" {
  let simulator = arbiter_probe_prepare()
  arbiter_probe_put(simulator, "reader_valid", 1, 1UL)
  arbiter_probe_put(simulator, "reader_address", 32, 17UL)
  arbiter_probe_put(simulator, "engine_valid", 1, 1UL)
  arbiter_probe_put(simulator, "engine_write", 1, 1UL)
  arbiter_probe_put(simulator, "engine_address", 32, 48UL)
  arbiter_probe_put(simulator, "engine_bytes", 3, 4UL)
  arbiter_probe_put(simulator, "engine_mask", 4, 15UL)
  arbiter_probe_put(simulator, "engine_data", 32, 0xfedcba98UL)
  assert_eq(arbiter_probe_read(simulator, "request_valid"), 0UL)
  simulator.rising_edge("clock")
  assert_eq(arbiter_probe_read(simulator, "request_valid"), 1UL)
  assert_eq(arbiter_probe_payload(simulator), [0UL, 17UL, 1UL, 1UL, 0UL, 0UL])
  for address in [64UL, 128UL, 256UL] {
    arbiter_probe_put(simulator, "engine_address", 32, address)
    simulator.rising_edge("clock")
    assert_eq(arbiter_probe_payload(simulator), [0UL, 17UL, 1UL, 1UL, 0UL, 0UL])
    assert_eq(arbiter_probe_read(simulator, "reader_request_ready"), 0UL)
    assert_eq(arbiter_probe_read(simulator, "engine_request_ready"), 0UL)
  }
  arbiter_probe_put(simulator, "bus_request_ready", 1, 1UL)
  assert_eq(arbiter_probe_read(simulator, "reader_request_ready"), 1UL)
  assert_eq(arbiter_probe_read(simulator, "engine_request_ready"), 0UL)
  simulator.rising_edge("clock")
  arbiter_probe_put(simulator, "reader_valid", 1, 0UL)
  for _ in 0..<4 {
    assert_eq(arbiter_probe_read(simulator, "request_valid"), 0UL)
    assert_eq(arbiter_probe_read(simulator, "engine_request_ready"), 0UL)
    simulator.rising_edge("clock")
  }
  arbiter_probe_put(simulator, "reader_response_ready", 1, 1UL)
  arbiter_probe_put(simulator, "bus_response_valid", 1, 1UL)
  arbiter_probe_put(simulator, "bus_response_data", 32, 128UL)
  assert_eq(arbiter_probe_read(simulator, "reader_response_valid"), 1UL)
  assert_eq(arbiter_probe_read(simulator, "engine_response_valid"), 0UL)
  assert_eq(arbiter_probe_read(simulator, "reader_response_tag"), 77UL)
  assert_eq(arbiter_probe_read(simulator, "reader_response_data"), 128UL)
  simulator.rising_edge("clock")
  arbiter_probe_put(simulator, "bus_response_valid", 1, 0UL)
  assert_eq(arbiter_probe_read(simulator, "request_valid"), 0UL)
  simulator.rising_edge("clock")
  assert_eq(arbiter_probe_payload(simulator), [1UL, 256UL, 4UL, 15UL, 0xfedcba98UL, 1UL])
}

///|
test "arbiter round robin is per transaction with colliding local tags and global sequencing" {
  let simulator = arbiter_probe_prepare()
  for name in ["reader_valid", "engine_valid", "bus_request_ready", "reader_response_ready", "engine_response_ready"] {
    arbiter_probe_put(simulator, name, 1, 1UL)
  }
  arbiter_probe_put(simulator, "reader_address", 32, 16UL)
  arbiter_probe_put(simulator, "engine_address", 32, 32UL)
  for transaction in 0..<8 {
    let owner = if transaction % 2 == 0 { "reader" } else { "engine" }
    let other = if owner == "reader" { "engine" } else { "reader" }
    assert_eq(arbiter_probe_read(simulator, "request_valid"), 0UL)
    simulator.rising_edge("clock")
    assert_eq(arbiter_probe_read(simulator, owner + "_request_ready"), 1UL)
    assert_eq(arbiter_probe_read(simulator, other + "_request_ready"), 0UL)
    assert_eq(arbiter_probe_read(simulator, "request_tag"), transaction.to_uint64())
    assert_eq(arbiter_probe_read(simulator, "request_address"), if owner == "reader" { 16UL } else { 32UL })
    simulator.rising_edge("clock")
    arbiter_probe_put(simulator, "bus_response_tag", 32, transaction.to_uint64())
    arbiter_probe_put(simulator, "bus_response_fault", 2, if transaction == 3 { 1UL } else { 0UL })
    arbiter_probe_put(simulator, "bus_response_valid", 1, 1UL)
    assert_eq(arbiter_probe_read(simulator, owner + "_response_valid"), 1UL)
    assert_eq(arbiter_probe_read(simulator, other + "_response_valid"), 0UL)
    assert_eq(arbiter_probe_read(simulator, owner + "_response_tag"), 77UL)
    assert_eq(arbiter_probe_read(simulator, owner + "_response_fault"), if transaction == 3 { 1UL } else { 0UL })
    simulator.rising_edge("clock")
    arbiter_probe_put(simulator, "bus_response_valid", 1, 0UL)
    assert_eq(arbiter_probe_read(simulator, "poisoned"), 0UL)
    assert_eq(arbiter_probe_read(simulator, "request_valid"), 0UL)
  }
}

///|
test "arbiter response backpressure belongs to owner and holds local mapping" {
  let simulator = arbiter_probe_prepare()
  arbiter_probe_put(simulator, "engine_valid", 1, 1UL)
  arbiter_probe_put(simulator, "bus_request_ready", 1, 1UL)
  arbiter_probe_put(simulator, "reader_response_ready", 1, 1UL)
  simulator.rising_edge("clock")
  simulator.rising_edge("clock")
  arbiter_probe_put(simulator, "engine_valid", 1, 0UL)
  arbiter_probe_put(simulator, "reader_valid", 1, 1UL)
  arbiter_probe_put(simulator, "bus_response_valid", 1, 1UL)
  arbiter_probe_put(simulator, "bus_response_data", 32, 0xdeadbeefUL)
  for _ in 0..<5 {
    assert_eq(arbiter_probe_read(simulator, "response_ready"), 0UL)
    assert_eq(arbiter_probe_read(simulator, "engine_response_valid"), 1UL)
    assert_eq(arbiter_probe_read(simulator, "reader_response_valid"), 0UL)
    assert_eq(arbiter_probe_read(simulator, "engine_response_tag"), 77UL)
    assert_eq(arbiter_probe_read(simulator, "engine_response_data"), 0xdeadbeefUL)
    assert_eq(arbiter_probe_read(simulator, "request_valid"), 0UL)
    simulator.rising_edge("clock")
  }
  arbiter_probe_put(simulator, "engine_response_ready", 1, 1UL)
  assert_eq(arbiter_probe_read(simulator, "response_ready"), 1UL)
  simulator.rising_edge("clock")
  arbiter_probe_put(simulator, "bus_response_valid", 1, 0UL)
  assert_eq(arbiter_probe_read(simulator, "request_valid"), 0UL)
  simulator.rising_edge("clock")
  assert_eq(arbiter_probe_read(simulator, "reader_request_ready"), 1UL)
}
