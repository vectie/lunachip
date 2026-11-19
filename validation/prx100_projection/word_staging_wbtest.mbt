///|
test "word staging returns all lanes and rejects bad aligned shapes without memory access" {
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
  for node in b.inputs {
    if node.kind() is Input(name) && name.has_prefix("c_") {
      b.set(name, node.signal_type().width().bits(), 0UL)
    }
  }
  fn transaction(
    address : UInt64,
    bytes : UInt64,
    mask : UInt64,
    writing : Bool,
    data : UInt64,
    expected_fault : UInt64,
    expected_data : UInt64,
  ) -> Unit raise {
    for
      (name, width, value) in [
        ("c_memory_request_valid", 1, 1UL),
        ("c_memory_request_write", 1, if writing { 1UL } else { 0UL }),
        ("c_memory_request_address", 32, address),
        ("c_memory_request_bytes", 3, bytes),
        ("c_memory_request_mask", 4, mask),
        ("c_memory_request_data", 32, data),
        ("c_memory_request_tag", 32, 0xabcdefUL),
      ] {
      b.set(name, width, value)
    }
    b.sim.settle()
    assert_eq(value(b.sim, "memory_request_ready"), 1UL)
    b.sim.rising_edge("clock")
    b.set("c_memory_request_valid", 1, 0UL)
    for _ in 0..<5 {
      assert_eq(value(b.sim, "memory_response_valid"), 1UL)
      assert_eq(value(b.sim, "memory_response_tag"), 0xabcdefUL)
      assert_eq(value(b.sim, "memory_response_fault"), expected_fault)
      assert_eq(value(b.sim, "memory_response_data"), expected_data)
      b.sim.rising_edge("clock")
    }
    b.set("c_memory_response_ready", 1, 1UL)
    b.sim.rising_edge("clock")
    b.set("c_memory_response_ready", 1, 0UL)
  }
  transaction(3072UL, 4UL, 15UL, true, 0x80ff7f01UL, 0UL, 0UL)
  transaction(3072UL, 4UL, 15UL, false, 0UL, 0UL, 0x80ff7f01UL)
  for i, byte in [1UL, 127UL, 255UL, 128UL] {
    transaction(3072UL + i.to_uint64(), 1UL, 1UL, false, 0UL, 0UL, byte)
  }
  for
    (address, bytes, mask, data, fault) in [
      (3073UL, 4UL, 15UL, 0UL, 2UL),
      (4093UL, 4UL, 15UL, 0UL, 2UL),
      (4096UL, 4UL, 15UL, 0UL, 1UL),
      (3072UL, 4UL, 1UL, 0UL, 2UL),
      (3072UL, 2UL, 3UL, 0UL, 2UL),
      (3072UL, 4UL, 15UL, 1UL, 2UL),
    ] {
    transaction(address, bytes, mask, false, data, fault, 0UL)
  }
}
