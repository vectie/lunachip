///|
// Candidate-only actual-state union for the seven original dependency
// assertions. Prior local lemma cuts are not inherited or assumed.
priv struct DependencyConjunctionProbe {
  packet : QueuePacketCompositionProbe
  bindings : ReadOnlyArray[DependencyGenerationBinding]
  roots : ReadOnlyArray[DependencyComputeRoot]
  observations : ReadOnlyArray[QueueControlAlias]
  seeds : ReadOnlyArray[QueuePacketCompositionSeed]
  candidates : ReadOnlyArray[QueuePacketCompositionCandidate]
  cone : ReadOnlyArray[@ir.Node]
} derive(Eq)

///|
#warnings("-unused_field")
priv struct DependencyConjunctionSequential {
  probe : DependencyConjunctionProbe
  hardware : @ir.Module
  cuts : ReadOnlyArray[DependencyGenerationCut]
  original_to_local : ReadOnlyArray[@ir.NodeId?]
  original_to_local_memory : ReadOnlyArray[@ir.MemoryId?]
  inventory_digest : String
}
