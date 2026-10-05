///|
fn queue_conservation_expected_roles() -> Array[
  (@flux_tile.QueueConservationRole, @ir.SignalType),
] raise {
  let roles : Array[(@flux_tile.QueueConservationRole, @ir.SignalType)] = []
  for lane in 0..<4 {
    for
      role in [
        @flux_tile.QueueConservationRole::FifoPushValid(lane),
        FifoPushReady(lane),
        FifoPopRequest(lane),
        FifoPopReady(lane),
        FifoResponseValid(lane),
        FifoFull(lane),
        FifoEmpty(lane),
      ] {
      roles.push((role, @wire.bits(1)))
    }
    roles.push((FifoResponseData(lane), @wire.bits(64)))
    roles.push((FifoOccupancy(lane), @wire.uint(2)))
    roles.push((HeadLane(lane), @wire.bits(64)))
  }
  roles.push((HeadState, @wire.uint(2)))
  for
    role in [
      @flux_tile.QueueConservationRole::HeadEntry,
      RetirementReadPointer,
      RetirementWritePointer,
      RetirementOccupancy,
    ] {
    roles.push((role, @wire.uint(5)))
  }
  for
    role in [
      @flux_tile.QueueConservationRole::HeadTicket,
      NextTicket,
      RetirementId,
      RetirementProgress,
      RetirementAddress,
    ] {
    roles.push((role, @wire.uint(32)))
  }
  for
    role in [
      @flux_tile.QueueConservationRole::HeadReserve,
      HeadPop,
      HeadCapture,
      HeadIssue,
      HeadFinish,
      HeadReject,
      HeadFence,
      RetirementFire,
      RetirementValid,
    ] {
    roles.push((role, @wire.bits(1)))
  }
  roles.push((HeadLocalFault, @wire.uint(4)))
  roles.push((RetirementFault, @wire.uint(4)))
  for entry in 0..<3 {
    for
      role in [
        @flux_tile.QueueConservationRole::EntryValid(entry),
        EntryTerminal(entry),
        EntryAllocate(entry),
        EntryAcknowledge(entry),
        EntryLocalTerminal(entry),
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
    for engine in 0..<3 {
      roles.push((EntryCollector(entry, engine), @wire.bits(1)))
    }
  }
  for engine in 0..<3 {
    roles.push((EngineAccept(engine), @wire.bits(1)))
    roles.push(
      (EngineState(engine), @wire.uint(if engine == 1 { 2 } else { 3 })),
    )
    roles.push((EngineTicket(engine), @wire.uint(32)))
    roles.push((EngineTerminal(engine), @wire.bits(1)))
    roles.push((EngineFault(engine), @wire.uint(4)))
  }
  roles
}

///|
fn queue_conservation_value(
  fixture : @flux_tile.QueueConservationFixture,
  simulator : @sim.Simulator,
  role : @flux_tile.QueueConservationRole,
) -> UInt64 raise {
  for observation in fixture.observations() {
    if observation.role() == role {
      let value = simulator.value(observation.node())
      if !value.is_fully_known() {
        fail("unknown queue-conservation observation: \{Repr(role)}")
      }
      return value.to_uint64()
    }
  }
  fail("missing queue-conservation observation: \{Repr(role)}")
}

///|
test "queue conservation seam preserves ordinary IR RTL and the old 48-role fixture" {
  let dependency = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  assert_eq(fixture, @flux_tile.queued_concurrent_queue_formal_fixture())
  let ordinary = @flux_tile.queued_concurrent_tile(
    rows=1,
    columns=1,
    max_reduction=2,
    host_bytes=1024UL,
    queue_depth=3,
  )
  assert_eq(fixture.hardware(), ordinary)
  assert_eq(fixture.hardware(), dependency.hardware())
  let first = @wire.single_design("QueueConservationSeam", fixture.hardware())
  let second = @wire.single_design("QueueConservationSeam", ordinary)
  assert_eq(@codec.serialize(first), @codec.serialize(second))
  assert_eq(
    @systemverilog.emit_design(first),
    @systemverilog.emit_design(second),
  )
  assert_eq(fixture.hardware().memories().length(), 10)
  assert_eq(fixture.hardware().outputs(), ordinary.outputs())
  assert_eq(
    dependency,
    @flux_tile.queued_concurrent_dependency_formal_fixture(),
  )
  let old_roles = queued_concurrent_formal_expected_roles()
  assert_eq(dependency.observations().length(), 48)
  for index, observation in dependency.observations() {
    let (role, width) = old_roles[index]
    assert_eq(observation.role(), role)
    assert_eq(observation.signal_type().width().bits(), width)
  }
}

///|
test "queue conservation seam has exactly 115 unique existing typed references" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let expected = queue_conservation_expected_roles()
  assert_eq(expected.length(), 115)
  assert_eq(fixture.observations().length(), 115)
  let emitted = @systemverilog.emit_design(
    @wire.single_design("QueueConservationSeam", fixture.hardware()),
  )
  for (role, signal_type) in expected {
    let selected = fixture
      .observations()
      .filter(observation => observation.role() == role)
    assert_eq(selected.length(), 1)
    let observation = selected[0]
    assert_eq(observation.signal_type(), signal_type)
    guard fixture.hardware().node(observation.node()) is Some(node) else {
      fail("queue observation did not identify an existing canonical node")
    }
    assert_eq(node.signal_type(), signal_type)
    let mappings = emitted
      .manifest()
      .mappings()
      .filter(mapping => {
        mapping.kind() is Node &&
        mapping.module_ordinal() == emitted.manifest().top_module_ordinal() &&
        mapping.local_ordinal() == observation.node().ordinal()
      })
    assert_eq(mappings.length(), 1)
    match role {
      FifoResponseData(_) => assert_true(node.kind() is MemoryRead(..))
      FifoResponseValid(_)
      | FifoOccupancy(_)
      | HeadLane(_)
      | HeadState
      | HeadEntry
      | HeadTicket
      | NextTicket
      | RetirementReadPointer
      | RetirementWritePointer
      | RetirementOccupancy
      | EntryValid(_)
      | EntryTerminal(_)
      | EntryTicket(_)
      | EntryId(_)
      | EntryFault(_)
      | EntryProgress(_)
      | EntryAddress(_)
      | EngineState(_)
      | EngineTicket(_)
      | EngineFault(_) => assert_true(node.kind() is Register(_))
      _ => ()
    }
  }
  for index, observation in fixture.observations() {
    for prior in fixture.observations()[0:index] {
      assert_true(prior.role() != observation.role())
    }
  }
}
