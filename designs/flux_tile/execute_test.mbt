///|
fn execute_drive(
  simulator : @sim.Simulator,
  name : String,
  width : Int,
  value : Int,
) -> Unit raise {
  let bits = if width == 8 { value & 255 } else { value }
  simulator.set_input(
    name,
    @wave.LogicValue::from_uint64(width~, value=bits.to_uint64()),
  )
  simulator.settle()
}

///|
fn execute_read(simulator : @sim.Simulator, name : String) -> UInt64 raise {
  simulator.output(name).to_uint64()
}

///|
fn execute_results(
  simulator : @sim.Simulator,
  rows : Int,
  columns : Int,
) -> Array[Int] raise {
  Array::makei(rows * columns, index => {
    let bits = execute_read(
      simulator,
      "accumulator_\{index / columns}_\{index % columns}",
    )
    if bits >= 0x80000000UL {
      (bits.reinterpret_as_int64() - 4294967296L).to_int()
    } else {
      bits.to_int()
    }
  })
}

///|
fn execute_prepare(
  rows : Int,
  columns : Int,
  capacity : Int,
) -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(
    @flux_tile.execute_tile(rows~, columns~, max_reduction=capacity),
  )
  for
    name in [
      "reset", "load_a_valid", "load_b_valid", "command_valid", "step_ready", "completion_ready",
    ] {
    execute_drive(simulator, name, 1, if name == "reset" { 1 } else { 0 })
  }
  for name in ["load_a_row", "load_b_column", "command_rows", "command_columns"] {
    execute_drive(simulator, name, 4, 0)
  }
  for name in ["load_a_index", "load_b_index", "command_reduction"] {
    execute_drive(simulator, name, 13, 0)
  }
  for name in ["load_a_data", "load_b_data"] {
    execute_drive(simulator, name, 8, 0)
  }
  execute_drive(simulator, "command_id", 32, 0)
  simulator.rising_edge("clock")
  execute_drive(simulator, "reset", 1, 0)
  assert_eq(execute_read(simulator, "command_ready"), 1UL)
  assert_eq(execute_read(simulator, "completion_valid"), 0UL)
  simulator
}

///|
fn execute_load(
  simulator : @sim.Simulator,
  side : String,
  bank : Int,
  index : Int,
  value : Int,
  ready : UInt64,
) -> Unit raise {
  execute_drive(simulator, "load_\{side}_valid", 1, 1)
  execute_drive(
    simulator,
    "load_\{side}_" + (if side == "a" { "row" } else { "column" }),
    4,
    bank,
  )
  execute_drive(simulator, "load_\{side}_index", 13, index)
  execute_drive(simulator, "load_\{side}_data", 8, value)
  assert_eq(execute_read(simulator, "load_\{side}_ready"), ready)
  simulator.rising_edge("clock")
  execute_drive(simulator, "load_\{side}_valid", 1, 0)
}

///|
fn execute_load_matrix(
  simulator : @sim.Simulator,
  rows : Int,
  columns : Int,
  reduction : Int,
  left : Array[Int],
  right : Array[Int],
) -> Unit raise {
  for row in 0..<rows {
    for k in 0..<reduction {
      execute_load(simulator, "a", row, k, left[row * reduction + k], 1UL)
    }
  }
  for column in 0..<columns {
    for k in 0..<reduction {
      execute_load(simulator, "b", column, k, right[k * columns + column], 1UL)
    }
  }
}

///|
fn execute_accept(
  simulator : @sim.Simulator,
  rows : Int,
  columns : Int,
  reduction : Int,
  id : Int,
) -> Unit raise {
  assert_eq(execute_read(simulator, "command_ready"), 1UL)
  execute_drive(simulator, "command_rows", 4, rows)
  execute_drive(simulator, "command_columns", 4, columns)
  execute_drive(simulator, "command_reduction", 13, reduction)
  execute_drive(simulator, "command_id", 32, id)
  execute_drive(simulator, "command_valid", 1, 1)
  simulator.rising_edge("clock")
  execute_drive(simulator, "command_valid", 1, 0)
  for
    name in [
      "accepted_steps", "elapsed_cycles", "active_cycles", "stall_cycles",
    ] {
    assert_eq(execute_read(simulator, name), 0UL)
  }
}

///|
fn execute_acknowledge(simulator : @sim.Simulator) -> Unit raise {
  assert_eq(execute_read(simulator, "completion_valid"), 1UL)
  assert_eq(execute_read(simulator, "command_ready"), 0UL)
  execute_drive(simulator, "completion_ready", 1, 1)
  simulator.rising_edge("clock")
  execute_drive(simulator, "completion_ready", 1, 0)
  assert_eq(execute_read(simulator, "completion_valid"), 0UL)
  assert_eq(execute_read(simulator, "command_ready"), 1UL)
}

