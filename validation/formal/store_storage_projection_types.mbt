///|
// Exact control/storage closure with only independently reviewed arithmetic
// production values abstracted. No assumption, monitor, exporter or proof.
#warnings("-unused_value")
priv struct StoreStorageProjectionPlan {
  probe : StorePreservationProbe
  observations : ReadOnlyArray[@flux_tile.StorePreservationObservation]
  arithmetic : ReadOnlyArray[@ir.Node]
  arbiter_roots : ReadOnlyArray[DependencyComputeRoot]
  seeds : ReadOnlyArray[@ir.NodeId]
  selected : ReadOnlyArray[@ir.Node]
  memories : ReadOnlyArray[@ir.MemorySpec]
} derive(Debug, Eq)

///|
#warnings("-unused_field")
priv struct StoreStorageProjection {
  hardware : @ir.Module
  plan : StoreStorageProjectionPlan
  original_to_local : ReadOnlyArray[@ir.NodeId?]
  original_to_local_memory : ReadOnlyArray[@ir.MemoryId?]
}
