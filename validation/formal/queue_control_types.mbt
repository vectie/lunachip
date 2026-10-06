///|
// Fixed queue-control projection only: immutable references to production
// nodes, not a replacement controller or an engine/data ownership proof.
priv struct QueueControlAlias {
  name : String
  node : @ir.NodeId
  signal_type : @ir.SignalType
} derive(Debug, Eq)

///|
#warnings("-unused_value")
priv struct QueueControlPlan {
  roots : ReadOnlyArray[DependencyComputeRoot]
  cuts : ReadOnlyArray[DependencyGenerationCut]
  cone : ReadOnlyArray[@ir.Node]
  events : ReadOnlyArray[QueueControlAlias]
  clock : @ir.NodeId
  reset : @ir.NodeId
} derive(Debug, Eq)

///|
#warnings("-unused_value")
priv struct QueueControlSequential {
  hardware : @ir.Module
  plan : QueueControlPlan
  original_to_local : ReadOnlyArray[@ir.NodeId?]
} derive(Debug, Eq)
