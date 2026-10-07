///|
// This reviewed report is an acceptance boundary for the FIFO-to-head prefix,
// not permission to use these foreign records in full retirement provenance.
// The exact source/report pins bind the following complete category review;
// discovery resolves identities from original observations/ports, not these
// explanatory ordinals:
//   7 public inputs: reset1, descriptor-valid4, payload5..8, completion-ready9.
//   1 HeadTicket20; 3 terminal27/34/41 and 3 entry-ticket28/35/42 records.
//  12 writer status/ticket records47..58 and 4 dependency records59..62.
//   1 arbiter-state387 (including freely changing poison/no-poison timing).
//  10 engine/lease/selectors: loader425/426/439, Store441/442,
//     compute455/456/458/459/460.
//  12 A0/A1/B0/B1 valid/rows/columns publication records558..569.
//   6 C0/C1 valid/rows/columns records1082/1087/1088,1131/1136/1137.
// Every raw register becomes one shared symbolic input, with arbitrary values
// and changes, even impossible production histories. Terminal27/34/41 are the
// SAME nodes in HeadFinish/fence and ring-retirement/ACK equations. No separate
// per-use aliases, terminal identity, monotonic poison, idle/readiness, storage
// availability, generation or fairness premise is introduced. These cuts can
// cause premature retirement or permanent dispatch stalls: neither undermines
// prefix data preservation, but neither supports ownership, ordinal p12,
// completion-payload correctness, fault/progress or eventual-completion claims.
fn queue_storage_require_inventory(
  probe : QueueStorageProbe,
) -> Unit raise FormalGateError {
  if probe.production_digest !=
    "35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc" ||
    sha256_hex(queue_storage_probe_report(probe)) !=
    "9a4613301556bfd0229a8696e219e9853047f645813e4f5b27032fdc5476f29d" {
    raise InvalidFormalBundleIdentity(
      "queue storage sequential: reviewed prefix inventory drift",
    )
  }
}

///|
// Explicit probe argument permits fail-closed source/report corruption tests.
// Acceptance rederives every original root/port/cone/seed/provenance before
// materializing, and never trusts a count-only or caller-supplied cut roster.
fn queue_storage_sequential_from_probe(
  fixture : @flux_tile.QueueConservationFixture,
  probe : QueueStorageProbe,
) -> QueueStorageSequential raise {
  queue_storage_require_inventory(probe)
  if probe != queue_storage_probe(fixture) {
    raise InvalidFormalBundleIdentity(
      "queue storage sequential: original closure drift",
    )
  }
  let source = fixture.hardware()
  let cuts : Array[DependencyGenerationCut] = []
  let mut inputs = 0
  let mut registers = 0
  for candidate in probe.candidates {
    let original = candidate.original
    let role = match original.kind() {
      Input(name) => {
        inputs += 1
        name
      }
      Register(_) => {
        registers += 1
        "foreign_n\{original.id().ordinal()}"
      }
      _ =>
        raise InvalidFormalBundleIdentity(
          "queue storage sequential: unreviewed leaf kind",
        )
    }
    if candidate.memory != None ||
      candidate.provenance.is_empty() ||
      cuts.any(cut => cut.node == original.id()) {
      raise InvalidFormalBundleIdentity(
        "queue storage sequential: candidate identity drift",
      )
    }
    cuts.push({
      node: original.id(),
      signal_type: original.signal_type(),
      roles: [role],
    })
  }
  if inputs != 7 || registers != 52 || probe.cone.length() != 801 {
    raise InvalidFormalBundleIdentity(
      "queue storage sequential: reviewed category inventory",
    )
  }
  let selected = source
    .nodes()
    .filter(node => {
      node.id() == probe.clock ||
      probe.roots.any(root => root.node == node.id()) ||
      cuts.any(cut => cut.node == node.id()) ||
      probe.cone.any(original => original.id() == node.id()) ||
      probe.lanes.any(lane => lane.result.id() == node.id())
    })
  let mapping : Array[@ir.NodeId?] = Array::make(source.nodes().length(), None)
  for index, original in selected {
    mapping[original.id().ordinal()] = Some(@ir.NodeId::new(index))
  }
  let original_memories = source
    .memories()
    .filter(memory => probe.lanes.any(lane => lane.memory.id() == memory.id()))
  let memory_mapping : Array[@ir.MemoryId?] = Array::make(
    source.memories().length(),
    None,
  )
  for index, memory in original_memories {
    memory_mapping[memory.id().ordinal()] = Some(@ir.MemoryId::new(index))
  }
  if selected.length() != 893 || original_memories.length() != 4 {
    raise InvalidFormalBundleIdentity(
      "queue storage sequential: retained graph inventory",
    )
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
              "queue storage sequential: original read kind",
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
          "queue storage sequential: repeated root",
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
  for event in probe.events {
    outputs.push(
      @ir.OutputPort::new(
        event.name,
        event.signal_type,
        dependency_generation_mapped(mapping, event.node),
      ),
    )
  }
  for lane in probe.lanes {
    outputs.push(
      @ir.OutputPort::new(
        queue_role_name(FifoResponseData(lane.lane)),
        lane.result.signal_type(),
        dependency_generation_mapped(mapping, lane.result.id()),
      ),
    )
  }
  {
    hardware: @ir.Module::checked_with_memories(
      "QueueStorageSequential", nodes, memories, outputs,
    ),
    probe,
    cuts: ReadOnlyArray::from_array(cuts),
    original_to_local: ReadOnlyArray::from_array(mapping),
    original_to_local_memory: ReadOnlyArray::from_array(memory_mapping),
    inventory_digest: "9a4613301556bfd0229a8696e219e9853047f645813e4f5b27032fdc5476f29d",
  }
}

///|
#warnings("-unused_value")
fn queue_storage_sequential(
  fixture : @flux_tile.QueueConservationFixture,
) -> QueueStorageSequential raise {
  queue_storage_sequential_from_probe(fixture, queue_storage_probe(fixture))
}
