///|
fn Harness::store_logit(
  h : Harness,
  addr : UInt64,
  bits : UInt64,
  fault~ : UInt64 = 0UL,
) -> Unit raise {
  h.set("c_ddr_request_valid", 1, 1UL)
  h.set("c_ddr_request_write", 1, 1UL)
  h.set("c_ddr_request_address", 32, addr)
  h.set("c_ddr_request_data", 32, bits)
  h.tick()
  h.set("c_ddr_request_valid", 1, 0UL)
  h.set("ddr_request_ready", 1, 1UL)
  h.tick()
  h.set("ddr_request_ready", 1, 0UL)
  h.set("ddr_response_valid", 1, 1UL)
  h.set("ddr_response_last", 1, 1UL)
  h.set("ddr_response_fault", 2, fault)
  h.tick()
  h.set("ddr_response_valid", 1, 0UL)
  h.set("ddr_response_fault", 2, 0UL)
}

///|
test "committed FP32 scores: first maximum, signed zero, invalid and incomplete streams" {
  let h = Harness::new()
  assert_eq(h.read(0x94UL), (0UL, 1UL))
  assert_eq(h.write(0x44UL, 3UL), 0UL)
  assert_eq(h.write(0x48UL, 0x7ffffffcUL), 2UL)
  for
    (words, expected) in [
      ([0xc0400000UL, 0xc0000000UL, 0xc0000000UL], 1UL),
      ([0x80000000UL, 0UL, 0xbf800000UL], 0UL),
      ([0xc0000000UL, 1UL, 0x40000000UL], 2UL),
      ([0x7f800000UL, 1UL, 2UL], 0xffffffffUL),
      ([1UL, 2UL, 0x7fc00001UL], 0xffffffffUL),
    ] {
    assert_eq(h.write(0x48UL, 0x1000UL), 0UL)
    h.store_logit(0x800UL, 0x7f800000UL)
    for i, word in words {
      assert_eq(h.read(0x4cUL), (0UL, 0xffffffffUL))
      h.store_logit(0x1000UL + i.to_uint64() * 4UL, word)
    }
    assert_eq(h.read(0x4cUL), (0UL, expected))
  }
  assert_eq(h.write(0x48UL, 0x1000UL), 0UL)
  h.store_logit(0x1000UL, 1UL, fault=2UL)
  h.store_logit(0x1004UL, 2UL)
  h.store_logit(0x1008UL, 3UL)
  assert_eq(h.read(0x4cUL), (0UL, 0xffffffffUL))
  assert_eq(h.write(0x48UL, 0x1000UL), 0UL)
  h.store_logit(0x1000UL, 1UL)
  h.store_logit(0x1000UL, 1UL)
  h.store_logit(0x1004UL, 2UL)
  h.store_logit(0x1008UL, 3UL)
  assert_eq(h.read(0x4cUL), (0UL, 0xffffffffUL))
}

///|
test "burst snapshot aliases preserve all legacy CSR values and generation brackets" {
  let h = Harness::new()
  h.set("c_cycles_high", 32, 123UL)
  h.set("c_cycles_low", 32, 456UL)
  assert_eq(h.write(0x14UL, 19UL), 0UL)
  assert_eq(h.write(0x10UL, 1UL), 0UL)
  for
    i, addr in [
      0x38UL, 8UL, 12UL, 20UL, 24UL, 28UL, 32UL, 36UL, 40UL, 44UL, 48UL, 52UL, 0x40UL,
      0x38UL,
    ] {
    assert_eq(h.read(0xa0UL + i.to_uint64() * 4UL), h.read(addr))
  }
}
