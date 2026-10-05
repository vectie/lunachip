///|
// Fixed compute identity slice only. These references do not establish saved
// authorization, ownership, lease safety or full-device composition.
priv struct DependencyComputeRoot {
  name : String
  node : @ir.NodeId
  signal_type : @ir.SignalType
  spec : @ir.RegisterSpec
} derive(Debug, Eq)

///|
#warnings("-unused_value")
priv struct DependencyComputePlan {
  roots : ReadOnlyArray[DependencyComputeRoot]
  cuts : ReadOnlyArray[DependencyGenerationCut]
  cone : ReadOnlyArray[@ir.Node]
  clock : @ir.NodeId
  reset : @ir.NodeId
  raw_poison : @ir.NodeId
  public_halted : @ir.NodeId
  accept : @ir.NodeId
  preflight : @ir.NodeId
  inner_valid : @ir.NodeId
  inner_ready : @ir.NodeId
  terminal : @ir.NodeId
} derive(Debug, Eq)
