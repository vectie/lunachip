///|
// Once any actual read state is reached, retain the WHOLE original memory:
// all reads/results, all writes/masks and every control/data/address/clock.
fn store_storage_projection_memory_dependencies(
  memory : @ir.MemorySpec,
) -> Array[@ir.NodeId] {
  let nodes = [memory.domain().clock()]
  for read in memory.read_ports() {
    nodes.push(read.result())
    nodes.push(read.domain().clock())
    nodes.push(read.address())
    if read.enable() is Some(enable) {
      nodes.push(enable)
    }
  }
  for write in memory.write_ports() {
    nodes.push(write.domain().clock())
    nodes.push(write.address())
    nodes.push(write.data())
    if write.enable() is Some(enable) {
      nodes.push(enable)
    }
    if write.mask() is Granular(signal~, ..) {
      nodes.push(signal)
    }
  }
  nodes
}

///|
fn store_storage_projection_arithmetic(
  probe : StorePreservationProbe,
) -> Array[@ir.Node] raise {
  if probe.source_digest !=
    "69b9a4a97b7ee2b050ad46d93ffe1786a54e09a932c431db30afc9255aa09f4a" ||
    sha256_hex(store_preservation_probe_report(probe)) !=
    "719035593a20e9edace3b6190a5a3ad84b330b27f45a2d6997d9daa42a20dfb7" {
    raise InvalidFormalBundleIdentity(
      "Store projection: exact reviewed source/arithmetic inventory",
    )
  }
  let arithmetic = probe.candidates.filter(candidate => {
    candidate.original.kind() is Register(_) &&
    candidate.original.signal_type() == @wire.sint(32)
  })
  if arithmetic.length() != 4 {
    raise InvalidFormalBundleIdentity(
      "Store projection: four original arithmetic producers",
    )
  }
  for candidate in arithmetic {
    if candidate.memory != None || candidate.provenance.length() != 2 {
      raise InvalidFormalBundleIdentity(
        "Store projection: arithmetic-only provenance",
      )
    }
    for slot in 0..<2 {
      if !candidate.provenance.any(index => {
          probe.seeds[index].origin is WriteData(selected, _) &&
          selected == slot
        }) {
        raise InvalidFormalBundleIdentity(
          "Store projection: shared two-slot arithmetic producer",
        )
      }
    }
    guard candidate.original.kind() is Register(spec) &&
      spec.domain() == probe.domain else {
      raise InvalidFormalBundleIdentity(
        "Store projection: original arithmetic domain",
      )
    }
  }
  arithmetic.map(candidate => candidate.original).iter().to_array()
}

///|
// Fixed-point transition closure, not the former leaf-stopping discovery. In
// particular all49 foreign controls/identity registers recursively retain
// feedback. Public input leaves are original ports; only four payload values
// stop recursion. Actual memory reads are never arbitrary input leaves.
fn store_storage_projection_plan(
  fixture : @flux_tile.StorePreservationFixture,
) -> StoreStorageProjectionPlan raise {
  let probe = store_preservation_probe(fixture)
  let source = probe.source
  let arithmetic = store_storage_projection_arithmetic(probe)
  let arbiter_roots = store_storage_projection_arbiter(probe)
  let seeds : Array[@ir.NodeId] = [probe.clock, probe.reset]
  for observation in fixture.observations() {
    seeds.push(observation.node())
  }
  // Retain ordinary ABI for real public transcripts, including descriptor,
  // completion and both DMA channels; no test-only/internal observation input.
  for output in source.outputs() {
    seeds.push(output.driver())
  }
  for root in arbiter_roots {
    seeds.push(root.node)
  }
  let pending = seeds.iter().to_array()
  let seen = Array::make(source.nodes().length(), false)
  let memory_seen = Array::make(source.memories().length(), false)
  for cursor = 0; cursor < pending.length(); cursor = cursor + 1 {
    let id = pending[cursor]
    let node = dependency_generation_node(source, id)
    if seen[id.ordinal()] {
      continue
    }
    seen[id.ordinal()] = true
    if arithmetic.any(cut => cut.id() == id) {
      continue
    }
    match node.kind() {
      Input(_) => ()
      Register(spec) => {
        if spec.domain() != probe.domain {
          raise InvalidFormalBundleIdentity(
            "Store projection: unsupported register clock domain",
          )
        }
        pending.push(spec.domain().clock())
        pending.push(spec.next())
        if spec.reset() is Some(control) {
          pending.push(control.signal())
        }
        if spec.enable() is Some(enable) {
          pending.push(enable)
        }
      }
      MemoryRead(memory~, port~) => {
        guard source.memories().filter(spec => spec.id() == memory) is [spec] &&
          spec.read_ports().filter(read => read.id() == port) is [read] &&
          read.result() == id else {
          raise InvalidFormalBundleIdentity(
            "Store projection: actual synchronous storage identity",
          )
        }
        if !memory_seen[memory.ordinal()] {
          store_preservation_probe_memory_spec(source, spec, probe.domain)
          memory_seen[memory.ordinal()] = true
          for dependency in store_storage_projection_memory_dependencies(spec) {
            pending.push(dependency)
          }
        }
      }
      AsyncFifoRead(..) =>
        raise InvalidFormalBundleIdentity(
          "Store projection: unsupported asynchronous storage",
        )
      _ =>
        for dependency in dependency_generation_operands(node.kind()) {
          pending.push(dependency)
        }
    }
  }
  let selected = source.nodes().filter(node => seen[node.id().ordinal()])
  let memories = source
    .memories()
    .filter(memory => memory_seen[memory.id().ordinal()])
  for cut in arithmetic {
    if !seen[cut.id().ordinal()] {
      raise InvalidFormalBundleIdentity(
        "Store projection: unconsumed arithmetic cut",
      )
    }
  }
  for candidate in probe.candidates {
    if !seen[candidate.original.id().ordinal()] {
      raise InvalidFormalBundleIdentity(
        "Store projection: missing prior control/identity dependency",
      )
    }
  }
  for binding in probe.memories {
    if !memory_seen[binding.memory().id().ordinal()] ||
      !seen[binding.read_node().ordinal()] {
      raise InvalidFormalBundleIdentity(
        "Store projection: missing original C storage",
      )
    }
  }
  for root in arbiter_roots {
    if !seen[root.node.ordinal()] ||
      arithmetic.any(cut => cut.id() == root.node) {
      raise InvalidFormalBundleIdentity(
        "Store projection: omitted/cut arbiter register",
      )
    }
  }
  {
    probe,
    observations: fixture.observations(),
    arithmetic: ReadOnlyArray::from_array(arithmetic),
    arbiter_roots: ReadOnlyArray::from_array(arbiter_roots),
    seeds: ReadOnlyArray::from_array(seeds),
    selected,
    memories,
  }
}
