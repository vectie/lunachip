///|
test "three client arbiter validates global tag before restoring local tag and poisons on ACK" {
  for owner, prefix in ["reader", "loader", "storer"] {
    for
      (global_tag, status) in [(77UL, 0UL), (0UL, 2UL), (0UL, 3UL), (42UL, 1UL)] {
      let simulator = arbiter_three_prepare()
      arbiter_probe_put(simulator, prefix + "_valid", 1, 1UL)
      arbiter_probe_put(simulator, "bus_request_ready", 1, 1UL)
      simulator.rising_edge("clock")
      simulator.rising_edge("clock")
      for other in ["reader", "loader", "storer"] {
        arbiter_probe_put(simulator, other + "_valid", 1, 1UL)
        arbiter_probe_put(simulator, other + "_response_ready", 1, 1UL)
      }
      arbiter_probe_put(simulator, prefix + "_response_ready", 1, 0UL)
      arbiter_probe_put(simulator, "bus_response_valid", 1, 1UL)
      arbiter_probe_put(simulator, "bus_response_tag", 32, global_tag)
      arbiter_probe_put(simulator, "bus_response_fault", 2, status)
      for _ in 0..<3 {
        arbiter_three_ready_owner(simulator, "response_valid", owner)
        assert_eq(arbiter_probe_read(simulator, prefix + "_response_tag"), 77UL)
        assert_eq(
          arbiter_probe_read(simulator, prefix + "_response_fault"),
          2UL,
        )
        assert_eq(arbiter_probe_read(simulator, "response_ready"), 0UL)
        assert_eq(arbiter_probe_read(simulator, "poisoned"), 0UL)
        simulator.rising_edge("clock")
      }
      arbiter_probe_put(simulator, prefix + "_response_ready", 1, 1UL)
      simulator.rising_edge("clock")
      for _ in 0..<3 {
        assert_eq(arbiter_probe_read(simulator, "poisoned"), 1UL)
        assert_eq(arbiter_probe_read(simulator, "request_valid"), 0UL)
        assert_eq(arbiter_probe_read(simulator, "response_ready"), 0UL)
        assert_eq(
          arbiter_probe_read(simulator, "request_address"),
          (16 * (owner + 1)).to_uint64(),
        )
        for other in ["reader", "loader", "storer"] {
          assert_eq(
            arbiter_probe_read(simulator, other + "_request_ready"),
            0UL,
          )
          assert_eq(
            arbiter_probe_read(simulator, other + "_response_valid"),
            0UL,
          )
        }
        simulator.rising_edge("clock")
      }
    }
  }
}

///|
test "three client arbiter unowned responses are unaccepted without inferred poison" {
  let simulator = arbiter_three_prepare()
  arbiter_probe_put(simulator, "bus_response_valid", 1, 1UL)
  arbiter_probe_put(simulator, "bus_response_tag", 32, 123UL)
  arbiter_probe_put(simulator, "bus_response_fault", 2, 3UL)
  for prefix in ["reader", "loader", "storer"] {
    arbiter_probe_put(simulator, prefix + "_response_ready", 1, 1UL)
  }
  for _ in 0..<3 {
    assert_eq(arbiter_probe_read(simulator, "response_ready"), 0UL)
    assert_eq(arbiter_probe_read(simulator, "poisoned"), 0UL)
    for prefix in ["reader", "loader", "storer"] {
      assert_eq(arbiter_probe_read(simulator, prefix + "_response_valid"), 0UL)
    }
    simulator.rising_edge("clock")
  }
  arbiter_probe_put(simulator, "loader_valid", 1, 1UL)
  simulator.rising_edge("clock")
  assert_eq(arbiter_probe_read(simulator, "request_valid"), 1UL)
  assert_eq(arbiter_probe_read(simulator, "response_ready"), 0UL)
  assert_eq(arbiter_probe_read(simulator, "poisoned"), 0UL)
}

///|
test "three client arbiter joint reset gates every owner then restarts preference and tag" {
  for owner, prefix in ["reader", "loader", "storer"] {
    for mode in 0..<3 {
      let simulator = arbiter_three_prepare()
      arbiter_probe_put(simulator, prefix + "_valid", 1, 1UL)
      arbiter_probe_put(simulator, prefix + "_response_ready", 1, 1UL)
      arbiter_probe_put(simulator, "bus_request_ready", 1, 1UL)
      simulator.rising_edge("clock") // Offer
      arbiter_three_ready_owner(simulator, "request_ready", owner)
      if mode > 0 {
        simulator.rising_edge("clock") // Wait
        arbiter_probe_put(simulator, "bus_response_valid", 1, 1UL)
        if mode == 2 {
          arbiter_probe_put(simulator, "bus_response_tag", 32, 123UL)
          simulator.rising_edge("clock") // Poison
          assert_eq(arbiter_probe_read(simulator, "poisoned"), 1UL)
        }
      }
      for other in ["reader", "loader", "storer"] {
        arbiter_probe_put(simulator, other + "_valid", 1, 1UL)
        arbiter_probe_put(simulator, other + "_response_ready", 1, 1UL)
      }
      arbiter_probe_put(simulator, "reset", 1, 1UL)
      for name in ["request_valid", "response_ready", "poisoned"] {
        assert_eq(arbiter_probe_read(simulator, name), 0UL)
      }
      for other in ["reader", "loader", "storer"] {
        assert_eq(arbiter_probe_read(simulator, other + "_request_ready"), 0UL)
        assert_eq(arbiter_probe_read(simulator, other + "_response_valid"), 0UL)
      }
      simulator.rising_edge("clock")
      // Joint reset really flushes the external response, not just local state.
      arbiter_probe_put(simulator, "bus_response_valid", 1, 0UL)
      arbiter_probe_put(simulator, "bus_response_tag", 32, 0UL)
      arbiter_probe_put(simulator, "reset", 1, 0UL)
      assert_eq(arbiter_probe_read(simulator, "request_valid"), 0UL)
      simulator.rising_edge("clock")
      arbiter_three_ready_owner(simulator, "request_ready", 0)
      assert_eq(arbiter_probe_read(simulator, "request_tag"), 0UL)
      assert_eq(arbiter_probe_read(simulator, "poisoned"), 0UL)
    }
  }
}
