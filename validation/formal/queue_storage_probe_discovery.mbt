///|
fn queue_storage_probe_inventory(
  fixture : @flux_tile.QueueConservationFixture,
) -> (
  Array[DependencyComputeRoot],
  Array[QueueStorageLane],
  Array[QueueControlAlias],
  @ir.NodeId,
  @ir.NodeId,
) raise FormalGateError {
  let hardware = fixture.hardware()
  let base = queue_control_discover(fixture)
  let roots = base.roots.iter().to_array()
  let lanes : Array[QueueStorageLane] = []
  for index in 0..<4 {
    let lane = queue_storage_lane(fixture, index, base.clock, base.reset)
    lanes.push(lane)
    roots.push(lane.read_pointer)
    roots.push(lane.write_pointer)
    roots.push(
      queue_control_root(
        hardware,
        queue_control_binding(fixture, HeadLane(index)),
        base.clock,
        base.reset,
      ),
    )
  }
  let events = base.events
    .filter(event => event.name != "dispatch_finish_raw")
    .iter()
    .to_array()
  events.push(queue_control_binding(fixture, HeadFinish))
  for lane in lanes {
    guard lane.read.enable() is Some(pop_fire) &&
      lane.write.enable() is Some(push_fire) else {
      raise InvalidFormalBundleIdentity(
        "queue storage probe: missing port enables",
      )
    }
    for
      (name, node) in [
        ("fifo_pop_fire_\{lane.lane}", pop_fire),
        ("fifo_push_fire_\{lane.lane}", push_fire),
      ] {
      events.push({ name, node, signal_type: queue_role_type(HeadPop), })
    }
  }
  (roots, lanes, events, base.clock, base.reset)
}

///|
fn queue_storage_probe_seeds(
  roots : ArrayView[DependencyComputeRoot],
  lanes : ArrayView[QueueStorageLane],
  events : ArrayView[QueueControlAlias],
) -> Array[QueueStorageProbeSeed] raise FormalGateError {
  let seeds : Array[QueueStorageProbeSeed] = []
  for root in roots {
    seeds.push({ origin: RootNext(root.name), node: root.spec.next(), })
    if root.spec.reset() is Some(control) {
      seeds.push({ origin: RootReset(root.name), node: control.signal(), })
    }
    if root.spec.enable() is Some(enable) {
      seeds.push({ origin: RootEnable(root.name), node: enable, })
    }
  }
  for event in events {
    seeds.push({ origin: Event(event.name), node: event.node, })
  }
  for lane in lanes {
    guard lane.read.enable() is Some(read_enable) &&
      lane.write.enable() is Some(write_enable) else {
      raise InvalidFormalBundleIdentity(
        "queue storage probe: missing port enable seeds",
      )
    }
    seeds.push({ origin: ReadResult(lane.lane), node: lane.result.id(), })
    seeds.push({ origin: ReadAddress(lane.lane), node: lane.read.address(), })
    seeds.push({ origin: ReadEnable(lane.lane), node: read_enable, })
    seeds.push({ origin: WriteAddress(lane.lane), node: lane.write.address(), })
    seeds.push({ origin: WriteData(lane.lane), node: lane.write.data(), })
    seeds.push({ origin: WriteEnable(lane.lane), node: write_enable, })
  }
  seeds
}

