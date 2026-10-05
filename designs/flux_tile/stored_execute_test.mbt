///|
fn stored_prepare(
  rows : Int,
  columns : Int,
  capacity : Int,
) -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(
    @flux_tile.stored_execute_tile(rows~, columns~, max_reduction=capacity),
  )
  for
    name in [
      "reset", "load_a_valid", "load_b_valid", "command_valid", "step_ready", "completion_ready",
      "result_read_valid", "result_response_ready",
    ] {
    execute_drive(simulator, name, 1, if name == "reset" { 1 } else { 0 })
  }
  for
    name in [
      "load_a_row", "load_b_column", "command_rows", "command_columns", "result_read_row",
      "result_read_column",
    ] {
    execute_drive(simulator, name, 4, 0)
  }
  for name in ["load_a_index", "load_b_index", "command_reduction"] {
    execute_drive(simulator, name, 13, 0)
  }
  for name in ["load_a_data", "load_b_data"] {
    execute_drive(simulator, name, 8, 0)
  }
  for name in ["command_id", "result_read_id"] {
    execute_drive(simulator, name, 32, 0)
  }
  simulator.rising_edge("clock")
  execute_drive(simulator, "reset", 1, 0)
  assert_eq(execute_read(simulator, "command_ready"), 1UL)
  assert_eq(execute_read(simulator, "result_read_ready"), 1UL)
  assert_eq(execute_read(simulator, "result_response_valid"), 0UL)
  simulator
}

///|
fn stored_read_accept(
  simulator : @sim.Simulator,
  row : Int,
  column : Int,
  id : Int,
  fault : UInt64,
  value : Int,
) -> Unit raise {
  assert_eq(execute_read(simulator, "result_read_ready"), 1UL)
  assert_eq(execute_read(simulator, "result_response_valid"), 0UL)
  execute_drive(simulator, "result_read_row", 4, row)
  execute_drive(simulator, "result_read_column", 4, column)
  execute_drive(simulator, "result_read_id", 32, id)
  execute_drive(simulator, "result_read_valid", 1, 1)
  assert_eq(execute_read(simulator, "command_ready"), 0UL)
  // Data and metadata become visible after this one synchronous read edge.
  simulator.rising_edge("clock")
  execute_drive(simulator, "result_read_valid", 1, 0)
  assert_eq(execute_read(simulator, "result_response_valid"), 1UL)
  assert_eq(execute_read(simulator, "result_read_ready"), 0UL)
  assert_eq(execute_read(simulator, "command_ready"), 0UL)
  assert_eq(execute_read(simulator, "result_response_id"), id.to_uint64())
  assert_eq(execute_read(simulator, "result_response_fault"), fault)
  let bits = execute_read(simulator, "result_response_data")
  let signed = if bits >= 0x80000000UL {
    (bits.reinterpret_as_int64() - 4294967296L).to_int()
  } else {
    bits.to_int()
  }
  assert_eq(signed, value)
}

///|
fn stored_read_acknowledge(simulator : @sim.Simulator) -> Unit raise {
  execute_drive(simulator, "result_response_ready", 1, 1)
  simulator.rising_edge("clock")
  execute_drive(simulator, "result_response_ready", 1, 0)
  assert_eq(execute_read(simulator, "result_response_valid"), 0UL)
  assert_eq(execute_read(simulator, "result_read_ready"), 1UL)
}

///|
fn stored_matrix_reads(
  simulator : @sim.Simulator,
  rows : Int,
  columns : Int,
  expected : Array[Int],
) -> Unit raise {
  for row in 0..<rows {
    for column in 0..<columns {
      stored_read_accept(
        simulator,
        row,
        column,
        row * 16 + column,
        0UL,
        expected[row * columns + column],
      )
      stored_read_acknowledge(simulator)
    }
  }
}

