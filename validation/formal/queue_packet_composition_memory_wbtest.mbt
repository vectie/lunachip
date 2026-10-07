///|
test "packet composition retains complete original FIFO storage policies ports and registered read state" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let slice = queue_packet_composition_sequential(fixture)
  let source = fixture.hardware()
  let probe = slice.probe
  let mut copied_memories = 0
  for original in source.memories() {
    match slice.original_to_local_memory[original.id().ordinal()] {
      None =>
        assert_false(probe.lanes.any(lane => lane.memory.id() == original.id()))
      Some(mapped_memory) => {
        assert_eq(mapped_memory.ordinal(), copied_memories)
        copied_memories += 1
        guard probe.lanes.filter(lane => lane.memory == original) is [lane] else {
          fail("complete original memory not bound")
        }
        let copy = slice.hardware.memories()[mapped_memory.ordinal()]
        fn mapped(id : @ir.NodeId) -> @ir.NodeId raise {
          queue_storage_test_node(slice.original_to_local, id)
        }
        fn domain(actual : @ir.ClockDomain) -> @ir.ClockDomain raise {
          @ir.ClockDomain::new(
            actual.id(),
            mapped(actual.clock()),
            actual.edge(),
          )
        }
        let reads : Array[@ir.MemoryReadPort] = []
        for read in original.read_ports() {
          let enable = read.enable().map(mapped)
          reads.push(
            @ir.MemoryReadPort::new(
              read.id(),
              read.name(),
              domain(read.domain()),
              mapped(read.address()),
              enable?,
              read.latency(),
              read.enable_behavior(),
              mapped(read.result()),
            ),
          )
          assert_eq(read, lane.read)
          assert_eq(read.latency(), OneCycle)
          assert_eq(read.enable_behavior(), HoldLast)
          assert_eq(read.address(), lane.read_pointer.node)
          assert_eq(read.result(), lane.result.id())
          assert_false(slice.cuts.any(cut => cut.node == read.result()))
          assert_eq(
            slice.hardware.nodes()[mapped(read.result()).ordinal()].kind(),
            MemoryRead(memory=mapped_memory, port=read.id()),
          )
        }
        let writes : Array[@ir.MemoryWritePort] = []
        for write in original.write_ports() {
          let enable = write.enable().map(mapped)
          let mask : @ir.MemoryWriteMask = match write.mask() {
            All => All
            Granular(signal~, granularity~) =>
              Granular(signal=mapped(signal), granularity~)
          }
          writes.push(
            @ir.MemoryWritePort::new(
              write.id(),
              write.name(),
              domain(write.domain()),
              mapped(write.address()),
              mapped(write.data()),
              enable?,
              mask,
            ),
          )
          assert_eq(write, lane.write)
          assert_eq(write.address(), lane.write_pointer.node)
          assert_eq(write.data(), lane.public_data)
          assert_eq(write.mask(), All)
        }
        assert_eq(
          copy,
          @ir.MemorySpec::new(
            mapped_memory,
            original.name(),
            original.element_type(),
            original.depth(),
            domain(original.domain()),
            reads,
            writes,
            original.read_write_policy(),
            original.multi_write_policy(),
            original.bounds_policy(),
          ),
        )
        assert_eq(copy.depth().elements(), 3)
        assert_eq(copy.element_type(), @wire.bits(64))
        assert_eq(copy.read_write_policy(), ReadOld)
        assert_eq(copy.multi_write_policy(), Reject)
        assert_eq(copy.bounds_policy(), Fault)
        assert_eq(copy.read_ports().length(), 1)
        assert_eq(copy.write_ports().length(), 1)
      }
    }
  }
  assert_eq(copied_memories, 4)
  assert_eq(slice.hardware.memories().length(), 4)
  assert_eq(probe.lanes.length(), 4)
  for index, lane in probe.lanes {
    assert_eq(lane.lane, index)
    assert_false(
      probe.lanes[:index].any(prior => {
        prior.memory.id() == lane.memory.id() ||
        prior.result.id() == lane.result.id()
      }),
    )
    assert_true(probe.roots.contains(lane.read_pointer))
    assert_true(probe.roots.contains(lane.write_pointer))
  }
}

///|
test "packet composition preserves original unknown startup registers memory cells and read results" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let slice = queue_packet_composition_sequential(fixture)
  let source = @sim.Simulator::prepare(fixture.hardware())
  let projected = @sim.Simulator::prepare(slice.hardware)
  for root in slice.probe.roots {
    let value = projected.value(
      queue_storage_test_node(slice.original_to_local, root.node),
    )
    assert_eq(value, source.value(root.node))
    assert_true(value.is_fully_unknown())
    assert_eq(value.known_mask(), 0UL)
  }
  for lane in slice.probe.lanes {
    let value = projected.value(
      queue_storage_test_node(slice.original_to_local, lane.result.id()),
    )
    assert_eq(value, source.value(lane.result.id()))
    assert_true(value.is_fully_unknown())
    assert_eq(value.width(), 64)
    for address in 0..<3 {
      let cell = projected.memory_cell(lane.memory.name(), address)
      assert_eq(cell, source.memory_cell(lane.memory.name(), address))
      assert_true(cell.is_fully_unknown())
      assert_eq(cell.width(), 64)
    }
  }
}
