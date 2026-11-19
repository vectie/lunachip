///|
// Rewalk each root transition, observation, public pin and actual memory port.
// Only raw foreign registers/public inputs may stop recursion. In particular
// no derived readiness, conflict, preflight, terminal or capture event is free.
fn dependency_conjunction_walk(
  packet : QueuePacketCompositionProbe,
  roots : ArrayView[DependencyComputeRoot],
  observations : ArrayView[QueueControlAlias],
  seeds : ArrayView[QueuePacketCompositionSeed],
) -> (Array[QueuePacketCompositionCandidate], Array[@ir.Node]) raise {
  let source = packet.source
  let clock = packet.clock
  let reset = packet.reset
  let lanes = packet.lanes
  if seeds !=
    queue_packet_composition_seeds(
      source, roots, lanes, observations, clock, reset,
    )[:] ||
    packet.roots.any(root => !roots.contains(root)) {
    raise InvalidFormalBundleIdentity(
      "dependency conjunction: omitted original causal seed/state",
    )
  }
  for index, root in roots {
    if roots[:index].any(prior => {
        prior.node == root.node || prior.name == root.name
      }) ||
      queue_control_root(
        source,
        { name: root.name, node: root.node, signal_type: root.signal_type, },
        clock,
        reset,
      ) !=
      root {
      raise InvalidFormalBundleIdentity(
        "dependency conjunction: original register identity",
      )
    }
  }
  for lane in lanes {
    queue_storage_validate_lane(source, lane, clock, reset)
    if !roots.contains(lane.read_pointer) || !roots.contains(lane.write_pointer) {
      raise InvalidFormalBundleIdentity(
        "dependency conjunction: actual memory pointer omitted",
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
              "dependency conjunction: foreign state domain",
            )
          }
          provenance[index].push(seed_index)
        }
        MemoryRead(..) | AsyncFifoRead(..) =>
          raise InvalidFormalBundleIdentity(
            "dependency conjunction: unretained actual storage",
          )
        _ => {
          if !node.signal_type().is_data() {
            raise InvalidFormalBundleIdentity(
              "dependency conjunction: foreign control cone",
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
