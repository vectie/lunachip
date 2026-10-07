///|
fn store_projection_test_node(
  mapping : ArrayView[@ir.NodeId?],
  original : @ir.NodeId,
) -> @ir.NodeId raise {
  guard mapping.get(original.ordinal()) is Some(Some(mapped)) else {
    fail("Store projection omitted an original dependency")
  }
  mapped
}

///|
fn store_projection_test_domain(
  original : @ir.ClockDomain,
  mapping : ArrayView[@ir.NodeId?],
) -> @ir.ClockDomain raise {
  @ir.ClockDomain::new(
    original.id(),
    store_projection_test_node(mapping, original.clock()),
    original.edge(),
  )
}

///|
// Independent reference enumeration, including feedback and all memory ports.
// This does not call the projection walker or its dependency helpers.
fn store_projection_test_dependencies(kind : @ir.NodeKind) -> Array[@ir.NodeId] {
  match kind {
    Input(_) | Constant(_) => []
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
    BitNot(value)
    | ZeroExtend(value)
    | SignExtend(value)
    | Truncate(value)
    | Reinterpret(value)
    | Slice(value~, ..) => [value]
    ShiftLeft(value~, amount~)
    | LogicalShiftRight(value~, amount~)
    | ArithmeticShiftRight(value~, amount~) => [value, amount]
    Concat(most_significant~, least_significant~) =>
      [most_significant, least_significant]
    Mux(select~, when_true~, when_false~) => [select, when_true, when_false]
    Register(spec) => {
      let refs = [spec.domain().clock(), spec.next()]
      if spec.reset() is Some(control) {
        refs.push(control.signal())
      }
      if spec.enable() is Some(enable) {
        refs.push(enable)
      }
      refs
    }
    MemoryRead(..) | AsyncFifoRead(..) => []
  }
}

///|
test "Store projection closes original feedback and complete memory ports independently" {
  let fixture = @flux_tile.queued_concurrent_store_preservation_fixture()
  let slice = store_storage_projection(fixture)
  let source = fixture.hardware()
  let plan = slice.plan
  let seeds = [plan.probe.clock, plan.probe.reset]
  for observation in fixture.observations() {
    seeds.push(observation.node())
  }
  for output in source.outputs() {
    seeds.push(output.driver())
  }
  for root in plan.arbiter_roots {
    seeds.push(root.node)
  }
  assert_eq(plan.seeds, ReadOnlyArray::from_array(seeds))
  let pending = seeds.iter().to_array()
  let seen = Array::make(source.nodes().length(), false)
  let memory_seen = Array::make(source.memories().length(), false)
  for cursor = 0; cursor < pending.length(); cursor = cursor + 1 {
    let original = source.nodes()[pending[cursor].ordinal()]
    if seen[original.id().ordinal()] {
      continue
    }
    seen[original.id().ordinal()] = true
    if plan.arithmetic.any(cut => cut.id() == original.id()) {
      continue
    }
    if original.kind() is MemoryRead(memory~, port~) {
      let spec = source.memories()[memory.ordinal()]
      assert_true(
        spec
        .read_ports()
        .any(read => read.id() == port && read.result() == original.id()),
      )
      if !memory_seen[memory.ordinal()] {
        memory_seen[memory.ordinal()] = true
        pending.push(spec.domain().clock())
        for read in spec.read_ports() {
          pending.push(read.result())
          pending.push(read.domain().clock())
          pending.push(read.address())
          if read.enable() is Some(enable) {
            pending.push(enable)
          }
        }
        for write in spec.write_ports() {
          pending.push(write.domain().clock())
          pending.push(write.address())
          pending.push(write.data())
          if write.enable() is Some(enable) {
            pending.push(enable)
          }
          if write.mask() is Granular(signal~, ..) {
            pending.push(signal)
          }
        }
      }
    } else {
      assert_false(original.kind() is AsyncFifoRead(..))
      for dependency in store_projection_test_dependencies(original.kind()) {
        pending.push(dependency)
      }
    }
  }
  assert_eq(
    plan.selected,
    source.nodes().filter(node => seen[node.id().ordinal()]),
  )
  assert_eq(
    plan.memories,
    source.memories().filter(memory => memory_seen[memory.id().ordinal()]),
  )
  assert_eq(slice.original_to_local_memory.length(), source.memories().length())
  let mut ordinal = 0
  for memory in source.memories() {
    match slice.original_to_local_memory[memory.id().ordinal()] {
      None => assert_false(memory_seen[memory.id().ordinal()])
      Some(mapped_memory) => {
        assert_true(memory_seen[memory.id().ordinal()])
        assert_eq(mapped_memory.ordinal(), ordinal)
        ordinal += 1
        let reads : Array[@ir.MemoryReadPort] = []
        for read in memory.read_ports() {
          let enable = read
            .enable()
            .map(id => store_projection_test_node(slice.original_to_local, id))
          reads.push(
            @ir.MemoryReadPort::new(
              read.id(),
              read.name(),
              store_projection_test_domain(
                read.domain(),
                slice.original_to_local,
              ),
              store_projection_test_node(
                slice.original_to_local,
                read.address(),
              ),
              enable?,
              read.latency(),
              read.enable_behavior(),
              store_projection_test_node(slice.original_to_local, read.result()),
            ),
          )
        }
        let writes : Array[@ir.MemoryWritePort] = []
        for write in memory.write_ports() {
          let enable = write
            .enable()
            .map(id => store_projection_test_node(slice.original_to_local, id))
          let mask : @ir.MemoryWriteMask = match write.mask() {
            All => All
            Granular(signal~, granularity~) =>
              Granular(
                signal=store_projection_test_node(
                  slice.original_to_local,
                  signal,
                ),
                granularity~,
              )
          }
          writes.push(
            @ir.MemoryWritePort::new(
              write.id(),
              write.name(),
              store_projection_test_domain(
                write.domain(),
                slice.original_to_local,
              ),
              store_projection_test_node(
                slice.original_to_local,
                write.address(),
              ),
              store_projection_test_node(slice.original_to_local, write.data()),
              enable?,
              mask,
            ),
          )
        }
        assert_eq(
          slice.hardware.memories()[mapped_memory.ordinal()],
          @ir.MemorySpec::new(
            mapped_memory,
            memory.name(),
            memory.element_type(),
            memory.depth(),
            store_projection_test_domain(
              memory.domain(),
              slice.original_to_local,
            ),
            reads,
            writes,
            memory.read_write_policy(),
            memory.multi_write_policy(),
            memory.bounds_policy(),
          ),
        )
      }
    }
  }
  assert_eq(ordinal, slice.hardware.memories().length())
  for binding in fixture.c_memories() {
    assert_true(plan.memories.any(memory => memory == binding.memory()))
    assert_eq(binding.memory().depth().elements(), 4)
    assert_eq(binding.memory().element_type(), @wire.sint(32))
    assert_eq(binding.memory().read_write_policy(), ReadOld)
    assert_eq(binding.memory().multi_write_policy(), Reject)
    assert_eq(binding.memory().bounds_policy(), Fault)
    assert_eq(binding.memory().read_ports()[0].enable_behavior(), HoldLast)
    assert_eq(binding.memory().read_ports()[0].latency(), OneCycle)
    assert_eq(binding.memory().write_ports()[0].mask(), All)
    assert_true(
      slice.hardware.nodes()[store_projection_test_node(
        slice.original_to_local,
        binding.read_node(),
      ).ordinal()].kind()
      is MemoryRead(..),
    )
  }
}
