///|
test "general-depth FIFO fills, replaces at full, drains, and wraps" {
  let config = @memory.FifoConfig::new(
    "fifo_depth_three",
    UInt(@ir.Width::new(8)),
    3,
    GeneralDepth,
  )
  let simulator = @sim.Simulator::prepare(
    @memory.synchronous_fifo_module(config),
  )
  memory_test_drive_bit(simulator, "reset", 1UL)
  memory_test_drive_bit(simulator, "push_valid", 1UL)
  memory_test_drive(simulator, "push_data", 8, 77UL)
  memory_test_drive_bit(simulator, "pop_request", 1UL)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("empty").to_uint64(), 1UL)
  assert_eq(simulator.output("full").to_uint64(), 0UL)
  assert_eq(simulator.output("occupancy").to_uint64(), 0UL)
  assert_eq(simulator.output("push_ready").to_uint64(), 0UL)
  assert_eq(simulator.output("pop_ready").to_uint64(), 0UL)
  assert_eq(simulator.output("response_valid").to_uint64(), 0UL)

  memory_test_drive_bit(simulator, "reset", 0UL)
  memory_test_drive_bit(simulator, "pop_request", 0UL)
  memory_test_drive_bit(simulator, "push_valid", 1UL)
  for index, value in [10UL, 11UL, 12UL] {
    memory_test_drive(simulator, "push_data", 8, value)
    simulator.rising_edge("clock")
    assert_eq(
      simulator.output("occupancy").to_uint64(),
      (index + 1).to_uint64(),
    )
  }
  assert_eq(simulator.output("full").to_uint64(), 1UL)
  assert_eq(simulator.output("push_ready").to_uint64(), 0UL)

  // A blocked push must not overwrite the oldest entry.
  memory_test_drive(simulator, "push_data", 8, 88UL)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("occupancy").to_uint64(), 3UL)

  // Full replacement accepts both operations. ReadOld returns the displaced
  // oldest entry, and the new word becomes the newest entry.
  memory_test_drive_bit(simulator, "pop_request", 1UL)
  memory_test_drive(simulator, "push_data", 8, 99UL)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("response_valid").to_uint64(), 1UL)
  assert_eq(simulator.output("response_data").to_uint64(), 10UL)
  assert_eq(simulator.output("occupancy").to_uint64(), 3UL)

  memory_test_drive_bit(simulator, "push_valid", 0UL)
  for value in [11UL, 12UL, 99UL] {
    simulator.rising_edge("clock")
    assert_eq(simulator.output("response_valid").to_uint64(), 1UL)
    assert_eq(simulator.output("response_data").to_uint64(), value)
  }
  assert_eq(simulator.output("empty").to_uint64(), 1UL)
  assert_eq(simulator.output("pop_ready").to_uint64(), 0UL)

  memory_test_drive_bit(simulator, "pop_request", 0UL)
  memory_test_drive_bit(simulator, "push_valid", 1UL)
  memory_test_drive(simulator, "push_data", 8, 44UL)
  simulator.rising_edge("clock")
  memory_test_drive_bit(simulator, "push_valid", 0UL)
  memory_test_drive_bit(simulator, "pop_request", 1UL)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("response_data").to_uint64(), 44UL)
  assert_eq(simulator.output("empty").to_uint64(), 1UL)
  memory_test_drive_bit(simulator, "pop_request", 0UL)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("response_valid").to_uint64(), 0UL)
}

///|
test "single-entry FIFO uses explicit wrap and full/empty transitions" {
  let simulator = @sim.Simulator::prepare(
    @memory.synchronous_fifo_module(
      @memory.FifoConfig::new(
        "single_fifo",
        UInt(@ir.Width::new(4)),
        1,
        PowerOfTwo,
      ),
    ),
  )
  memory_test_drive_bit(simulator, "reset", 1UL)
  memory_test_drive_bit(simulator, "push_valid", 0UL)
  memory_test_drive(simulator, "push_data", 4, 0UL)
  memory_test_drive_bit(simulator, "pop_request", 0UL)
  simulator.rising_edge("clock")
  memory_test_drive_bit(simulator, "reset", 0UL)
  memory_test_drive_bit(simulator, "push_valid", 1UL)
  memory_test_drive(simulator, "push_data", 4, 13UL)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("full").to_uint64(), 1UL)
  memory_test_drive_bit(simulator, "push_valid", 0UL)
  memory_test_drive_bit(simulator, "pop_request", 1UL)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("response_data").to_uint64(), 13UL)
  assert_eq(simulator.output("empty").to_uint64(), 1UL)
}