///|
fn stored_run(
  simulator : @sim.Simulator,
  rows : Int,
  columns : Int,
  reduction : Int,
  pause : Bool,
) -> Unit raise {
  let total = reduction + rows + columns - 2
  let start = simulator.cycle().value()
  simulator.rising_edge("clock") // Clear/read launch.
  let mut stalls = 0
  for step in 0..<total {
    if pause && (step == 0 || step == total - 1) {
      execute_drive(simulator, "step_ready", 1, 0)
      simulator.rising_edge("clock")
      stalls += 1
      assert_eq(execute_read(simulator, "accepted_steps"), step.to_uint64())
      assert_eq(execute_read(simulator, "result_read_ready"), 0UL)
    }
    execute_drive(simulator, "step_ready", 1, 1)
    simulator.rising_edge("clock")
    assert_eq(execute_read(simulator, "accepted_steps"), (step + 1).to_uint64())
    assert_eq(execute_read(simulator, "completion_valid"), 0UL)
    assert_eq(execute_read(simulator, "result_read_ready"), 0UL)
    assert_eq(execute_read(simulator, "command_ready"), 0UL)
    assert_eq(execute_read(simulator, "capture_cycles"), 0UL)
  }
  let compute_elapsed = (1 + total + stalls).to_uint64()
  assert_eq(execute_read(simulator, "elapsed_cycles"), compute_elapsed)
  for captured in 0..<(rows * columns) {
    // Capture is independent of the array's step permission.
    execute_drive(simulator, "step_ready", 1, 0)
    simulator.rising_edge("clock")
    assert_eq(
      execute_read(simulator, "completion_valid"),
      if captured == rows * columns - 1 {
        1UL
      } else {
        0UL
      },
    )
    assert_eq(execute_read(simulator, "elapsed_cycles"), compute_elapsed)
    assert_eq(execute_read(simulator, "active_cycles"), total.to_uint64())
    assert_eq(execute_read(simulator, "stall_cycles"), stalls.to_uint64())
    assert_eq(
      execute_read(simulator, "capture_cycles"),
      (captured + 1).to_uint64(),
    )
    if captured != rows * columns - 1 {
      assert_eq(execute_read(simulator, "result_read_ready"), 0UL)
    }
  }
  assert_eq(
    simulator.cycle().value() - start,
    (1 + total + stalls + rows * columns).to_uint64(),
  )
  assert_eq(execute_read(simulator, "completion_fault"), 0UL)
  assert_eq(execute_read(simulator, "result_read_ready"), 1UL)
}

///|
test "stored execute writes signed oracle results before publishing completion" {
  for (rows, columns, reduction) in [(1, 1, 1), (2, 3, 5), (3, 2, 2), (8, 8, 3)] {
    let simulator = stored_prepare(rows, columns, reduction)
    let extrema = [-128, 127, -1, 0, 1]
    let left = Array::makei(rows * reduction, index => extrema[index * 3 % 5])
    let right = Array::makei(reduction * columns, index => {
      extrema[(index * 2 + 1) % 5]
    })
    execute_load_matrix(simulator, rows, columns, reduction, left, right)
    execute_accept(simulator, rows, columns, reduction, 35)
    stored_run(simulator, rows, columns, reduction, true)
    assert_eq(execute_read(simulator, "completion_id"), 35UL)
    let expected = @flux_tile.matmul_int8_oracle(
      left,
      right,
      rows~,
      columns~,
      reduction~,
    )
    stored_matrix_reads(simulator, rows, columns, expected)
  }
}

///|
test "stored execute uses fixed physical stride for smaller active results and reuse" {
  let simulator = stored_prepare(3, 4, 3)
  let left = [1, -2, 3, -4, 5, -6]
  let right = [7, -8, 9, 10, -11, 12]
  execute_load_matrix(simulator, 2, 2, 3, left, right)
  execute_accept(simulator, 2, 2, 3, 50)
  stored_run(simulator, 2, 2, 3, false)
  stored_matrix_reads(
    simulator,
    2,
    2,
    @flux_tile.matmul_int8_oracle(left, right, rows=2, columns=2, reduction=3),
  )
  execute_acknowledge(simulator)
  execute_load_matrix(simulator, 1, 3, 1, [-128], [-128, 0, 127])
  execute_accept(simulator, 1, 3, 1, 51)
  stored_run(simulator, 1, 3, 1, false)
  stored_matrix_reads(simulator, 1, 3, [16384, 0, -16256])
}
