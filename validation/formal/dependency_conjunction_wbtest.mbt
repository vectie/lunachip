///|
// Seed oracle reads original controls and ports, not the production builder.
fn dependency_conjunction_test_seeds(
  probe : DependencyConjunctionProbe,
) -> Array[QueuePacketCompositionSeed] {
  let packet = probe.packet
  let seeds : Array[QueuePacketCompositionSeed] = [
    { origin: Clock, node: packet.clock, },
    { origin: Reset, node: packet.reset, },
  ]
  for root in probe.roots {
    seeds.push({ origin: RootNext(root.name), node: root.spec.next(), })
    if root.spec.reset() is Some(control) {
      seeds.push({ origin: RootReset(root.name), node: control.signal(), })
    }
    if root.spec.enable() is Some(enable) {
      seeds.push({ origin: RootEnable(root.name), node: enable, })
    }
  }
  for observation in packet.observations {
    seeds.push({
      origin: Observation(observation.name),
      node: observation.node,
    })
  }
  for binding in probe.bindings {
    seeds.push({
      origin: Observation("dependency_" + dependency_role_name(binding.role)),
      node: binding.node,
    })
  }
  for node in packet.source.nodes() {
    if node.kind() is Input(name) &&
      node.id() != packet.clock &&
      node.id() != packet.reset {
      seeds.push({ origin: PublicInput(name), node: node.id(), })
    }
  }
  for output in packet.source.outputs() {
    seeds.push({ origin: PublicOutput(output.name()), node: output.driver(), })
  }
  for lane in packet.lanes {
    let index = lane.lane
    seeds.push({
      origin: MemoryClock(index),
      node: lane.memory.domain().clock(),
    })
    seeds.push({ origin: ReadClock(index), node: lane.read.domain().clock(), })
    seeds.push({ origin: ReadResult(index), node: lane.result.id(), })
    seeds.push({ origin: ReadAddress(index), node: lane.read.address(), })
    if lane.read.enable() is Some(enable) {
      seeds.push({ origin: ReadEnable(index), node: enable, })
    }
    seeds.push({ origin: WriteClock(index), node: lane.write.domain().clock(), })
    seeds.push({ origin: WriteAddress(index), node: lane.write.address(), })
    seeds.push({ origin: WriteData(index), node: lane.write.data(), })
    if lane.write.enable() is Some(enable) {
      seeds.push({ origin: WriteEnable(index), node: enable, })
    }
    if lane.write.mask() is Granular(signal~, ..) {
      seeds.push({ origin: WriteMask(index), node: signal, })
    }
  }
  seeds
}

///|
test "dependency conjunction retains exactly packet state and every original dependency register" {
  let queue_fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let dependency_fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let ordinary = @flux_tile.queued_concurrent_tile(
    rows=1,
    columns=1,
    max_reduction=2,
    host_bytes=1024UL,
    queue_depth=3,
  )
  let before = @ir_codec.serialize(
    @ir.Design::single("QueuedConcurrentQueueConservationPilot", ordinary),
  )
  let probe = dependency_conjunction_probe(queue_fixture, dependency_fixture)
  assert_true(
    probe == dependency_conjunction_probe(queue_fixture, dependency_fixture),
  )
  assert_eq(queue_fixture.hardware(), ordinary)
  assert_eq(dependency_fixture.hardware(), ordinary)
  assert_eq(probe.packet.source, ordinary)
  assert_eq(probe.packet.production_digest, sha256_hex(before))
  assert_eq(probe.bindings.length(), 48)
  assert_eq(probe.observations.length(), 115 + 48)
  let expected = packet_composition_test_roots(queue_fixture).map(root => {
    root.node
  })
  for index, observation in dependency_fixture.observations() {
    let binding = probe.bindings[index]
    assert_eq(binding.role, observation.role())
    assert_eq(binding.node, observation.node())
    assert_eq(binding.signal_type, observation.signal_type())
    let original = ordinary.nodes()[binding.node.ordinal()]
    if original.kind() is Register(_) && !expected.contains(original.id()) {
      expected.push(original.id())
    }
    assert_false(
      probe.candidates.any(candidate => candidate.original.id() == binding.node),
    )
    if !(original.kind() is Register(_)) {
      assert_true(probe.cone.contains(original))
    }
  }
  expected.sort_by((a, b) => a.ordinal() - b.ordinal())
  assert_eq(probe.roots.iter().map(root => root.node).to_array(), expected)
  for index, root in probe.roots {
    assert_false(
      probe.roots[:index].any(other => {
        other.node == root.node || other.name == root.name
      }),
    )
    assert_eq(ordinary.nodes()[root.node.ordinal()].kind(), Register(root.spec))
    assert_eq(root.spec.domain(), @ir.ClockDomain::rising(probe.packet.clock))
    assert_eq(root.spec.initial(), None)
    guard root.spec.reset() is Some(control) else {
      fail("retained register reset missing")
    }
    assert_eq(control.signal(), probe.packet.reset)
    assert_eq(control.mode(), Synchronous)
    assert_eq(control.polarity(), ActiveHigh)
  }
  assert_eq(
    before,
    @ir_codec.serialize(
      @ir.Design::single(
        "QueuedConcurrentQueueConservationPilot",
        queue_fixture.hardware(),
      ),
    ),
  )
}

