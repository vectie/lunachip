///|
// Private FIFO-to-head prefix projection only. No ownership, full p12,
// progress theorem, public exporter, proof task or result is constructed.
#warnings("-unused_field")
priv struct QueueStorageSequential {
  hardware : @ir.Module
  probe : QueueStorageProbe
  cuts : ReadOnlyArray[DependencyGenerationCut]
  original_to_local : ReadOnlyArray[@ir.NodeId?]
  original_to_local_memory : ReadOnlyArray[@ir.MemoryId?]
  inventory_digest : String
}
