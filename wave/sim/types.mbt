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
  SnapshotDesignMismatch
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

///|
/// An immutable in-memory checkpoint of one exact validated module instance.
/// The retained canonical module prevents restoring shape-compatible state
/// into a semantically different design.
pub struct SimulatorSnapshot {
  hardware_module : @ir.Module
  values : ReadOnlyArray[@wave.LogicValue]
  cycle : @wave.CycleCounter
} derive(Debug, Eq)

///|
pub fn SimulatorSnapshot::cycle(self : SimulatorSnapshot) -> @wave.CycleCounter {
  self.cycle
}
