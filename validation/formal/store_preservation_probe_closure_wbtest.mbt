///|
// This oracle deliberately does not call the production seed builder or walker.
fn store_probe_independent_seeds(
  probe : StorePreservationProbe,
) -> Array[StorePreservationProbeSeed] raise {
  let result : Array[StorePreservationProbeSeed] = []
  for root in probe.roots {
    guard dependency_generation_node(probe.source, root.original.id()).kind()
      is Register(spec) else {
      fail("seed oracle needs original register specifications")
    }
    let role = root.binding.role()
    result.push({ origin: RootNext(role), node: spec.next(), })
    if spec.reset() is Some(reset) {
      result.push({ origin: RootReset(role), node: reset.signal(), })
    }
    if spec.enable() is Some(enable) {
      result.push({ origin: RootEnable(role), node: enable, })
    }
  }
  for event in probe.events {
    guard event.role() is Event(role) else {
      fail("seed event role is not an event")
    }
    result.push({ origin: Event(role), node: event.node(), })
  }
  for slot in 0..<2 {
    guard probe.memories.filter(binding => binding.slot() == slot) is [binding] else {
      fail("seed oracle requires both original C memories")
    }
    let memory = binding.memory()
    result.push({ origin: ReadResult(slot), node: binding.read_node(), })
    for read in memory.read_ports() {
      result.push({
        origin: ReadAddress(slot, read.id()),
        node: read.address(),
      })
      if read.enable() is Some(enable) {
        result.push({ origin: ReadEnable(slot, read.id()), node: enable, })
      }
    }
    for write in memory.write_ports() {
      result.push({
        origin: WriteAddress(slot, write.id()),
        node: write.address(),
      })
      result.push({ origin: WriteData(slot, write.id()), node: write.data(), })
      if write.enable() is Some(enable) {
        result.push({ origin: WriteEnable(slot, write.id()), node: enable, })
      }
      if write.mask() is Granular(signal~, ..) {
        result.push({ origin: WriteMask(slot, write.id()), node: signal, })
      }
    }
  }
  result
}

///|
fn store_probe_independent_operands(
  kind : @ir.NodeKind,
) -> Array[@ir.NodeId] raise {
  match kind {
    Constant(_) => []
    BitNot(id)
    | ZeroExtend(id)
    | SignExtend(id)
    | Truncate(id)
    | Reinterpret(id)
    | Slice(value=id, ..) => [id]
    Add(a, b)
    | Sub(a, b)
    | MulLow(a, b)
    | MulFull(a, b)
    | BitAnd(a, b)
    | BitOr(a, b)
    | BitXor(a, b)
    | Equal(a, b)
    | LessThan(a, b)
    | LessEqual(a, b) => [a, b]
    ShiftLeft(value~, amount~)
    | LogicalShiftRight(value~, amount~)
    | ArithmeticShiftRight(value~, amount~) => [value, amount]
    Concat(most_significant~, least_significant~) =>
      [most_significant, least_significant]
    Mux(select~, when_true~, when_false~) => [select, when_true, when_false]
    Input(_) | Register(_) | MemoryRead(..) | AsyncFifoRead(..) =>
      fail("oracle cannot traverse a state leaf as combinational logic")
  }
}

