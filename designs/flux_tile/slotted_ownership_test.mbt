///|
test "slotted execute legal admission wins conflicting new writes and reads through final capture" {
  let simulator = slotted_prepare(2, 2, 2)
  let left = [1, -2, 3, -4]
  let right = [5, -6, 7, -8]
  slotted_load_matrix(simulator, 0, 0, 2, 2, 2, left, right)
  slotted_select(simulator, 0, 0, 0)
  for
    (name, width, value) in [
      ("command_rows", 4, 2),
      ("command_columns", 4, 2),
      ("command_reduction", 13, 2),
      ("command_id", 32, 30),
      ("load_a_slot", 1, 0),
      ("load_b_slot", 1, 0),
      ("load_a_row", 4, 0),
      ("load_b_column", 4, 0),
      ("load_a_index", 13, 0),
      ("load_b_index", 13, 0),
      ("load_a_data", 8, 99),
      ("load_b_data", 8, 99),
      ("result_read_slot", 1, 0),
      ("result_read_row", 4, 0),
      ("result_read_column", 4, 0),
      ("result_read_id", 32, 31),
      ("load_a_valid", 1, 1),
      ("load_b_valid", 1, 1),
      ("result_read_valid", 1, 1),
      ("command_valid", 1, 1),
    ] {
    execute_drive(simulator, name, width, value)
  }
  assert_eq(execute_read(simulator, "command_ready"), 1UL)
  for name in ["load_a_ready", "load_b_ready", "result_read_ready"] {
    assert_eq(execute_read(simulator, name), 0UL)
  }
  simulator.rising_edge("clock")
  execute_drive(simulator, "command_valid", 1, 0)
  slotted_select(simulator, 1, 1, 1)
  execute_drive(simulator, "step_ready", 1, 1)
  for _ in 0..<9 { // Clear + four Run edges + four committed capture writes.
    for name in ["load_a_ready", "load_b_ready", "result_read_ready"] {
      assert_eq(execute_read(simulator, name), 0UL)
    }
    simulator.rising_edge("clock")
    assert_eq(execute_read(simulator, "result_response_valid"), 0UL)
  }
  assert_eq(execute_read(simulator, "completion_valid"), 1UL)
  for name in ["load_a_ready", "load_b_ready", "result_read_ready"] {
    assert_eq(execute_read(simulator, name), 1UL)
  }
  for name in ["load_a_valid", "load_b_valid", "result_read_valid"] {
    execute_drive(simulator, name, 1, 0)
  }
  slotted_completion(simulator, 30, 0, 0UL)
  // Source leases ended at internal publication, despite host completion stall.
  slotted_load(simulator, "a", 0, 0, 0, 42, 1UL)
  slotted_matrix_reads(
    simulator,
    0,
    2,
    2,
    @flux_tile.matmul_int8_oracle(left, right, rows=2, columns=2, reduction=2),
  )
}

///|
test "slotted execute accepts other-slot writes concurrently with Run capture and held completion" {
  let simulator = slotted_prepare(3, 3, 5)
  let left = Array::makei(15, index => index * 3 - 17)
  let right = Array::makei(15, index => index * 5 - 23)
  slotted_load_matrix(simulator, 0, 0, 3, 3, 5, left, right)
  slotted_accept(simulator, 0, 0, 0, 3, 3, 5, 40)
  execute_drive(simulator, "step_ready", 1, 1)
  let other_left = [-128, 127, -1, 0, 1]
  let other_right = [127, -128, 1, -1, 0]
  for k in 0..<5 {
    slotted_load(simulator, "a", 1, 0, k, other_left[k], 1UL)
  }
  for k in 0..<5 {
    slotted_load(simulator, "b", 1, 0, k, other_right[k], 1UL)
  }
  assert_eq(execute_read(simulator, "active_cycles"), 9UL)
  assert_eq(execute_read(simulator, "capture_cycles"), 0UL)
  // Capture is active while this independent overwrite actually handshakes.
  slotted_load(simulator, "a", 1, 0, 0, 33, 1UL)
  other_left[0] = 33
  assert_eq(execute_read(simulator, "capture_cycles"), 1UL)
  execute_drive(simulator, "load_a_slot", 1, 0)
  assert_eq(execute_read(simulator, "load_a_ready"), 0UL)
  slotted_completion(simulator, 40, 0, 0UL)
  assert_eq(execute_read(simulator, "capture_cycles"), 9UL)
  slotted_load(simulator, "b", 1, 0, 4, 9, 1UL)
  other_right[4] = 9
  slotted_ack(simulator)
  slotted_accept(simulator, 1, 1, 1, 1, 1, 5, 41)
  slotted_run(simulator, 1, 1, 5, false)
  slotted_matrix_reads(
    simulator,
    1,
    1,
    1,
    @flux_tile.matmul_int8_oracle(
      other_left,
      other_right,
      rows=1,
      columns=1,
      reduction=5,
    ),
  )
  slotted_matrix_reads(
    simulator,
    0,
    3,
    3,
    @flux_tile.matmul_int8_oracle(left, right, rows=3, columns=3, reduction=5),
  )
}

