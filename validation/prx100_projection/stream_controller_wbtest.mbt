///|
fn waiting_weight_stream() -> Bench raise {
  let b = bench()
  b.configure(1)
  b.environment(stalled=true)
  assert_eq(b.write(16UL, 1UL), 0UL)
  for _ in 0..<80 {
    if value(b.sim, "ddr_request_valid") == 1UL {
      break
    }
    b.step()
  }
  assert_eq(value(b.sim, "ddr_request_valid"), 1UL)
  assert_eq(value(b.sim, "ddr_request_burst"), 0UL)
  b.set("ddr_request_ready", 1, 1UL)
  b.sim.rising_edge("clock")
  b.set("ddr_request_ready", 1, 0UL)
  for beat in 0..<4 {
    b.set("ddr_response_valid", 1, 1UL)
    b.set("ddr_response_data", 32, beat.to_uint64())
    b.set("ddr_response_last", 1, if beat == 3 { 1UL } else { 0UL })
    b.sim.rising_edge("clock")
  }
  b.set("ddr_response_valid", 1, 0UL)
  for _ in 0..<3 {
    b.sim.rising_edge("clock")
  }
  assert_eq(value(b.sim, "ddr_request_valid"), 1UL)
  assert_eq(value(b.sim, "ddr_request_burst"), 1UL)
  b.set("ddr_request_ready", 1, 1UL)
  b.sim.rising_edge("clock")
  b.set("ddr_request_ready", 1, 0UL)
  b
}

///|
test "weight stream boundary prefixes reject early or missing last and faults" {
  for faulted in [false, true] {
    for bad_beat in [0, 3, 4, 15, 16, 30, 31] {
      let b = waiting_weight_stream()
      for beat in 0..<=bad_beat {
        b.set("ddr_response_valid", 1, 1UL)
        b.set("ddr_response_data", 32, beat.to_uint64())
        b.set(
          "ddr_response_fault",
          2,
          if faulted && beat == bad_beat {
            2UL
          } else {
            0UL
          },
        )
        b.set(
          "ddr_response_last",
          1,
          if faulted {
            if beat == 31 {
              1UL
            } else {
              0UL
            }
          } else if beat == bad_beat && bad_beat < 31 {
            1UL
          } else {
            0UL
          },
        )
        b.sim.rising_edge("clock")
      }
      b.set("ddr_response_valid", 1, 0UL)
      assert_eq(b.observe("state"), 17UL)
      assert_eq(b.read(12UL), if faulted { 3UL } else { 7UL })
      assert_eq(b.read(96UL), 4UL + bad_beat.to_uint64())
      assert_eq(b.read(108UL), 0UL)
      assert_eq(value(b.sim, "publish_valid"), 0UL)
    }
  }
}
