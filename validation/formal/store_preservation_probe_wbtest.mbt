///|
// Independent literal inventory, not derived from discovery's role table.
fn store_probe_expected_registers() -> Array[
  (@flux_tile.StorePreservationRole, @ir.SignalType),
] raise {
  let expected : Array[(@flux_tile.StorePreservationRole, @ir.SignalType)] = []
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
    expected.push((StoreRegister(field), @wire.uint(width)))
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
    expected.push((ComputeRegister(field), @wire.uint(width)))
  }
  expected.push((ComputeRegister(Leased), @wire.bits(1)))
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
    expected.push((SlottedRegister(field), @wire.uint(width)))
  }
  expected.push((SlottedRegister(Pending), @wire.bits(1)))
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
    expected.push((CoreRegister(field), @wire.uint(width)))
  }
  for slot in 0..<2 {
    expected.push((ResultValid(slot), @wire.bits(1)))
    expected.push((ResultRows(slot), @wire.uint(4)))
    expected.push((ResultColumns(slot), @wire.uint(4)))
  }
  expected.push((ResponseId, @wire.uint(32)))
  expected.push((ResponseFault, @wire.uint(2)))
  expected
}

///|
fn store_probe_expected_events() -> Array[
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
  let expected : Array[(@flux_tile.StorePreservationRole, @ir.SignalType)] = []
  for event in events {
    expected.push((Event(event), @wire.bits(1)))
  }
  expected.push((Event(ComputePreflight), @wire.uint(4)))
  expected.push((Event(ResponseData), @wire.sint(32)))
  expected
}

///|
test "Store candidate discovery binds complete original registers events memory and controls" {
  let fixture = @flux_tile.queued_concurrent_store_preservation_fixture()
  let source = fixture.hardware()
  let before = @ir_codec.serialize(
    @ir.Design::single("QueuedConcurrentStorePreservationProbe", source),
  )
  let probe = store_preservation_probe(fixture)
  assert_eq(probe, store_preservation_probe(fixture))
  assert_eq(probe.source, source)
  assert_eq(
    probe.source,
    @flux_tile.queued_concurrent_tile(
      rows=2,
      columns=2,
      max_reduction=2,
      host_bytes=1024UL,
      queue_depth=3,
    ),
  )
  assert_eq(probe.source_digest, sha256_hex(before))
  assert_eq(
    before,
    @ir_codec.serialize(
      @ir.Design::single("QueuedConcurrentStorePreservationProbe", probe.source),
    ),
  )
  assert_eq(probe.clock, dependency_generation_input(source, "clock", Clock))
  assert_eq(probe.reset, dependency_generation_input(source, "reset", Reset))
  assert_eq(probe.domain, @ir.ClockDomain::rising(probe.clock))
  assert_eq(source.domains(), [probe.domain])
  let roots = store_probe_expected_registers()
  let events = store_probe_expected_events()
  assert_eq(roots.length(), 48)
  assert_eq(events.length(), 33)
  assert_eq(fixture.observations().length(), 83)
  assert_eq(probe.roots.length(), 48)
  assert_eq(probe.events.length(), 33)
  assert_eq(probe.memories, fixture.c_memories())
  let mut bits = 0
  for (role, signal_type) in roots {
    guard fixture.observations().filter(item => item.role() == role)
      is [binding] &&
      probe.roots.filter(root => root.binding.role() == role) is [root] else {
      fail("essential Store register binding is absent or duplicated")
    }
    assert_eq(root.binding, binding)
    assert_eq(binding.signal_type(), signal_type)
    let original = dependency_generation_node(source, binding.node())
    assert_eq(root.original, original)
    assert_eq(original.signal_type(), signal_type)
    guard original.kind() is Register(spec) else {
      fail("Store root is not state")
    }
    assert_eq(root.spec, spec)
    assert_eq(spec.domain(), probe.domain)
    assert_eq(spec.reset(), Some(@ir.ResetSpec::new(probe.reset, 0UL)))
    assert_eq(spec.initial(), None)
    assert_eq(
      dependency_generation_node(source, spec.next()).signal_type(),
      signal_type,
    )
    if spec.enable() is Some(enable) {
      assert_eq(
        dependency_generation_node(source, enable).signal_type(),
        @wire.bits(1),
      )
    }
    assert_false(
      probe.candidates.any(leaf => leaf.original.id() == original.id()),
    )
    assert_false(probe.cone.any(node => node.id() == original.id()))
    for other in probe.roots {
      if other.binding.role() != role {
        assert_true(other.original.id() != original.id())
      }
    }
    bits += signal_type.width().bits()
  }
  assert_eq(bits, 515)
  for (role, signal_type) in events {
    guard fixture.observations().filter(item => item.role() == role)
      is [binding] &&
      probe.events.filter(event => event.role() == role) is [event] else {
      fail("original Store event binding is absent or duplicated")
    }
    assert_eq(event, binding)
    assert_eq(event.signal_type(), signal_type)
    let original = dependency_generation_node(source, event.node())
    assert_eq(original.signal_type(), signal_type)
    assert_false(
      original.kind() is Input(_) ||
      original.kind() is Register(_) ||
      original.kind() is MemoryRead(..),
    )
    assert_true(probe.cone.any(node => node == original))
    assert_false(
      probe.candidates.any(leaf => leaf.original.id() == original.id()),
    )
  }
  assert_eq(probe.memories.length(), 2)
  for binding in probe.memories {
    let memory = binding.memory()
    guard source.memories().filter(spec => spec.id() == memory.id())
      is [original] else {
      fail("retained C memory has no complete original identity")
    }
    assert_eq(memory, original)
    assert_eq(memory.name(), "c_result_slot_\{binding.slot()}")
    assert_eq(memory.element_type(), @wire.sint(32))
    assert_eq(memory.depth().elements(), 4)
    assert_eq(memory.domain(), probe.domain)
    assert_eq(memory.read_write_policy(), ReadOld)
    assert_eq(memory.multi_write_policy(), Reject)
    assert_eq(memory.bounds_policy(), Fault)
    assert_eq(memory.read_ports().length(), 1)
    assert_eq(memory.write_ports().length(), 1)
    let read = memory.read_ports()[0]
    let write = memory.write_ports()[0]
    assert_eq(read.result(), binding.read_node())
    assert_eq(read.latency(), OneCycle)
    assert_eq(read.enable_behavior(), HoldLast)
    assert_eq(read.domain(), probe.domain)
    assert_eq(write.domain(), probe.domain)
    assert_eq(write.mask(), All)
    assert_eq(
      dependency_generation_node(source, binding.read_node()).kind(),
      MemoryRead(memory=memory.id(), port=read.id()),
    )
    guard fixture
      .observations()
      .filter(item => item.role() == CReadData(binding.slot()))
      is [data] else {
      fail("retained C read state has no observation")
    }
    assert_eq(data.node(), binding.read_node())
    assert_eq(data.signal_type(), memory.element_type())
    assert_false(
      probe.candidates.any(leaf => leaf.original.id() == binding.read_node()),
    )
    assert_false(probe.cone.any(node => node.id() == binding.read_node()))
  }
}

