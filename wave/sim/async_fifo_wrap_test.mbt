///|
test "depth-four FIFO preserves order across two complete address wraps" {
  let simulator = @sim.Simulator::prepare(simulated_fifo_module())
  let source = @ir.ClockDomainId::new(0)
  let destination = @ir.ClockDomainId::new(1)
  let mut time = 1UL
  fifo_event(
    simulator,
    time,
    [
      fifo_drive("source_reset", 1, 1UL),
      fifo_drive("destination_reset", 1, 1UL),
      fifo_drive("valid", 1, 0UL),
      fifo_drive("data", 8, 0UL),
      fifo_drive("data_second", 8, 0UL),
      fifo_drive("ready", 1, 0UL),
    ],
    [source, destination],
  )
  for batch in 0..<3 {
    for offset in 0..<4 {
      time += 1UL
      let value = (batch * 4 + offset + 1).to_uint64()
      let drives = if batch == 0 && offset == 0 {
        [
          fifo_drive("source_reset", 1, 0UL),
          fifo_drive("destination_reset", 1, 0UL),
          fifo_drive("valid", 1, 1UL),
          fifo_drive("data", 8, value),
          fifo_drive("data_second", 8, value + 0x40UL),
        ]
      } else {
        [
          fifo_drive("valid", 1, 1UL),
          fifo_drive("data", 8, value),
          fifo_drive("data_second", 8, value + 0x40UL),
        ]
      }
      fifo_event(simulator, time, drives, [source])
    }
    assert_eq(simulator.output("source_ready").to_uint64(), 0UL)
    for edge in 0..<3 {
      time += 1UL
      fifo_event(
        simulator,
        time,
        if edge == 0 {
          [fifo_drive("valid", 1, 0UL)]
        } else {
          []
        },
        [destination],
      )
    }
    assert_eq(simulator.output("destination_valid").to_uint64(), 1UL)
    for offset in 0..<4 {
      let expected = (batch * 4 + offset + 1).to_uint64()
      assert_eq(simulator.output("destination_data").to_uint64(), expected)
      time += 1UL
      fifo_event(
        simulator,
        time,
        if offset == 0 {
          [fifo_drive("ready", 1, 1UL)]
        } else {
          []
        },
        [destination],
      )
    }
    assert_eq(simulator.output("destination_valid").to_uint64(), 0UL)
    for edge in 0..<3 {
      time += 1UL
      fifo_event(
        simulator,
        time,
        if edge == 0 {
          [fifo_drive("ready", 1, 0UL)]
        } else {
          []
        },
        [source],
      )
    }
    assert_eq(simulator.output("source_ready").to_uint64(), 1UL)
  }
}
