///|
test "one host generation runs a full segment and tail with a sticky previous DONE" {
  let h = Harness::new(chain=true)
  h.set("c_done", 1, 1UL)
  h.set("ddr_request_ready", 1, 1UL)
  let base = 0x7ffdffc0UL
  assert_eq(h.write(0x3cUL, base), 0UL)
  assert_eq(h.write(0x98UL, 2049UL), 0UL)
  assert_eq(h.write(0x10UL, 2UL), 0UL)
  for segment, count in [2048, 1] {
    assert_eq(h.read(8UL), (0UL, 3UL))
    assert_eq(h.read(0x38UL), (0UL, 1UL))
    assert_eq(h.write(0x98UL, 1UL), 2UL)
    for i in 0..<(count * 16) {
      while h.get("observe_issued") == 0UL {
        h.tick()
      }
      if i == 0 || i == count * 16 - 1 {
        assert_eq(
          h.get("ddr_request_address"),
          base + segment.to_uint64() * 131072UL + i.to_uint64() * 4UL,
        )
      }
      h.set("ddr_response_valid", 1, 1UL)
      h.set("ddr_response_last", 1, 1UL)
      h.tick()
      h.set("ddr_response_valid", 1, 0UL)
    }
    assert_eq(h.get("start"), 1UL)
    assert_eq(h.get("program_count"), count.to_uint64())
    h.tick()
    h.set("c_busy", 1, 1UL)
    h.set("c_done", 1, 0UL)
    for _ in 0..<7 {
      h.tick()
    }
    h.set("c_busy", 1, 0UL)
    h.set("c_done", 1, 1UL)
    h.set("c_cycles_low", 32, 7UL)
    h.set("c_instructions", 32, count.to_uint64() - 1UL)
    h.tick()
  }
  assert_eq(h.read(8UL), (0UL, 5UL))
  assert_eq(h.read(0x200UL), h.read(0x234UL))
  assert_eq(h.read(0x238UL), (0UL, 2UL))
  assert_eq(h.read(0x224UL), (0UL, 2047UL))
  assert_eq(h.read(0x21cUL), (0UL, 14UL))
  assert_eq(h.read(0x23cUL).1, h.read(0x230UL).1 + 16UL)
  assert_eq(h.read(0x3cUL).1, 0x7fffffc0UL)
}
