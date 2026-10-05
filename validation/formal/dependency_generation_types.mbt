///|
// Discovery only: immutable references to the unchanged production graph.
// No transfer module, ghost invariant, assumption or proof is constructed.
priv struct DependencyGenerationBinding {
  role : @flux_tile.QueuedConcurrentFormalRole
  node : @ir.NodeId
  signal_type : @ir.SignalType
} derive(Debug, Eq)

///|
priv struct DependencyGenerationRoot {
  binding : DependencyGenerationBinding
  spec : @ir.RegisterSpec
} derive(Debug, Eq)

///|
priv struct DependencyGenerationCut {
  node : @ir.NodeId
  signal_type : @ir.SignalType
  roles : ReadOnlyArray[String]
} derive(Debug, Eq)

///|
// Equality/debug are used by the white-box discovery checkpoint, before the
// independent lemma exporter consumes this private implementation slice.
#warnings("-unused_value")
priv struct DependencyGenerationPlan {
  roots : ReadOnlyArray[DependencyGenerationRoot]
  cuts : ReadOnlyArray[DependencyGenerationCut]
  cone : ReadOnlyArray[@ir.Node]
  local_fault : @ir.NodeId
  local_reject : @ir.NodeId
  clock : @ir.NodeId
  reset : @ir.NodeId
  public_halted : @ir.NodeId
  raw_poison : @ir.NodeId
} derive(Debug, Eq)

///|
fn dependency_generation_bindings(
  fixture : @flux_tile.QueuedConcurrentFormalFixture,
) -> Array[DependencyGenerationBinding] {
  fixture
  .observations()
  .iter()
  .map(observation => {
    role: observation.role(),
    node: observation.node(),
    signal_type: observation.signal_type(),
  })
  .to_array()
}

///|
fn dependency_generation_node(
  hardware : @ir.Module,
  id : @ir.NodeId,
) -> @ir.Node raise FormalGateError {
  guard hardware.node(id) is Some(node) else {
    raise InvalidFormalBundleIdentity(
      "generation discovery: unknown node \{id.ordinal()}",
    )
  }
  node
}

///|
fn dependency_generation_binding(
  bindings : ArrayView[DependencyGenerationBinding],
  role : @flux_tile.QueuedConcurrentFormalRole,
) -> DependencyGenerationBinding raise FormalGateError {
  let matching = bindings.filter(binding => binding.role == role)
  guard matching is [binding] else {
    raise InvalidFormalBundleIdentity(
      "generation discovery: missing/repeated role " +
      dependency_role_name(role),
    )
  }
  binding
}

///|
fn dependency_generation_state_roles() -> Array[
  @flux_tile.QueuedConcurrentFormalRole,
] {
  let roles : Array[@flux_tile.QueuedConcurrentFormalRole] = [
    NextTicket,
    HeadTicket,
  ]
  for index in 0..<6 {
    roles.push(WriterStatus(index))
    roles.push(WriterTicket(index))
  }
  for index in 0..<2 {
    roles.push(DependencyStatus(index))
    roles.push(DependencyTicket(index))
  }
  roles
}

///|
fn dependency_generation_boundary_roles() -> Array[
  @flux_tile.QueuedConcurrentFormalRole,
] {
  [
    HeadLane(0),
    HeadLane(1),
    HeadLane(2),
    HeadLane(3),
    HeadState,
    HeadReserve,
    LoadTerminal,
    LoadTerminalTicket,
    LoadTerminalFault,
    ComputeTerminal,
    ComputeTerminalTicket,
    ComputeTerminalFault,
  ]
}
