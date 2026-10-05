///|
// Exact compute-only production extraction. Generation/admission observations
// at its cuts are not a proved ghost relation or authorization assumption.
#warnings("-unused_field")
priv struct DependencyComputeSequential {
  hardware : @ir.Module
  plan : DependencyComputePlan
  original_to_local : ReadOnlyArray[@ir.NodeId?]
}

///|
#warnings("-unused_value")
fn dependency_compute_sequential(
  fixture : @flux_tile.QueuedConcurrentFormalFixture,
) -> DependencyComputeSequential raise {
  let source = fixture.hardware()
  let plan = dependency_compute_discover(fixture)
  let selected = source
    .nodes()
    .filter(node => {
      node.id() == plan.clock ||
      plan.cuts.any(cut => cut.node == node.id()) ||
      plan.cone.any(original => original.id() == node.id())
    })
  let mapping : Array[@ir.NodeId?] = Array::make(source.nodes().length(), None)
  for index, original in selected {
    mapping[original.id().ordinal()] = Some(@ir.NodeId::new(index))
  }
  let nodes : Array[@ir.Node] = []
  for original in selected {
    let kind : @ir.NodeKind = match
      plan.roots.filter(root => root.node == original.id()) {
      [root] => dependency_sequential_register_kind(root.spec, mapping)
      [] =>
        if original.id() == plan.clock {
          Input("clock")
        } else if plan.cuts.any(cut => cut.node == original.id()) {
          Input("cut_n\{original.id().ordinal()}")
        } else {
          dependency_generation_remap(original.kind(), mapping)
        }
      _ =>
        raise InvalidFormalBundleIdentity("compute slice: repeated state root")
    }
    nodes.push(
      @ir.Node::new(
        dependency_generation_mapped(mapping, original.id()),
        original.signal_type(),
        kind,
      ),
    )
  }
  let outputs : Array[@ir.OutputPort] = []
  for root in plan.roots {
    outputs.push(
      @ir.OutputPort::new(
        "current_" + root.name,
        root.signal_type,
        dependency_generation_mapped(mapping, root.node),
      ),
    )
  }
  for
    (name, original) in [
      ("accept", plan.accept),
      ("preflight", plan.preflight),
      ("inner_valid", plan.inner_valid),
      ("inner_ready", plan.inner_ready),
      ("terminal", plan.terminal),
      ("public_halted", plan.public_halted),
    ] {
    outputs.push(
      @ir.OutputPort::new(
        name,
        dependency_generation_node(source, original).signal_type(),
        dependency_generation_mapped(mapping, original),
      ),
    )
  }
  {
    hardware: @ir.Module::checked("DependencyComputeSequential", nodes, outputs),
    plan,
    original_to_local: ReadOnlyArray::from_array(mapping),
  }
}
