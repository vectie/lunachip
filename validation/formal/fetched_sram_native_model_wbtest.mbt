///|
priv struct FetchedSramNative {
  fixture : @flux_tile.StorePreservationFixture
  dependency : Array[QueueControlAlias]
  producer : @ir.NodeId
  valid : Array[Bool]
  written : Array[Bool]
  rows : Array[UInt64]
  columns : Array[UInt64]
  word : Array[UInt64]
  ticket : Array[UInt64]
  read_tracked : Array[Bool]
  read_word : Array[UInt64]
  mut store_basis : UInt64
  mut pending : Bool
  mut pending_word : UInt64
  mut captures : Int
  mut negative_seen : Bool
}

///|
fn FetchedSramNative::new(source : @ir.Module) -> FetchedSramNative raise {
  let fixture = fetched_sram_fixture(source)
  {
    fixture,
    dependency: fetched_dependency_aliases(source),
    producer: fetched_sram_producer(fixture),
    valid: [false, false],
    written: [false, false],
    rows: [0UL, 0UL],
    columns: [0UL, 0UL],
    word: [0UL, 0UL],
    ticket: [0UL, 0UL],
    read_tracked: [false, false],
    read_word: [0UL, 0UL],
    store_basis: 0UL,
    pending: false,
    pending_word: 0UL,
    captures: 0,
    negative_seen: false,
  }
}

///|
fn FetchedSramNative::read(
  self : FetchedSramNative,
  simulator : @sim.Simulator,
  role : @flux_tile.StorePreservationRole,
) -> UInt64 raise {
  guard self.fixture.observations().filter(binding => binding.role() == role)
    is [binding] else {
    fail("missing SRAM role")
  }
  simulator.value(binding.node()).to_uint64()
}

///|
fn FetchedSramNative::step(
  self : FetchedSramNative,
  simulator : @sim.Simulator,
  reset : Bool,
) -> Unit raise {
  if reset {
    for slot in 0..<2 {
      self.valid[slot] = false
      self.written[slot] = false
      self.rows[slot] = 0UL
      self.columns[slot] = 0UL
      self.read_tracked[slot] = false
    }
    self.pending = false
    return
  }
  let read = role => self.read(simulator, role)
  let store_slot = read(StoreRegister(Slot)).to_int()
  if read(Event(StoreAccept)) == 1UL {
    self.store_basis = fetched_dependency_native_read(
      self.dependency,
      simulator,
      DependencyTicket(0),
    )
  }
  if read(Event(ReadAccept)) == 1UL {
    assert_true(self.valid[store_slot] && self.written[store_slot])
    self.pending_word = self.word[store_slot]
    self.pending = true
  } else if read(StoreRegister(State)) == 3UL ||
    read(StoreRegister(State)) == 4UL {
    self.pending = false
  }
  // ReadOld/HoldLast samples the previous word before any capture changes it.
  for binding in self.fixture.c_memories() {
    let slot = binding.slot()
    let port = binding.memory().read_ports()[0]
    if simulator.value(port.enable().unwrap()).to_uint64() == 1UL {
      assert_true(self.valid[slot] && self.written[slot])
      self.read_tracked[slot] = true
      self.read_word[slot] = self.word[slot]
    }
  }
  for slot in 0..<2 {
    if read(Event(SlottedLegalAccept)) == 1UL &&
      read(ComputeRegister(C)) == slot.to_uint64() {
      self.valid[slot] = false
      self.written[slot] = false
      self.ticket[slot] = read(ComputeRegister(Id))
    } else {
      if read(Event(Capture)) == 1UL &&
        read(SlottedRegister(ActiveC)) == slot.to_uint64() {
        self.written[slot] = true
      }
      if read(Event(FinalCapture)) == 1UL &&
        read(SlottedRegister(ActiveC)) == slot.to_uint64() {
        self.valid[slot] = true
      }
    }
    if read(Event(Capture)) == 1UL &&
      read(SlottedRegister(ActiveC)) == slot.to_uint64() {
      self.word[slot] = simulator.value(self.producer).to_uint64()
      self.captures += 1
    }
    if read(Event(FinalCapture)) == 1UL &&
      read(SlottedRegister(ActiveC)) == slot.to_uint64() {
      self.rows[slot] = read(CoreRegister(Rows))
      self.columns[slot] = read(CoreRegister(Columns))
    }
  }
}

///|
fn FetchedSramNative::check(
  self : FetchedSramNative,
  simulator : @sim.Simulator,
) -> Unit raise {
  let read = role => self.read(simulator, role)
  assert_eq(
    read(SlottedRegister(Pending)),
    if self.pending {
      1UL
    } else {
      0UL
    },
  )
  for slot in 0..<2 {
    assert_eq(read(ResultValid(slot)), if self.valid[slot] { 1UL } else { 0UL })
    assert_eq(
      (read(ResultRows(slot)), read(ResultColumns(slot))),
      (self.rows[slot], self.columns[slot]),
    )
    if self.valid[slot] {
      assert_true(self.written[slot])
      assert_eq((self.rows[slot], self.columns[slot]), (1UL, 1UL))
    }
    if self.written[slot] {
      assert_eq(
        simulator.memory_cell("c_result_slot_\{slot}", 0).to_uint64(),
        self.word[slot],
      )
    }
    if self.read_tracked[slot] {
      assert_eq(read(CReadData(slot)), self.read_word[slot])
    }
    if fetched_dependency_native_read(
        self.dependency,
        simulator,
        WriterStatus(slot + 4),
      ) ==
      2UL {
      assert_true(self.valid[slot] && self.written[slot])
      assert_eq(
        self.ticket[slot],
        fetched_dependency_native_read(
          self.dependency,
          simulator,
          WriterTicket(slot + 4),
        ),
      )
    }
    let state = read(StoreRegister(State))
    if state >= 1UL &&
      state <= 3UL &&
      read(StoreRegister(Slot)) == slot.to_uint64() {
      assert_true(self.valid[slot] && self.written[slot])
      assert_eq(self.ticket[slot], self.store_basis)
    }
  }
  if self.pending && read(Event(ResponseValid)) == 1UL {
    assert_eq(read(Event(ResponseData)), self.pending_word)
  }
}
