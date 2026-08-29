///|
/// Stable failures raised while preparing or driving the reference simulator.
pub(all) suberror SimulatorError {
  UnsupportedWidth(node~ : Int, width~ : Int)
  UnsupportedMemoryDepth(memory~ : String, depth~ : Int, maximum~ : Int)
  UnsupportedTotalMemoryCells(total~ : Int, maximum~ : Int)
  UnknownInput(String)
  InputWidthMismatch(name~ : String, expected~ : Int, actual~ : Int)
  UnknownNode(Int)
  UnknownOutput(String)
  UnknownClock(String)
  ExpectedClockInput(String)
  MissingRegisterUpdate(Int)
  MissingMemoryReadUpdate(node~ : Int)
  MissingMemoryUpdate(memory~ : Int)
  UnknownMemory(String)
  MemoryAddressUnknown(
    memory~ : String,
    role~ : @ir.MemoryPortRole,
    port~ : Int
  )
  MemoryAddressOutOfRange(
    memory~ : String,
    role~ : @ir.MemoryPortRole,
    port~ : Int,
    address~ : UInt64,
    depth~ : Int
  )
  MemoryWriteCollision(
    memory~ : String,
    address~ : UInt64,
    first_port~ : Int,
    second_port~ : Int
  )
  MemoryCellOutOfRange(memory~ : String, index~ : Int, depth~ : Int)
  SnapshotDesignMismatch
} derive(Debug, Eq)

///|
struct PendingMemoryWrite {
  address : Int
  value : @wave.LogicValue
}

///|
/// Mutable execution state for one validated canonical module.
///
/// The canonical module and its node order are immutable. Only external input
/// slots, register slots, settled combinational slots, and the cycle counter
/// change while the simulator runs.
pub struct Simulator {
  hardware_module : @ir.Module
  values : Array[@wave.LogicValue]
  pending_state : Array[@wave.LogicValue?]
  memory_cells : Array[Array[@wave.LogicValue]]
  pending_memories : Array[Array[PendingMemoryWrite]?]
  mut cycle : @wave.CycleCounter
}

///|
/// An immutable in-memory checkpoint of one exact validated module instance.
/// The retained canonical module prevents restoring shape-compatible state
/// into a semantically different design.
pub struct SimulatorSnapshot {
  hardware_module : @ir.Module
  values : ReadOnlyArray[@wave.LogicValue]
  memory_cells : ReadOnlyArray[ReadOnlyArray[@wave.LogicValue]]
  cycle : @wave.CycleCounter
} derive(Debug, Eq)

///|
pub fn SimulatorSnapshot::cycle(self : SimulatorSnapshot) -> @wave.CycleCounter {
  self.cycle
}
