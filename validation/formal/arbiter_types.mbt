///|
// Raw client interface candidates may be combinational production nodes.
// Their exact immutable kinds/specs and semantic roles are review evidence,
// not an accepted cut set or a replacement controller.
priv struct TwoClientArbiterCandidate {
  original : @ir.Node
  roles : ReadOnlyArray[String]
} derive(Debug, Eq)

///|
#warnings("-unused_value")
priv struct TwoClientArbiterProbe {
  roots : ReadOnlyArray[DependencyComputeRoot]
  boundaries : ReadOnlyArray[TwoClientArbiterCandidate]
  candidates : ReadOnlyArray[TwoClientArbiterCandidate]
  cone : ReadOnlyArray[@ir.Node]
  events : ReadOnlyArray[QueueControlAlias]
  clock : @ir.NodeId
  reset : @ir.NodeId
  production_digest : String
} derive(Debug, Eq)
