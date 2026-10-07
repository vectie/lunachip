///|
fn store_preservation_probe_seeds(
  roots : ArrayView[StorePreservationProbeRoot],
  events : ArrayView[@flux_tile.StorePreservationObservation],
  memories : ArrayView[@flux_tile.StorePreservationMemory],
) -> Array[StorePreservationProbeSeed] raise FormalGateError {
  let seeds : Array[StorePreservationProbeSeed] = []
  for root in roots {
    let role = root.binding.role()
    seeds.push({ origin: RootNext(role), node: root.spec.next(), })
    if root.spec.reset() is Some(control) {
      seeds.push({ origin: RootReset(role), node: control.signal(), })
    }
    if root.spec.enable() is Some(enable) {
      seeds.push({ origin: RootEnable(role), node: enable, })
    }
  }
  for event in events {
    guard event.role() is Event(role) else {
      raise InvalidFormalBundleIdentity("Store probe: non-event seed")
    }
    seeds.push({ origin: Event(role), node: event.node(), })
  }
  for binding in memories {
    let slot = binding.slot()
    seeds.push({ origin: ReadResult(slot), node: binding.read_node(), })
    for port in binding.memory().read_ports() {
      seeds.push({ origin: ReadAddress(slot, port.id()), node: port.address(), })
      if port.enable() is Some(enable) {
        seeds.push({ origin: ReadEnable(slot, port.id()), node: enable, })
      }
    }
    for port in binding.memory().write_ports() {
      seeds.push({
        origin: WriteAddress(slot, port.id()),
        node: port.address(),
      })
      seeds.push({ origin: WriteData(slot, port.id()), node: port.data(), })
      if port.enable() is Some(enable) {
        seeds.push({ origin: WriteEnable(slot, port.id()), node: enable, })
      }
      if port.mask() is Granular(signal~, ..) {
        seeds.push({ origin: WriteMask(slot, port.id()), node: signal, })
      }
    }
  }
  seeds
}

///|
#warnings("-unused_value")
fn store_preservation_probe_from_parts(
  source : @ir.Module,
  observations : ArrayView[@flux_tile.StorePreservationObservation],
  memories : ArrayView[@flux_tile.StorePreservationMemory],
) -> StorePreservationProbe raise {
  let clock = dependency_generation_input(source, "clock", Clock)
  let reset = dependency_generation_input(source, "reset", Reset)
  let domain = @ir.ClockDomain::rising(clock)
  if source.name() != "FluxTileQueuedConcurrent" ||
    source.domains() != [domain] ||
    !source.cdc_primitives().is_empty() ||
    observations.length() != 83 ||
    memories.length() != 2 {
    raise InvalidFormalBundleIdentity("Store probe: source/inventory contract")
  }
  let roots : Array[StorePreservationProbeRoot] = []
  for index, binding in observations {
    let original = dependency_generation_node(source, binding.node())
    if original.signal_type() != binding.signal_type() ||
      binding.signal_type() !=
      store_preservation_probe_role_type(binding.role()) ||
      observations[0:index].any(previous => previous.role() == binding.role()) {
      raise InvalidFormalBundleIdentity(
        "Store probe: exact observation identity",
      )
    }
    match binding.role() {
      Event(_) =>
        if original.kind() is Input(_) ||
          original.kind() is Register(_) ||
          original.kind() is MemoryRead(..) ||
          original.kind() is AsyncFifoRead(..) {
          raise InvalidFormalBundleIdentity("Store probe: non-derived event")
        }
      CReadData(slot) => {
        guard memories.filter(memory => memory.slot() == slot) is [memory] &&
          memory.read_node() == binding.node() else {
          raise InvalidFormalBundleIdentity("Store probe: C read observation")
        }
      }
      _ => {
        let root = queue_control_root(
          source,
          {
            name: "Store root",
            node: binding.node(),
            signal_type: binding.signal_type(),
          },
          clock,
          reset,
        )
        if roots.any(previous => previous.original.id() == original.id()) {
          raise InvalidFormalBundleIdentity(
            "Store probe: aliased essential registers",
          )
        }
        roots.push({ binding, original, spec: root.spec, })
      }
    }
  }
  let events : Array[@flux_tile.StorePreservationObservation] = []
  for role in store_preservation_probe_event_roles() {
    guard observations.filter(binding => binding.role() == Event(role))
      is [binding] else {
      raise InvalidFormalBundleIdentity("Store probe: missing original event")
    }
    events.push(binding)
  }
  roots.sort_by((left, right) => {
    left.original.id().ordinal() - right.original.id().ordinal()
  })
  let ordered_memories = memories.to_owned()
  ordered_memories.sort_by((left, right) => left.slot() - right.slot())
  if ordered_memories[0].slot() != 0 ||
    ordered_memories[1].slot() != 1 ||
    ordered_memories[0].memory().id() == ordered_memories[1].memory().id() ||
    ordered_memories[0].read_node() == ordered_memories[1].read_node() {
    raise InvalidFormalBundleIdentity("Store probe: two distinct C stores")
  }
  let seeds = store_preservation_probe_seeds(roots, events, ordered_memories)
  let (candidates, cone) = store_preservation_probe_walk(
    source, roots, events, ordered_memories, seeds, clock, reset, domain,
  )
  {
    source,
    source_digest: sha256_hex(
      @ir_codec.serialize(
        @ir.Design::single("QueuedConcurrentStorePreservationProbe", source),
      ),
    ),
    clock,
    reset,
    domain,
    roots: ReadOnlyArray::from_array(roots),
    events: ReadOnlyArray::from_array(events),
    memories: ReadOnlyArray::from_array(ordered_memories),
    seeds: ReadOnlyArray::from_array(seeds),
    candidates: ReadOnlyArray::from_array(candidates),
    cone: ReadOnlyArray::from_array(cone),
  }
}

