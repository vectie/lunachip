///|
fn memory_test_known(width : Int32, value : UInt64) -> @wave.LogicValue raise {
  @wave.LogicValue::from_uint64(width~, value~)
}

///|
fn memory_test_drive(
  simulator : @sim.Simulator,
  name : String,
  width : Int32,
  value : UInt64,
) -> Unit raise {
  simulator.set_input(name, memory_test_known(width, value))
}

///|
fn memory_test_drive_bit(
  simulator : @sim.Simulator,
  name : String,
  value : UInt64,
) -> Unit raise {
  memory_test_drive(simulator, name, 1, value)
}
