///|
test "three client arbiter cyclic fairness global tags and owner local remote errors" {
  let simulator = arbiter_three_prepare()
  arbiter_probe_put(simulator, "bus_request_ready", 1, 1UL)
  for prefix in ["reader", "loader", "storer"] {
    arbiter_probe_put(simulator, prefix + "_valid", 1, 1UL)
    arbiter_probe_put(simulator, prefix + "_response_ready", 1, 1UL)
  }
  for transaction in 0..<12 {
    arbiter_three_transaction(
      simulator,
      transaction % 3,
      transaction.to_uint64(),
      if transaction < 3 {
        1UL
      } else {
        0UL
      },
    )
  }
}

///|
test "three client arbiter skips absent peers for sole and paired requesters" {
  // Reset prefers reader, but neither loader nor storer requires a reader.
  for owner in 0..<3 {
    let simulator = arbiter_three_prepare()
    arbiter_probe_put(simulator, "bus_request_ready", 1, 1UL)
    for index, prefix in ["reader", "loader", "storer"] {
      arbiter_probe_put(
        simulator,
        prefix + "_valid",
        1,
        if index == owner {
          1UL
        } else {
          0UL
        },
      )
      arbiter_probe_put(simulator, prefix + "_response_ready", 1, 1UL)
    }
    for transaction in 0..<4 {
      arbiter_three_transaction(simulator, owner, transaction.to_uint64(), 0UL)
    }
  }
  for absent in 0..<3 {
    let simulator = arbiter_three_prepare()
    arbiter_probe_put(simulator, "bus_request_ready", 1, 1UL)
    let participants = if absent == 0 {
      [1, 2]
    } else if absent == 1 {
      [0, 2]
    } else {
      [0, 1]
    }
    for index, prefix in ["reader", "loader", "storer"] {
      arbiter_probe_put(
        simulator,
        prefix + "_valid",
        1,
        if index == absent {
          0UL
        } else {
          1UL
        },
      )
      arbiter_probe_put(simulator, prefix + "_response_ready", 1, 1UL)
    }
    for transaction in 0..<8 {
      arbiter_three_transaction(
        simulator,
        participants[transaction % 2],
        transaction.to_uint64(),
        0UL,
      )
    }
  }
}

///|
test "three client arbiter captures every offered field and holds owner mapping" {
  for owner, prefix in ["reader", "loader", "storer"] {
    let simulator = arbiter_three_prepare()
    arbiter_probe_put(simulator, prefix + "_valid", 1, 1UL)
    arbiter_probe_put(simulator, prefix + "_tag", 32, 91UL)
    simulator.rising_edge("clock")
    let payload = arbiter_probe_payload(simulator)
    assert_eq(payload, [
      if owner == 2 {
        1UL
      } else {
        0UL
      },
      (16 * (owner + 1)).to_uint64(),
      if owner == 2 {
        4UL
      } else {
        1UL
      },
      if owner == 2 {
        15UL
      } else {
        1UL
      },
      (128 + owner).to_uint64(),
      0UL,
    ])
    // Change all contenders, including the now-snapshotted owner's live input.
    for other in ["reader", "loader", "storer"] {
      for
        (field, width, value) in [
          ("valid", 1, 1UL),
          ("write", 1, if owner == 2 { 0UL } else { 1UL }),
          ("address", 32, 999UL),
          ("bytes", 3, 2UL),
          ("mask", 4, 7UL),
          ("data", 32, 0xfacebeefUL),
          ("tag", 32, 123UL),
        ] {
        arbiter_probe_put(simulator, other + "_" + field, width, value)
      }
      arbiter_probe_put(simulator, other + "_response_ready", 1, 1UL)
    }
    for _ in 0..<4 {
      assert_eq(arbiter_probe_read(simulator, "request_valid"), 1UL)
      assert_eq(arbiter_probe_payload(simulator), payload)
      for other in ["reader", "loader", "storer"] {
        assert_eq(arbiter_probe_read(simulator, other + "_request_ready"), 0UL)
      }
      simulator.rising_edge("clock")
    }
    arbiter_probe_put(simulator, "bus_request_ready", 1, 1UL)
    arbiter_three_ready_owner(simulator, "request_ready", owner)
    simulator.rising_edge("clock")
    arbiter_probe_put(simulator, prefix + "_response_ready", 1, 0UL)
    arbiter_probe_put(simulator, "bus_response_data", 32, 0xdeadbeefUL)
    arbiter_probe_put(simulator, "bus_response_valid", 1, 1UL)
    for _ in 0..<4 {
      assert_eq(arbiter_probe_read(simulator, "response_ready"), 0UL)
      assert_eq(arbiter_probe_read(simulator, "request_valid"), 0UL)
      arbiter_three_ready_owner(simulator, "response_valid", owner)
      assert_eq(arbiter_probe_read(simulator, prefix + "_response_tag"), 91UL)
      assert_eq(
        arbiter_probe_read(simulator, prefix + "_response_data"),
        0xdeadbeefUL,
      )
      simulator.rising_edge("clock")
    }
    arbiter_probe_put(simulator, prefix + "_response_ready", 1, 1UL)
    assert_eq(arbiter_probe_read(simulator, "response_ready"), 1UL)
    simulator.rising_edge("clock")
    arbiter_probe_put(simulator, "bus_response_valid", 1, 0UL)
    assert_eq(arbiter_probe_read(simulator, "request_valid"), 0UL)
  }
}