///|
test "slotted execute held C response isolates independent compute and blocks same-C even on ACK edge" {
  let simulator = slotted_prepare(1, 1, 3)
  slotted_load_matrix(simulator, 0, 0, 1, 1, 1, [2], [3])
  slotted_accept(simulator, 0, 0, 0, 1, 1, 1, 50)
  slotted_run(simulator, 1, 1, 1, false)
  slotted_ack(simulator)
  slotted_read(simulator, 0, 0, 0, 51, 0UL, 6)
  execute_drive(simulator, "result_read_slot", 1, 1)
  execute_drive(simulator, "result_read_id", 32, 99)
  slotted_load_matrix(simulator, 1, 1, 1, 1, 1, [-128], [127])
  slotted_accept(simulator, 1, 1, 1, 1, 1, 1, 52)
  slotted_run(simulator, 1, 1, 1, true)
  slotted_completion(simulator, 52, 1, 0UL)
  slotted_response(simulator, 51, 0, 0UL, 6)
  slotted_ack(simulator)
  slotted_select(simulator, 0, 0, 0)
  assert_eq(execute_read(simulator, "command_ready"), 0UL)
  execute_drive(simulator, "command_rows", 4, 0) // Still blocked despite malformed command.
  execute_drive(simulator, "command_id", 32, 53)
  execute_drive(simulator, "command_valid", 1, 1)
  execute_drive(simulator, "result_response_ready", 1, 1)
  assert_eq(execute_read(simulator, "command_ready"), 0UL)
  slotted_response(simulator, 51, 0, 0UL, 6)
  simulator.rising_edge("clock")
  execute_drive(simulator, "result_response_ready", 1, 0)
  assert_eq(execute_read(simulator, "result_response_valid"), 0UL)
  assert_eq(execute_read(simulator, "completion_valid"), 0UL)
  assert_eq(execute_read(simulator, "command_ready"), 1UL)
  simulator.rising_edge("clock")
  execute_drive(simulator, "command_valid", 1, 0)
  slotted_completion(simulator, 53, 0, 1UL)
  slotted_ack(simulator)
  slotted_read(simulator, 0, 0, 0, 54, 0UL, 6)
  slotted_response_ack(simulator)
  slotted_read(simulator, 1, 0, 0, 55, 0UL, -16256)
  slotted_response_ack(simulator)
}

///|
test "slotted execute accepts a fresh independent C read during Run and capture" {
  for phase in ["run", "capture"] {
    let simulator = slotted_prepare(2, 2, 2)
    slotted_load_matrix(simulator, 0, 0, 1, 1, 1, [2], [3])
    slotted_accept(simulator, 0, 0, 0, 1, 1, 1, 100)
    slotted_run(simulator, 1, 1, 1, false)
    slotted_ack(simulator)
    let left = [1, -2, 3, -4]
    let right = [5, -6, 7, -8]
    slotted_load_matrix(simulator, 1, 1, 2, 2, 2, left, right)
    slotted_accept(simulator, 1, 1, 1, 2, 2, 2, 101)
    simulator.rising_edge("clock") // Clear/prefetch.
    execute_drive(simulator, "step_ready", 1, 1)
    let steps = if phase == "run" { 1 } else { 4 }
    for _ in 0..<steps {
      simulator.rising_edge("clock")
    }
    let active = execute_read(simulator, "active_cycles")
    let capture = execute_read(simulator, "capture_cycles")
    assert_eq(execute_read(simulator, "result_response_valid"), 0UL)
    // This is a new SRAM read handshake during actual active work, not an
    // earlier response merely held across a later computation.
    slotted_read(simulator, 0, 0, 0, 102, 0UL, 6)
    if phase == "run" {
      assert_eq(active, 1UL)
      assert_eq(execute_read(simulator, "active_cycles"), active + 1UL)
      assert_eq(execute_read(simulator, "capture_cycles"), 0UL)
    } else {
      assert_eq(active, 4UL)
      assert_eq(capture, 0UL)
      assert_eq(execute_read(simulator, "active_cycles"), active)
      assert_eq(execute_read(simulator, "capture_cycles"), capture + 1UL)
    }
    slotted_completion(simulator, 101, 1, 0UL)
    slotted_response(simulator, 102, 0, 0UL, 6)
    slotted_response_ack(simulator)
    slotted_matrix_reads(
      simulator,
      1,
      2,
      2,
      @flux_tile.matmul_int8_oracle(left, right, rows=2, columns=2, reduction=2),
    )
  }
}

///|
test "slotted execute new independent C read can accept alongside a legal command" {
  let simulator = slotted_prepare(1, 1, 1)
  slotted_load_matrix(simulator, 0, 0, 1, 1, 1, [2], [3])
  slotted_accept(simulator, 0, 0, 0, 1, 1, 1, 60)
  slotted_run(simulator, 1, 1, 1, false)
  slotted_ack(simulator)
  slotted_load(simulator, "a", 0, 0, 0, 5, 1UL)
  execute_drive(simulator, "result_read_slot", 1, 0)
  execute_drive(simulator, "result_read_row", 4, 0)
  execute_drive(simulator, "result_read_column", 4, 0)
  execute_drive(simulator, "result_read_id", 32, 61)
  execute_drive(simulator, "result_read_valid", 1, 1)
  slotted_accept(simulator, 0, 0, 1, 1, 1, 1, 62)
  execute_drive(simulator, "result_read_valid", 1, 0)
  slotted_response(simulator, 61, 0, 0UL, 6)
  slotted_run(simulator, 1, 1, 1, false)
  slotted_response(simulator, 61, 0, 0UL, 6)
  slotted_response_ack(simulator)
  slotted_matrix_reads(simulator, 1, 1, 1, [15])
}
