///|
// These tests inspect original state and dependencies only. They do not accept
// cuts, construct a sequential projection, or establish packet provenance.
fn queue_storage_test_seeds(
  probe : QueueStorageProbe,
) -> Array[QueueStorageProbeSeed] {
  let seeds : Array[QueueStorageProbeSeed] = []
  for root in probe.roots {
    seeds.push({ origin: RootNext(root.name), node: root.spec.next(), })
    if root.spec.reset() is Some(control) {
      seeds.push({ origin: RootReset(root.name), node: control.signal(), })
    }
    if root.spec.enable() is Some(enable) {
      seeds.push({ origin: RootEnable(root.name), node: enable, })
    }
  }
  for event in probe.events {
    seeds.push({ origin: Event(event.name), node: event.node, })
  }
  for lane in probe.lanes {
    seeds.push({ origin: ReadResult(lane.lane), node: lane.result.id(), })
    seeds.push({ origin: ReadAddress(lane.lane), node: lane.read.address(), })
    if lane.read.enable() is Some(enable) {
      seeds.push({ origin: ReadEnable(lane.lane), node: enable, })
    }
    seeds.push({ origin: WriteAddress(lane.lane), node: lane.write.address(), })
    seeds.push({ origin: WriteData(lane.lane), node: lane.write.data(), })
    if lane.write.enable() is Some(enable) {
      seeds.push({ origin: WriteEnable(lane.lane), node: enable, })
    }
  }
  seeds
}

///|
test "queue storage candidate closure is independently complete and source ordered" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let source = fixture.hardware()
  let probe = queue_storage_probe(fixture)
  let seeds = queue_storage_test_seeds(probe)
  assert_eq(probe.seeds.iter().to_array(), seeds)
  assert_eq(seeds.length(), 126)
  // Independently classify the transitive original graph, starting at every
  // register transition/control and memory port; do not trust reported cuts.
  let visited = Array::make(source.nodes().length(), false)
  let foreign = Array::make(source.nodes().length(), false)
  let provenance : Array[Array[Int32]] = []
  for _ in source.nodes() {
    provenance.push([])
  }
  for seed_index, seed in seeds {
    let pending = [seed.node]
    let reached = Array::make(source.nodes().length(), false)
    for cursor = 0; cursor < pending.length(); cursor = cursor + 1 {
      let node = dependency_generation_node(source, pending[cursor])
      let index = node.id().ordinal()
      if reached[index] {
        continue
      }
      reached[index] = true
      visited[index] = true
      if probe.roots.any(root => root.node == node.id()) ||
        probe.lanes.any(lane => lane.result.id() == node.id()) {
        continue
      }
      match node.kind() {
        Input(_) | Register(_) => {
          foreign[index] = true
          provenance[index].push(seed_index)
        }
        MemoryRead(..) | AsyncFifoRead(..) =>
          fail("unretained storage in original cone")
        kind => {
          assert_true(node.signal_type().is_data())
          for operand in dependency_generation_operands(kind) {
            pending.push(operand)
          }
        }
      }
    }
  }
  let expected_foreign = source
    .nodes()
    .filter(node => foreign[node.id().ordinal()])
  assert_eq(
    probe.candidates.iter().map(leaf => leaf.original).to_array(),
    expected_foreign.iter().to_array(),
  )
  let expected_cone = source
    .nodes()
    .filter(node => {
      visited[node.id().ordinal()] &&
      !foreign[node.id().ordinal()] &&
      !probe.roots.any(root => root.node == node.id()) &&
      !probe.lanes.any(lane => lane.result.id() == node.id())
    })
  assert_eq(probe.cone.iter().to_array(), expected_cone.iter().to_array())
  for leaf in probe.candidates {
    assert_eq(
      leaf.provenance.iter().to_array(),
      provenance[leaf.original.id().ordinal()],
    )
    assert_false(leaf.provenance.is_empty())
    assert_eq(leaf.memory, None)
    assert_eq(
      leaf.original,
      dependency_generation_node(source, leaf.original.id()),
    )
    assert_true(
      leaf.original.kind() is Input(_) || leaf.original.kind() is Register(_),
    )
    assert_true(
      leaf.original.signal_type().is_data() || leaf.original.id() == probe.reset,
    )
  }
  for event in probe.events {
    assert_true(probe.cone.any(node => node.id() == event.node))
    assert_eq(
      dependency_generation_node(source, event.node).signal_type(),
      event.signal_type,
    )
  }
  for lane in probe.lanes {
    let data = probe.candidates.filter(leaf => {
      leaf.original.id() == lane.public_data
    })
    guard data is [leaf] else { fail("missing public lane data provenance") }
    for index in leaf.provenance {
      assert_eq(seeds[index].origin, WriteData(lane.lane))
      assert_eq(seeds[index].node, lane.public_data)
    }
  }
  let (leaves, cone) = queue_storage_probe_walk(
    fixture,
    probe.roots,
    probe.lanes,
    probe.events,
    seeds,
    probe.reset,
  )
  assert_eq(leaves, probe.candidates.iter().to_array())
  assert_eq(cone, probe.cone.iter().to_array())
  let report = queue_storage_probe_report(probe)
  println(report)
  println("QUEUE-PROBE-REPORT-SHA256 \{sha256_hex(report)}")
  assert_eq(report, queue_storage_probe_report(probe))
  assert_true(report.contains("ONLY-not-accepted-cut-projection-or-proof"))
  assert_true(
    report.contains(
      "original-uninitialized-registers-and-memory-read-state-no-zero-storage-assumption",
    ),
  )
  assert_eq(report.split("\nROOT ").count() - 1, 28)
  assert_eq(report.split("\nMEMORY ").count() - 1, 4)
  assert_eq(report.split("\nREAD-STATE ").count() - 1, 4)
  assert_eq(report.split("\nEVENT ").count() - 1, 46)
  assert_eq(report.split("\nSEED ").count() - 1, 126)
  assert_eq(report.split("\nCONE node ").count() - 1, probe.cone.length())
  assert_eq(
    report.split("\nCANDIDATE node ").count() - 1,
    probe.candidates.length(),
  )
  for index, seed in seeds {
    assert_true(
      report.contains(
        "SEED \{index} origin \{Repr(seed.origin)} node \{seed.node.ordinal()}\n",
      ),
    )
  }
  for leaf in probe.candidates {
    let kind = "\{Repr(leaf.original.kind())}".replace_all(old="\n", new="")
    assert_true(
      report.contains(
        "CANDIDATE node \{leaf.original.id().ordinal()} type \{Repr(leaf.original.signal_type())} kind \{kind} seeds \{Repr(leaf.provenance)}\n",
      ),
    )
  }
}
