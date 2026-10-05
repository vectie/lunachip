///|
test "arbiter validates global tag before local restoration and poisons on owner acceptance" {
  for owner in ["reader", "engine"] {
    for
      (global_tag, status) in [(77UL, 0UL), (0UL, 2UL), (0UL, 3UL), (42UL, 1UL)] {
      let simulator = arbiter_probe_prepare()
      let other = if owner == "reader" { "engine" } else { "reader" }
      arbiter_probe_put(simulator, owner + "_valid", 1, 1UL)
      arbiter_probe_put(simulator, "bus_request_ready", 1, 1UL)
      simulator.rising_edge("clock")
      simulator.rising_edge("clock")
      arbiter_probe_put(simulator, other + "_valid", 1, 1UL)
      arbiter_probe_put(simulator, other + "_response_ready", 1, 1UL)
      arbiter_probe_put(simulator, "bus_response_valid", 1, 1UL)
      arbiter_probe_put(simulator, "bus_response_tag", 32, global_tag)
      arbiter_probe_put(simulator, "bus_response_fault", 2, status)
      for _ in 0..<3 {
        assert_eq(arbiter_probe_read(simulator, owner + "_response_valid"), 1UL)
        assert_eq(arbiter_probe_read(simulator, other + "_response_valid"), 0UL)
        assert_eq(arbiter_probe_read(simulator, owner + "_response_tag"), 77UL)
        assert_eq(arbiter_probe_read(simulator, owner + "_response_fault"), 2UL)
        assert_eq(arbiter_probe_read(simulator, "response_ready"), 0UL)
        assert_eq(arbiter_probe_read(simulator, "poisoned"), 0UL)
        simulator.rising_edge("clock")
      }
      arbiter_probe_put(simulator, owner + "_response_ready", 1, 1UL)
      simulator.rising_edge("clock")
      for _ in 0..<3 {
        assert_eq(arbiter_probe_read(simulator, "poisoned"), 1UL)
        assert_eq(arbiter_probe_read(simulator, "request_valid"), 0UL)
        assert_eq(arbiter_probe_read(simulator, "response_ready"), 0UL)
        for prefix in ["reader", "engine"] {
          assert_eq(
            arbiter_probe_read(simulator, prefix + "_request_ready"),
            0UL,
          )
          assert_eq(
            arbiter_probe_read(simulator, prefix + "_response_valid"),
            0UL,
          )
        }
        simulator.rising_edge("clock")
      }
    }
  }
}

///|
test "arbiter joint reset gates offers wait responses and sticky fault then restarts tag zero" {
  for mode in 0..<3 {
    let simulator = arbiter_probe_prepare()
    arbiter_probe_put(simulator, "reader_valid", 1, 1UL)
    arbiter_probe_put(simulator, "engine_valid", 1, 1UL)
    arbiter_probe_put(simulator, "bus_request_ready", 1, 1UL)
    arbiter_probe_put(simulator, "reader_response_ready", 1, 1UL)
    simulator.rising_edge("clock") // Offer
    if mode > 0 {
      simulator.rising_edge("clock") // Wait
      arbiter_probe_put(simulator, "bus_response_valid", 1, 1UL)
      if mode == 2 {
        arbiter_probe_put(simulator, "bus_response_tag", 32, 123UL)
        simulator.rising_edge("clock") // Fault
        assert_eq(arbiter_probe_read(simulator, "poisoned"), 1UL)
      }
    }
    arbiter_probe_put(simulator, "reset", 1, 1UL)
    for
      name in [
        "request_valid", "response_ready", "poisoned", "reader_request_ready", "engine_request_ready",
        "reader_response_valid", "engine_response_valid",
      ] {
      assert_eq(arbiter_probe_read(simulator, name), 0UL)
    }
    simulator.rising_edge("clock")
    // Actual environment flush: no old response survives deassertion.
    arbiter_probe_put(simulator, "bus_response_valid", 1, 0UL)
    arbiter_probe_put(simulator, "bus_response_tag", 32, 0UL)
    arbiter_probe_put(simulator, "reset", 1, 0UL)
    assert_eq(arbiter_probe_read(simulator, "request_valid"), 0UL)
    simulator.rising_edge("clock")
    assert_eq(arbiter_probe_read(simulator, "reader_request_ready"), 1UL)
    assert_eq(arbiter_probe_read(simulator, "engine_request_ready"), 0UL)
    assert_eq(arbiter_probe_read(simulator, "request_tag"), 0UL)
    assert_eq(arbiter_probe_read(simulator, "poisoned"), 0UL)
  }
}
