///|
fn store_preservation_expected_roots() -> Array[
  (@flux_tile.StorePreservationRole, @ir.SignalType),
] raise {
  let roles : Array[(@flux_tile.StorePreservationRole, @ir.SignalType)] = []
  let store : Array[(@flux_tile.StorePreservationStoreField, Int)] = [
    (State, 3),
    (Slot, 1),
    (Id, 32),
    (Rows, 13),
    (Columns, 13),
    (Base, 32),
    (Stride, 32),
    (Row, 13),
    (Column, 13),
    (Tag, 32),
    (ExpectedTag, 32),
    (Progress, 32),
    (Fault, 4),
    (FaultAddress, 32),
  ]
  for (field, width) in store {
    roles.push((StoreRegister(field), @wire.uint(width)))
  }
  let compute : Array[(@flux_tile.StorePreservationComputeField, Int)] = [
    (State, 2),
    (Id, 32),
    (A, 1),
    (B, 1),
    (C, 1),
    (Rows, 13),
    (Columns, 13),
    (Reduction, 13),
    (Fault, 4),
  ]
  for (field, width) in compute {
    roles.push((ComputeRegister(field), @wire.uint(width)))
  }
  roles.push((ComputeRegister(Leased), @wire.bits(1)))
  let slotted : Array[(@flux_tile.StorePreservationSlottedField, Int)] = [
    (State, 2),
    (CaptureRow, 4),
    (CaptureColumn, 4),
    (ActiveA, 1),
    (ActiveB, 1),
    (ActiveC, 1),
    (ResponseSlot, 1),
  ]
  for (field, width) in slotted {
    roles.push((SlottedRegister(field), @wire.uint(width)))
  }
  roles.push((SlottedRegister(Pending), @wire.bits(1)))
  let core : Array[(@flux_tile.StorePreservationCoreField, Int)] = [
    (State, 2),
    (Rows, 4),
    (Columns, 4),
    (Reduction, 13),
    (Id, 32),
    (TotalSteps, 13),
    (AcceptedSteps, 13),
    (Fault, 2),
  ]
  for (field, width) in core {
    roles.push((CoreRegister(field), @wire.uint(width)))
  }
  for slot in 0..<2 {
    roles.push((ResultValid(slot), @wire.bits(1)))
    roles.push((ResultRows(slot), @wire.uint(4)))
    roles.push((ResultColumns(slot), @wire.uint(4)))
  }
  roles.push((ResponseId, @wire.uint(32)))
  roles.push((ResponseFault, @wire.uint(2)))
  roles
}

///|
fn store_preservation_expected_events() -> Array[
  (@flux_tile.StorePreservationRole, @ir.SignalType),
] raise {
  let events : Array[@flux_tile.StorePreservationEvent] = [
    StoreAccept,
    StoreActive,
    StoreReadValid,
    StoreRequestValid,
    StoreRequestAccept,
    StoreResponseGood,
    StoreResponseRemote,
    StoreResponseProtocol,
    StoreInternalFault,
    StoreCancelled,
    StoreTerminal,
    ComputeAccept,
    ComputeLegalAccept,
    ComputeTerminal,
    ComputeRelease,
    CoreAccept,
    CoreReady,
    CoreLegal,
    CoreClearing,
    CoreRunning,
    CoreDone,
    CoreAdvance,
    CoreFinalStep,
    SlottedAccept,
    SlottedLegalAccept,
    OwnershipActive,
    Capture,
    FinalCapture,
    ReadReady,
    ReadAccept,
    ResponseValid,
  ]
  let roles : Array[(@flux_tile.StorePreservationRole, @ir.SignalType)] = []
  for event in events {
    roles.push((Event(event), @wire.bits(1)))
  }
  roles.push((Event(ComputePreflight), @wire.uint(4)))
  roles.push((Event(ResponseData), @wire.sint(32)))
  roles
}

///|
fn store_preservation_observation(
  fixture : @flux_tile.StorePreservationFixture,
  role : @flux_tile.StorePreservationRole,
) -> @flux_tile.StorePreservationObservation raise {
  let selected = fixture.observations().filter(item => item.role() == role)
  guard selected is [observation] else {
    fail("missing or duplicated Store preservation role: \{Repr(role)}")
  }
  observation
}

///|
fn store_preservation_node(
  hardware : @ir.Module,
  id : @ir.NodeId,
  signal_type : @ir.SignalType,
) -> @ir.Node raise {
  guard hardware.node(id) is Some(node) else {
    fail("Store preservation reference is not an original node")
  }
  assert_eq(node.signal_type(), signal_type)
  node
}

