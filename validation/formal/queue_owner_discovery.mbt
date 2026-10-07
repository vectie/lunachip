///|
fn queue_owner_candidate_leaf(
  hardware : @ir.Module,
  node : @ir.Node,
  reset : @ir.NodeId,
) -> QueueOwnerCandidateLeaf raise FormalGateError {
  if !node.signal_type().is_data() &&
    !(node.id() == reset &&
    node.signal_type() is Reset &&
    node.kind() is Input("reset")) {
    raise InvalidFormalBundleIdentity(
      "queue owner probe: unexpected control leaf",
    )
  }
  let memory = match node.kind() {
    Input(_) | Register(_) => None
    MemoryRead(memory~, port~) => {
      guard hardware.memories().filter(spec => spec.id() == memory) is [spec] &&
        spec.read_ports().filter(read => read.id() == port) is [read] &&
        read.result() == node.id() &&
        spec.element_type() == node.signal_type() &&
        read.latency() is OneCycle else {
        raise InvalidFormalBundleIdentity(
          "queue owner probe: synchronous memory read identity",
        )
      }
      Some(spec)
    }
    AsyncFifoRead(..) =>
      raise InvalidFormalBundleIdentity(
        "queue owner probe: asynchronous FIFO leaf",
      )
    _ =>
      raise InvalidFormalBundleIdentity("queue owner probe: not a foreign leaf")
  }
  { original: node, memory, }
}

///|
// Bootstrap discovery only. Every combinational operation is walked unchanged;
// no ready/accept/finish/collector/terminal expression can become a candidate.
fn queue_owner_probe_walk(
  hardware : @ir.Module,
  roots : ArrayView[DependencyComputeRoot],
  seeds : ArrayView[@ir.NodeId],
  reset : @ir.NodeId,
) -> (Array[QueueOwnerCandidateLeaf], Array[@ir.Node]) raise FormalGateError {
  if roots.length() != 30 ||
    roots
    .iter()
    .fold(init=0, (bits, root) => bits + root.signal_type.width().bits()) !=
    304 {
    raise InvalidFormalBundleIdentity(
      "queue owner probe: unretained essential state",
    )
  }
  let visited = Array::make(hardware.nodes().length(), false)
  let pending = seeds.to_owned()
  let leaves : Array[QueueOwnerCandidateLeaf] = []
  // Each original node is visited at most once; operands only extend this
  // worklist through the finite checked canonical graph.
  for cursor = 0; cursor < pending.length(); cursor = cursor + 1 {
    let node = dependency_generation_node(hardware, pending[cursor])
    if visited[node.id().ordinal()] {
      continue
    }
    visited[node.id().ordinal()] = true
    if roots.any(root => root.node == node.id()) {
      guard node.kind() is Register(_) else {
        raise InvalidFormalBundleIdentity(
          "queue owner probe: unretained essential state",
        )
      }
      continue
    }
    match node.kind() {
      Input(_) | Register(_) | MemoryRead(..) | AsyncFifoRead(..) =>
        leaves.push(queue_owner_candidate_leaf(hardware, node, reset))
      _ => {
        if !node.signal_type().is_data() {
          raise InvalidFormalBundleIdentity(
            "queue owner probe: control in combinational cone",
          )
        }
        for operand in dependency_generation_operands(node.kind()) {
          pending.push(operand)
        }
      }
    }
  }
  leaves.sort_by((left, right) => {
    left.original.id().ordinal() - right.original.id().ordinal()
  })
  let cone = hardware
    .nodes()
    .iter()
    .filter(node => {
      visited[node.id().ordinal()] &&
      !roots.any(root => root.node == node.id()) &&
      !leaves.any(leaf => leaf.original.id() == node.id())
    })
    .to_array()
  (leaves, cone)
}

