///|
// Only the operand stimulus and final independent oracle are host computations.
// Addresses, read latency, wavefront issue, and accumulation execute in IR.
fn matmul_demo() -> String raise {
  let left = [1, -2, 3, -128, 4, 127]
  let right = [5, -6, 7, 8, 9, -10, -11, 12, 13]
  let simulator = demo_prepare()
  for row in 0..<2 {
    for k in 0..<3 {
      demo_load(simulator, "a", row, k, left[row * 3 + k])
    }
  }
  for column in 0..<3 {
    for k in 0..<3 {
      demo_load(simulator, "b", column, k, right[k * 3 + column])
    }
  }
  demo_drive(simulator, "command_rows", 4, 2)
  demo_drive(simulator, "command_columns", 4, 3)
  demo_drive(simulator, "command_reduction", 13, 3)
  demo_drive(simulator, "command_id", 32, 42)
  demo_drive(simulator, "command_valid", 1, 1)
  demo_expect(simulator, "command_ready", 1UL)
  simulator.rising_edge("clock")
  demo_drive(simulator, "command_valid", 1, 0)
  simulator.rising_edge("clock") // Clear array and prefetch the first operands.
  for step in 0..<6 {
    if step == 2 {
      demo_drive(simulator, "step_ready", 1, 0)
      for _ in 0..<2 {
        simulator.rising_edge("clock")
        demo_expect(simulator, "accepted_steps", 2UL)
        demo_expect(simulator, "completion_valid", 0UL)
      }
    }
    demo_drive(simulator, "step_ready", 1, 1)
    simulator.rising_edge("clock")
    demo_expect(simulator, "accepted_steps", (step + 1).to_uint64())
    demo_expect(
      simulator,
      "completion_valid",
      if step == 5 {
        1UL
      } else {
        0UL
      },
    )
  }
  let expected = @flux_tile.matmul_int8_oracle(
    left,
    right,
    rows=2,
    columns=3,
    reduction=3,
  )
  let results = Array::makei(6, index => {
    let actual = demo_result(simulator, index / 3, index % 3)
    if actual != expected[index] {
      raise DemoError::UnexpectedResult(
        index~,
        expected=expected[index],
        actual~,
      )
    }
    actual
  })
  // Hold completion for two clocks: result identity and modeled execution
  // counters must not advance while the host applies backpressure.
  for held in 0..<3 {
    demo_expect(simulator, "completion_valid", 1UL)
    demo_expect(simulator, "completion_id", 42UL)
    demo_expect(simulator, "completion_fault", 0UL)
    demo_expect(simulator, "elapsed_cycles", 9UL)
    demo_expect(simulator, "active_cycles", 6UL)
    demo_expect(simulator, "stall_cycles", 2UL)
    for index in 0..<6 {
      let actual = demo_result(simulator, index / 3, index % 3)
      if actual != results[index] {
        raise DemoError::UnexpectedResult(
          index~,
          expected=results[index],
          actual~,
        )
      }
    }
    if held < 2 {
      simulator.rising_edge("clock")
    }
  }
  demo_drive(simulator, "completion_ready", 1, 1)
  simulator.rising_edge("clock")
  demo_expect(simulator, "completion_valid", 0UL)
  demo_expect(simulator, "command_ready", 1UL)
  "LunaWave FluxTile execute demo: signed INT8 M=2 N=3 K=3\n" +
  "C=[\{results[0]}, \{results[1]}, \{results[2]}; \{results[3]}, \{results[4]}, \{results[5]}]\n" +
  "completion id=42 fault=0 oracle=match\n" +
  "modeled execution cycles=9 active=6 stalls=2; completion held for 2 cycles\n" +
  "Simulation only; provisional execute slice, not a complete device ABI."
}