///|
#warnings("-unused_value")
fn store_preservation_probe(
  fixture : @flux_tile.StorePreservationFixture,
) -> StorePreservationProbe raise {
  store_preservation_probe_from_parts(
    fixture.hardware(),
    fixture.observations(),
    fixture.c_memories(),
  )
}

///|
#warnings("-unused_value")
fn store_preservation_probe_report(
  probe : StorePreservationProbe,
) -> String raise FormalGateError {
  let out = StringBuilder()
  out.write_string("CANDIDATE-PROBE ONLY-not-accepted-projection-or-proof\n")
  out.write_string("NO-CUT-AUTHORITY no-materialization-or-observers\n")
  out.write_string("PRODUCTION sha256 \{probe.source_digest}\n")
  out.write_string(
    "DOMAIN \{Repr(probe.domain)} RESET \{probe.reset.ordinal()}\n",
  )
  out.write_string(
    "ESSENTIAL roots \{probe.roots.length()} bits515 C-cell-bits256 C-read-bits64\n",
  )
  out.write_string(
    "CANDIDATES \{probe.candidates.length()} CONE \{probe.cone.length()} EVENTS \{probe.events.length()} SEEDS \{probe.seeds.length()}\n",
  )
  for root in probe.roots {
    let spec = "\{Repr(root.spec)}".replace_all(old="\n", new="")
    out.write_string(
      "ROOT \{Repr(root.binding.role())} node \{root.original.id().ordinal()} type \{Repr(root.original.signal_type())} spec \{spec}\n",
    )
  }
  for event in probe.events {
    let original = dependency_generation_node(probe.source, event.node())
    let kind = "\{Repr(original.kind())}".replace_all(old="\n", new="")
    out.write_string(
      "EVENT \{Repr(event.role())} node \{event.node().ordinal()} type \{Repr(event.signal_type())} kind \{kind}\n",
    )
  }
  for binding in probe.memories {
    let spec = "\{Repr(binding.memory())}".replace_all(old="\n", new="")
    out.write_string(
      "RETAINED-MEMORY slot \{binding.slot()} read-node \{binding.read_node().ordinal()} spec \{spec}\n",
    )
  }
  for index, seed in probe.seeds {
    out.write_string(
      "SEED \{index} origin \{Repr(seed.origin)} node \{seed.node.ordinal()}\n",
    )
  }
  for candidate in probe.candidates {
    let node = candidate.original
    let kind = "\{Repr(node.kind())}".replace_all(old="\n", new="")
    out.write_string(
      "CANDIDATE node \{node.id().ordinal()} type \{Repr(node.signal_type())} kind \{kind} seeds \{Repr(candidate.provenance)}\n",
    )
    if candidate.memory is Some(memory) {
      let spec = "\{Repr(memory)}".replace_all(old="\n", new="")
      out.write_string("FOREIGN-MEMORY-CONTROLS \{spec}\n")
    }
  }
  for node in probe.cone {
    let kind = "\{Repr(node.kind())}".replace_all(old="\n", new="")
    out.write_string(
      "CONE node \{node.id().ordinal()} type \{Repr(node.signal_type())} kind \{kind}\n",
    )
  }
  out.to_string()
}
