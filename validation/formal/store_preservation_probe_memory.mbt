///|
fn store_preservation_probe_memory_spec(
  source : @ir.Module,
  memory : @ir.MemorySpec,
  domain : @ir.ClockDomain,
) -> Unit raise FormalGateError {
  guard source.memories().filter(item => item.id() == memory.id()) is [original] &&
    original == memory &&
    memory.domain() == domain else {
    raise InvalidFormalBundleIdentity("Store probe: memory source/domain")
  }
  let address_type = @ir.SignalType::UInt(memory.depth().address_width())
  for port in memory.read_ports() {
    let result = dependency_generation_node(source, port.result())
    if port.domain() != domain ||
      !(port.latency() is OneCycle) ||
      result.signal_type() != memory.element_type() ||
      !(result.kind() is MemoryRead(memory=id, port=read) &&
      id == memory.id() &&
      read == port.id()) ||
      dependency_generation_node(source, port.address()).signal_type() !=
      address_type {
      raise InvalidFormalBundleIdentity("Store probe: memory read dependency")
    }
    if port.enable() is Some(enable) &&
      dependency_generation_node(source, enable).signal_type() !=
      queue_public_port_type("memory-enable", 1) {
      raise InvalidFormalBundleIdentity("Store probe: memory read enable")
    }
  }
  for port in memory.write_ports() {
    if port.domain() != domain ||
      dependency_generation_node(source, port.address()).signal_type() !=
      address_type ||
      dependency_generation_node(source, port.data()).signal_type() !=
      memory.element_type() {
      raise InvalidFormalBundleIdentity("Store probe: memory write dependency")
    }
    if port.enable() is Some(enable) &&
      dependency_generation_node(source, enable).signal_type() !=
      queue_public_port_type("memory-enable", 1) {
      raise InvalidFormalBundleIdentity("Store probe: memory write enable")
    }
    if port.mask() is Granular(signal~, granularity~) {
      let width = memory.element_type().width().bits()
      if width % granularity.bits() != 0 ||
        dependency_generation_node(source, signal).signal_type() !=
        queue_public_port_type(
          "memory_request_mask",
          width / granularity.bits(),
        ) {
        raise InvalidFormalBundleIdentity("Store probe: memory write mask")
      }
    }
  }
}

///|
fn store_preservation_probe_memory(
  source : @ir.Module,
  binding : @flux_tile.StorePreservationMemory,
  domain : @ir.ClockDomain,
) -> Unit raise FormalGateError {
  let memory = binding.memory()
  store_preservation_probe_memory_spec(source, memory, domain)
  guard (binding.slot() == 0 || binding.slot() == 1) &&
    memory.element_type() is SInt(width) &&
    width.bits() == 32 &&
    memory.depth().elements() == 4 &&
    memory.read_ports() is [read] &&
    memory.write_ports() is [write] &&
    read.result() == binding.read_node() &&
    read.enable_behavior() is HoldLast &&
    read.enable() is Some(_) &&
    write.enable() is Some(_) &&
    write.mask() is All &&
    memory.read_write_policy() is ReadOld &&
    memory.multi_write_policy() is Reject &&
    memory.bounds_policy() is Fault else {
    raise InvalidFormalBundleIdentity(
      "Store probe: retained C storage contract",
    )
  }
}

///|
fn store_preservation_probe_candidate(
  source : @ir.Module,
  node : @ir.Node,
  domain : @ir.ClockDomain,
  reset : @ir.NodeId,
) -> StorePreservationProbeCandidate raise FormalGateError {
  if dependency_generation_node(source, node.id()) != node ||
    (
      !node.signal_type().is_data() &&
      !(node.id() == reset &&
      node.signal_type() is Reset &&
      node.kind() is Input("reset"))
    ) {
    raise InvalidFormalBundleIdentity(
      "Store probe: foreign source/control leaf",
    )
  }
  let memory = match node.kind() {
    Input(_) => None
    Register(spec) => {
      if spec.domain() != domain ||
        dependency_generation_node(source, spec.next()).signal_type() !=
        node.signal_type() {
        raise InvalidFormalBundleIdentity(
          "Store probe: foreign register dependency/domain",
        )
      }
      if spec.enable() is Some(enable) &&
        dependency_generation_node(source, enable).signal_type() !=
        queue_public_port_type("register-enable", 1) {
        raise InvalidFormalBundleIdentity(
          "Store probe: foreign register enable",
        )
      }
      if spec.reset() is Some(control) &&
        (
          control.signal() != reset ||
          !(control.mode() is Synchronous) ||
          !(control.polarity() is ActiveHigh)
        ) {
        raise InvalidFormalBundleIdentity("Store probe: foreign register reset")
      }
      None
    }
    MemoryRead(memory~, port~) => {
      guard source.memories().filter(item => item.id() == memory) is [spec] &&
        spec.read_ports().filter(item => item.id() == port) is [read] &&
        read.result() == node.id() else {
        raise InvalidFormalBundleIdentity(
          "Store probe: foreign memory read identity",
        )
      }
      store_preservation_probe_memory_spec(source, spec, domain)
      Some(spec)
    }
    AsyncFifoRead(..) =>
      raise InvalidFormalBundleIdentity(
        "Store probe: asynchronous storage leaf",
      )
    _ => raise InvalidFormalBundleIdentity("Store probe: not a foreign leaf")
  }
  { original: node, memory, provenance: [], }
}

