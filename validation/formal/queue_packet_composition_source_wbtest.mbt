///|
// Independent semantic roster: neither prior root arrays nor production
// composition inventory helpers are used to establish the 54-state contract.
fn packet_composition_test_roots(
  fixture : @flux_tile.QueueConservationFixture,
) -> Array[DependencyComputeRoot] raise {
  let source = fixture.hardware()
  let roles : Array[(@flux_tile.QueueConservationRole, @ir.SignalType)] = []
  for lane in 0..<4 {
    roles.push((FifoOccupancy(lane), @wire.uint(2)))
    roles.push((FifoResponseValid(lane), @wire.bits(1)))
    roles.push((HeadLane(lane), @wire.bits(64)))
  }
  for
    role in [
      @flux_tile.QueueConservationRole::HeadState,
      HeadEntry,
      RetirementReadPointer,
      RetirementWritePointer,
      RetirementOccupancy,
    ] {
    roles.push((role, @wire.uint(if role is HeadState { 2 } else { 5 })))
  }
  for role in [@flux_tile.QueueConservationRole::HeadTicket, NextTicket] {
    roles.push((role, @wire.uint(32)))
  }
  for entry in 0..<3 {
    for
      role in [
        @flux_tile.QueueConservationRole::EntryValid(entry),
        EntryTerminal(entry),
      ] {
      roles.push((role, @wire.bits(1)))
    }
    for
      role in [
        @flux_tile.QueueConservationRole::EntryTicket(entry),
        EntryId(entry),
        EntryProgress(entry),
        EntryAddress(entry),
      ] {
      roles.push((role, @wire.uint(32)))
    }
    roles.push((EntryFault(entry), @wire.uint(4)))
  }
  for engine in 0..<3 {
    roles.push(
      (EngineState(engine), @wire.uint(if engine == 1 { 2 } else { 3 })),
    )
    roles.push((EngineTicket(engine), @wire.uint(32)))
  }
  let roots : Array[DependencyComputeRoot] = []
  for (role, signal_type) in roles {
    guard fixture
      .observations()
      .filter(observation => observation.role() == role)
      is [observation] else {
      fail("missing unique semantic state role")
    }
    let original = source.nodes()[observation.node().ordinal()]
    guard original.kind() is Register(spec) else {
      fail("essential state was not an original register")
    }
    assert_eq(observation.signal_type(), signal_type)
    assert_eq(original.signal_type(), signal_type)
    roots.push({
      name: queue_role_name(role),
      node: observation.node(),
      signal_type,
      spec,
    })
  }
  for lane in 0..<4 {
    guard fixture
      .observations()
      .filter(observation => observation.role() == FifoResponseData(lane))
      is [observation] else {
      fail("missing FIFO response role")
    }
    guard source.nodes()[observation.node().ordinal()].kind()
      is MemoryRead(memory~, port~) else {
      fail("FIFO response is not registered memory read state")
    }
    let memory = source.memories()[memory.ordinal()]
    guard memory.read_ports().filter(read => read.id() == port) is [read] &&
      memory.write_ports() is [write] else {
      fail("FIFO ports changed")
    }
    for
      (name, id) in [
        ("fifo_read_pointer_\{lane}", read.address()),
        ("fifo_write_pointer_\{lane}", write.address()),
      ] {
      let node = source.nodes()[id.ordinal()]
      guard node.kind() is Register(spec) else {
        fail("FIFO pointer was replaced")
      }
      assert_eq(node.signal_type(), @wire.uint(2))
      roots.push({ name, node: id, signal_type: node.signal_type(), spec, })
    }
  }
  roots.sort_by((a, b) => a.node.ordinal() - b.node.ordinal())
  roots
}

///|
test "packet composition independently binds all 54 actual state roles and unchanged production" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let source = fixture.hardware()
  let ordinary = @flux_tile.queued_concurrent_tile(
    rows=1,
    columns=1,
    max_reduction=2,
    host_bytes=1024UL,
    queue_depth=3,
  )
  assert_eq(source, ordinary)
  let before = @ir_codec.serialize(
    @ir.Design::single("QueuedConcurrentQueueConservationPilot", source),
  )
  let probe = queue_packet_composition_probe(fixture)
  assert_eq(probe, queue_packet_composition_probe(fixture))
  assert_eq(probe.source, source)
  assert_eq(probe.production_digest, sha256_hex(before))
  assert_eq(
    probe.production_digest,
    "35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc",
  )
  assert_eq(
    probe.owner_inventory_digest,
    "ad6dc56cf01fc55a28eacc6be5dc16493f882b665e1d9570e6e737f9985b289a",
  )
  assert_eq(
    probe.storage_inventory_digest,
    "9a4613301556bfd0229a8696e219e9853047f645813e4f5b27032fdc5476f29d",
  )
  assert_eq(
    probe.roots,
    ReadOnlyArray::from_array(packet_composition_test_roots(fixture)),
  )
  assert_eq(probe.roots.length(), 54)
  assert_eq(
    probe.roots
    .iter()
    .fold(init=0, (n, root) => n + root.signal_type.width().bits()),
    876,
  )
  assert_eq(probe.observations.length(), 115)
  for observation in fixture.observations() {
    guard probe.observations.filter(binding => {
        binding.name == queue_role_name(observation.role())
      })
      is [binding] else {
      fail("original role binding missing or repeated")
    }
    assert_eq(binding.node, observation.node())
    assert_eq(binding.signal_type, observation.signal_type())
    let original = source.nodes()[binding.node.ordinal()]
    match original.kind() {
      Input(_) | Register(_) | MemoryRead(..) => ()
      _ => {
        assert_true(probe.cone.contains(original))
        assert_false(
          probe.candidates.any(candidate => {
            candidate.original.id() == original.id()
          }),
        )
      }
    }
  }
  for index, root in probe.roots {
    assert_false(probe.roots[:index].any(prior => prior.node == root.node))
    assert_eq(root.spec.domain(), @ir.ClockDomain::rising(probe.clock))
    assert_eq(root.spec.initial(), None)
    assert_eq(root.spec.reset(), Some(@ir.ResetSpec::new(probe.reset, 0UL)))
    assert_false(
      probe.candidates.any(candidate => candidate.original.id() == root.node),
    )
  }
  assert_eq(source.nodes()[probe.clock.ordinal()].kind(), Input("clock"))
  assert_eq(source.nodes()[probe.reset.ordinal()].kind(), Input("reset"))
  assert_eq(
    @ir_codec.serialize(
      @ir.Design::single("QueuedConcurrentQueueConservationPilot", source),
    ),
    before,
  )
}
