///|
test "MIG ownership observation registers both edges before domain crossing" {
  let h = Harness::new(profile=true)
  h.set("c_busy", 1, 1UL)
  h.set("c_state", 5, 20UL)
  h.set("c_ddr_request_data", 32, 0x80000100UL)
  for name in ["valid", "line", "burst", "wide"] {
    h.set("c_ddr_request_" + name, 1, 1UL)
  }
  assert_eq(h.get("observe_weight_owned"), 0UL)
  h.tick()
  h.set("c_ddr_request_valid", 1, 0UL)
  h.set("ddr_request_ready", 1, 1UL)
  assert_eq(h.get("observe_weight_owned"), 0UL)
  h.tick()
  assert_eq(h.get("observe_issued"), 1UL)
  assert_eq(h.get("observe_weight_owned"), 0UL)
  h.tick()
  assert_eq(h.get("observe_weight_owned"), 1UL)
  h.set("ddr_response_valid", 1, 1UL)
  for i in 0..<64 {
    h.set("ddr_response_last", 1, if i == 63 { 1UL } else { 0UL })
    assert_eq(h.get("observe_weight_owned"), 1UL)
    h.tick()
  }
  assert_eq(h.get("observe_issued"), 0UL)
  assert_eq(h.get("observe_weight_owned"), 1UL)
  h.set("ddr_response_valid", 1, 0UL)
  h.tick()
  assert_eq(h.get("observe_weight_owned"), 0UL)
  h.set("reset", 1, 1UL)
  h.tick()
  assert_eq(h.get("observe_weight_owned"), 0UL)
}

///|
test "cycle profile separates exposed bank wait, matrix issue, scalar execution and idle" {
  let h = Harness::new(profile=true)
  h.set("c_busy", 1, 1UL)
  h.set("c_opcode", 32, 4UL)
  for state in [18, 18, 18, 20, 20, 21, 22, 23, 13, 1, 2, 3, 9, 10, 10, 12, 5] {
    h.set("c_state", 5, state.to_uint64())
    h.tick()
  }
  h.set("c_busy", 1, 0UL)
  h.set("c_state", 5, 14UL)
  assert_eq(h.read(0x100UL), (0UL, 0x50465231UL))
  for
    i, expected in [
      17, 3, 2, 1, 1, 1, 4, 1, 2, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ] {
    assert_eq(
      h.read(0x108UL + 4UL * i.to_uint64()),
      (0UL, expected.to_uint64()),
    )
  }
  assert_eq(h.read(0x160UL + 4UL * 4UL), (0UL, 5UL))
  h.set("reset", 1, 1UL)
  h.tick()
  h.set("reset", 1, 0UL)
  assert_eq(h.read(0x108UL), (0UL, 0UL))
}

///|
test "weight packets distinguish hidden transfer from exposed first and inter-packet waits" {
  let h = Harness::new(profile=true)
  h.set("c_busy", 1, 1UL)
  h.set("c_state", 5, 20UL)
  for name in ["valid", "line", "burst", "wide"] {
    h.set("c_ddr_request_" + name, 1, 1UL)
  }
  h.tick()
  h.set("c_ddr_request_valid", 1, 0UL)
  h.set("ddr_request_ready", 1, 1UL)
  h.tick()
  for
    (state, valid, last) in [
      (20, 0, 0),
      (18, 0, 0),
      (20, 1, 0),
      (20, 1, 0),
      (18, 0, 0),
      (18, 0, 0),
      (18, 1, 0),
      (18, 1, 1),
    ] {
    h.set("c_state", 5, state.to_uint64())
    h.set("ddr_response_valid", 1, valid.to_uint64())
    h.set("ddr_response_last", 1, last.to_uint64())
    h.tick()
  }
  h.set("c_state", 5, 14UL)
  h.set("c_busy", 1, 0UL)
  h.set("ddr_response_valid", 1, 0UL)
  assert_eq(h.get("observe_protocol"), 0UL)
  for
    (counter, expected) in [
      (12, 4),
      (13, 2),
      (14, 2),
      (15, 2),
      (19, 1),
      (20, 2),
      (21, 2),
    ] {
    assert_eq(
      h.read(0x108UL + 4UL * counter.to_uint64()),
      (0UL, expected.to_uint64()),
    )
  }
}
