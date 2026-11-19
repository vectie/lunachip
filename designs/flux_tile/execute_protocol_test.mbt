///|
fn execute_fault(
  simulator : @sim.Simulator,
  rows : Int32,
  columns : Int32,
  reduction : Int32,
  fault : UInt64,
) -> Unit raise {
  let before = execute_results(simulator, 2, 2)
  execute_accept(simulator, rows, columns, reduction, 91)
  assert_eq(execute_read(simulator, "completion_valid"), 1UL)
  assert_eq(execute_read(simulator, "completion_fault"), fault)
  assert_eq(execute_read(simulator, "completion_id"), 91UL)
  for _ in 0..<3 {
    execute_drive(simulator, "step_ready", 1, 1)
    simulator.rising_edge("clock")
    assert_eq(execute_results(simulator, 2, 2), before)
    for
      name in [
        "accepted_steps", "elapsed_cycles", "active_cycles", "stall_cycles",
      ] {
      assert_eq(execute_read(simulator, name), 0UL)
    }
    assert_eq(execute_read(simulator, "completion_fault"), fault)
    assert_eq(execute_read(simulator, "completion_id"), 91UL)
  }
  execute_acknowledge(simulator)
}

///|
test "execute tile faults before issue and preserves the previous result" {
  let simulator = execute_prepare(2, 2, 4)
  execute_load_matrix(simulator, 2, 2, 2, [1, 2, 3, 4], [5, 6, 7, 8])
  execute_accept(simulator, 2, 2, 2, 17)
  execute_run(simulator, 2, 2, 2, [1, 2, 3, 4], [5, 6, 7, 8], false)
  execute_acknowledge(simulator)
  for
    (rows, columns, reduction) in [
      (0, 2, 2),
      (3, 2, 2),
      (2, 0, 2),
      (2, 3, 2),
      (2, 2, 0),
      (2, 2, 5),
    ] {
    execute_fault(simulator, rows, columns, reduction, 1UL)
  }
  execute_fault(simulator, 2, 2, 3, 2UL)
  // Dimension failure has priority over missing bank data.
  execute_fault(simulator, 3, 2, 3, 1UL)
}

///|
test "execute tile load guards reject holes, bad banks, and capacity overflow" {
  let simulator = execute_prepare(2, 2, 2)
  for side in ["a", "b"] {
    execute_load(simulator, side, 0, 1, 99, 0UL)
    execute_load(simulator, side, 2, 0, 99, 0UL)
    execute_load(simulator, side, 15, 0, 99, 0UL)
    execute_load(simulator, side, 0, 2, 99, 0UL)
    execute_load(simulator, side, 0, 8191, 99, 0UL)
  }
  execute_fault(simulator, 1, 1, 1, 2UL)
  execute_load(simulator, "a", 0, 0, 2, 1UL)
  execute_load(simulator, "b", 0, 0, 3, 1UL)
  execute_fault(simulator, 1, 1, 2, 2UL)
  execute_load(simulator, "a", 0, 1, 4, 1UL)
  execute_load(simulator, "b", 0, 1, 5, 1UL)
  execute_load(simulator, "a", 0, 2, 99, 0UL)
  execute_load(simulator, "a", 0, 0, -128, 1UL)
  execute_accept(simulator, 1, 1, 2, 6)
  execute_run(simulator, 1, 1, 2, [-128, 4], [3, 5], false)
  assert_eq(execute_results(simulator, 2, 2), [-364, 0, 0, 0])
}

///|
test "execute tile uses pre-edge initialization and later sees same-edge overwrites" {
  let simulator = execute_prepare(1, 1, 2)
  execute_load(simulator, "a", 0, 0, 2, 1UL)
  execute_load(simulator, "b", 0, 0, 4, 1UL)
  execute_load(simulator, "b", 0, 1, 5, 1UL)
  execute_drive(simulator, "load_a_valid", 1, 1)
  execute_drive(simulator, "load_a_index", 13, 1)
  execute_drive(simulator, "load_a_data", 8, 3)
  assert_eq(execute_read(simulator, "load_a_ready"), 1UL)
  execute_accept(simulator, 1, 1, 2, 40)
  execute_drive(simulator, "load_a_valid", 1, 0)
  assert_eq(execute_read(simulator, "completion_valid"), 1UL)
  assert_eq(execute_read(simulator, "completion_fault"), 2UL)
  assert_eq(execute_results(simulator, 1, 1), [0])
  execute_acknowledge(simulator)
  // Prefix is now complete. The overwrite and command both handshake; the
  // Clear edge's read observes the completed previous-edge memory write.
  execute_drive(simulator, "load_a_valid", 1, 1)
  execute_drive(simulator, "load_a_index", 13, 0)
  execute_drive(simulator, "load_a_data", 8, 7)
  assert_eq(execute_read(simulator, "load_a_ready"), 1UL)
  execute_accept(simulator, 1, 1, 2, 41)
  execute_drive(simulator, "load_a_valid", 1, 0)
  execute_run(simulator, 1, 1, 2, [7, 3], [4, 5], false)
  assert_eq(execute_results(simulator, 1, 1), [43])
}

