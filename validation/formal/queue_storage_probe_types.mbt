///|
// Original storage/read state and both port-control specifications. This is
// inspection metadata, not a free read-result input or a copied memory.
priv struct QueueStorageLane {
  lane : Int
  memory : @ir.MemorySpec
  read : @ir.MemoryReadPort
  write : @ir.MemoryWritePort
  result : @ir.Node
  read_pointer : DependencyComputeRoot
  write_pointer : DependencyComputeRoot
  public_data : @ir.NodeId
} derive(Debug, Eq)

///|
priv enum QueueStorageProbeOrigin {
  RootNext(String)
  RootReset(String)
  RootEnable(String)
  Event(String)
  ReadResult(Int)
  ReadAddress(Int)
  ReadEnable(Int)
  WriteAddress(Int)
  WriteData(Int)
  WriteEnable(Int)
} derive(Debug, Eq)

///|
priv struct QueueStorageProbeSeed {
  origin : QueueStorageProbeOrigin
  node : @ir.NodeId
} derive(Debug, Eq)

///|
priv struct QueueStorageProbeCandidate {
  original : @ir.Node
  memory : @ir.MemorySpec?
  // Every causal seed index, in deterministic seed order.
  provenance : ReadOnlyArray[Int]
} derive(Debug, Eq)

///|
// No accepted cuts, materialized module, exporter, task or proof result.
#warnings("-unused_value")
priv struct QueueStorageProbe {
  roots : ReadOnlyArray[DependencyComputeRoot]
  lanes : ReadOnlyArray[QueueStorageLane]
  seeds : ReadOnlyArray[QueueStorageProbeSeed]
  candidates : ReadOnlyArray[QueueStorageProbeCandidate]
  cone : ReadOnlyArray[@ir.Node]
  events : ReadOnlyArray[QueueControlAlias]
  clock : @ir.NodeId
  reset : @ir.NodeId
  production_digest : String
} derive(Debug, Eq)