///|
test "Store preservation seam leaves the complete ordinary graph and canonical bytes unchanged" {
  let fixture = @flux_tile.queued_concurrent_store_preservation_fixture()
  assert_eq(fixture, @flux_tile.queued_concurrent_store_preservation_fixture())
  let hardware = fixture.hardware()
  let ordinary = @flux_tile.queued_concurrent_tile(
    rows=2,
    columns=2,
    max_reduction=2,
    host_bytes=1024UL,
    queue_depth=3,
  )
  assert_eq(hardware, ordinary)
  assert_eq(hardware.name(), ordinary.name())
  assert_eq(hardware.domains(), ordinary.domains())
  assert_eq(hardware.nodes(), ordinary.nodes())
  assert_eq(hardware.memories(), ordinary.memories())
  assert_eq(hardware.outputs(), ordinary.outputs())
  assert_eq(hardware.metadata(), ordinary.metadata())
  assert_eq(hardware.parameters(), ordinary.parameters())
  assert_eq(hardware.input_timings(), ordinary.input_timings())
  assert_eq(hardware.output_timings(), ordinary.output_timings())
  assert_eq(hardware.cdc_primitives(), ordinary.cdc_primitives())
  assert_eq(hardware.aggregate_bindings(), ordinary.aggregate_bindings())
  assert_eq(
    hardware.nodes().filter(node => node.kind() is Input(_)),
    ordinary.nodes().filter(node => node.kind() is Input(_)),
  )
  let first = @codec.serialize(
    @wire.single_design("StorePreservationSeam", hardware),
  )
  let second = @codec.serialize(
    @wire.single_design("StorePreservationSeam", ordinary),
  )
  assert_eq(first, second)
  assert_eq(@utf8.encode(first), @utf8.encode(second))
  assert_eq(
    @crypto.sha256(@utf8.encode(first)),
    @crypto.sha256(@utf8.encode(second)),
  )
  assert_eq(hardware.memories().length(), 14)
}

///|
test "Store preservation seam has exact unique typed roots events and original controls" {
  let fixture = @flux_tile.queued_concurrent_store_preservation_fixture()
  let hardware = fixture.hardware()
  let roots = store_preservation_expected_roots()
  let events = store_preservation_expected_events()
  assert_eq(roots.length(), 48)
  assert_eq(events.length(), 33)
  assert_eq(fixture.observations().length(), 83)
  let resets = hardware.nodes().filter(node => node.kind() is Input("reset"))
  let clocks = hardware.nodes().filter(node => node.kind() is Input("clock"))
  assert_eq(resets.length(), 1)
  assert_eq(clocks.length(), 1)
  assert_eq(hardware.domains().length(), 1)
  let domain = hardware.domains()[0]
  assert_eq(domain.clock(), clocks[0].id())
  assert_eq(domain.edge(), Rising)
  let mut root_bits = 0
  let root_nodes : Array[@ir.NodeId] = []
  for (role, signal_type) in roots {
    let observation = store_preservation_observation(fixture, role)
    assert_eq(observation.signal_type(), signal_type)
    let node = store_preservation_node(
      hardware,
      observation.node(),
      signal_type,
    )
    guard node.kind() is Register(spec) else {
      fail("Store preservation root is not an original register")
    }
    assert_eq(spec.domain(), domain)
    assert_eq(spec.initial(), None)
    assert_eq(spec.reset(), Some(@ir.ResetSpec::new(resets[0].id(), 0UL)))
    ignore(store_preservation_node(hardware, spec.next(), signal_type))
    let enabled = match role {
      CoreRegister(State) => false
      CoreRegister(_)
      | ResultRows(_)
      | ResultColumns(_)
      | ResponseId
      | ResponseFault => true
      _ => false
    }
    match spec.enable() {
      Some(enable) => {
        assert_true(enabled)
        ignore(store_preservation_node(hardware, enable, @wire.bits(1)))
        match role {
          CoreRegister(AcceptedSteps) | ResultRows(_) | ResultColumns(_) => ()
          CoreRegister(_) =>
            assert_eq(
              enable,
              store_preservation_observation(fixture, Event(CoreAccept)).node(),
            )
          ResponseId | ResponseFault =>
            assert_eq(
              enable,
              store_preservation_observation(fixture, Event(ReadAccept)).node(),
            )
          _ => fail("unexpected enabled Store preservation root")
        }
      }
      None => assert_false(enabled)
    }
    for prior in root_nodes {
      assert_true(prior != observation.node())
    }
    root_nodes.push(observation.node())
    root_bits += signal_type.width().bits()
  }
  assert_eq(root_bits, 515)
  for (role, signal_type) in events {
    let observation = store_preservation_observation(fixture, role)
    assert_eq(observation.signal_type(), signal_type)
    let node = store_preservation_node(
      hardware,
      observation.node(),
      signal_type,
    )
    assert_false(node.kind() is Input(_))
  }
  for slot in 0..<2 {
    let observation = store_preservation_observation(fixture, CReadData(slot))
    assert_eq(observation.signal_type(), @wire.sint(32))
    assert_true(
      store_preservation_node(hardware, observation.node(), @wire.sint(32)).kind()
      is MemoryRead(..),
    )
  }
  // Semantic event aliases are legal; register roots must remain distinct.
  for index, observation in fixture.observations() {
    for prior in fixture.observations()[0:index] {
      assert_true(prior.role() != observation.role())
    }
  }
}