///|
test "execute tile latches requests and holds completion under changing busy inputs" {
  let simulator = execute_prepare(2, 2, 3)
  let left = [2, -3, 4, 5, -6, 7]
  let right = [-8, 9, 10, -11, 12, 13]
  execute_load_matrix(simulator, 2, 2, 3, left, right)
  execute_accept(simulator, 2, 2, 3, 1234)
  for side in ["a", "b"] {
    execute_drive(simulator, "load_\{side}_valid", 1, 1)
    execute_drive(simulator, "load_\{side}_index", 13, 0)
    execute_drive(simulator, "load_\{side}_data", 8, 99)
    assert_eq(execute_read(simulator, "load_\{side}_ready"), 0UL)
  }
  execute_drive(simulator, "command_valid", 1, 1)
  execute_drive(simulator, "command_rows", 4, 0)
  execute_drive(simulator, "command_columns", 4, 15)
  execute_drive(simulator, "command_reduction", 13, 8191)
  execute_drive(simulator, "command_id", 32, 999)
  execute_run(simulator, 2, 2, 3, left, right, true)
  let result = execute_results(simulator, 2, 2)
  let counters = [
    "accepted_steps", "elapsed_cycles", "active_cycles", "stall_cycles",
  ].map(name => execute_read(simulator, name))
  for cycle in 0..<5 {
    execute_drive(simulator, "command_id", 32, cycle)
    execute_drive(simulator, "load_a_data", 8, -128 + cycle)
    simulator.rising_edge("clock")
    assert_eq(execute_read(simulator, "command_ready"), 0UL)
    assert_eq(execute_read(simulator, "load_a_ready"), 0UL)
    assert_eq(execute_read(simulator, "load_b_ready"), 0UL)
    assert_eq(execute_read(simulator, "completion_valid"), 1UL)
    assert_eq(execute_read(simulator, "completion_id"), 1234UL)
    assert_eq(execute_read(simulator, "completion_fault"), 0UL)
    assert_eq(execute_results(simulator, 2, 2), result)
    assert_eq(
      ["accepted_steps", "elapsed_cycles", "active_cycles", "stall_cycles"].map(name => {
          execute_read(simulator, name)
        },
      ),
      counters,
    )
  }
  execute_drive(simulator, "command_valid", 1, 0)
  execute_drive(simulator, "load_a_valid", 1, 0)
  execute_drive(simulator, "load_b_valid", 1, 0)
  execute_acknowledge(simulator)
  execute_accept(simulator, 2, 2, 3, 1235)
  execute_run(simulator, 2, 2, 3, left, right, false)
}

///|
test "execute tile reset cancels every phase and invalidates unreset memory data" {
  for phase in ["idle", "clear", "run", "done"] {
    let simulator = execute_prepare(2, 2, 2)
    execute_load_matrix(simulator, 2, 2, 2, [1, 2, 3, 4], [5, 6, 7, 8])
    if phase != "idle" {
      execute_accept(simulator, 2, 2, 2, 27)
      if phase == "run" {
        simulator.rising_edge("clock")
        execute_drive(simulator, "step_ready", 1, 1)
        simulator.rising_edge("clock")
      } else if phase == "done" {
        execute_run(simulator, 2, 2, 2, [1, 2, 3, 4], [5, 6, 7, 8], false)
      }
    }
    execute_drive(simulator, "reset", 1, 1)
    execute_drive(simulator, "step_ready", 1, 0)
    simulator.rising_edge("clock")
    execute_drive(simulator, "reset", 1, 0)
    assert_eq(execute_read(simulator, "command_ready"), 1UL)
    assert_eq(execute_read(simulator, "completion_valid"), 0UL)
    assert_eq(execute_results(simulator, 2, 2), [0, 0, 0, 0])
    for
      name in [
        "accepted_steps", "elapsed_cycles", "active_cycles", "stall_cycles",
      ] {
      assert_eq(execute_read(simulator, name), 0UL)
    }
    execute_fault(simulator, 1, 1, 1, 2UL)
    execute_load(simulator, "a", 0, 0, -128, 1UL)
    execute_fault(simulator, 1, 1, 1, 2UL)
    // Independently check A-prefix reset by re-resetting and loading only B.
    execute_drive(simulator, "reset", 1, 1)
    simulator.rising_edge("clock")
    execute_drive(simulator, "reset", 1, 0)
    execute_load(simulator, "b", 0, 0, 127, 1UL)
    execute_fault(simulator, 1, 1, 1, 2UL)
    execute_load(simulator, "a", 0, 0, -128, 1UL)
    execute_accept(simulator, 1, 1, 1, 28)
    execute_run(simulator, 1, 1, 1, [-128], [127], false)
  }
}
