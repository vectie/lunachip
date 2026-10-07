///|
test "queue storage candidate preserves ordinary source and exact twenty eight roots" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let hardware = fixture.hardware()
  assert_eq(
    hardware,
    @flux_tile.queued_concurrent_tile(
      rows=1,
      columns=1,
      max_reduction=2,
      host_bytes=1024UL,
      queue_depth=3,
    ),
  )
  let before = @ir_codec.serialize(
    @ir.Design::single("QueuedConcurrentQueueConservationPilot", hardware),
  )
  let probe = queue_storage_probe(fixture)
  assert_eq(probe, queue_storage_probe(fixture))
  assert_eq(probe.production_digest, sha256_hex(before))
  assert_eq(
    probe.production_digest,
    "35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc",
  )
  assert_eq(probe.roots.length(), 28)
  assert_eq(
    probe.roots
    .iter()
    .fold(init=0, (bits, root) => bits + root.signal_type.width().bits()),
    309,
  )
  assert_eq(probe.lanes.length(), 4)
  assert_eq(probe.events.length(), 46)
  let roles : Array[@flux_tile.QueueConservationRole] = []
  for lane in 0..<4 {
    roles.push(FifoOccupancy(lane))
    roles.push(FifoResponseValid(lane))
  }
  for
    role in [
      @flux_tile.QueueConservationRole::HeadState,
      HeadEntry,
      RetirementReadPointer,
      RetirementWritePointer,
      RetirementOccupancy,
    ] {
    roles.push(role)
  }
  for entry in 0..<3 {
    roles.push(EntryValid(entry))
  }
  for index, role in roles {
    let binding = queue_control_binding(fixture, role)
    assert_eq(probe.roots[index].node, binding.node)
    assert_eq(probe.roots[index].name, binding.name)
    assert_eq(probe.roots[index].signal_type, binding.signal_type)
  }
  for index, root in probe.roots {
    assert_false(probe.roots[:index].any(prior => prior.node == root.node))
    let original = dependency_generation_node(hardware, root.node)
    guard original.kind() is Register(spec) else {
      fail("storage root is not original register state")
    }
    assert_eq(original.signal_type(), root.signal_type)
    assert_eq(spec, root.spec)
    assert_eq(spec.initial(), None)
    assert_eq(spec.enable(), None)
    assert_eq(spec.domain(), @ir.ClockDomain::rising(probe.clock))
    guard spec.reset() is Some(reset) else { fail("missing root reset") }
    assert_eq(reset.signal(), probe.reset)
    assert_eq(reset.value(), 0UL)
    assert_eq(reset.mode(), Synchronous)
    assert_eq(reset.polarity(), ActiveHigh)
    assert_false(probe.candidates.any(leaf => leaf.original.id() == root.node))
  }
  for lane in probe.lanes {
    let offset = 16 + lane.lane * 3
    assert_eq(probe.roots[offset], lane.read_pointer)
    assert_eq(probe.roots[offset + 1], lane.write_pointer)
    let head = queue_control_binding(fixture, HeadLane(lane.lane))
    assert_eq(probe.roots[offset + 2].node, head.node)
    assert_eq(probe.roots[offset + 2].name, head.name)
    assert_eq(probe.roots[offset + 2].signal_type, @wire.bits(64))
  }
  assert_eq(
    @ir_codec.serialize(
      @ir.Design::single("QueuedConcurrentQueueConservationPilot", hardware),
    ),
    before,
  )
}