///|
// A storage read stops only at one of the four retained original memories.
// Foreign data/control records remain review candidates, never accepted cuts.
fn queue_storage_probe_walk(
  fixture : @flux_tile.QueueConservationFixture,
  roots : ArrayView[DependencyComputeRoot],
  lanes : ArrayView[QueueStorageLane],
  events : ArrayView[QueueControlAlias],
  seeds : ArrayView[QueueStorageProbeSeed],
  reset : @ir.NodeId,
) -> (Array[QueueStorageProbeCandidate], Array[@ir.Node]) raise FormalGateError {
  let hardware = fixture.hardware()
  let (expected_roots, expected_lanes, expected_events, clock, expected_reset) = queue_storage_probe_inventory(
    fixture,
  )
  if roots.length() != 28 ||
    roots
    .iter()
    .fold(init=0, (bits, root) => bits + root.signal_type.width().bits()) !=
    309 ||
    lanes.length() != 4 ||
    roots != expected_roots[:] ||
    lanes != expected_lanes[:] ||
    events != expected_events[:] ||
    reset != expected_reset ||
    seeds !=
    queue_storage_probe_seeds(expected_roots, expected_lanes, expected_events)[:] {
    raise InvalidFormalBundleIdentity(
      "queue storage probe: essential inventory",
    )
  }
  for index, lane in lanes {
    if lane.lane != index ||
      lanes.any(other => {
        other.lane != index &&
        (
          other.memory.id() == lane.memory.id() ||
          other.result.id() == lane.result.id()
        )
      }) {
      raise InvalidFormalBundleIdentity("queue storage probe: repeated storage")
    }
    queue_storage_validate_lane(hardware, lane, clock, reset)
    for pointer in [lane.read_pointer, lane.write_pointer] {
      if !roots.contains(pointer) {
        raise InvalidFormalBundleIdentity(
          "queue storage probe: unretained pointer",
        )
      }
    }
  }
  for index, root in roots {
    if roots[:index].any(prior => prior.node == root.node) ||
      queue_control_root(
        hardware,
        { name: root.name, node: root.node, signal_type: root.signal_type, },
        clock,
        reset,
      ) !=
      root {
      raise InvalidFormalBundleIdentity(
        "queue storage probe: root source drift",
      )
    }
  }
  let visited = Array::make(hardware.nodes().length(), false)
  let provenance : Array[Array[Int32]] = Array::makei(
    hardware.nodes().length(),
    _ => [],
  )
  // Independent traversal per seed retains every causal origin, not merely
  // whichever seed first reached a leaf in a shared visited worklist.
  for seed_index, seed in seeds {
    let seen = Array::make(hardware.nodes().length(), false)
    let pending = [seed.node]
    for cursor = 0; cursor < pending.length(); cursor = cursor + 1 {
      let node = dependency_generation_node(hardware, pending[cursor])
      let index = node.id().ordinal()
      if seen[index] {
        continue
      }
      seen[index] = true
      visited[index] = true
      if roots.any(root => root.node == node.id()) ||
        lanes.any(lane => lane.result.id() == node.id()) {
        continue
      }
      match node.kind() {
        Input(_) | Register(_) => {
          ignore(queue_owner_candidate_leaf(hardware, node, reset))
          provenance[index].push(seed_index)
        }
        MemoryRead(..) | AsyncFifoRead(..) =>
          raise InvalidFormalBundleIdentity(
            "queue storage probe: unretained storage leaf",
          )
        _ => {
          if !node.signal_type().is_data() {
            raise InvalidFormalBundleIdentity(
              "queue storage probe: control in cone",
            )
          }
          for operand in dependency_generation_operands(node.kind()) {
            pending.push(operand)
          }
        }
      }
    }
  }
  let candidates : Array[QueueStorageProbeCandidate] = []
  let cone : Array[@ir.Node] = []
  for node in hardware.nodes() {
    if !visited[node.id().ordinal()] ||
      roots.any(root => root.node == node.id()) ||
      lanes.any(lane => lane.result.id() == node.id()) {
      continue
    }
    let origins = provenance[node.id().ordinal()]
    if origins.is_empty() {
      cone.push(node)
    } else {
      let leaf = queue_owner_candidate_leaf(hardware, node, reset)
      candidates.push({
        original: leaf.original,
        memory: leaf.memory,
        provenance: ReadOnlyArray::from_array(origins),
      })
    }
  }
  (candidates, cone)
}