///|
// Private inspection checkpoint only, not an accepted projection. The frozen
// production digest blocks source drift even before candidate classification.
#warnings("-unused_value")
fn queue_owner_probe(
  fixture : @flux_tile.QueueConservationFixture,
) -> QueueOwnerProbe raise {
  let hardware = fixture.hardware()
  let digest = sha256_hex(
    @ir_codec.serialize(
      @ir.Design::single("QueuedConcurrentQueueConservationPilot", hardware),
    ),
  )
  if digest !=
    "35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc" {
    raise InvalidFormalBundleIdentity(
      "queue owner probe: frozen production drift",
    )
  }
  let base = queue_control_discover(fixture)
  let roots = base.roots.iter().to_array()
  let added : Array[@flux_tile.QueueConservationRole] = [HeadTicket, NextTicket]
  for entry in 0..<3 {
    added.push(EntryTerminal(entry))
    added.push(EntryTicket(entry))
  }
  for engine in 0..<3 {
    added.push(EngineState(engine))
    added.push(EngineTicket(engine))
  }
  for role in added {
    let root = queue_control_root(
      hardware,
      queue_control_binding(fixture, role),
      base.clock,
      base.reset,
    )
    if roots.any(previous => previous.node == root.node) {
      raise InvalidFormalBundleIdentity(
        "queue owner probe: aliased essential roots",
      )
    }
    roots.push(root)
  }
  if roots.length() != 30 ||
    roots
    .iter()
    .fold(init=0, (bits, root) => bits + root.signal_type.width().bits()) !=
    304 {
    raise InvalidFormalBundleIdentity(
      "queue owner probe: essential state inventory",
    )
  }
  // Keep the existing individual lane/control equations, but restore the
  // original derived HeadFinish instead of the older raw abstraction label.
  let events = base.events
    .filter(event => event.name != "dispatch_finish_raw")
    .iter()
    .to_array()
  let added_events : Array[@flux_tile.QueueConservationRole] = [
    HeadIssue,
    HeadFinish,
    HeadReject,
    HeadFence,
  ]
  for engine in 0..<3 {
    added_events.push(EngineAccept(engine))
    added_events.push(EngineTerminal(engine))
  }
  for entry in 0..<3 {
    added_events.push(EntryLocalTerminal(entry))
    for engine in 0..<3 {
      added_events.push(EntryCollector(entry, engine))
    }
  }
  for role in added_events {
    let binding = queue_control_binding(fixture, role)
    if events.any(event => event.name == binding.name) {
      raise InvalidFormalBundleIdentity(
        "queue owner probe: repeated derived event",
      )
    }
    events.push(binding)
  }
  let seeds : Array[@ir.NodeId] = []
  for root in roots {
    seeds.push(root.spec.next())
    if root.spec.reset() is Some(control) {
      seeds.push(control.signal())
    }
    if root.spec.enable() is Some(enable) {
      seeds.push(enable)
    }
  }
  for event in events {
    seeds.push(event.node)
  }
  let (candidates, cone) = queue_owner_probe_walk(
    hardware,
    roots,
    seeds,
    base.reset,
  )
  for event in events {
    if candidates.any(leaf => leaf.original.id() == event.node) ||
      !cone.any(node => node.id() == event.node) {
      raise InvalidFormalBundleIdentity(
        "queue owner probe: derived event cut or missing",
      )
    }
  }
  {
    roots: ReadOnlyArray::from_array(roots),
    candidates: ReadOnlyArray::from_array(candidates),
    cone: ReadOnlyArray::from_array(cone),
    events: ReadOnlyArray::from_array(events),
    clock: base.clock,
    reset: base.reset,
    production_digest: digest,
  }
}

///|
#warnings("-unused_value")
fn queue_owner_probe_report(probe : QueueOwnerProbe) -> String {
  let out = StringBuilder()
  out.write_string("CANDIDATE-PROBE ONLY-not-accepted-projection-or-proof\n")
  out.write_string("PRODUCTION sha256 \{probe.production_digest}\n")
  out.write_string("ESSENTIAL roots \{probe.roots.length()} bits304\n")
  out.write_string(
    "CANDIDATES \{probe.candidates.length()} CONE \{probe.cone.length()} EVENTS \{probe.events.length()}\n",
  )
  for root in probe.roots {
    let spec = "\{Repr(root.spec)}".replace_all(old="\n", new="")
    out.write_string(
      "ROOT \{root.name} node \{root.node.ordinal()} type \{Repr(root.signal_type)} spec \{spec}\n",
    )
  }
  for event in probe.events {
    out.write_string(
      "EVENT \{event.name} node \{event.node.ordinal()} type \{Repr(event.signal_type)}\n",
    )
  }
  for leaf in probe.candidates {
    let node = leaf.original
    let kind = "\{Repr(node.kind())}".replace_all(old="\n", new="")
    out.write_string(
      "CANDIDATE node \{node.id().ordinal()} type \{Repr(node.signal_type())} kind \{kind}\n",
    )
    if leaf.memory is Some(memory) {
      let controls = "\{Repr(memory)}".replace_all(old="\n", new="")
      out.write_string("MEMORY-CONTROLS \{controls}\n")
    }
  }
  out.to_string()
}