///|
test "queue storage ports retain original pointers fires response and head transfer" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let source = fixture.hardware()
  let probe = queue_storage_probe(fixture)
  for index, lane in probe.lanes {
    assert_eq(lane.lane, index)
    guard source.memories().filter(memory => memory.id() == lane.memory.id())
      is [original] else {
      fail("missing original lane memory")
    }
    assert_eq(lane.memory, original)
    assert_eq(original.element_type(), @wire.bits(64))
    assert_eq(original.depth().elements(), 3)
    assert_eq(original.depth().address_width().bits(), 2)
    assert_eq(original.domain(), @ir.ClockDomain::rising(probe.clock))
    assert_eq(original.read_write_policy(), ReadOld)
    assert_eq(original.multi_write_policy(), Reject)
    assert_eq(original.bounds_policy(), Fault)
    assert_eq(original.read_ports().iter().to_array(), [lane.read])
    assert_eq(original.write_ports().iter().to_array(), [lane.write])
    assert_eq(lane.read.name(), "pop")
    assert_eq(lane.write.name(), "push")
    assert_eq(lane.read.domain(), original.domain())
    assert_eq(lane.write.domain(), original.domain())
    assert_eq(lane.read.latency(), OneCycle)
    assert_eq(lane.read.enable_behavior(), HoldLast)
    assert_eq(lane.write.mask(), All)
    assert_eq(lane.read.address(), lane.read_pointer.node)
    assert_eq(lane.write.address(), lane.write_pointer.node)
    assert_eq(lane.read_pointer.signal_type, @wire.uint(2))
    assert_eq(lane.write_pointer.signal_type, @wire.uint(2))
    assert_false(lane.read_pointer.node == lane.write_pointer.node)
    let public_data = dependency_generation_input(
      source,
      "descriptor_lane_\{index}",
      @wire.bits(64),
    )
    assert_eq(lane.public_data, public_data)
    assert_eq(lane.write.data(), public_data)
    assert_eq(
      lane.result,
      dependency_generation_node(
        source,
        queue_control_binding(fixture, FifoResponseData(index)).node,
      ),
    )
    assert_eq(lane.result.id(), lane.read.result())
    assert_eq(lane.result.signal_type(), @wire.bits(64))
    assert_eq(
      lane.result.kind(),
      MemoryRead(memory=original.id(), port=lane.read.id()),
    )
    assert_false(
      probe.candidates.any(leaf => leaf.original.id() == lane.result.id()),
    )
    assert_false(probe.cone.any(node => node.id() == lane.result.id()))
    assert_false(
      probe.lanes[:index].any(other => {
        other.memory.id() == original.id() ||
        other.result.id() == lane.result.id()
      }),
    )
    guard lane.read.enable() is Some(pop) && lane.write.enable() is Some(push) else {
      fail("missing original port fires")
    }
    assert_eq(
      dependency_generation_node(source, pop).kind(),
      BitAnd(
        queue_control_binding(fixture, FifoPopRequest(index)).node,
        queue_control_binding(fixture, FifoPopReady(index)).node,
      ),
    )
    assert_eq(
      dependency_generation_node(source, push).kind(),
      BitAnd(
        queue_control_binding(fixture, FifoPushValid(index)).node,
        queue_control_binding(fixture, FifoPushReady(index)).node,
      ),
    )
    let response_binding = queue_control_binding(
      fixture,
      FifoResponseValid(index),
    )
    let response = probe.roots.filter(root => root.node == response_binding.node)[0]
    assert_eq(response.spec.next(), pop)
    let head = probe.roots[16 + index * 3 + 2]
    assert_eq(
      dependency_generation_node(source, head.spec.next()).kind(),
      Mux(
        select=queue_control_binding(fixture, HeadCapture).node,
        when_true=lane.result.id(),
        when_false=head.node,
      ),
    )
    for
      (pointer, fire) in [(lane.read_pointer, pop), (lane.write_pointer, push)] {
      let (advance, wrapped, hold) = dependency_generation_decoder_mux(
        source,
        pointer.spec.next(),
      )
      assert_eq(advance, fire)
      assert_eq(hold, pointer.node)
      let (at_last, zero, increment) = dependency_generation_decoder_mux(
        source, wrapped,
      )
      assert_eq(
        dependency_generation_decoder_equal_constant(source, at_last, 2, 2UL),
        pointer.node,
      )
      assert_eq(dependency_generation_node(source, zero).kind(), Constant(0UL))
      guard dependency_generation_node(source, increment).kind()
        is Add(value, one) else {
        fail("pointer no longer increments")
      }
      assert_eq(value, pointer.node)
      assert_eq(dependency_generation_node(source, one).kind(), Constant(1UL))
    }
  }
}

///|
test "queue storage discovery retains actual uninitialized memory and held read state" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let probe = queue_storage_probe(fixture)
  let simulator = @sim.Simulator::prepare(fixture.hardware())
  for node in fixture.hardware().nodes() {
    if node.kind() is Input(name) {
      simulator.set_input(
        name,
        @wave.LogicValue::zero(width=node.signal_type().width().bits()),
      )
    }
  }
  simulator.set_input(
    "reset",
    @wave.LogicValue::from_uint64(width=1, value=1UL),
  )
  simulator.settle()
  for root in probe.roots {
    assert_true(simulator.value(root.node).is_fully_unknown())
  }
  for epoch in 0..<2 {
    for lane in probe.lanes {
      assert_eq(
        simulator.value(lane.result.id()),
        @wave.LogicValue::unknown(width=64),
      )
      for cell in 0..<3 {
        assert_eq(
          simulator.memory_cell(lane.memory.name(), cell),
          @wave.LogicValue::unknown(width=64),
        )
      }
    }
    simulator.rising_edge("clock")
    for root in probe.roots {
      assert_eq(
        simulator.value(root.node),
        @wave.LogicValue::zero(width=root.signal_type.width().bits()),
      )
    }
    if epoch == 0 {
      simulator.set_input("reset", @wave.LogicValue::zero(width=1))
      simulator.settle()
    }
  }
  // A second idle edge cannot silently initialize the held response or cells.
  for lane in probe.lanes {
    assert_eq(
      simulator.value(lane.result.id()),
      @wave.LogicValue::unknown(width=64),
    )
    for cell in 0..<3 {
      assert_eq(
        simulator.memory_cell(lane.memory.name(), cell),
        @wave.LogicValue::unknown(width=64),
      )
    }
  }
}