///|
test "Store candidate report is deterministic and explicitly not accepted or proved" {
  let fixture = @flux_tile.queued_concurrent_store_preservation_fixture()
  let probe = store_preservation_probe(fixture)
  let report = store_preservation_probe_report(probe)
  assert_eq(
    report,
    store_preservation_probe_report(store_preservation_probe(fixture)),
  )
  assert_true(
    report.has_prefix("CANDIDATE-PROBE ONLY-not-accepted-projection-or-proof\n"),
  )
  assert_true(
    report.contains("NO-CUT-AUTHORITY no-materialization-or-observers\n"),
  )
  assert_eq(report.split("\nROOT ").length() - 1, 48)
  assert_eq(report.split("\nEVENT ").length() - 1, 33)
  assert_eq(report.split("\nRETAINED-MEMORY ").length() - 1, 2)
  assert_eq(report.split("\nSEED ").length() - 1, probe.seeds.length())
  assert_eq(
    report.split("\nCANDIDATE node ").length() - 1,
    probe.candidates.length(),
  )
  assert_eq(report.split("\nCONE node ").length() - 1, probe.cone.length())
  for root in probe.roots {
    let spec = "\{Repr(root.spec)}".replace_all(old="\n", new="")
    assert_true(
      report.contains(
        "ROOT \{Repr(root.binding.role())} node \{root.original.id().ordinal()} type \{Repr(root.original.signal_type())} spec \{spec}\n",
      ),
    )
  }
  for binding in probe.memories {
    let spec = "\{Repr(binding.memory())}".replace_all(old="\n", new="")
    assert_true(
      report.contains(
        "RETAINED-MEMORY slot \{binding.slot()} read-node \{binding.read_node().ordinal()} spec \{spec}\n",
      ),
    )
  }
  for index, seed in probe.seeds {
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
    if leaf.memory is Some(memory) {
      let spec = "\{Repr(memory)}".replace_all(old="\n", new="")
      assert_true(report.contains("FOREIGN-MEMORY-CONTROLS \{spec}\n"))
    }
  }
  // Parent retains and inspects the COMPLETE report before any later boundary.
  println(report)
}
