///|
// A discovered foreign leaf is a review candidate, not permission to cut it.
// The immutable original node retains its complete type/kind/register spec;
// memory reads additionally retain the entire authoritative memory definition.
priv struct QueueOwnerCandidateLeaf {
  original : @ir.Node
  memory : @ir.MemorySpec?
} derive(Debug, Eq)

///|
// This deliberately has no sequential module, remapping, accepted cut list,
// public exporter, proof task or result. Materialization requires later review.
#warnings("-unused_value")
priv struct QueueOwnerProbe {
  roots : ReadOnlyArray[DependencyComputeRoot]
  candidates : ReadOnlyArray[QueueOwnerCandidateLeaf]
  cone : ReadOnlyArray[@ir.Node]
  events : ReadOnlyArray[QueueControlAlias]
  clock : @ir.NodeId
  reset : @ir.NodeId
  production_digest : String
} derive(Debug, Eq)
