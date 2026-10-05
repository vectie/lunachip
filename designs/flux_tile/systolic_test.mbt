///|
fn systolic_drive(
  simulator : @sim.Simulator,
  name : String,
  width : Int,
  value : Int,
) -> Unit raise {
  let bits = if width == 8 {
    (value & 255).to_uint64()
  } else {
    value.to_uint64()
  }
  simulator.set_input(name, @wave.LogicValue::from_uint64(width~, value=bits))
}

///|
fn systolic_output(
  simulator : @sim.Simulator,
  row : Int,
  column : Int,
) -> Int raise {
  let bits = simulator.output("accumulator_\{row}_\{column}").to_uint64()
  if bits >= 0x80000000UL {
    (bits.reinterpret_as_int64() - 4294967296L).to_int()
  } else {
    bits.to_int()
  }
}

///|
fn systolic_initialize(
  simulator : @sim.Simulator,
  rows : Int,
  columns : Int,
) -> Unit raise {
  systolic_drive(simulator, "reset", 1, 1)
  systolic_drive(simulator, "clear", 1, 0)
  systolic_drive(simulator, "advance", 1, 0)
  for row in 0..<rows {
    systolic_drive(simulator, "a_\{row}", 8, 0)
    systolic_drive(simulator, "a_valid_\{row}", 1, 0)
  }
  for column in 0..<columns {
    systolic_drive(simulator, "b_\{column}", 8, 0)
    systolic_drive(simulator, "b_valid_\{column}", 1, 0)
  }
  simulator.rising_edge("clock")
  systolic_drive(simulator, "reset", 1, 0)
}

///|
fn systolic_check_outputs(
  simulator : @sim.Simulator,
  rows : Int,
  columns : Int,
  expected : Array[Int],
) -> Unit raise {
  for row in 0..<rows {
    for column in 0..<columns {
      assert_eq(
        systolic_output(simulator, row, column),
        expected[row * columns + column],
      )
    }
  }
}

///|
// This host oracle uses ordinary integer products/sums and never evaluates IR
// operations. Each cycle is checked against the mathematical wavefront, then
// the final state is independently checked against a conventional matrix loop.
fn systolic_check_matrix(
  simulator : @sim.Simulator,
  rows : Int,
  columns : Int,
  reduction : Int,
  left : Array[Int],
  right : Array[Int],
  pause : Bool,
) -> Unit raise {
  let expected = Array::make(rows * columns, 0)
  for accepted in 0..<(reduction + rows + columns - 2) {
    if pause && accepted % 3 == 1 {
      systolic_drive(simulator, "advance", 1, 0)
      // Invalid changing boundary values prove pauses preserve in-flight state.
      for row in 0..<rows {
        systolic_drive(simulator, "a_\{row}", 8, -128)
        systolic_drive(simulator, "a_valid_\{row}", 1, 1)
      }
      for column in 0..<columns {
        systolic_drive(simulator, "b_\{column}", 8, 127)
        systolic_drive(simulator, "b_valid_\{column}", 1, 1)
      }
      for _ in 0..<2 {
        simulator.rising_edge("clock")
        systolic_check_outputs(simulator, rows, columns, expected)
      }
    }
    systolic_drive(simulator, "advance", 1, 1)
    for row in 0..<rows {
      let k = accepted - row
      let valid = k >= 0 && k < reduction
      systolic_drive(
        simulator,
        "a_\{row}",
        8,
        if valid {
          left[row * reduction + k]
        } else {
          91
        },
      )
      systolic_drive(simulator, "a_valid_\{row}", 1, if valid { 1 } else { 0 })
    }
    for column in 0..<columns {
      let k = accepted - column
      let valid = k >= 0 && k < reduction
      systolic_drive(
        simulator,
        "b_\{column}",
        8,
        if valid {
          right[k * columns + column]
        } else {
          -73
        },
      )
      systolic_drive(
        simulator,
        "b_valid_\{column}",
        1,
        if valid {
          1
        } else {
          0
        },
      )
    }
    simulator.rising_edge("clock")
    for row in 0..<rows {
      for column in 0..<columns {
        let k = accepted - row - column
        if k >= 0 && k < reduction {
          expected[row * columns + column] += left[row * reduction + k] *
            right[k * columns + column]
        }
      }
    }
    systolic_check_outputs(simulator, rows, columns, expected)
  }
  let matrix_result = @flux_tile.matmul_int8_oracle(
    left,
    right,
    rows~,
    columns~,
    reduction~,
  )
  systolic_check_outputs(simulator, rows, columns, matrix_result)
}

