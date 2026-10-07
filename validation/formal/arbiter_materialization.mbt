///|
// Acceptance is purpose-specific: the complete reviewed original report is
// pinned without newline normalization, and the current source cone is closed
// again before any candidate becomes an input of a sequential module.
fn two_client_arbiter_require_materialization(
  source : @ir.Module,
  probe : TwoClientArbiterProbe,
) -> Unit raise {
  if probe.production_digest !=
    "35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc" ||
    sha256_hex(two_client_arbiter_probe_report(probe)) !=
    "cc867599656fda1bc3897b42d971feb75736de72e22112a6ef1d0364af32d138" ||
    probe.boundaries.length() != 22 ||
    probe.candidates.length() != 15 ||
    probe.cone.length() != 81 ||
    probe.events.length() != 17 {
    raise InvalidFormalBundleIdentity(
      "arbiter sequential: reviewed inventory drift",
    )
  }
  if dependency_generation_input(source, "clock", Clock) != probe.clock ||
    dependency_generation_input(source, "reset", Reset) != probe.reset {
    raise InvalidFormalBundleIdentity(
      "arbiter sequential: clock/reset identity",
    )
  }
  let membership = Array::make(source.nodes().length(), 0)
  for root in probe.roots {
    let binding : QueueControlAlias = {
      name: root.name,
      node: root.node,
      signal_type: root.signal_type,
    }
    if queue_control_root(source, binding, probe.clock, probe.reset) != root {
      raise InvalidFormalBundleIdentity(
        "arbiter sequential: original register drift",
      )
    }
    membership[root.node.ordinal()] += 1
  }
  for boundary in probe.boundaries {
    if dependency_generation_node(source, boundary.original.id()) !=
      boundary.original {
      raise InvalidFormalBundleIdentity(
        "arbiter sequential: original interface drift",
      )
    }
  }
  let nonconstant = probe.boundaries.filter(boundary => {
    !(boundary.original.kind() is Constant(_))
  })
  if nonconstant != probe.candidates {
    raise InvalidFormalBundleIdentity(
      "arbiter sequential: exact raw interface cuts",
    )
  }
  for candidate in probe.candidates {
    membership[candidate.original.id().ordinal()] += 1
  }
  for original in probe.cone {
    if dependency_generation_node(source, original.id()) != original {
      raise InvalidFormalBundleIdentity(
        "arbiter sequential: original cone drift",
      )
    }
    membership[original.id().ordinal()] += 1
  }
  membership[probe.clock.ordinal()] += 1
  for count in membership {
    if count > 1 {
      raise InvalidFormalBundleIdentity(
        "arbiter sequential: overlapping retained nodes",
      )
    }
  }
  for event in probe.events {
    if dependency_generation_node(source, event.node).signal_type() !=
      event.signal_type {
      raise InvalidFormalBundleIdentity(
        "arbiter sequential: original event type drift",
      )
    }
  }
  if two_client_arbiter_probe_closure(
      source,
      probe.roots,
      probe.candidates,
      probe.events,
    ) !=
    probe.cone.iter().to_array() {
    raise InvalidFormalBundleIdentity(
      "arbiter sequential: exact closed cone drift",
    )
  }
}

///|
// Preserve original node order and register next-state references. Only the
// fifteen reviewed nonconstant raw boundary nodes change to named inputs;
// original constants and every derived grant/accept/route remain operations.
#warnings("-unused_value")
fn two_client_arbiter_sequential(
  fixture : @flux_tile.QueueConservationFixture,
) -> TwoClientArbiterSequential raise {
  let source = fixture.hardware()
  let probe = two_client_arbiter_probe(fixture)
  two_client_arbiter_require_materialization(source, probe)
  let selected = source
    .nodes()
    .filter(original => {
      original.id() == probe.clock ||
      probe.roots.any(root => root.node == original.id()) ||
      probe.candidates.any(candidate => candidate.original.id() == original.id()) ||
      probe.cone.any(node => node.id() == original.id())
    })
  // Allocate all mappings before copying any register's forward next pointer.
  let mapping : Array[@ir.NodeId?] = Array::make(source.nodes().length(), None)
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
        } else if probe.candidates.any(candidate => {
            candidate.original.id() == original.id()
          }) {
          Input("cut_n\{original.id().ordinal()}")
        } else {
          dependency_generation_remap(original.kind(), mapping)
        }
      _ =>
        raise InvalidFormalBundleIdentity("arbiter sequential: repeated root")
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
    hardware: @ir.Module::checked("TwoClientArbiterSequential", nodes, outputs),
    probe,
    original_to_local: ReadOnlyArray::from_array(mapping),
  }
}
