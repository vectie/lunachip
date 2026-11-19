///|
test "active core cannot overwrite reused descriptors or operands; result writes remain acknowledged" {
  let b = bench()
  let (a, w, _, _) = fixture(1, 7)
  store_codes(b, 0x100000U, w)
  store_codes(b, 0x200000U, a)
  b.configure(1)
  assert_eq(b.write(16UL, 1UL), 0UL)
  for _ in 0..<2000 {
    b.step()
    if value(b.sim, "completion_ready") == 1UL {
      break
    }
  }
  assert_eq(value(b.sim, "completion_ready"), 1UL)
  // Stop the real core at this boundary and inject malformed client traffic.
  for node in b.inputs {
    if node.kind() is Input(name) && name.has_prefix("c_") {
      b.set(name, node.signal_type().width().bits(), 0UL)
    }
  }
  for address in [0UL, 256UL, 512UL, 1020UL, 1056UL, 4092UL, 1025UL] {
    b.set("c_memory_request_valid", 1, 1UL)
    b.set("c_memory_request_write", 1, 1UL)
    b.set("c_memory_request_address", 32, address)
    b.set("c_memory_request_bytes", 3, 4UL)
    b.set("c_memory_request_mask", 4, 15UL)
    b.set("c_memory_request_data", 32, 0xdeadbeefUL)
    b.set("c_memory_request_tag", 32, 123UL)
    b.sim.settle()
    assert_eq(value(b.sim, "memory_request_ready"), 1UL)
    b.sim.rising_edge("clock")
    b.set("c_memory_request_valid", 1, 0UL)
    let fault = if address == 1025UL { 2UL } else { 1UL }
    for _ in 0..<4 {
      b.sim.rising_edge("clock")
      assert_eq(value(b.sim, "memory_response_valid"), 1UL)
      assert_eq(value(b.sim, "memory_response_tag"), 123UL)
      assert_eq(value(b.sim, "memory_response_fault"), fault)
    }
    b.set("c_memory_response_ready", 1, 1UL)
    b.sim.rising_edge("clock")
    b.set("c_memory_response_ready", 1, 0UL)
  }
  b.set("c_memory_request_valid", 1, 1UL)
  b.set("c_memory_request_address", 32, 1024UL)
  b.set("c_memory_request_data", 32, 77UL)
  b.sim.rising_edge("clock")
  assert_eq(value(b.sim, "memory_response_fault"), 0UL)
  b.set("c_memory_request_valid", 1, 0UL)
  b.set("c_memory_response_ready", 1, 1UL)
  b.sim.rising_edge("clock")
  b.set("c_memory_response_ready", 1, 0UL)
  b.set("c_memory_request_valid", 1, 1UL)
  b.set("c_memory_request_write", 1, 0UL)
  b.set("c_memory_request_bytes", 3, 1UL)
  b.set("c_memory_request_mask", 4, 1UL)
  b.set("c_memory_request_data", 32, 0UL)
  b.sim.rising_edge("clock")
  assert_eq(value(b.sim, "memory_response_fault"), 0UL)
  assert_eq(value(b.sim, "memory_response_data"), 77UL)
}
