///|
priv enum QueuePacketCompositionOrigin {
  Clock
  Reset
  RootNext(String)
  RootReset(String)
  RootEnable(String)
  Observation(String)
  PublicInput(String)
  PublicOutput(String)
  MemoryClock(Int)
  ReadClock(Int)
  ReadResult(Int)
  ReadAddress(Int)
  ReadEnable(Int)
  WriteClock(Int)
  WriteAddress(Int)
  WriteData(Int)
  WriteEnable(Int)
  WriteMask(Int)
} derive(Debug, Eq)

///|
priv struct QueuePacketCompositionSeed {
  origin : QueuePacketCompositionOrigin
  node : @ir.NodeId
} derive(Debug, Eq)

///|
priv struct QueuePacketCompositionCandidate {
  original : @ir.Node
  provenance : ReadOnlyArray[Int]
} derive(Debug, Eq)

///|
// Source-bound inspection metadata. Remaining leaves are candidates for the
// full seven-assertion packet task, not inherited owner/prefix cut permissions.
#warnings("-unused_value")
priv struct QueuePacketCompositionProbe {
  source : @ir.Module
  production_digest : String
  owner_inventory_digest : String
  storage_inventory_digest : String
  clock : @ir.NodeId
  reset : @ir.NodeId
  roots : ReadOnlyArray[DependencyComputeRoot]
  lanes : ReadOnlyArray[QueueStorageLane]
  observations : ReadOnlyArray[QueueControlAlias]
  seeds : ReadOnlyArray[QueuePacketCompositionSeed]
  candidates : ReadOnlyArray[QueuePacketCompositionCandidate]
  cone : ReadOnlyArray[@ir.Node]
} derive(Debug, Eq)

///|
// A private candidate projection, not a proof, accepted abstraction or public
// fixture. All original storage/read state is retained without initialization.
#warnings("-unused_field")
priv struct QueuePacketCompositionSequential {
  probe : QueuePacketCompositionProbe
  hardware : @ir.Module
  cuts : ReadOnlyArray[DependencyGenerationCut]
  original_to_local : ReadOnlyArray[@ir.NodeId?]
  original_to_local_memory : ReadOnlyArray[@ir.MemoryId?]
  inventory_digest : String
}
