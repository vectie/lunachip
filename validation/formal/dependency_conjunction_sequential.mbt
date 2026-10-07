///|
// Materialize the freshly rederived candidate graph, not an accepted theorem
// boundary. Full report review/pinning and native correspondence precede proof.
fn dependency_conjunction_sequential_from_probe(
  queue_fixture : @flux_tile.QueueConservationFixture,
  dependency_fixture : @flux_tile.QueuedConcurrentFormalFixture,
  probe : DependencyConjunctionProbe,
) -> DependencyConjunctionSequential raise {
  if probe != dependency_conjunction_probe(queue_fixture, dependency_fixture) {
    raise InvalidFormalBundleIdentity(
      "dependency conjunction: full fresh source/closure drift",
    )
  }
  let packet = probe.packet
  let source = packet.source
  let cuts : Array[DependencyGenerationCut] = []
  for candidate in probe.candidates {
    let original = candidate.original
    let role = match original.kind() {
      Input(name) => name
      Register(_) => "foreign_n\{original.id().ordinal()}"
      _ =>
        raise InvalidFormalBundleIdentity(
          "dependency conjunction: derived/storage cut",
        )
    }
    if candidate.provenance.is_empty() {
      raise InvalidFormalBundleIdentity(
        "dependency conjunction: missing cut provenance",
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
      node.id() == packet.clock ||
      probe.roots.any(root => root.node == node.id()) ||
      cuts.any(cut => cut.node == node.id()) ||
      probe.cone.contains(node) ||
      packet.lanes.any(lane => lane.result.id() == node.id())
    })
  if selected.length() !=
    1 +
    probe.roots.length() +
    cuts.length() +
    probe.cone.length() +
    packet.lanes.length() {
    raise InvalidFormalBundleIdentity(
      "dependency conjunction: selected sets overlap",
    )
  }
  let mapping : Array[@ir.NodeId?] = Array::make(source.nodes().length(), None)
  for index, original in selected {
    mapping[original.id().ordinal()] = Some(@ir.NodeId::new(index))
  }
  let original_memories = source
    .memories()
    .filter(memory => packet.lanes.any(lane => lane.memory == memory))
  if original_memories.length() != packet.lanes.length() {
    raise InvalidFormalBundleIdentity(
      "dependency conjunction: incomplete actual FIFO identity",
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
        if original.id() == packet.clock {
          Input("clock")
        } else if cuts.any(cut => cut.node == original.id()) {
          Input("cut_n\{original.id().ordinal()}")
        } else if packet.lanes.any(lane => lane.result.id() == original.id()) {
          guard original.kind() is MemoryRead(memory~, port~) else {
            raise InvalidFormalBundleIdentity(
              "dependency conjunction: actual read state kind",
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
          "dependency conjunction: repeated retained state",
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
  for output in source.outputs() {
    outputs.push(
      @ir.OutputPort::new(
        "public_" + output.name(),
        output.signal_type(),
        dependency_generation_mapped(mapping, output.driver()),
      ),
    )
  }
  for lane in packet.lanes {
    guard lane.read.enable() is Some(pop_fire) &&
      lane.write.enable() is Some(push_fire) else {
      raise InvalidFormalBundleIdentity(
        "dependency conjunction: original memory fire missing",
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
  // Same explicitly reviewed unused original pin as the accepted packet
  // source. This reaches the existing host payload input without any new node.
  let response_data = dependency_generation_input(
    source,
    "memory_response_data",
    queue_public_port_type("memory_response_data", 32),
  )
  guard cuts.filter(cut => cut.roles == ["memory_response_data"])
    is [response_cut] &&
    response_cut.node == response_data else {
    raise InvalidFormalBundleIdentity(
      "dependency conjunction: public response-data identity",
    )
  }
  outputs.push(
    @ir.OutputPort::new(
      "public_input_memory_response_data",
      response_cut.signal_type,
      dependency_generation_mapped(mapping, response_data),
    ),
  )
  {
    probe,
    hardware: @ir.Module::checked_with_memories(
      "DependencyConjunctionSequential", nodes, memories, outputs,
    ),
    cuts: ReadOnlyArray::from_array(cuts),
    original_to_local: ReadOnlyArray::from_array(mapping),
    original_to_local_memory: ReadOnlyArray::from_array(memory_mapping),
    inventory_digest: sha256_hex(dependency_conjunction_report(probe)),
  }
}

///|
#warnings("-unused_value")
fn dependency_conjunction_sequential(
  queue_fixture : @flux_tile.QueueConservationFixture,
  dependency_fixture : @flux_tile.QueuedConcurrentFormalFixture,
) -> DependencyConjunctionSequential raise {
  dependency_conjunction_sequential_from_probe(
    queue_fixture,
    dependency_fixture,
    dependency_conjunction_probe(queue_fixture, dependency_fixture),
  )
}
