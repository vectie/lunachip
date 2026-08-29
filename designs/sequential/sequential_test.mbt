///|
fn known(width : Int, value : UInt64) -> @wave.LogicValue raise {
  @wave.LogicValue::from_uint64(width~, value~)
}

///|
fn drive_bit(
  simulator : @sim.Simulator,
  name : String,
  value : UInt64,
) -> Unit raise {
  simulator.set_input(name, known(1, value))
}

///|
test "counter resets synchronously, advances, wraps, and holds" {
  let simulator = @sim.Simulator::prepare(@sequential.counter(3))
  inspect(simulator.output("count").to_bit_string(), content="xxx")
  drive_bit(simulator, "reset", 1UL)
  drive_bit(simulator, "enable", 0UL)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("count").to_uint64(), 0UL)
  drive_bit(simulator, "reset", 0UL)
  drive_bit(simulator, "enable", 1UL)
  let observed : Array[UInt64] = []
  for _ in 0..<9 {
    simulator.rising_edge("clock")
    observed.push(simulator.output("count").to_uint64())
  }
  assert_eq(observed, [1UL, 2UL, 3UL, 4UL, 5UL, 6UL, 7UL, 0UL, 1UL])
  drive_bit(simulator, "enable", 0UL)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("count").to_uint64(), 1UL)
}

///|
test "LFSR reset seed produces the fixed nonzero sequence and holds" {
  let simulator = @sim.Simulator::prepare(@sequential.lfsr8())
  inspect(simulator.output("value").to_bit_string(), content="xxxxxxxx")
  drive_bit(simulator, "reset", 1UL)
  drive_bit(simulator, "enable", 0UL)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("value").to_uint64(), 1UL)
  drive_bit(simulator, "reset", 0UL)
  drive_bit(simulator, "enable", 1UL)
  let observed : Array[UInt64] = []
  for _ in 0..<10 {
    simulator.rising_edge("clock")
    observed.push(simulator.output("value").to_uint64())
  }
  assert_eq(observed, [
    0xb8UL, 0x5cUL, 0x2eUL, 0x17UL, 0xb3UL, 0xe1UL, 0xc8UL, 0x64UL, 0x32UL, 0x19UL,
  ])
  drive_bit(simulator, "enable", 0UL)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("value").to_uint64(), 0x19UL)
}

///|
test "LFSR visits every nonzero eight-bit state before repeating" {
  let simulator = @sim.Simulator::prepare(@sequential.lfsr8())
  drive_bit(simulator, "reset", 1UL)
  drive_bit(simulator, "enable", 1UL)
  simulator.rising_edge("clock")
  drive_bit(simulator, "reset", 0UL)
  let seen = Array::make(256, false)
  seen[1] = true
  for _ in 1..<255 {
    simulator.rising_edge("clock")
    let value = simulator.output("value").to_uint64().to_int()
    assert_true(value != 0)
    assert_false(seen[value])
    seen[value] = true
  }
  simulator.rising_edge("clock")
  assert_eq(simulator.output("value").to_uint64(), 1UL)
}

///|
test "two-stage pipeline commits old state simultaneously and holds" {
  let simulator = @sim.Simulator::prepare(@sequential.two_stage_pipeline(8))
  inspect(simulator.output("first").to_bit_string(), content="xxxxxxxx")
  inspect(simulator.output("second").to_bit_string(), content="xxxxxxxx")
  drive_bit(simulator, "reset", 1UL)
  drive_bit(simulator, "enable", 0UL)
  simulator.set_input("input", known(8, 99UL))
  simulator.rising_edge("clock")
  assert_eq(simulator.output("first").to_uint64(), 0UL)
  assert_eq(simulator.output("second").to_uint64(), 0UL)
  drive_bit(simulator, "reset", 0UL)
  drive_bit(simulator, "enable", 1UL)
  simulator.set_input("input", known(8, 11UL))
  simulator.rising_edge("clock")
  assert_eq(simulator.output("first").to_uint64(), 11UL)
  assert_eq(simulator.output("second").to_uint64(), 0UL)
  simulator.set_input("input", known(8, 22UL))
  simulator.rising_edge("clock")
  assert_eq(simulator.output("first").to_uint64(), 22UL)
  assert_eq(simulator.output("second").to_uint64(), 11UL)
  drive_bit(simulator, "enable", 0UL)
  simulator.set_input("input", known(8, 33UL))
  simulator.rising_edge("clock")
  assert_eq(simulator.output("first").to_uint64(), 22UL)
  assert_eq(simulator.output("second").to_uint64(), 11UL)
}

///|
test "elastic buffer accepts, blocks, replaces, and drains one entry" {
  let simulator = @sim.Simulator::prepare(@sequential.elastic_buffer(8))
  drive_bit(simulator, "reset", 1UL)
  drive_bit(simulator, "in_valid", 0UL)
  drive_bit(simulator, "out_ready", 0UL)
  simulator.set_input("in_data", known(8, 0UL))
  simulator.rising_edge("clock")
  assert_eq(simulator.output("in_ready").to_uint64(), 1UL)
  assert_eq(simulator.output("out_valid").to_uint64(), 0UL)
  inspect(simulator.output("out_data").to_bit_string(), content="xxxxxxxx")

  drive_bit(simulator, "reset", 0UL)
  drive_bit(simulator, "in_valid", 1UL)
  simulator.set_input("in_data", known(8, 42UL))
  simulator.rising_edge("clock")
  assert_eq(simulator.output("in_ready").to_uint64(), 0UL)
  assert_eq(simulator.output("out_valid").to_uint64(), 1UL)
  assert_eq(simulator.output("out_data").to_uint64(), 42UL)

  simulator.set_input("in_data", known(8, 99UL))
  simulator.rising_edge("clock")
  assert_eq(simulator.output("out_valid").to_uint64(), 1UL)
  assert_eq(simulator.output("out_data").to_uint64(), 42UL)

  drive_bit(simulator, "out_ready", 1UL)
  assert_eq(simulator.output("in_ready").to_uint64(), 0UL)
  simulator.settle()
  assert_eq(simulator.output("in_ready").to_uint64(), 1UL)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("out_valid").to_uint64(), 1UL)
  assert_eq(simulator.output("out_data").to_uint64(), 99UL)

  drive_bit(simulator, "in_valid", 0UL)
  simulator.rising_edge("clock")
  assert_eq(simulator.output("in_ready").to_uint64(), 1UL)
  assert_eq(simulator.output("out_valid").to_uint64(), 0UL)
  assert_eq(simulator.output("out_data").to_uint64(), 99UL)
}