///|
test "systolic 1x1 and rectangular signed products follow exact wavefront timing" {
  for
    (rows, columns, reduction) in [
      (1, 1, 4),
      (2, 3, 5),
      (3, 2, 7),
      (1, 8, 3),
      (8, 1, 3),
    ] {
    let simulator = @sim.Simulator::prepare(
      @flux_tile.systolic_array(rows~, columns~),
    )
    systolic_initialize(simulator, rows, columns)
    let left = Array::makei(rows * reduction, i => (i * 53 + 17) % 256 - 128)
    let right = Array::makei(reduction * columns, i => {
      (i * 97 + 211) % 256 - 128
    })
    systolic_check_matrix(
      simulator, rows, columns, reduction, left, right, true,
    )
  }
}

///|
test "systolic 8x8 signed extrema and deterministic varied workloads" {
  let simulator = @sim.Simulator::prepare(
    @flux_tile.systolic_array(rows=8, columns=8),
  )
  let values = [-128, -127, -1, 0, 1, 126, 127]
  for trial in 0..<4 {
    systolic_initialize(simulator, 8, 8)
    let reduction = 9 + trial
    let left = Array::makei(8 * reduction, i => {
      values[(i * 3 + trial) % values.length()]
    })
    let right = Array::makei(reduction * 8, i => {
      values[(i * 5 + trial * 2) % values.length()]
    })
    systolic_check_matrix(
      simulator,
      8,
      8,
      reduction,
      left,
      right,
      trial % 2 == 0,
    )
  }
}

///|
test "systolic clear and reset flush in-flight terms while paused and permit reuse" {
  let rows = 2
  let columns = 3
  let simulator = @sim.Simulator::prepare(
    @flux_tile.systolic_array(rows~, columns~),
  )
  systolic_initialize(simulator, rows, columns)
  for control in ["clear", "reset"] {
    systolic_drive(simulator, "advance", 1, 1)
    for row in 0..<rows {
      systolic_drive(simulator, "a_\{row}", 8, -128)
      systolic_drive(simulator, "a_valid_\{row}", 1, 1)
    }
    for column in 0..<columns {
      systolic_drive(simulator, "b_\{column}", 8, -128)
      systolic_drive(simulator, "b_valid_\{column}", 1, 1)
    }
    simulator.rising_edge("clock")
    assert_eq(systolic_output(simulator, 0, 0), 16384)
    systolic_drive(simulator, "advance", 1, 0)
    systolic_drive(simulator, control, 1, 1)
    simulator.rising_edge("clock")
    systolic_check_outputs(
      simulator,
      rows,
      columns,
      Array::make(rows * columns, 0),
    )
    systolic_drive(simulator, control, 1, 0)
    systolic_drive(simulator, "advance", 1, 1)
    for row in 0..<rows {
      systolic_drive(simulator, "a_valid_\{row}", 1, 0)
    }
    for column in 0..<columns {
      systolic_drive(simulator, "b_valid_\{column}", 1, 0)
    }
    for _ in 0..<(rows + columns) {
      simulator.rising_edge("clock")
      systolic_check_outputs(
        simulator,
        rows,
        columns,
        Array::make(rows * columns, 0),
      )
    }
    systolic_check_matrix(
      simulator,
      rows,
      columns,
      2,
      [1, -2, 3, -4],
      [-5, 6, -7, 8, -9, 10],
      true,
    )
    systolic_drive(simulator, "clear", 1, 1)
    simulator.rising_edge("clock")
    systolic_drive(simulator, "clear", 1, 0)
  }
}