///|
// A frozen source-bound candidate discovery, not an approved abstraction.
#warnings("-unused_value")
fn queue_storage_probe(
  fixture : @flux_tile.QueueConservationFixture,
) -> QueueStorageProbe raise {
  let hardware = fixture.hardware()
  let digest = sha256_hex(
    @ir_codec.serialize(
      @ir.Design::single("QueuedConcurrentQueueConservationPilot", hardware),
    ),
  )
  if digest !=
    "35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc" {
    raise InvalidFormalBundleIdentity(
      "queue storage probe: frozen production drift",
    )
  }
  let (roots, lanes, events, clock, reset) = queue_storage_probe_inventory(
    fixture,
  )
  let seeds = queue_storage_probe_seeds(roots, lanes, events)
  let (candidates, cone) = queue_storage_probe_walk(
    fixture, roots, lanes, events, seeds, reset,
  )
  for event in events {
    if candidates.any(leaf => leaf.original.id() == event.node) ||
      !cone.any(node => node.id() == event.node) ||
      dependency_generation_node(hardware, event.node).signal_type() !=
      event.signal_type {
      raise InvalidFormalBundleIdentity(
        "queue storage probe: derived event missing/cut",
      )
    }
  }
  {
    roots: ReadOnlyArray::from_array(roots),
    lanes: ReadOnlyArray::from_array(lanes),
    seeds: ReadOnlyArray::from_array(seeds),
    candidates: ReadOnlyArray::from_array(candidates),
    cone: ReadOnlyArray::from_array(cone),
    events: ReadOnlyArray::from_array(events),
    clock,
    reset,
    production_digest: digest,
  }
}

///|
// All original signatures are included, not merely a cone node count.
#warnings("-unused_value")
fn queue_storage_probe_report(probe : QueueStorageProbe) -> String {
  let out = StringBuilder()
  out.write_string(
    "CANDIDATE-STORAGE-PROBE ONLY-not-accepted-cut-projection-or-proof\n",
  )
  out.write_string("PRODUCTION sha256 \{probe.production_digest}\n")
  out.write_string(
    "ESSENTIAL roots \{probe.roots.length()} bits309 MEMORIES \{probe.lanes.length()} words12 cell-bits768 READ-STATE bits256\n",
  )
  out.write_string(
    "INITIAL original-uninitialized-registers-and-memory-read-state-no-zero-storage-assumption\n",
  )
  out.write_string(
    "CANDIDATES \{probe.candidates.length()} CONE \{probe.cone.length()} EVENTS \{probe.events.length()} SEEDS \{probe.seeds.length()}\n",
  )
  for root in probe.roots {
    let spec = "\{Repr(root.spec)}".replace_all(old="\n", new="")
    out.write_string(
      "ROOT \{root.name} node \{root.node.ordinal()} type \{Repr(root.signal_type)} spec \{spec}\n",
    )
  }
  for lane in probe.lanes {
    let memory = "\{Repr(lane.memory)}".replace_all(old="\n", new="")
    let result = "\{Repr(lane.result.kind())}".replace_all(old="\n", new="")
    out.write_string(
      "MEMORY lane\{lane.lane} public-data \{lane.public_data.ordinal()} controls \{memory}\n",
    )
    out.write_string(
      "READ-STATE lane\{lane.lane} node \{lane.result.id().ordinal()} type \{Repr(lane.result.signal_type())} kind \{result}\n",
    )
  }
  for event in probe.events {
    out.write_string(
      "EVENT \{event.name} node \{event.node.ordinal()} type \{Repr(event.signal_type)}\n",
    )
  }
  for index, seed in probe.seeds {
    out.write_string(
      "SEED \{index} origin \{Repr(seed.origin)} node \{seed.node.ordinal()}\n",
    )
  }
  for node in probe.cone {
    let kind = "\{Repr(node.kind())}".replace_all(old="\n", new="")
    out.write_string(
      "CONE node \{node.id().ordinal()} type \{Repr(node.signal_type())} kind \{kind}\n",
    )
  }
  for leaf in probe.candidates {
    let node = leaf.original
    let kind = "\{Repr(node.kind())}".replace_all(old="\n", new="")
    out.write_string(
      "CANDIDATE node \{node.id().ordinal()} type \{Repr(node.signal_type())} kind \{kind} seeds \{Repr(leaf.provenance)}\n",
    )
  }
  out.to_string()
}