///|
// Observe actual cell state against a mathematical wavefront, then compare
// final values with the independent row/column/reduction oracle.
fn execute_run(
  simulator : @sim.Simulator,
  rows : Int,
  columns : Int,
  reduction : Int,
  left : Array[Int],
  right : Array[Int],
  pause : Bool,
) -> Unit raise {
  let expected = Array::make(rows * columns, 0)
  let total = reduction + rows + columns - 2
  assert_eq(execute_read(simulator, "completion_valid"), 0UL)
  simulator.rising_edge("clock") // Clear resets array and prefetches s=0.
  assert_eq(execute_read(simulator, "elapsed_cycles"), 1UL)
  assert_eq(execute_results(simulator, rows, columns), expected)
  let mut stalls = 0
  for step in 0..<total {
    if pause && (step == 0 || step == total - 1 || step % 3 == 1) {
      execute_drive(simulator, "step_ready", 1, 0)
      for _ in 0..<2 {
        simulator.rising_edge("clock")
        stalls += 1
        assert_eq(execute_results(simulator, rows, columns), expected)
        assert_eq(execute_read(simulator, "accepted_steps"), step.to_uint64())
        assert_eq(execute_read(simulator, "active_cycles"), step.to_uint64())
        assert_eq(execute_read(simulator, "stall_cycles"), stalls.to_uint64())
        assert_eq(
          execute_read(simulator, "elapsed_cycles"),
          (1 + step + stalls).to_uint64(),
        )
        assert_eq(execute_read(simulator, "completion_valid"), 0UL)
      }
    }
    execute_drive(simulator, "step_ready", 1, 1)
    simulator.rising_edge("clock")
    for row in 0..<rows {
      for column in 0..<columns {
        let k = step - row - column
        if k >= 0 && k < reduction {
          expected[row * columns + column] += left[row * reduction + k] *
            right[k * columns + column]
        }
      }
    }
    assert_eq(execute_results(simulator, rows, columns), expected)
    assert_eq(execute_read(simulator, "accepted_steps"), (step + 1).to_uint64())
    assert_eq(execute_read(simulator, "active_cycles"), (step + 1).to_uint64())
    assert_eq(
      execute_read(simulator, "elapsed_cycles"),
      (2 + step + stalls).to_uint64(),
    )
    assert_eq(
      execute_read(simulator, "completion_valid"),
      if step == total - 1 {
        1UL
      } else {
        0UL
      },
    )
  }
  assert_eq(execute_read(simulator, "completion_fault"), 0UL)
  assert_eq(
    execute_results(simulator, rows, columns),
    @flux_tile.matmul_int8_oracle(left, right, rows~, columns~, reduction~),
  )
}

///|
test "execute tile runs synchronous bank data through rectangular and 8x8 wavefronts" {
  for
    (rows, columns, reduction) in [
      (1, 1, 1),
      (2, 3, 5),
      (3, 2, 7),
      (1, 8, 3),
      (8, 1, 3),
      (8, 8, 4),
    ] {
    let simulator = execute_prepare(rows, columns, reduction)
    let extrema = [-128, 127, -1, 0, 1, 126, -127]
    let left = Array::makei(rows * reduction, index => {
      extrema[index * 3 % extrema.length()]
    })
    let right = Array::makei(reduction * columns, index => {
      extrema[(index * 5 + 1) % extrema.length()]
    })
    execute_load_matrix(simulator, rows, columns, reduction, left, right)
    execute_accept(simulator, rows, columns, reduction, 73)
    execute_run(simulator, rows, columns, reduction, left, right, true)
    assert_eq(execute_read(simulator, "completion_id"), 73UL)
  }
}

///|
test "execute tile supports active subsets, reuse, and overwriting loaded prefixes" {
  let simulator = execute_prepare(4, 4, 5)
  let left = [1, -2, 3, -4, 5, -6]
  let right = [7, -8, 9, 10, -11, 12, 13, -14, 15]
  execute_load_matrix(simulator, 2, 3, 3, left, right)
  execute_accept(simulator, 2, 3, 3, 1)
  execute_run(simulator, 2, 3, 3, left, right, false)
  for row in 0..<4 {
    for column in 0..<4 {
      if row >= 2 || column >= 3 {
        assert_eq(execute_read(simulator, "accumulator_\{row}_\{column}"), 0UL)
      }
    }
  }
  execute_acknowledge(simulator)
  let changed = [127, -2, 3, -4, 5, -6]
  execute_load(simulator, "a", 0, 0, 127, 1UL)
  execute_accept(simulator, 2, 3, 3, 2)
  execute_run(simulator, 2, 3, 3, changed, right, false)
  assert_eq(execute_read(simulator, "completion_id"), 2UL)
  execute_acknowledge(simulator)
  execute_load_matrix(simulator, 1, 1, 1, [-128], [-128])
  execute_accept(simulator, 1, 1, 1, 3)
  execute_run(simulator, 1, 1, 1, [-128], [-128], false)
  assert_eq(execute_results(simulator, 4, 4), [
    16384, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  ])
}

///|
test "execute tile represents the full 4096-element prefix and simultaneous bank writes" {
  let simulator = execute_prepare(1, 1, 4096)
  for side in ["a", "b"] {
    execute_drive(simulator, "load_\{side}_valid", 1, 1)
    execute_drive(simulator, "load_\{side}_data", 8, -128)
  }
  for index in 0..<4096 {
    execute_drive(simulator, "load_a_index", 13, index)
    execute_drive(simulator, "load_b_index", 13, index)
    assert_eq(execute_read(simulator, "load_a_ready"), 1UL)
    assert_eq(execute_read(simulator, "load_b_ready"), 1UL)
    simulator.rising_edge("clock")
  }
  execute_drive(simulator, "load_a_valid", 1, 0)
  execute_drive(simulator, "load_b_valid", 1, 0)
  execute_load(simulator, "a", 0, 4096, 99, 0UL)
  execute_load(simulator, "b", 0, 4096, 99, 0UL)
  execute_accept(simulator, 1, 1, 4096, 4096)
  execute_run(
    simulator,
    1,
    1,
    4096,
    Array::make(4096, -128),
    Array::make(4096, -128),
    false,
  )
  assert_eq(execute_results(simulator, 1, 1), [67108864])
  assert_eq(execute_read(simulator, "accepted_steps"), 4096UL)
  assert_eq(execute_read(simulator, "elapsed_cycles"), 4097UL)
}