///|
// A retained memory read is state, not a free input. Its original port
// dependencies are separately seeded even if no current output consumes it.
fn store_preservation_probe_walk(
  source : @ir.Module,
  roots : ArrayView[StorePreservationProbeRoot],
  events : ArrayView[@flux_tile.StorePreservationObservation],
  memories : ArrayView[@flux_tile.StorePreservationMemory],
  seeds : ArrayView[StorePreservationProbeSeed],
  clock : @ir.NodeId,
  reset : @ir.NodeId,
  domain : @ir.ClockDomain,
) -> (Array[StorePreservationProbeCandidate], Array[@ir.Node]) raise FormalGateError {
  if roots.length() != 48 ||
    events.length() != 33 ||
    memories.length() != 2 ||
    roots
    .iter()
    .fold(init=0, (bits, root) => {
      bits + root.original.signal_type().width().bits()
    }) !=
    515 ||
    domain != @ir.ClockDomain::rising(clock) ||
    dependency_generation_node(source, clock).signal_type() !=
    @ir.SignalType::Clock ||
    dependency_generation_node(source, reset).signal_type() !=
    @ir.SignalType::Reset ||
    seeds != store_preservation_probe_seeds(roots, events, memories)[:] {
    raise InvalidFormalBundleIdentity(
      "Store probe: incomplete state/storage seeds",
    )
  }
  for index, root in roots {
    let role = root.binding.role()
    let expected = store_preservation_probe_role_type(role) catch {
      _ => raise InvalidFormalBundleIdentity("Store probe: root role/type")
    }
    if role is Event(_) ||
      role is CReadData(_) ||
      root.binding.signal_type() != expected ||
      roots[0:index].any(previous => {
        previous.binding.role() == role ||
        previous.original.id() == root.original.id()
      }) {
      raise InvalidFormalBundleIdentity(
        "Store probe: missing/duplicated essential root",
      )
    }
    let actual = queue_control_root(
      source,
      {
        name: "Store root",
        node: root.binding.node(),
        signal_type: root.binding.signal_type(),
      },
      clock,
      reset,
    )
    if dependency_generation_node(source, root.binding.node()) != root.original ||
      actual.spec != root.spec {
      raise InvalidFormalBundleIdentity("Store probe: root source identity")
    }
  }
  let event_roles = store_preservation_probe_event_roles()
  for index, event in events {
    let original = dependency_generation_node(source, event.node())
    let expected = store_preservation_probe_role_type(event.role()) catch {
      _ => raise InvalidFormalBundleIdentity("Store probe: event role/type")
    }
    if event.role() != Event(event_roles[index]) ||
      event.signal_type() != expected ||
      original.signal_type() != expected ||
      original.kind() is Input(_) ||
      original.kind() is Register(_) ||
      original.kind() is MemoryRead(..) ||
      original.kind() is AsyncFifoRead(..) {
      raise InvalidFormalBundleIdentity(
        "Store probe: exact derived event inventory",
      )
    }
  }
  for index, memory in memories {
    if memory.slot() != index ||
      memories[0:index].any(previous => {
        previous.memory().id() == memory.memory().id() ||
        previous.read_node() == memory.read_node()
      }) {
      raise InvalidFormalBundleIdentity(
        "Store probe: missing/duplicated C memory",
      )
    }
    store_preservation_probe_memory(source, memory, domain)
  }
  let provenance : Array[Array[Int]] = Array::makei(source.nodes().length(), _ => {
    []
  })
  let visited = Array::make(source.nodes().length(), false)
  // Every seed receives an independent visited set. This records every causal
  // seed reaching a candidate, not only the first worklist path to that leaf.
  for seed_index, seed in seeds {
    let seen = Array::make(source.nodes().length(), false)
    let pending = [seed.node]
    // Finite checked graph: each original node appends operands at most once.
    for cursor = 0; cursor < pending.length(); cursor = cursor + 1 {
      let node = dependency_generation_node(source, pending[cursor])
      let index = node.id().ordinal()
      if seen[index] {
        continue
      }
      seen[index] = true
      visited[index] = true
      if roots.any(root => root.original.id() == node.id()) ||
        memories.any(memory => memory.read_node() == node.id()) {
        continue
      }
      match node.kind() {
        Input(_) | Register(_) | MemoryRead(..) | AsyncFifoRead(..) => {
          ignore(
            store_preservation_probe_candidate(source, node, domain, reset),
          )
          provenance[index].push(seed_index)
        }
        _ => {
          if !node.signal_type().is_data() {
            raise InvalidFormalBundleIdentity(
              "Store probe: control in combinational cone",
            )
          }
          for operand in dependency_generation_operands(node.kind()) {
            pending.push(operand)
          }
        }
      }
    }
  }
  let candidates : Array[StorePreservationProbeCandidate] = []
  let cone : Array[@ir.Node] = []
  for node in source.nodes() {
    if !visited[node.id().ordinal()] ||
      roots.any(root => root.original.id() == node.id()) ||
      memories.any(memory => memory.read_node() == node.id()) {
      continue
    }
    let origins = provenance[node.id().ordinal()]
    if origins.is_empty() {
      cone.push(node)
    } else {
      let candidate = store_preservation_probe_candidate(
        source, node, domain, reset,
      )
      candidates.push({
        ..candidate,
        provenance: ReadOnlyArray::from_array(origins),
      })
    }
  }
  for event in events {
    if candidates.any(candidate => candidate.original.id() == event.node()) {
      raise InvalidFormalBundleIdentity(
        "Store probe: derived event became candidate",
      )
    }
  }
  (candidates, cone)
}
