///|
test "early and missing fourth DDR last fail before operand publication" {
  for bad_beat in 0..<4 {
    let b = bench()
    b.configure(1)
    b.environment(stalled=true)
    assert_eq(b.write(16UL, 1UL), 0UL)
    for _ in 0..<80 {
      b.step()
      if value(b.sim, "ddr_request_valid") == 1UL {
        break
      }
    }
    assert_eq(value(b.sim, "ddr_request_line"), 1UL)
    assert_eq(value(b.sim, "ddr_request_write"), 0UL)
    b.set("ddr_request_ready", 1, 1UL)
    b.sim.rising_edge("clock")
    b.set("ddr_request_ready", 1, 0UL)
    for beat in 0..<=bad_beat {
      b.set("ddr_response_valid", 1, 1UL)
      b.set("ddr_response_data", 32, 0x80010203UL + beat.to_uint64())
      b.set("ddr_response_fault", 2, 0UL)
      b.set(
        "ddr_response_last",
        1,
        if beat == bad_beat && bad_beat < 3 {
          1UL
        } else {
          0UL
        },
      )
      b.sim.rising_edge("clock")
    }
    b.set("ddr_response_valid", 1, 0UL)
    assert_eq(b.observe("state"), 17UL)
    assert_eq(value(b.sim, "publish_valid"), 0UL)
    assert_eq(b.read(12UL), 7UL)
    assert_eq(b.read(108UL), 0UL)
    assert_eq(b.read(96UL), bad_beat.to_uint64())
  }
}

///|
test "a fault in each DDR stream beat leaves an unpublished operand prefix" {
  for fault_beat in 0..<4 {
    let b = bench()
    b.configure(1)
    b.environment(stalled=true)
    assert_eq(b.write(16UL, 1UL), 0UL)
    for _ in 0..<80 {
      b.step()
      if value(b.sim, "ddr_request_valid") == 1UL {
        break
      }
    }
    b.set("ddr_request_ready", 1, 1UL)
    b.sim.rising_edge("clock")
    b.set("ddr_request_ready", 1, 0UL)
    for beat in 0..<=fault_beat {
      b.set("ddr_response_valid", 1, 1UL)
      b.set("ddr_response_data", 32, beat.to_uint64())
      b.set("ddr_response_fault", 2, if beat == fault_beat { 2UL } else { 0UL })
      b.set("ddr_response_last", 1, if beat == 3 { 1UL } else { 0UL })
      b.sim.rising_edge("clock")
    }
    b.set("ddr_response_valid", 1, 0UL)
    assert_eq(b.observe("state"), 17UL)
    assert_eq(b.read(12UL), 3UL)
    assert_eq(b.read(96UL), fault_beat.to_uint64())
    assert_eq(b.read(108UL), 0UL)
  }
}
