///|
/// Stable failures raised while preparing or driving the reference simulator.
pub(all) suberror SimulatorError {
  UnsupportedWidth(node~ : Int, width~ : Int)
  UnknownInput(String)
  InputWidthMismatch(name~ : String, expected~ : Int, actual~ : Int)
  UnknownNode(Int)
  UnknownOutput(String)
  UnknownClock(String)
  ExpectedClockInput(String)
  MissingRegisterUpdate(Int)
} derive(Debug, Eq)

///|
/// Mutable execution state for one validated canonical module.
///
/// The canonical module and its node order are immutable. Only external input
/// slots, register slots, settled combinational slots, and the cycle counter
/// change while the simulator runs.
pub struct Simulator {
  hardware_module : @ir.Module
  values : Array[@wave.LogicValue]
  pending_registers : Array[@wave.LogicValue?]
  mut cycle : @wave.CycleCounter
}