///|
test "dependency conjunction fresh closure and every raw leaf provenance match independent traversal" {
  let probe = dependency_conjunction_probe(
    @flux_tile.queued_concurrent_queue_formal_fixture(),
    @flux_tile.queued_concurrent_dependency_formal_fixture(),
  )
  let source = probe.packet.source
  let seeds = dependency_conjunction_test_seeds(probe)
  assert_eq(probe.seeds, ReadOnlyArray::from_array(seeds))
  let retained = probe.roots.iter().map(root => root.node).to_array()
  retained.push(probe.packet.clock)
  for lane in probe.packet.lanes {
    retained.push(lane.result.id())
  }
  let reached = Array::make(source.nodes().length(), false)
  let provenance : Array[Array[Int32]] = Array::makei(source.nodes().length(), _ => {
    []
  })
  for seed_index, seed in seeds {
    let seen = Array::make(source.nodes().length(), false)
    let pending = [seed.node]
    for cursor = 0; cursor < pending.length(); cursor = cursor + 1 {
      let id = pending[cursor]
      if seen[id.ordinal()] {
        continue
      }
      seen[id.ordinal()] = true
      reached[id.ordinal()] = true
      if retained.contains(id) {
        continue
      }
      let node = source.nodes()[id.ordinal()]
      match node.kind() {
        Input(_) | Register(_) => provenance[id.ordinal()].push(seed_index)
        MemoryRead(..) | AsyncFifoRead(..) =>
          fail("unretained memory found by independent oracle")
        _ =>
          for operand in store_probe_independent_operands(node.kind()) {
            pending.push(operand)
          }
      }
    }
  }
  let candidates : Array[QueuePacketCompositionCandidate] = []
  let cone : Array[@ir.Node] = []
  for node in source.nodes() {
    if !reached[node.id().ordinal()] || retained.contains(node.id()) {
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
  assert_eq(probe.candidates, ReadOnlyArray::from_array(candidates))
  assert_eq(probe.cone, ReadOnlyArray::from_array(cone))
  for candidate in candidates {
    assert_false(candidate.provenance.is_empty())
    assert_true(
      candidate.original.kind() is Input(_) ||
      candidate.original.kind() is Register(_),
    )
  }
  for binding in probe.bindings {
    assert_true(
      seeds.any(seed => {
        seed.origin ==
        Observation("dependency_" + dependency_role_name(binding.role)) &&
        seed.node == binding.node
      }),
    )
  }
}

///|
test "dependency conjunction rejects same count forged roots observations provenance and cone" {
  let queue_fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let dependency_fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let probe = dependency_conjunction_probe(queue_fixture, dependency_fixture)
  let roots = probe.roots.iter().to_array()
  roots[0] = { ..roots[0], name: "unrelated_state", }
  let observations = probe.observations.iter().to_array()
  observations[0] = { ..observations[0], name: "fabricated_event", }
  let candidates = probe.candidates.iter().to_array()
  candidates[0] = { ..candidates[0], provenance: [], }
  let cone = probe.cone.iter().to_array()
  cone[0] = cone[1]
  for
    changed in [
      { ..probe, roots: ReadOnlyArray::from_array(roots), },
      { ..probe, observations: ReadOnlyArray::from_array(observations), },
      { ..probe, candidates: ReadOnlyArray::from_array(candidates), },
      { ..probe, cone: ReadOnlyArray::from_array(cone), },
    ] {
    queue_storage_test_reject(() => {
      ignore(
        dependency_conjunction_sequential_from_probe(
          queue_fixture, dependency_fixture, changed,
        ),
      )
    })
  }
  queue_storage_test_reject(() => {
    ignore(
      dependency_conjunction_walk(
        probe.packet,
        probe.roots,
        probe.observations,
        probe.seeds[1:],
      ),
    )
  })
  queue_storage_test_reject(() => {
    ignore(
      dependency_conjunction_walk(
        probe.packet,
        probe.roots[1:],
        probe.observations,
        probe.seeds,
      ),
    )
  })
}