///|
test "systolic requires both operand qualifiers and accumulates across launches" {
  let simulator = @sim.Simulator::prepare(
    @flux_tile.systolic_array(rows=1, columns=1),
  )
  systolic_initialize(simulator, 1, 1)
  systolic_drive(simulator, "advance", 1, 1)
  systolic_drive(simulator, "a_0", 8, -128)
  systolic_drive(simulator, "b_0", 8, 127)
  for (a_valid, b_valid) in [(0, 0), (1, 0), (0, 1), (1, 1), (1, 1)] {
    systolic_drive(simulator, "a_valid_0", 1, a_valid)
    systolic_drive(simulator, "b_valid_0", 1, b_valid)
    simulator.rising_edge("clock")
  }
  assert_eq(systolic_output(simulator, 0, 0), -32512)
}

///|
test "systolic persistent accumulation wraps rather than saturating at INT32 bounds" {
  let simulator = @sim.Simulator::prepare(
    @flux_tile.systolic_array(rows=1, columns=1),
  )
  systolic_initialize(simulator, 1, 1)
  systolic_drive(simulator, "advance", 1, 1)
  systolic_drive(simulator, "a_0", 8, -128)
  systolic_drive(simulator, "b_0", 8, -128)
  systolic_drive(simulator, "a_valid_0", 1, 1)
  systolic_drive(simulator, "b_valid_0", 1, 1)
  for _ in 0..<131071 {
    simulator.rising_edge("clock")
  }
  assert_eq(systolic_output(simulator, 0, 0), 2147467264)
  systolic_drive(simulator, "advance", 1, 0)
  simulator.rising_edge("clock")
  assert_eq(systolic_output(simulator, 0, 0), 2147467264)
  systolic_drive(simulator, "advance", 1, 1)
  simulator.rising_edge("clock")
  assert_eq(systolic_output(simulator, 0, 0), -2147483647 - 1)
  systolic_drive(simulator, "b_0", 8, 127)
  simulator.rising_edge("clock")
  assert_eq(systolic_output(simulator, 0, 0), 2147467392)
}

///|
test "systolic 2x3 canonical bytes remain stable through internal composition refactors" {
  let design = @wire.single_design(
    "FluxTileCompute",
    @flux_tile.systolic_array(rows=2, columns=3),
  )
  inspect(
    @crypto.bytes_to_hex_string(
      @crypto.sha256(@utf8.encode(@codec.serialize(design))),
    ),
    content=(
      #|3ae3a65265adde247d59aef5640726ec3b6b464d2106940f04f3acf7dd28fc9f
    ),
  )
}

///|
test "systolic construction and emitted RTL are deterministic and dimensions checked" {
  for (rows, columns) in [(1, 1), (2, 3), (8, 8)] {
    let first = @wire.single_design(
      "FluxTileCompute",
      @flux_tile.systolic_array(rows~, columns~),
    )
    let second = @wire.single_design(
      "FluxTileCompute",
      @flux_tile.systolic_array(rows~, columns~),
    )
    assert_eq(@codec.serialize(first), @codec.serialize(second))
    assert_eq(
      @systemverilog.emit_design(first).source(),
      @systemverilog.emit_design(second).source(),
    )
  }
  for rows in [0, -1, 9] {
    try @flux_tile.systolic_array(rows~, columns=1) catch {
      @flux_tile.SystolicArrayError::InvalidRows(actual) =>
        assert_eq(actual, rows)
      error => fail("unexpected error: \{error}")
    } noraise {
      _ => fail("invalid rows accepted")
    }
  }
  for columns in [0, -1, 9] {
    try @flux_tile.systolic_array(rows=1, columns~) catch {
      @flux_tile.SystolicArrayError::InvalidColumns(actual) =>
        assert_eq(actual, columns)
      error => fail("unexpected error: \{error}")
    } noraise {
      _ => fail("invalid columns accepted")
    }
  }
}
