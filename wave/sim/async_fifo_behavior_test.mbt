///|
fn prepared_two_item_fifo() -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(simulated_fifo_module())
  let source = @ir.ClockDomainId::new(0)
  let destination = @ir.ClockDomainId::new(1)
  fifo_event(
    simulator,
    1UL,
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
  fifo_event(
    simulator,
    2UL,
    [
      fifo_drive("source_reset", 1, 0UL),
      fifo_drive("destination_reset", 1, 0UL),
      fifo_drive("valid", 1, 1UL),
      fifo_drive("data", 8, 0x11UL),
    ],
    [source],
  )
  fifo_event(simulator, 3UL, [fifo_drive("data", 8, 0x22UL)], [source])
  fifo_event(simulator, 4UL, [fifo_drive("valid", 1, 0UL)], [destination])
  fifo_event(simulator, 5UL, [], [destination])
  fifo_event(simulator, 6UL, [], [destination])
  assert_eq(simulator.output("destination_data").to_uint64(), 0x11UL)
  simulator
}

///|
test "coincident enqueue and consume use one pre-state independent of domain order" {
  let source = @ir.ClockDomainId::new(0)
  let destination = @ir.ClockDomainId::new(1)
  let first = prepared_two_item_fifo()
  let second = prepared_two_item_fifo()
  let drives = [
    fifo_drive("valid", 1, 1UL),
    fifo_drive("data", 8, 0x33UL),
    fifo_drive("ready", 1, 1UL),
  ]
  fifo_event(first, 7UL, drives, [source, destination])
  fifo_event(second, 7UL, drives, [destination, source])
  assert_eq(first.snapshot(), second.snapshot())
  assert_eq(first.output("destination_valid").to_uint64(), 1UL)
  assert_eq(first.output("destination_data").to_uint64(), 0x22UL)
}

///|
test "known transfer preserves a partially unknown payload exactly" {
  let simulator = @sim.Simulator::prepare(simulated_fifo_module())
  let source = @ir.ClockDomainId::new(0)
  let destination = @ir.ClockDomainId::new(1)
  fifo_event(
    simulator,
    1UL,
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
  let partial = @wave.LogicValue::from_masks(
    width=8,
    value_bits=0xa0UL,
    known_mask=0xf0UL,
  )
  fifo_event(
    simulator,
    2UL,
    [
      fifo_drive("source_reset", 1, 0UL),
      fifo_drive("destination_reset", 1, 0UL),
      fifo_drive("valid", 1, 1UL),
      @sim.InputDrive::checked("data", partial),
    ],
    [source],
  )
  fifo_event(simulator, 3UL, [fifo_drive("valid", 1, 0UL)], [destination])
  fifo_event(simulator, 4UL, [], [destination])
  fifo_event(simulator, 5UL, [], [destination])
  assert_eq(simulator.output("destination_data"), partial)
}