///|
test "Store preservation seam binds both complete original C memories without guessed IDs" {
  let fixture = @flux_tile.queued_concurrent_store_preservation_fixture()
  let hardware = fixture.hardware()
  let ordinary = @flux_tile.queued_concurrent_tile(
    rows=2,
    columns=2,
    max_reduction=2,
    host_bytes=1024UL,
    queue_depth=3,
  )
  assert_eq(fixture.c_memories().length(), 2)
  for slot in 0..<2 {
    let selected = fixture
      .c_memories()
      .filter(binding => binding.slot() == slot)
    guard selected is [binding] else {
      fail("C slot binding missing or duplicated")
    }
    let observation = store_preservation_observation(fixture, CReadData(slot))
    assert_eq(binding.read_node(), observation.node())
    let node = store_preservation_node(
      hardware,
      binding.read_node(),
      @wire.sint(32),
    )
    guard node.kind() is MemoryRead(memory~, port~) else {
      fail("C read must be original memory state")
    }
    let spec = binding.memory()
    assert_eq(spec.id(), memory)
    let originals = ordinary
      .memories()
      .filter(candidate => candidate.id() == memory)
    guard originals is [original] else {
      fail("C memory ID is not in ordinary graph")
    }
    assert_eq(spec, original)
    assert_eq(spec.name(), "c_result_slot_\{slot}")
    assert_eq(spec.element_type(), @wire.sint(32))
    assert_eq(spec.depth().elements(), 4)
    assert_eq(spec.depth().address_width().bits(), 2)
    assert_eq(spec.domain(), hardware.domains()[0])
    assert_eq(spec.read_write_policy(), ReadOld)
    assert_eq(spec.multi_write_policy(), Reject)
    assert_eq(spec.bounds_policy(), Fault)
    assert_eq(spec.read_ports(), original.read_ports())
    assert_eq(spec.write_ports(), original.write_ports())
    assert_eq(spec.read_ports().length(), 1)
    assert_eq(spec.write_ports().length(), 1)
    let read = spec.read_ports()[0]
    assert_eq(read.id(), port)
    assert_eq(read.name(), "result")
    assert_eq(read.domain(), spec.domain())
    assert_eq(read.latency(), OneCycle)
    assert_eq(read.enable_behavior(), HoldLast)
    assert_eq(read.result(), binding.read_node())
    ignore(store_preservation_node(hardware, read.address(), @wire.uint(2)))
    guard read.enable() is Some(read_enable) else {
      fail("C read requires original enable")
    }
    ignore(store_preservation_node(hardware, read_enable, @wire.bits(1)))
    let write = spec.write_ports()[0]
    assert_eq(write.name(), "capture")
    assert_eq(write.domain(), spec.domain())
    assert_eq(write.mask(), All)
    ignore(store_preservation_node(hardware, write.address(), @wire.uint(2)))
    ignore(store_preservation_node(hardware, write.data(), @wire.sint(32)))
    guard write.enable() is Some(write_enable) else {
      fail("C write requires original enable")
    }
    ignore(store_preservation_node(hardware, write_enable, @wire.bits(1)))
    for other in fixture.c_memories() {
      if other.slot() != slot {
        assert_true(other.memory().id() != spec.id())
        assert_true(other.read_node() != binding.read_node())
      }
    }
  }
}

///|
test "Store preservation seam does not extend or alter the existing 115 and 48 role fixtures" {
  let queue = @flux_tile.queued_concurrent_queue_formal_fixture()
  let dependency = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let ordinary = @flux_tile.queued_concurrent_tile(
    rows=1,
    columns=1,
    max_reduction=2,
    host_bytes=1024UL,
    queue_depth=3,
  )
  assert_eq(queue.hardware(), ordinary)
  assert_eq(dependency.hardware(), ordinary)
  assert_eq(queue, @flux_tile.queued_concurrent_queue_formal_fixture())
  assert_eq(
    dependency,
    @flux_tile.queued_concurrent_dependency_formal_fixture(),
  )
  let queue_roles = queue_conservation_expected_roles()
  let dependency_roles = queued_concurrent_formal_expected_roles()
  assert_eq(queue.observations().length(), 115)
  assert_eq(queue_roles.length(), 115)
  assert_eq(dependency.observations().length(), 48)
  assert_eq(dependency_roles.length(), 48)
  for (role, signal_type) in queue_roles {
    let selected = queue.observations().filter(item => item.role() == role)
    assert_eq(selected.length(), 1)
    assert_eq(selected[0].signal_type(), signal_type)
    ignore(store_preservation_node(ordinary, selected[0].node(), signal_type))
  }
  for index, observation in dependency.observations() {
    let (role, width) = dependency_roles[index]
    let signal_type = match role {
      HeadLane(_) => @wire.bits(width)
      HeadReserve
      | LoadAccept
      | ComputeAccept
      | StoreAccept
      | LoadTerminal
      | ComputeTerminal
      | StoreTerminal
      | InnerCommandValid
      | InnerCommandReady
      | LocalReject => @wire.bits(width)
      _ => @wire.uint(width)
    }
    assert_eq(observation.role(), role)
    assert_eq(observation.signal_type(), signal_type)
    ignore(store_preservation_node(ordinary, observation.node(), signal_type))
    for prior in dependency.observations()[0:index] {
      assert_true(prior.role() != role)
    }
  }
}
