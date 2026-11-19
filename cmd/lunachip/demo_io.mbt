///|
suberror DemoError {
  Usage(String)
  UnexpectedOutput(name~ : String, expected~ : UInt64, actual~ : UInt64)
  UnexpectedResult(index~ : Int32, expected~ : Int32, actual~ : Int32)
  Transport(String)
  Timeout(id~ : Int32)
}

///|
fn demo_drive(
  simulator : @sim.Simulator,
  name : String,
  width : Int32,
  value : Int32,
) -> Unit raise {
  let bits = if width == 8 { value & 255 } else { value }
  simulator.set_input(
    name,
    @wave.LogicValue::from_uint64(width~, value=bits.to_uint64()),
  )
  simulator.settle()
}

///|
fn demo_read(simulator : @sim.Simulator, name : String) -> UInt64 raise {
  simulator.output(name).to_uint64()
}

///|
fn demo_expect(
  simulator : @sim.Simulator,
  name : String,
  expected : UInt64,
) -> Unit raise {
  let actual = demo_read(simulator, name)
  if actual != expected {
    raise DemoError::UnexpectedOutput(name~, expected~, actual~)
  }
}

///|
fn demo_result(
  simulator : @sim.Simulator,
  row : Int32,
  column : Int32,
) -> Int32 raise {
  let bits = demo_read(simulator, "accumulator_\{row}_\{column}")
  if bits >= 0x80000000UL {
    (bits.reinterpret_as_int64() - 4294967296L).to_int()
  } else {
    bits.to_int()
  }
}

///|
fn demo_prepare() -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(
    @flux_tile.execute_tile(rows=2, columns=3, max_reduction=3),
  )
  for
    name in [
      "reset", "load_a_valid", "load_b_valid", "command_valid", "step_ready", "completion_ready",
    ] {
    demo_drive(simulator, name, 1, if name == "reset" { 1 } else { 0 })
  }
  for name in ["load_a_row", "load_b_column", "command_rows", "command_columns"] {
    demo_drive(simulator, name, 4, 0)
  }
  for name in ["load_a_index", "load_b_index", "command_reduction"] {
    demo_drive(simulator, name, 13, 0)
  }
  for name in ["load_a_data", "load_b_data"] {
    demo_drive(simulator, name, 8, 0)
  }
  demo_drive(simulator, "command_id", 32, 0)
  simulator.rising_edge("clock")
  demo_drive(simulator, "reset", 1, 0)
  demo_expect(simulator, "command_ready", 1UL)
  simulator
}

///|
fn demo_load(
  simulator : @sim.Simulator,
  side : String,
  bank : Int32,
  index : Int32,
  value : Int32,
) -> Unit raise {
  demo_drive(simulator, "load_\{side}_valid", 1, 1)
  demo_drive(
    simulator,
    "load_\{side}_" + (if side == "a" { "row" } else { "column" }),
    4,
    bank,
  )
  demo_drive(simulator, "load_\{side}_index", 13, index)
  demo_drive(simulator, "load_\{side}_data", 8, value)
  demo_expect(simulator, "load_\{side}_ready", 1UL)
  simulator.rising_edge("clock")
  demo_drive(simulator, "load_\{side}_valid", 1, 0)
}
