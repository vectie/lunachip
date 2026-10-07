///|
// This checkpoint materializes only the freshly rederived candidate closure.
// It does not accept its remaining raw boundaries for a formal packet task.
// Later boundary acceptance requires inspection/pinning of the full new report.
fn queue_packet_composition_sequential_from_probe(
  fixture : @flux_tile.QueueConservationFixture,
  probe : QueuePacketCompositionProbe,
) -> QueuePacketCompositionSequential raise {
  if probe != queue_packet_composition_probe(fixture) {
    raise InvalidFormalBundleIdentity(
      "packet composition: full original closure drift",
    )
  }
  let source = probe.source
  let cuts : Array[DependencyGenerationCut] = []
  for candidate in probe.candidates {
    let original = candidate.original
    let role = match original.kind() {
      Input(name) => name
      Register(_) => "foreign_n\{original.id().ordinal()}"
      _ =>
        raise InvalidFormalBundleIdentity(
          "packet composition: unreviewed storage or derived cut",
        )
    }
    if candidate.provenance.is_empty() {
      raise InvalidFormalBundleIdentity(
        "packet composition: missing boundary provenance",
      )
    }
    cuts.push({
      node: original.id(),
      signal_type: original.signal_type(),
      roles: [role],
    })
  }
  let selected = source
    .nodes()
    .filter(node => {
      node.id() == probe.clock ||
      probe.roots.any(root => root.node == node.id()) ||
      cuts.any(cut => cut.node == node.id()) ||
      probe.cone.contains(node) ||
      probe.lanes.any(lane => lane.result.id() == node.id())
    })
  if selected.length() !=
    1 +
    probe.roots.length() +
    cuts.length() +
    probe.cone.length() +
    probe.lanes.length() {
    raise InvalidFormalBundleIdentity(
      "packet composition: overlapping selected sets",
    )
  }
  let mapping : Array[@ir.NodeId?] = Array::make(source.nodes().length(), None)
  for index, original in selected {
    mapping[original.id().ordinal()] = Some(@ir.NodeId::new(index))
  }
  let original_memories = source
    .memories()
    .filter(memory => probe.lanes.any(lane => lane.memory == memory))
  if original_memories.length() != 4 {
    raise InvalidFormalBundleIdentity(
      "packet composition: complete original FIFO memory identity",
    )
  }
  let memory_mapping : Array[@ir.MemoryId?] = Array::make(
    source.memories().length(),
    None,
  )
  for index, memory in original_memories {
    memory_mapping[memory.id().ordinal()] = Some(@ir.MemoryId::new(index))
  }
  let nodes : Array[@ir.Node] = []
  for original in selected {
    let kind : @ir.NodeKind = match
      probe.roots.filter(root => root.node == original.id()) {
      [root] => dependency_sequential_register_kind(root.spec, mapping)
      [] =>
        if original.id() == probe.clock {
          Input("clock")
        } else if cuts.any(cut => cut.node == original.id()) {
          Input("cut_n\{original.id().ordinal()}")
        } else if probe.lanes.any(lane => lane.result.id() == original.id()) {
          guard original.kind() is MemoryRead(memory~, port~) else {
            raise InvalidFormalBundleIdentity(
              "packet composition: actual read-result kind",
            )
          }
          MemoryRead(
            memory=queue_storage_sequential_mapped_memory(
              memory_mapping, memory,
            ),
            port~,
          )
        } else {
          dependency_generation_remap(original.kind(), mapping)
        }
      _ =>
        raise InvalidFormalBundleIdentity(
          "packet composition: repeated state root",
        )
    }
    nodes.push(
      @ir.Node::new(
        dependency_generation_mapped(mapping, original.id()),
        original.signal_type(),
        kind,
      ),
    )
  }
  let memories : Array[@ir.MemorySpec] = []
  for memory in original_memories {
    memories.push(
      queue_storage_sequential_memory(memory, mapping, memory_mapping),
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
  for observation in probe.observations {
    outputs.push(
      @ir.OutputPort::new(
        observation.name,
        observation.signal_type,
        dependency_generation_mapped(mapping, observation.node),
      ),
    )
  }
  // Preserve actual public drivers, not synthetic handshake/result aliases.
  for output in source.outputs() {
    outputs.push(
      @ir.OutputPort::new(
        "public_" + output.name(),
        output.signal_type(),
        dependency_generation_mapped(mapping, output.driver()),
      ),
    )
  }
  for lane in probe.lanes {
    guard lane.read.enable() is Some(pop_fire) &&
      lane.write.enable() is Some(push_fire) else {
      raise InvalidFormalBundleIdentity(
        "packet composition: actual FIFO fires missing",
      )
    }
    for
      (name, node) in [
        ("fifo_pop_fire_\{lane.lane}", pop_fire),
        ("fifo_push_fire_\{lane.lane}", push_fire),
      ] {
      outputs.push(
        @ir.OutputPort::new(
          name,
          queue_role_type(HeadPop),
          dependency_generation_mapped(mapping, node),
        ),
      )
    }
  }
  {
    probe,
    hardware: @ir.Module::checked_with_memories(
      "QueuePacketCompositionSequential", nodes, memories, outputs,
    ),
    cuts: ReadOnlyArray::from_array(cuts),
    original_to_local: ReadOnlyArray::from_array(mapping),
    original_to_local_memory: ReadOnlyArray::from_array(memory_mapping),
    inventory_digest: sha256_hex(queue_packet_composition_report(probe)),
  }
}

///|
#warnings("-unused_value")
fn queue_packet_composition_sequential(
  fixture : @flux_tile.QueueConservationFixture,
) -> QueuePacketCompositionSequential raise {
  queue_packet_composition_sequential_from_probe(
    fixture,
    queue_packet_composition_probe(fixture),
  )
}
