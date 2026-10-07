///|
test "queue storage sequential preserves all four original memory identities ports dependencies and policies" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let source = fixture.hardware()
  let slice = queue_storage_sequential(fixture)
  let probe = slice.probe
  assert_eq(slice.original_to_local_memory.length(), source.memories().length())
  let mut memory_ordinal = 0
  for original in source.memories() {
    let retained = probe.lanes.filter(lane => lane.memory.id() == original.id())
    match slice.original_to_local_memory[original.id().ordinal()] {
      None => assert_true(retained.is_empty())
      Some(mapped_memory) => {
        assert_eq(mapped_memory.ordinal(), memory_ordinal)
        memory_ordinal += 1
        guard retained is [lane] else {
          fail("memory mapping has no unique original FIFO lane")
        }
        assert_eq(original, lane.memory)
        let copied = slice.hardware.memories()[mapped_memory.ordinal()]
        assert_eq(copied.id(), mapped_memory)
        assert_eq(copied.name(), original.name())
        assert_eq(copied.element_type(), original.element_type())
        assert_eq(copied.depth(), original.depth())
        assert_eq(copied.depth().elements(), 3)
        assert_eq(copied.depth().address_width().bits(), 2)
        fn domain(actual : @ir.ClockDomain) -> @ir.ClockDomain raise {
          @ir.ClockDomain::new(
            actual.id(),
            queue_storage_test_node(slice.original_to_local, actual.clock()),
            actual.edge(),
          )
        }
        assert_eq(copied.domain(), domain(original.domain()))
        assert_eq(copied.read_write_policy(), original.read_write_policy())
        assert_eq(copied.multi_write_policy(), original.multi_write_policy())
        assert_eq(copied.bounds_policy(), original.bounds_policy())
        assert_eq(copied.read_write_policy(), ReadOld)
        assert_eq(copied.multi_write_policy(), Reject)
        assert_eq(copied.bounds_policy(), Fault)
        assert_eq(copied.read_ports().length(), original.read_ports().length())
        assert_eq(
          copied.write_ports().length(),
          original.write_ports().length(),
        )
        assert_eq(copied.read_ports().length(), 1)
        assert_eq(copied.write_ports().length(), 1)
        let expected_reads : Array[@ir.MemoryReadPort] = []
        for index, read in original.read_ports() {
          let copy = copied.read_ports()[index]
          let enable = read
            .enable()
            .map(id => queue_storage_test_node(slice.original_to_local, id))
          let expected = @ir.MemoryReadPort::new(
            read.id(),
            read.name(),
            domain(read.domain()),
            queue_storage_test_node(slice.original_to_local, read.address()),
            enable?,
            read.latency(),
            read.enable_behavior(),
            queue_storage_test_node(slice.original_to_local, read.result()),
          )
          expected_reads.push(expected)
          assert_eq(copy, expected)
          assert_eq(copy.latency(), OneCycle)
          assert_eq(copy.enable_behavior(), HoldLast)
          assert_eq(read, lane.read)
          assert_eq(read.address(), lane.read_pointer.node)
          assert_eq(
            copy.address(),
            queue_storage_test_node(
              slice.original_to_local,
              lane.read_pointer.node,
            ),
          )
          assert_eq(
            copy.result(),
            queue_storage_test_node(slice.original_to_local, lane.result.id()),
          )
          assert_eq(
            dependency_generation_node(slice.hardware, copy.result()).signal_type(),
            @wire.bits(64),
          )
          assert_eq(
            dependency_generation_node(slice.hardware, copy.result()).kind(),
            MemoryRead(memory=mapped_memory, port=read.id()),
          )
          assert_false(slice.cuts.any(cut => cut.node == read.result()))
          guard read.enable() is Some(read_enable) &&
            copy.enable() is Some(copy_enable) else {
            fail("original read fire became an unconditional read")
          }
          assert_eq(
            copy_enable,
            queue_storage_test_node(slice.original_to_local, read_enable),
          )
          assert_eq(
            dependency_generation_node(slice.hardware, copy_enable).signal_type(),
            @wire.bits(1),
          )
        }
        let expected_writes : Array[@ir.MemoryWritePort] = []
        for index, write in original.write_ports() {
          let copy = copied.write_ports()[index]
          let enable = write
            .enable()
            .map(id => queue_storage_test_node(slice.original_to_local, id))
          let mask : @ir.MemoryWriteMask = match write.mask() {
            All => All
            Granular(signal~, granularity~) =>
              Granular(
                signal=queue_storage_test_node(slice.original_to_local, signal),
                granularity~,
              )
          }
          let expected = @ir.MemoryWritePort::new(
            write.id(),
            write.name(),
            domain(write.domain()),
            queue_storage_test_node(slice.original_to_local, write.address()),
            queue_storage_test_node(slice.original_to_local, write.data()),
            enable?,
            mask,
          )
          expected_writes.push(expected)
          assert_eq(copy, expected)
          assert_eq(write, lane.write)
          assert_eq(write.mask(), All)
          assert_eq(copy.mask(), All)
          assert_eq(write.address(), lane.write_pointer.node)
          assert_eq(write.data(), lane.public_data)
          assert_eq(
            copy.address(),
            queue_storage_test_node(
              slice.original_to_local,
              lane.write_pointer.node,
            ),
          )
          assert_eq(
            copy.data(),
            queue_storage_test_node(slice.original_to_local, lane.public_data),
          )
          assert_eq(
            dependency_generation_node(slice.hardware, copy.data()).signal_type(),
            @wire.bits(64),
          )
          guard write.enable() is Some(write_enable) &&
            copy.enable() is Some(copy_enable) else {
            fail("original write fire became an unconditional write")
          }
          assert_eq(
            copy_enable,
            queue_storage_test_node(slice.original_to_local, write_enable),
          )
          assert_eq(
            dependency_generation_node(slice.hardware, copy_enable).signal_type(),
            @wire.bits(1),
          )
        }
        assert_eq(
          copied,
          @ir.MemorySpec::new(
            mapped_memory,
            original.name(),
            original.element_type(),
            original.depth(),
            domain(original.domain()),
            expected_reads,
            expected_writes,
            original.read_write_policy(),
            original.multi_write_policy(),
            original.bounds_policy(),
          ),
        )
      }
    }
  }
  assert_eq(memory_ordinal, 4)
  for index, memory in slice.hardware.memories() {
    assert_false(
      slice.hardware.memories()[:index].any(prior => {
        prior.id() == memory.id() || prior.name() == memory.name()
      }),
    )
  }
}

