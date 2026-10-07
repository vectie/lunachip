///|
// Copy exact original transitions. Source pin and fresh structural discovery
// bind the complete boundary; this is native/proof input, never a result.
fn fetched_transport_sequential() -> FetchedTransportSequential raise {
  let probe = fetched_transport_probe()
  let source = probe.source
  if fetched_transport_closure(
      source,
      probe.roots,
      probe.candidates,
      probe.events,
    ) !=
    probe.cone.iter().to_array() {
    raise InvalidFormalBundleIdentity("fetched sequential: closure identity")
  }
  let selected = source
    .nodes()
    .filter(node => {
      node.id() == probe.clock ||
      probe.roots.any(root => root.node == node.id()) ||
      probe.candidates.any(cut => cut.original.id() == node.id()) ||
      probe.cone.any(old => old.id() == node.id())
    })
  let mapping : Array[@ir.NodeId?] = Array::make(source.nodes().length(), None)
  for index, node in selected {
    mapping[node.id().ordinal()] = Some(@ir.NodeId::new(index))
  }
  let nodes : Array[@ir.Node] = []
  for original in selected {
    let kind = if original.id() == probe.clock {
      @ir.NodeKind::Input("clock")
    } else if probe.roots.filter(root => root.node == original.id()) is [root] {
      dependency_sequential_register_kind(root.spec, mapping)
    } else if probe.candidates.any(cut => cut.original.id() == original.id()) {
      Input("cut_n\{original.id().ordinal()}")
    } else {
      dependency_generation_remap(original.kind(), mapping)
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
  // Include all raw interfaces explicitly so no unused boundary is silently
  // removed for emission. These observation aliases assert nothing.
  for cut in probe.candidates {
    outputs.push(
      @ir.OutputPort::new(
        "raw_n\{cut.original.id().ordinal()}",
        cut.original.signal_type(),
        dependency_generation_mapped(mapping, cut.original.id()),
      ),
    )
  }
  {
    probe,
    hardware: @ir.Module::checked("FetchedTransportSequential", nodes, outputs),
    original_to_local: ReadOnlyArray::from_array(mapping),
  }
}
