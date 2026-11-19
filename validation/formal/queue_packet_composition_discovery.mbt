///|
// Walk each causal seed independently. Registered FIFO results stop at their
// actual retained memory port, whose entire dependencies are separate seeds.
// No ready/issue/collector/ACK expression can be made an input boundary.
fn queue_packet_composition_walk(
  source : @ir.Module,
  roots : ArrayView[DependencyComputeRoot],
  lanes : ArrayView[QueueStorageLane],
  seeds : ArrayView[QueuePacketCompositionSeed],
  clock : @ir.NodeId,
  reset : @ir.NodeId,
) -> (Array[QueuePacketCompositionCandidate], Array[@ir.Node]) raise FormalGateError {
  if roots.length() != 54 ||
    roots.iter().fold(init=0, (n, root) => n + root.signal_type.width().bits()) !=
    876 ||
    lanes.length() != 4 ||
    seeds.is_empty() ||
    clock != dependency_generation_input(source, "clock", Clock) ||
    reset != dependency_generation_input(source, "reset", Reset) {
    raise InvalidFormalBundleIdentity(
      "packet composition: incomplete state storage or source domains",
    )
  }
  for index, root in roots {
    if roots[:index].any(prior => prior.node == root.node) ||
      queue_control_root(
        source,
        { name: root.name, node: root.node, signal_type: root.signal_type, },
        clock,
        reset,
      ) !=
      root {
      raise InvalidFormalBundleIdentity(
        "packet composition: essential original register drift",
      )
    }
  }
  for index, lane in lanes {
    queue_storage_validate_lane(source, lane, clock, reset)
    if lane.lane != index ||
      lanes[:index].any(prior => {
        prior.memory.id() == lane.memory.id() ||
        prior.result.id() == lane.result.id()
      }) ||
      !roots.contains(lane.read_pointer) ||
      !roots.contains(lane.write_pointer) {
      raise InvalidFormalBundleIdentity(
        "packet composition: retained FIFO identity or pointer drift",
      )
    }
  }
  let visited = Array::make(source.nodes().length(), false)
  let provenance : Array[Array[Int32]] = Array::makei(source.nodes().length(), _ => {
    []
  })
  for seed_index, seed in seeds {
    let seen = Array::make(source.nodes().length(), false)
    let pending = [seed.node]
    for cursor = 0; cursor < pending.length(); cursor = cursor + 1 {
      let node = dependency_generation_node(source, pending[cursor])
      let index = node.id().ordinal()
      if seen[index] {
        continue
      }
      seen[index] = true
      visited[index] = true
      if node.id() == clock ||
        roots.any(root => root.node == node.id()) ||
        lanes.any(lane => lane.result.id() == node.id()) {
        continue
      }
      match node.kind() {
        Input(_) | Register(_) => {
          ignore(queue_owner_candidate_leaf(source, node, reset))
          if node.kind() is Register(spec) &&
            spec.domain() != @ir.ClockDomain::rising(clock) {
            raise InvalidFormalBundleIdentity(
              "packet composition: foreign state domain",
            )
          }
          provenance[index].push(seed_index)
        }
        MemoryRead(..) | AsyncFifoRead(..) =>
          raise InvalidFormalBundleIdentity(
            "packet composition: unretained read or asynchronous leaf",
          )
        _ => {
          if !node.signal_type().is_data() {
            raise InvalidFormalBundleIdentity(
              "packet composition: foreign control cone",
            )
          }
          for operand in dependency_generation_operands(node.kind()) {
            pending.push(operand)
          }
        }
      }
    }
  }
  let candidates : Array[QueuePacketCompositionCandidate] = []
  let cone : Array[@ir.Node] = []
  for node in source.nodes() {
    if !visited[node.id().ordinal()] ||
      node.id() == clock ||
      roots.any(root => root.node == node.id()) ||
      lanes.any(lane => lane.result.id() == node.id()) {
      continue
    }
    let origins = provenance[node.id().ordinal()]
    if origins.is_empty() {
      cone.push(node)
    } else {
      candidates.push({
        original: node,
        provenance: ReadOnlyArray::from_array(origins),
      })
    }
  }
  (candidates, cone)
}

///|
#warnings("-unused_value")
fn queue_packet_composition_probe(
  fixture : @flux_tile.QueueConservationFixture,
) -> QueuePacketCompositionProbe raise {
  let source = fixture.hardware()
  let production_digest = sha256_hex(
    @ir_codec.serialize(
      @ir.Design::single("QueuedConcurrentQueueConservationPilot", source),
    ),
  )
  if production_digest !=
    "35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc" {
    raise InvalidFormalBundleIdentity(
      "packet composition: canonical production drift",
    )
  }
  let (
    roots,
    lanes,
    observations,
    clock,
    reset,
    owner_inventory_digest,
    storage_inventory_digest,
  ) = queue_packet_composition_inventory(fixture)
  for lane in lanes {
    queue_storage_validate_lane(source, lane, clock, reset)
  }
  let seeds = queue_packet_composition_seeds(
    source, roots, lanes, observations, clock, reset,
  )
  let (candidates, cone) = queue_packet_composition_walk(
    source, roots, lanes, seeds, clock, reset,
  )
  // All role aliases resolve their actual original node. Register roles may
  // be raw foreign records; combinational decisions must remain in the cone.
  for observation in observations {
    let original = dependency_generation_node(source, observation.node)
    if original.signal_type() != observation.signal_type {
      raise InvalidFormalBundleIdentity("packet composition: role type drift")
    }
    match original.kind() {
      Input(_) | Register(_) | MemoryRead(..) => ()
      _ =>
        if !cone.contains(original) ||
          candidates.any(leaf => leaf.original.id() == observation.node) {
          raise InvalidFormalBundleIdentity(
            "packet composition: derived role cut",
          )
        }
    }
  }
  {
    source,
    production_digest,
    owner_inventory_digest,
    storage_inventory_digest,
    clock,
    reset,
    roots: ReadOnlyArray::from_array(roots),
    lanes: ReadOnlyArray::from_array(lanes),
    observations: ReadOnlyArray::from_array(observations),
    seeds: ReadOnlyArray::from_array(seeds),
    candidates: ReadOnlyArray::from_array(candidates),
    cone: ReadOnlyArray::from_array(cone),
  }
}
