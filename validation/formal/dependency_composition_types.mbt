///|
// Exact joint production extraction only. A native construction does not
// establish independent authorization, ownership or a sequential proof.
#warnings("-unused_field-unused_value")
priv struct DependencyCompositionPlan {
  generation : DependencyGenerationPlan
  compute : DependencyComputePlan
  roots : ReadOnlyArray[DependencyComputeRoot]
  cuts : ReadOnlyArray[DependencyGenerationCut]
  cone : ReadOnlyArray[@ir.Node]
  clock : @ir.NodeId
  reset : @ir.NodeId
} derive(Debug, Eq)

///|
#warnings("-unused_field")
priv struct DependencyCompositionSequential {
  hardware : @ir.Module
  plan : DependencyCompositionPlan
  original_to_local : ReadOnlyArray[@ir.NodeId?]
}
