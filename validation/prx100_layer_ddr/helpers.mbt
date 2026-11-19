///|
fn set(
  sim : @sim.Simulator,
  name : String,
  width : Int32,
  value : UInt64,
) -> Unit raise {
  sim.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
}

///|
fn value(sim : @sim.Simulator, name : String) -> UInt64 raise {
  let v = sim.output(name)
  guard v.is_fully_known() else { fail("unknown " + name) }
  v.value_bits()
}
