///|
// Actual production register specs and combinational equations, with only
// the discovery plan's explicit nonstate data boundaries becoming inputs.
#warnings("-unused_value")
fn queue_control_sequential(
  fixture : @flux_tile.QueueConservationFixture,
) -> QueueControlSequential raise {
  let source = fixture.hardware()
  let plan = queue_control_discover(fixture)
  let selected = source
    .nodes()
    .filter(node => {
      node.id() == plan.clock ||
      plan.cuts.any(cut => cut.node == node.id()) ||
      plan.cone.any(original => original.id() == node.id())
    })
  // Allocate forward next-state references before constructing any node.
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
      _ => raise InvalidFormalBundleIdentity("queue control: repeated root")
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
  for event in plan.events {
    outputs.push(
      @ir.OutputPort::new(
        event.name,
        event.signal_type,
        dependency_generation_mapped(mapping, event.node),
      ),
    )
  }
  {
    hardware: @ir.Module::checked("QueueControlSequential", nodes, outputs),
    plan,
    original_to_local: ReadOnlyArray::from_array(mapping),
  }
}
