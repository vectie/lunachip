///|
// Copy actual production state, never a hand-written replacement controller.
fn dependency_composition_sequential(
  fixture : @flux_tile.QueuedConcurrentFormalFixture,
) -> DependencyCompositionSequential raise {
  let source = fixture.hardware()
  let plan = dependency_composition_discover(fixture)
  let selected = source
    .nodes()
    .filter(node => {
      node.id() == plan.clock ||
      plan.cuts.any(cut => cut.node == node.id()) ||
      plan.cone.any(original => original.id() == node.id())
    })
  // Allocate every mapping first: register next expressions are later nodes.
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
      _ => raise InvalidFormalBundleIdentity("composition slice: repeated root")
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
      ("local_fault", plan.generation.local_fault),
      ("local_reject", plan.generation.local_reject),
      ("public_halted", plan.generation.public_halted),
      ("accept", plan.compute.accept),
      ("preflight", plan.compute.preflight),
      ("inner_valid", plan.compute.inner_valid),
      ("inner_ready", plan.compute.inner_ready),
      ("terminal", plan.compute.terminal),
    ] {
    outputs.push(
      @ir.OutputPort::new(
        name,
        dependency_generation_node(source, original).signal_type(),
        dependency_generation_mapped(mapping, original),
      ),
    )
  }
  for binding in plan.generation.decoder_bindings {
    outputs.push(
      @ir.OutputPort::new(
        binding.name,
        binding.signal_type,
        dependency_generation_mapped(mapping, binding.node),
      ),
    )
  }
  {
    hardware: @ir.Module::checked(
      "DependencyCompositionSequential", nodes, outputs,
    ),
    plan,
    original_to_local: ReadOnlyArray::from_array(mapping),
  }
}
