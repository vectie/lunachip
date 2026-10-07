///|
// Independently recover seeds from original specifications and ports. The
// production seed builder and its old owner/prefix cut rosters are not used.
fn packet_composition_test_seeds(
  fixture : @flux_tile.QueueConservationFixture,
  probe : QueuePacketCompositionProbe,
) -> Array[QueuePacketCompositionSeed] raise {
  let source = fixture.hardware()
  let seeds : Array[QueuePacketCompositionSeed] = [
    { origin: Clock, node: probe.clock, },
    { origin: Reset, node: probe.reset, },
  ]
  for root in packet_composition_test_roots(fixture) {
    guard source.nodes()[root.node.ordinal()].kind() is Register(spec) else {
      fail("original root missing")
    }
    seeds.push({ origin: RootNext(root.name), node: spec.next(), })
    if spec.reset() is Some(control) {
      seeds.push({ origin: RootReset(root.name), node: control.signal(), })
    }
    if spec.enable() is Some(enable) {
      seeds.push({ origin: RootEnable(root.name), node: enable, })
    }
  }
  for binding in probe.observations {
    guard fixture
      .observations()
      .filter(item => queue_role_name(item.role()) == binding.name)
      is [item] else {
      fail("seed oracle role missing")
    }
    seeds.push({ origin: Observation(binding.name), node: item.node(), })
  }
  for node in source.nodes() {
    if node.kind() is Input(name) &&
      node.id() != probe.clock &&
      node.id() != probe.reset {
      seeds.push({ origin: PublicInput(name), node: node.id(), })
    }
  }
  for output in source.outputs() {
    seeds.push({ origin: PublicOutput(output.name()), node: output.driver(), })
  }
  for lane in 0..<4 {
    guard fixture
      .observations()
      .filter(item => item.role() == FifoResponseData(lane))
      is [item] else {
      fail("read state role missing")
    }
    guard source.nodes()[item.node().ordinal()].kind()
      is MemoryRead(memory~, port~) else {
      fail("read state kind missing")
    }
    let memory = source.memories()[memory.ordinal()]
    guard memory.read_ports().filter(read => read.id() == port) is [read] &&
      memory.write_ports() is [write] else {
      fail("memory port seeds missing")
    }
    seeds.push({ origin: MemoryClock(lane), node: memory.domain().clock(), })
    seeds.push({ origin: ReadClock(lane), node: read.domain().clock(), })
    seeds.push({ origin: ReadResult(lane), node: item.node(), })
    seeds.push({ origin: ReadAddress(lane), node: read.address(), })
    if read.enable() is Some(enable) {
      seeds.push({ origin: ReadEnable(lane), node: enable, })
    }
    seeds.push({ origin: WriteClock(lane), node: write.domain().clock(), })
    seeds.push({ origin: WriteAddress(lane), node: write.address(), })
    seeds.push({ origin: WriteData(lane), node: write.data(), })
    if write.enable() is Some(enable) {
      seeds.push({ origin: WriteEnable(lane), node: enable, })
    }
    if write.mask() is Granular(signal~, ..) {
      seeds.push({ origin: WriteMask(lane), node: signal, })
    }
  }
  seeds
}

///|
test "packet composition closure and each boundary provenance match independent original traversal" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let probe = queue_packet_composition_probe(fixture)
  let source = fixture.hardware()
  let seeds = packet_composition_test_seeds(fixture, probe)
  assert_eq(probe.seeds, ReadOnlyArray::from_array(seeds))
  let roots = packet_composition_test_roots(fixture)
  let retained = roots.map(root => root.node)
  retained.push(probe.clock)
  for lane in 0..<4 {
    guard fixture
      .observations()
      .filter(item => item.role() == FifoResponseData(lane))
      is [item] else {
      fail("read state missing")
    }
    retained.push(item.node())
  }
  let reached = Array::make(source.nodes().length(), false)
  let provenance : Array[Array[Int]] = Array::makei(source.nodes().length(), _ => {
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
          fail("independent closure found unretained storage")
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
  for index, candidate in candidates {
    assert_false(candidate.provenance.is_empty())
    assert_true(
      candidate.original.kind() is Input(_) ||
      candidate.original.kind() is Register(_),
    )
    if index > 0 {
      assert_true(
        candidates[index - 1].original.id().ordinal() <
        candidate.original.id().ordinal(),
      )
    }
  }
  for entry in 0..<3 {
    for
      role in [
        @flux_tile.QueueConservationRole::EntryId(entry),
        EntryFault(entry),
        EntryProgress(entry),
        EntryAddress(entry),
      ] {
      let name = queue_role_name(role)
      assert_true(seeds.any(seed => seed.origin == RootNext(name)))
      guard roots.filter(root => root.name == name) is [root] else {
        fail("completion field missing")
      }
      assert_false(
        candidates.any(candidate => candidate.original.id() == root.node),
      )
    }
  }
}
