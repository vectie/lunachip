///|
test "stored execute returns exact missing and full-width bounds faults without a memory access" {
  let simulator = stored_prepare(2, 3, 2)
  for (row, column) in [(0, 0), (15, 15)] {
    stored_read_accept(simulator, row, column, 11, 2UL, 0)
    stored_read_acknowledge(simulator)
  }
  execute_load_matrix(simulator, 2, 3, 1, [2, -3], [4, 5, -6])
  execute_accept(simulator, 2, 3, 1, 12)
  stored_run(simulator, 2, 3, 1, false)
  for (row, column) in [(2, 0), (0, 3), (15, 0), (0, 15), (15, 15)] {
    stored_read_accept(simulator, row, column, 13, 1UL, 0)
    stored_read_acknowledge(simulator)
  }
  stored_matrix_reads(simulator, 2, 3, [8, 10, -12, -12, -15, 18])
  execute_acknowledge(simulator)
  execute_accept(simulator, 1, 1, 1, 14)
  stored_run(simulator, 1, 1, 1, false)
  // Old SRAM bytes may remain, but cells outside the latest active shape
  // cannot be observed as current result data.
  for (row, column) in [(1, 0), (0, 1)] {
    stored_read_accept(simulator, row, column, 15, 1UL, 0)
    stored_read_acknowledge(simulator)
  }
  stored_read_accept(simulator, 0, 0, 16, 0UL, 8)
}

///|
test "stored execute gives reads priority and holds responses across completion acknowledgement" {
  let simulator = stored_prepare(1, 1, 1)
  execute_load_matrix(simulator, 1, 1, 1, [-128], [127])
  execute_accept(simulator, 1, 1, 1, 21)
  stored_run(simulator, 1, 1, 1, false)
  execute_drive(simulator, "completion_ready", 1, 1)
  stored_read_accept(simulator, 0, 0, 22, 0UL, -16256)
  execute_drive(simulator, "completion_ready", 1, 0)
  assert_eq(execute_read(simulator, "completion_valid"), 0UL)
  execute_drive(simulator, "command_valid", 1, 1)
  execute_drive(simulator, "command_id", 32, 99)
  execute_drive(simulator, "result_read_valid", 1, 1)
  for cycle in 0..<4 {
    execute_drive(simulator, "result_read_id", 32, cycle)
    execute_drive(simulator, "result_read_row", 4, 15)
    simulator.rising_edge("clock")
    assert_eq(execute_read(simulator, "command_ready"), 0UL)
    assert_eq(execute_read(simulator, "result_read_ready"), 0UL)
    assert_eq(execute_read(simulator, "result_response_valid"), 1UL)
    assert_eq(execute_read(simulator, "result_response_id"), 22UL)
    assert_eq(execute_read(simulator, "result_response_fault"), 0UL)
    assert_eq(execute_read(simulator, "result_response_data"), 0xffffc080UL)
  }
  // On the response-drain edge both request channels see old pending state,
  // so neither the asserted command nor another read can be accepted.
  execute_drive(simulator, "result_response_ready", 1, 1)
  simulator.rising_edge("clock")
  execute_drive(simulator, "result_response_ready", 1, 0)
  execute_drive(simulator, "command_valid", 1, 0)
  execute_drive(simulator, "result_read_valid", 1, 0)
  assert_eq(execute_read(simulator, "result_response_valid"), 0UL)
  assert_eq(execute_read(simulator, "command_ready"), 1UL)
  // In Idle, a read request beats a simultaneously presented valid command.
  execute_drive(simulator, "command_valid", 1, 1)
  stored_read_accept(simulator, 0, 0, 23, 0UL, -16256)
  assert_eq(execute_read(simulator, "completion_valid"), 0UL)
  execute_drive(simulator, "command_valid", 1, 0)
  stored_read_acknowledge(simulator)
  execute_accept(simulator, 1, 1, 1, 24)
  stored_run(simulator, 1, 1, 1, false)
}

