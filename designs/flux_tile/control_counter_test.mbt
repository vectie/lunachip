///|
test "FluxTile control counter elaborates and executes through LunaWave" {
  let hardware_module = @flux_tile.control_cycle_counter(8)
  let simulator = @sim.Simulator::prepare(hardware_module)
  inspect(simulator.output("value").to_uint64(), content="0")
  simulator.rising_edge("clock")
  inspect(simulator.output("value").to_uint64(), content="1")
  simulator.rising_edge("clock")
  inspect(simulator.output("value").to_uint64(), content="2")
  inspect(simulator.cycle().value(), content="2")
}
