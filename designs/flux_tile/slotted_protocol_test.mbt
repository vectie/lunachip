///|
test "slotted execute rejected preflight preserves C while same-edge load and new read accept" {
  let simulator = slotted_prepare(1, 1, 3)
  slotted_load_matrix(simulator, 0, 0, 1, 1, 1, [2], [3])
  slotted_accept(simulator, 0, 0, 0, 1, 1, 1, 70)
  slotted_run(simulator, 1, 1, 1, false)
  slotted_ack(simulator)
  slotted_load(simulator, "b", 1, 0, 0, 7, 1UL)
  slotted_select(simulator, 1, 1, 0)
  for
    (name, width, value) in [
      ("command_rows", 4, 1),
      ("command_columns", 4, 1),
      ("command_reduction", 13, 1),
      ("command_id", 32, 71),
      ("load_a_slot", 1, 1),
      ("load_a_row", 4, 0),
      ("load_a_index", 13, 0),
      ("load_a_data", 8, 5),
      ("result_read_slot", 1, 0),
      ("result_read_row", 4, 0),
      ("result_read_column", 4, 0),
      ("result_read_id", 32, 72),
      ("command_valid", 1, 1),
      ("load_a_valid", 1, 1),
      ("result_read_valid", 1, 1),
    ] {
    execute_drive(simulator, name, width, value)
  }
  for name in ["command_ready", "load_a_ready", "result_read_ready"] {
    assert_eq(execute_read(simulator, name), 1UL)
  }
  simulator.rising_edge("clock")
  for name in ["command_valid", "load_a_valid", "result_read_valid"] {
    execute_drive(simulator, name, 1, 0)
  }
  slotted_select(simulator, 0, 0, 1)
  slotted_completion(simulator, 71, 0, 2UL)
  assert_eq(execute_read(simulator, "active_cycles"), 0UL)
  assert_eq(execute_read(simulator, "capture_cycles"), 0UL)
  slotted_response(simulator, 72, 0, 0UL, 6)
  slotted_ack(simulator)
  slotted_response_ack(simulator)
  slotted_read(simulator, 1, 15, 15, 73, 2UL, 0)
  slotted_response_ack(simulator)
  // The accepted append established A1 only after failed command preflight.
  slotted_accept(simulator, 1, 1, 0, 1, 1, 1, 74)
  slotted_run(simulator, 1, 1, 1, false)
  slotted_matrix_reads(simulator, 0, 1, 1, [35])
}

///|
test "slotted execute prefixes reject holes and bounds independently per physical slot" {
  let simulator = slotted_prepare(1, 1, 3)
  for index in 0..<3 {
    slotted_load(simulator, "a", 0, 0, index, index + 1, 1UL)
  }
  slotted_load(simulator, "a", 1, 0, 2, 99, 0UL)
  slotted_load(simulator, "a", 0, 1, 0, 99, 0UL)
  slotted_load(simulator, "a", 0, 0, 3, 99, 0UL)
  slotted_load(simulator, "a", 0, 0, 8191, 99, 0UL)
  slotted_load(simulator, "a", 0, 0, 1, -2, 1UL)
  slotted_load_matrix(simulator, 0, 0, 1, 1, 3, [1, -2, 3], [4, 5, 6])
  slotted_accept(simulator, 1, 0, 1, 1, 1, 3, 80)
  slotted_completion(simulator, 80, 1, 2UL)
  slotted_ack(simulator)
  slotted_accept(simulator, 0, 0, 0, 1, 1, 3, 81)
  slotted_run(simulator, 1, 1, 3, false)
  slotted_matrix_reads(simulator, 0, 1, 1, [12])
}

///|
test "slotted execute reset cancels every execution phase and clears both slot leases and validity" {
  for phase in ["clear", "run", "capture", "done", "response"] {
    let simulator = slotted_prepare(2, 2, 2)
    slotted_load_matrix(simulator, 0, 0, 1, 1, 1, [2], [3])
    slotted_accept(simulator, 0, 0, 0, 1, 1, 1, 90)
    slotted_run(simulator, 1, 1, 1, false)
    slotted_ack(simulator)
    slotted_load_matrix(simulator, 1, 1, 2, 2, 2, [1, 2, 3, 4], [5, 6, 7, 8])
    if phase == "response" {
      slotted_read(simulator, 0, 0, 0, 91, 0UL, 6)
    } else {
      slotted_accept(simulator, 1, 1, 1, 2, 2, 2, 92)
      if phase == "done" {
        slotted_run(simulator, 2, 2, 2, false)
      } else if phase != "clear" {
        simulator.rising_edge("clock")
        execute_drive(simulator, "step_ready", 1, 1)
        let steps = if phase == "run" { 1 } else { 4 }
        for _ in 0..<steps {
          simulator.rising_edge("clock")
        }
        if phase == "capture" {
          simulator.rising_edge("clock")
          assert_eq(execute_read(simulator, "capture_cycles"), 1UL)
        }
      }
    }
    for
      name in [
        "command_valid", "load_a_valid", "load_b_valid", "result_read_valid", "completion_ready",
        "result_response_ready",
      ] {
      execute_drive(simulator, name, 1, 1)
    }
    execute_drive(simulator, "reset", 1, 1)
    for
      name in [
        "command_ready", "load_a_ready", "load_b_ready", "result_read_ready", "completion_valid",
        "result_response_valid",
      ] {
      assert_eq(execute_read(simulator, name), 0UL)
    }
    simulator.rising_edge("clock")
    for
      name in [
        "command_valid", "load_a_valid", "load_b_valid", "result_read_valid", "completion_ready",
        "result_response_ready", "reset",
      ] {
      execute_drive(simulator, name, 1, 0)
    }
    for
      name in [
        "accepted_steps", "elapsed_cycles", "active_cycles", "stall_cycles", "capture_cycles",
      ] {
      assert_eq(execute_read(simulator, name), 0UL)
    }
    for slot in 0..<2 {
      slotted_read(simulator, slot, 0, 0, 93 + slot, 2UL, 0)
      slotted_response_ack(simulator)
      slotted_accept(simulator, slot, slot, slot, 1, 1, 1, 95 + slot)
      slotted_completion(simulator, 95 + slot, slot, 2UL)
      slotted_ack(simulator)
    }
    // Real bytes need not be erased; only new initialized prefixes permit use.
    slotted_load_matrix(simulator, 1, 1, 1, 1, 1, [7], [9])
    slotted_accept(simulator, 1, 1, 1, 1, 1, 2, 97)
    slotted_completion(simulator, 97, 1, 2UL)
    slotted_ack(simulator)
    slotted_accept(simulator, 1, 1, 1, 1, 1, 1, 98)
    slotted_run(simulator, 1, 1, 1, false)
    slotted_matrix_reads(simulator, 1, 1, 1, [63])
  }
}