///|
test "stored execute preserves SRAM after invalid commands and blocks requests during capture" {
  let simulator = stored_prepare(2, 3, 3)
  let left = [2, -3, 4, 5]
  let right = [-6, 7, 8, 9, -10, 11]
  execute_load_matrix(simulator, 2, 3, 2, left, right)
  execute_accept(simulator, 2, 3, 2, 31)
  execute_drive(simulator, "result_read_valid", 1, 1)
  execute_drive(simulator, "result_read_row", 4, 0)
  execute_drive(simulator, "result_read_column", 4, 0)
  stored_run(simulator, 2, 3, 2, true)
  assert_eq(execute_read(simulator, "result_response_valid"), 0UL)
  // Clear the request before advancing Done; no busy read was accepted.
  execute_drive(simulator, "result_read_valid", 1, 0)
  let expected = @flux_tile.matmul_int8_oracle(
    left,
    right,
    rows=2,
    columns=3,
    reduction=2,
  )
  stored_matrix_reads(simulator, 2, 3, expected)
  execute_acknowledge(simulator)
  for
    (rows, columns, reduction, fault) in [
      (0, 3, 2, 1UL),
      (2, 3, 4, 1UL),
      (2, 3, 3, 2UL),
    ] {
    execute_accept(simulator, rows, columns, reduction, 32)
    assert_eq(execute_read(simulator, "completion_valid"), 1UL)
    assert_eq(execute_read(simulator, "completion_fault"), fault)
    assert_eq(execute_read(simulator, "capture_cycles"), 0UL)
    stored_matrix_reads(simulator, 2, 3, expected)
    execute_acknowledge(simulator)
  }
}

///|
test "stored execute reset discards compute capture completion and pending read" {
  for phase in ["compute", "capture", "done", "read"] {
    let simulator = stored_prepare(2, 3, 2)
    execute_load_matrix(simulator, 2, 3, 2, [1, 2, 3, 4], [5, 6, 7, 8, 9, 10])
    execute_accept(simulator, 2, 3, 2, 41)
    if phase == "compute" {
      simulator.rising_edge("clock")
      execute_drive(simulator, "step_ready", 1, 1)
      simulator.rising_edge("clock")
    } else if phase == "capture" {
      simulator.rising_edge("clock")
      execute_drive(simulator, "step_ready", 1, 1)
      for _ in 0..<5 {
        simulator.rising_edge("clock")
      }
      simulator.rising_edge("clock")
      assert_eq(execute_read(simulator, "capture_cycles"), 1UL)
      assert_eq(execute_read(simulator, "completion_valid"), 0UL)
    } else {
      stored_run(simulator, 2, 3, 2, false)
      if phase == "read" {
        stored_read_accept(simulator, 0, 0, 42, 0UL, 21)
      }
    }
    execute_drive(simulator, "reset", 1, 1)
    execute_drive(simulator, "result_read_valid", 1, 1)
    execute_drive(simulator, "command_valid", 1, 1)
    execute_drive(simulator, "completion_ready", 1, 1)
    execute_drive(simulator, "result_response_ready", 1, 1)
    assert_eq(execute_read(simulator, "result_read_ready"), 0UL)
    simulator.rising_edge("clock")
    for
      name in [
        "reset", "result_read_valid", "command_valid", "completion_ready", "result_response_ready",
      ] {
      execute_drive(simulator, name, 1, 0)
    }
    assert_eq(execute_read(simulator, "completion_valid"), 0UL)
    assert_eq(execute_read(simulator, "result_response_valid"), 0UL)
    assert_eq(execute_read(simulator, "capture_cycles"), 0UL)
    stored_read_accept(simulator, 0, 0, 43, 2UL, 0)
    stored_read_acknowledge(simulator)
    execute_load_matrix(simulator, 1, 1, 1, [-128], [-128])
    execute_accept(simulator, 1, 1, 1, 44)
    stored_run(simulator, 1, 1, 1, false)
    stored_read_accept(simulator, 0, 0, 45, 0UL, 16384)
  }
}

///|
test "stored execute IR and emitted RTL use one additional deterministic result memory" {
  for (rows, columns, max_reduction) in [(1, 1, 1), (2, 3, 5), (8, 8, 3)] {
    let first = @wire.single_design(
      "StoredExecute",
      @flux_tile.stored_execute_tile(rows~, columns~, max_reduction~),
    )
    let second = @wire.single_design(
      "StoredExecute",
      @flux_tile.stored_execute_tile(rows~, columns~, max_reduction~),
    )
    assert_eq(@codec.serialize(first), @codec.serialize(second))
    assert_eq(
      @systemverilog.emit_design(first).source(),
      @systemverilog.emit_design(second).source(),
    )
    assert_eq(first.modules()[0].memories().length(), rows + columns + 1)
  }
}

///|
test "stored execute canonical graph has a fixed pre-transport golden digest" {
  let design = @wire.single_design(
    "StoredExecute",
    @flux_tile.stored_execute_tile(rows=2, columns=3, max_reduction=5),
  )
  inspect(
    @crypto.bytes_to_hex_string(
      @crypto.sha256(@utf8.encode(@codec.serialize(design))),
    ),
    content="b6a1cbe5a1bfa51966c8632e495bccba2fdcc8e587ce7874d0b0ca78cdcbf73d",
  )
}
