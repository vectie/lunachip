///|
fn main raise {
  let args = @env.args()
  println(run_command(args[1:]))
}

///|
fn run_command(args : ArrayView[String]) -> String raise {
  match args {
    [] | ["counter"] => counter_demo()
    ["matmul-demo"] => matmul_demo()
    ["portable-demo"] => portable_demo()
    ["ring-demo"] => ring_demo()
    ["concurrent-demo"] => concurrent_demo()
    ["help" | "--help" | "-h"] =>
      "Usage: lunachip [counter | matmul-demo | portable-demo | ring-demo | concurrent-demo | help]"
    _ =>
      raise DemoError::Usage(
        "Usage: lunachip [counter | matmul-demo | portable-demo | ring-demo | concurrent-demo | help]",
      )
  }
}

///|
fn counter_demo() -> String raise {
  let hardware_module = @flux_tile.control_cycle_counter(8)
  let simulator = @sim.Simulator::prepare(hardware_module)
  for _ in 0..<4 {
    simulator.rising_edge("clock")
  }
  let value = simulator.output("value").to_uint64()
  "LunaChip bootstrap: FluxTile control cycle=\{simulator.cycle().value()} value=\{value}"
}
