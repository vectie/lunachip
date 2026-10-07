///|
// Fresh fetched graph only; no direct-device IDs or observation roster.
priv struct FetchedTransportProbe {
  source : @ir.Module
  production_digest : String
  clock : @ir.NodeId
  reset : @ir.NodeId
  roots : ReadOnlyArray[DependencyComputeRoot]
  boundaries : ReadOnlyArray[TwoClientArbiterCandidate]
  candidates : ReadOnlyArray[TwoClientArbiterCandidate]
  events : ReadOnlyArray[QueueControlAlias]
  cone : ReadOnlyArray[@ir.Node]
} derive(Eq)

///|
priv struct FetchedTransportSequential {
  probe : FetchedTransportProbe
  hardware : @ir.Module
  original_to_local : ReadOnlyArray[@ir.NodeId?]
} derive(Eq)

///|
priv struct FetchedTransportArbiter {
  roots : ReadOnlyArray[DependencyComputeRoot]
  boundaries : ReadOnlyArray[TwoClientArbiterCandidate]
  events : ReadOnlyArray[QueueControlAlias]
  reader_fields : ReadOnlyArray[@ir.NodeId]
  reader_valid : @ir.NodeId
  reader_ready : @ir.NodeId
  reader_response_valid : @ir.NodeId
  inactive : @ir.NodeId
}
