///|
// Exact sequential projection, not an invariant, assumption or proof result.
priv struct QueueOwnerSequential {
  hardware : @ir.Module
  plan : QueueOwnerPlan
  original_to_local : ReadOnlyArray[@ir.NodeId?]
}

///|
#warnings("-unused_value")
fn queue_owner_sequential(
  fixture : @flux_tile.QueueConservationFixture,
) -> QueueOwnerSequential raise {
  let source = fixture.hardware()
  let plan = queue_owner_discover(fixture)
  let probe = plan.probe
  let selected = source
    .nodes()
    .filter(original => {
      original.id() == probe.clock ||
      probe.roots.any(root => root.node == original.id()) ||
      plan.cuts.any(cut => cut.node == original.id()) ||
      probe.cone.any(node => node.id() == original.id())
    })
  let mapping : Array[@ir.NodeId?] = Array::make(source.nodes().length(), None)
  // Allocate all forward next-state references before copying any node.
  for index, original in selected {
    mapping[original.id().ordinal()] = Some(@ir.NodeId::new(index))
  }
  let nodes : Array[@ir.Node] = []
  for original in selected {
    let kind : @ir.NodeKind = match
      probe.roots.filter(root => root.node == original.id()) {
      [root] => dependency_sequential_register_kind(root.spec, mapping)
      [] =>
        if original.id() == probe.clock {
          Input("clock")
        } else if plan.cuts.any(cut => cut.node == original.id()) {
          Input("cut_n\{original.id().ordinal()}")
        } else {
          dependency_generation_remap(original.kind(), mapping)
        }
      _ => raise InvalidFormalBundleIdentity("queue owner: repeated state root")
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
  for root in probe.roots {
    outputs.push(
      @ir.OutputPort::new(
        "current_" + root.name,
        root.signal_type,
        dependency_generation_mapped(mapping, root.node),
      ),
    )
  }
  for event in probe.events {
    outputs.push(
      @ir.OutputPort::new(
        event.name,
        event.signal_type,
        dependency_generation_mapped(mapping, event.node),
      ),
    )
  }
  {
    hardware: @ir.Module::checked("QueueOwnerSequential", nodes, outputs),
    plan,
    original_to_local: ReadOnlyArray::from_array(mapping),
  }
}
