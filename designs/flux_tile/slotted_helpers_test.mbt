///|
fn slotted_prepare(
  rows : Int32,
  columns : Int32,
  capacity : Int32,
) -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(
    @flux_tile.slotted_execute_tile(rows~, columns~, max_reduction=capacity),
  )
  for
    name in [
      "reset", "load_a_valid", "load_b_valid", "command_valid", "step_ready", "completion_ready",
      "result_read_valid", "result_response_ready", "load_a_slot", "load_b_slot",
      "command_a_slot", "command_b_slot", "command_c_slot", "result_read_slot",
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
  simulator
}

///|
fn slotted_load(
  simulator : @sim.Simulator,
  side : String,
  slot : Int32,
  bank : Int32,
  index : Int32,
  data : Int32,
  ready : UInt64,
) -> Unit raise {
  execute_drive(simulator, "load_" + side + "_slot", 1, slot)
  execute_load(simulator, side, bank, index, data, ready)
}

///|
fn slotted_load_matrix(
  simulator : @sim.Simulator,
  a : Int32,
  b : Int32,
  rows : Int32,
  columns : Int32,
  reduction : Int32,
  left : Array[Int32],
  right : Array[Int32],
) -> Unit raise {
  execute_drive(simulator, "load_a_slot", 1, a)
  execute_drive(simulator, "load_b_slot", 1, b)
  execute_load_matrix(simulator, rows, columns, reduction, left, right)
}

///|
fn slotted_select(
  simulator : @sim.Simulator,
  a : Int32,
  b : Int32,
  c : Int32,
) -> Unit raise {
  execute_drive(simulator, "command_a_slot", 1, a)
  execute_drive(simulator, "command_b_slot", 1, b)
  execute_drive(simulator, "command_c_slot", 1, c)
}

///|
fn slotted_accept(
  simulator : @sim.Simulator,
  a : Int32,
  b : Int32,
  c : Int32,
  rows : Int32,
  columns : Int32,
  reduction : Int32,
  id : Int32,
) -> Unit raise {
  slotted_select(simulator, a, b, c)
  execute_accept(simulator, rows, columns, reduction, id)
}

///|
fn slotted_completion(
  simulator : @sim.Simulator,
  id : Int32,
  slot : Int32,
  fault : UInt64,
) -> Unit raise {
  for _ in 0..<10000 {
    if execute_read(simulator, "completion_valid") == 1UL {
      break
    }
    execute_drive(simulator, "step_ready", 1, 1)
    simulator.rising_edge("clock")
  }
  for _ in 0..<3 {
    assert_eq(execute_read(simulator, "completion_valid"), 1UL)
    assert_eq(execute_read(simulator, "completion_id"), id.to_uint64())
    assert_eq(execute_read(simulator, "completion_c_slot"), slot.to_uint64())
    assert_eq(execute_read(simulator, "completion_fault"), fault)
    simulator.rising_edge("clock")
  }
}

///|
fn slotted_ack(simulator : @sim.Simulator) -> Unit raise {
  execute_drive(simulator, "completion_ready", 1, 1)
  simulator.rising_edge("clock")
  execute_drive(simulator, "completion_ready", 1, 0)
  assert_eq(execute_read(simulator, "completion_valid"), 0UL)
}

///|
fn slotted_run(
  simulator : @sim.Simulator,
  rows : Int32,
  columns : Int32,
  reduction : Int32,
  pause : Bool,
) -> Unit raise {
  let total = reduction + rows + columns - 2
  simulator.rising_edge("clock") // Clear and the first synchronous prefetch.
  let mut stalls = 0
  for step in 0..<total {
    if pause && (step == 0 || step == total - 1) {
      execute_drive(simulator, "step_ready", 1, 0)
      simulator.rising_edge("clock")
      stalls += 1
      assert_eq(execute_read(simulator, "accepted_steps"), step.to_uint64())
    }
    execute_drive(simulator, "step_ready", 1, 1)
    simulator.rising_edge("clock")
    assert_eq(execute_read(simulator, "accepted_steps"), (step + 1).to_uint64())
    assert_eq(execute_read(simulator, "completion_valid"), 0UL)
    assert_eq(execute_read(simulator, "capture_cycles"), 0UL)
  }
  for captured in 0..<(rows * columns) {
    execute_drive(simulator, "step_ready", 1, 0)
    simulator.rising_edge("clock")
    assert_eq(
      execute_read(simulator, "capture_cycles"),
      (captured + 1).to_uint64(),
    )
    assert_eq(
      execute_read(simulator, "completion_valid"),
      if captured == rows * columns - 1 {
        1UL
      } else {
        0UL
      },
    )
  }
  assert_eq(
    execute_read(simulator, "elapsed_cycles"),
    (1 + total + stalls).to_uint64(),
  )
  assert_eq(execute_read(simulator, "active_cycles"), total.to_uint64())
  assert_eq(execute_read(simulator, "stall_cycles"), stalls.to_uint64())
}

///|
fn slotted_response(
  simulator : @sim.Simulator,
  id : Int32,
  slot : Int32,
  fault : UInt64,
  data : Int32,
) -> Unit raise {
  assert_eq(execute_read(simulator, "result_response_valid"), 1UL)
  assert_eq(execute_read(simulator, "result_response_id"), id.to_uint64())
  assert_eq(execute_read(simulator, "result_response_slot"), slot.to_uint64())
  assert_eq(execute_read(simulator, "result_response_fault"), fault)
  let bits = execute_read(simulator, "result_response_data")
  let signed = if bits >= 0x80000000UL {
    (bits.reinterpret_as_int64() - 4294967296L).to_int()
  } else {
    bits.to_int()
  }
  assert_eq(signed, data)
}

///|
fn slotted_read(
  simulator : @sim.Simulator,
  slot : Int32,
  row : Int32,
  column : Int32,
  id : Int32,
  fault : UInt64,
  data : Int32,
) -> Unit raise {
  execute_drive(simulator, "result_read_slot", 1, slot)
  execute_drive(simulator, "result_read_row", 4, row)
  execute_drive(simulator, "result_read_column", 4, column)
  execute_drive(simulator, "result_read_id", 32, id)
  execute_drive(simulator, "result_read_valid", 1, 1)
  assert_eq(execute_read(simulator, "result_read_ready"), 1UL)
  simulator.rising_edge("clock")
  execute_drive(simulator, "result_read_valid", 1, 0)
  slotted_response(simulator, id, slot, fault, data)
}

///|
fn slotted_response_ack(simulator : @sim.Simulator) -> Unit raise {
  execute_drive(simulator, "result_response_ready", 1, 1)
  simulator.rising_edge("clock")
  execute_drive(simulator, "result_response_ready", 1, 0)
  assert_eq(execute_read(simulator, "result_response_valid"), 0UL)
}

///|
fn slotted_matrix_reads(
  simulator : @sim.Simulator,
  slot : Int32,
  rows : Int32,
  columns : Int32,
  expected : Array[Int32],
) -> Unit raise {
  for row in 0..<rows {
    for column in 0..<columns {
      slotted_read(
        simulator,
        slot,
        row,
        column,
        row * 16 + column,
        0UL,
        expected[row * columns + column],
      )
      slotted_response_ack(simulator)
    }
  }
}