///|
test "Store candidate closure and every seed provenance match independent original graph traversal" {
  let probe = store_preservation_probe(
    @flux_tile.queued_concurrent_store_preservation_fixture(),
  )
  let source = probe.source
  let seeds = store_probe_independent_seeds(probe)
  assert_eq(probe.seeds, ReadOnlyArray::from_array(seeds))
  let retained : Array[@ir.NodeId] = probe.roots
    .iter()
    .map(root => root.original.id())
    .to_array()
  for memory in probe.memories {
    retained.push(memory.read_node())
  }
  let provenance : Array[Array[Int]] = Array::makei(source.nodes().length(), _ => {
    []
  })
  let reached = Array::make(source.nodes().length(), false)
  for seed_index, seed in seeds {
    let visited = Array::make(source.nodes().length(), false)
    let pending : Array[@ir.NodeId] = [seed.node]
    for cursor = 0; cursor < pending.length(); cursor = cursor + 1 {
      let id = pending[cursor]
      if visited[id.ordinal()] {
        continue
      }
      visited[id.ordinal()] = true
      reached[id.ordinal()] = true
      let node = dependency_generation_node(source, id)
      if retained.contains(id) {
        continue
      }
      match node.kind() {
        Input(_) | Register(_) | MemoryRead(..) =>
          provenance[id.ordinal()].push(seed_index)
        AsyncFifoRead(..) =>
          fail("unexpected asynchronous state in Store closure")
        _ =>
          for operand in store_probe_independent_operands(node.kind()) {
            pending.push(operand)
          }
      }
    }
  }
  let expected_candidates = source
    .nodes()
    .filter(node => !provenance[node.id().ordinal()].is_empty())
  assert_eq(probe.candidates.length(), expected_candidates.length())
  for index, leaf in probe.candidates {
    let node = leaf.original
    assert_eq(node, expected_candidates[index])
    assert_eq(node, dependency_generation_node(source, node.id()))
    assert_eq(
      leaf.provenance,
      ReadOnlyArray::from_array(provenance[node.id().ordinal()]),
    )
    assert_false(leaf.provenance.is_empty())
    assert_false(retained.contains(node.id()))
    match node.kind() {
      Input(name) => {
        assert_eq(leaf.memory, None)
        assert_true(
          node.signal_type().is_data() ||
          (
            name == "reset" &&
            node.id() == probe.reset &&
            node.signal_type() is Reset
          ),
        )
      }
      Register(spec) => {
        assert_eq(leaf.memory, None)
        assert_eq(spec.domain(), probe.domain)
        assert_true(node.signal_type().is_data())
        ignore(dependency_generation_node(source, spec.next()))
        if spec.reset() is Some(reset) {
          ignore(dependency_generation_node(source, reset.signal()))
        }
        if spec.enable() is Some(enable) {
          ignore(dependency_generation_node(source, enable))
        }
      }
      MemoryRead(memory~, port~) => {
        guard source.memories().filter(spec => spec.id() == memory) is [spec] &&
          spec.read_ports().filter(read => read.id() == port) is [read] else {
          fail(
            "foreign memory candidate lost its complete original specification",
          )
        }
        assert_eq(leaf.memory, Some(spec))
        assert_eq(read.result(), node.id())
        assert_eq(spec.element_type(), node.signal_type())
        assert_eq(read.domain(), probe.domain)
        assert_eq(read.latency(), OneCycle)
      }
      _ =>
        fail(
          "discovery abstracted a derived expression rather than a foreign leaf",
        )
    }
  }
  let expected_cone = source
    .nodes()
    .filter(node => {
      reached[node.id().ordinal()] &&
      !retained.contains(node.id()) &&
      provenance[node.id().ordinal()].is_empty()
    })
  assert_eq(probe.cone, ReadOnlyArray::from_array(expected_cone))
  for node in probe.cone {
    assert_eq(node, dependency_generation_node(source, node.id()))
    assert_true(node.signal_type().is_data())
    for operand in store_probe_independent_operands(node.kind()) {
      assert_true(
        retained.contains(operand) ||
        probe.cone.any(cone_node => cone_node.id() == operand) ||
        probe.candidates.any(leaf => leaf.original.id() == operand),
      )
    }
  }
  for seed in seeds {
    assert_true(
      retained.contains(seed.node) ||
      probe.cone.any(node => node.id() == seed.node) ||
      probe.candidates.any(leaf => leaf.original.id() == seed.node),
    )
  }
  // These are arithmetic candidates only, never an accepted payload abstraction.
  let accumulators = probe.candidates.filter(leaf => {
    leaf.original.signal_type() == @wire.sint(32) &&
    leaf.original.kind() is Register(_)
  })
  assert_eq(accumulators.length(), 4)
  for leaf in accumulators {
    for slot in 0..<2 {
      assert_true(
        leaf.provenance.any(index => {
          seeds[index].origin is WriteData(selected, _) && selected == slot
        }),
      )
    }
  }
}