///|
test "queue storage sequential retains unknown cells read state and registers without manufactured initialization" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let slice = queue_storage_sequential(fixture)
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
    let read = projected.value(
      queue_storage_test_node(slice.original_to_local, lane.result.id()),
    )
    assert_eq(read, source.value(lane.result.id()))
    assert_eq(read.width(), 64)
    assert_true(read.is_fully_unknown())
    assert_eq(read.known_mask(), 0UL)
    for index in 0..<lane.memory.depth().elements() {
      let cell = projected.memory_cell(lane.memory.name(), index)
      assert_eq(cell, source.memory_cell(lane.memory.name(), index))
      assert_eq(cell.width(), 64)
      assert_true(cell.is_fully_unknown())
      assert_eq(cell.known_mask(), 0UL)
    }
  }
  for node in slice.hardware.nodes() {
    if node.kind() is Input(name) && name != "clock" {
      projected.set_input(
        name,
        @wave.LogicValue::from_uint64(
          width=node.signal_type().width().bits(),
          value=0UL,
        ),
      )
    }
  }
  let reset = dependency_generation_node(
    slice.hardware,
    queue_storage_test_node(slice.original_to_local, slice.probe.reset),
  )
  guard reset.kind() is Input(reset_name) else {
    fail("original reset is not a typed boundary")
  }
  projected.set_input(
    reset_name,
    @wave.LogicValue::from_uint64(width=1, value=1UL),
  )
  projected.settle()
  for memory in slice.hardware.memories() {
    for
      enable in [
        memory.read_ports()[0].enable(),
        memory.write_ports()[0].enable(),
      ] {
      guard enable is Some(node) else {
        fail("FIFO port lost its original fire")
      }
      assert_eq(projected.value(node).to_uint64(), 0UL)
    }
  }
  projected.rising_edge("clock")
  for root in slice.probe.roots {
    let value = projected.value(
      queue_storage_test_node(slice.original_to_local, root.node),
    )
    assert_true(value.is_fully_known())
    assert_eq(value.to_uint64(), 0UL)
  }
  // Reset clears controls, not SRAM or its disabled HoldLast read result.
  projected.set_input(
    reset_name,
    @wave.LogicValue::from_uint64(width=1, value=0UL),
  )
  projected.rising_edge("clock")
  for lane in slice.probe.lanes {
    let read = projected.value(
      queue_storage_test_node(slice.original_to_local, lane.result.id()),
    )
    assert_true(read.is_fully_unknown())
    assert_eq(read.known_mask(), 0UL)
    for index in 0..<lane.memory.depth().elements() {
      let cell = projected.memory_cell(lane.memory.name(), index)
      assert_true(cell.is_fully_unknown())
      assert_eq(cell.known_mask(), 0UL)
    }
  }
}
