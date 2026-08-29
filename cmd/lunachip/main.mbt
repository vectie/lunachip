///|
fn main raise {
  let hardware_module = @flux_tile.control_cycle_counter(8)
  let simulator = @sim.Simulator::prepare(hardware_module)
  for _ in 0..<4 {
    simulator.rising_edge("clock")
  }
  let value = simulator.output("value").to_uint64()
  println(
    "LunaChip bootstrap: FluxTile control cycle=\{simulator.cycle().value()} value=\{value}",
  )
}
