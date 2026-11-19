///|
priv struct FetchedGenerationNative {
  status : Array[UInt64]
  ticket : Array[UInt32]
  snapshot_status : Array[UInt64]
  snapshot_ticket : Array[UInt32]
  mut next : UInt32
  mut head : UInt32
  owned : Array[Bool]
  owner_ticket : Array[UInt32]
  mut authorization : Array[UInt64]?
}

///|
fn FetchedGenerationNative::new() -> FetchedGenerationNative {
  {
    status: Array::make(6, 0UL),
    ticket: Array::make(6, 0U),
    snapshot_status: Array::make(2, 0UL),
    snapshot_ticket: Array::make(2, 0U),
    next: 0U,
    head: 0U,
    owned: Array::make(3, false),
    owner_ticket: Array::make(3, 0U),
    authorization: None,
  }
}

///|
fn fetched_dependency_native_read(
  aliases : Array[QueueControlAlias],
  simulator : @sim.Simulator,
  role : @flux_tile.QueuedConcurrentFormalRole,
) -> UInt64 raise {
  let name = "composition_dependency_" + dependency_role_name(role)
  guard aliases.filter(binding => binding.name == name) is [binding] else {
    fail("one exact fetched role")
  }
  simulator.value(binding.node).to_uint64()
}

///|
fn FetchedGenerationNative::check(
  self : FetchedGenerationNative,
  read : (@flux_tile.QueuedConcurrentFormalRole) -> UInt64 raise,
) -> Unit raise {
  assert_eq(read(NextTicket), self.next.to_uint64())
  assert_eq(read(HeadTicket), self.head.to_uint64())
  for slot in 0..<6 {
    assert_eq(read(WriterStatus(slot)), self.status[slot])
    assert_eq(read(WriterTicket(slot)), self.ticket[slot].to_uint64())
  }
  for source in 0..<2 {
    assert_eq(read(DependencyStatus(source)), self.snapshot_status[source])
    assert_eq(
      read(DependencyTicket(source)),
      self.snapshot_ticket[source].to_uint64(),
    )
  }
}

///|
// raw_fault is independently specified for each host packet below. A zero
// fault still resolves old Pending snapshots by full ticket, not current data.
fn FetchedGenerationNative::step(
  self : FetchedGenerationNative,
  read : (@flux_tile.QueuedConcurrentFormalRole) -> UInt64 raise,
  raw_fault : UInt64,
  syntax_ok : Bool,
  halted : Bool,
) -> Unit raise {
  self.check(read)
  let lanes = Array::makei(4, lane => read(HeadLane(lane)))
  let opcode = (lanes[0] >> 16) & 255UL
  let a = (lanes[3] & 1UL).to_int()
  let b = ((lanes[3] >> 8) & 1UL).to_int()
  let c = ((lanes[3] >> 16) & 1UL).to_int()
  let sources = [if (opcode & 7UL) == 3UL { 4 + c } else { a }, 2 + b]
  let resolved = Array::makei(2, index => {
    if self.snapshot_status[index] != 1UL {
      self.snapshot_status[index]
    } else if self.snapshot_ticket[index] == self.ticket[sources[index]] {
      self.status[sources[index]]
    } else {
      3UL
    }
  })
  let bad = value => value == 0UL || value == 3UL
  let dependency_fault = if opcode == 2UL &&
    (bad(resolved[0]) || bad(resolved[1])) {
    4UL
  } else if opcode == 3UL && bad(resolved[0]) {
    5UL
  } else {
    0UL
  }
  let fault = if halted {
    15UL
  } else if raw_fault != 0UL {
    raw_fault
  } else {
    dependency_fault
  }
  let reject = read(HeadState) == 3UL && fault != 0UL
  assert_eq(read(LocalReject) == 1UL, reject)
  if read(HeadState) == 3UL {
    assert_eq(read(LocalFault), fault)
  }
  if read(ComputeAccept) == 1UL {
    assert_eq((fault, resolved[0], resolved[1]), (0UL, 2UL, 2UL))
  }
  if read(StoreAccept) == 1UL {
    assert_eq((fault, resolved[0]), (0UL, 2UL))
  }
  if read(InnerCommandValid) == 1UL {
    let actual = [
      read(ComputeLatchedTicket),
      read(ComputeLatchedA),
      read(ComputeLatchedB),
      read(ComputeLatchedC),
      read(ComputeLatchedRows),
      read(ComputeLatchedColumns),
      read(ComputeLatchedReduction),
    ]
    assert_eq(Some(actual), self.authorization)
  }
  // Snapshot PRE bank before any terminal, rejection or new publication.
  let old_status = self.status.copy()
  let old_ticket = self.ticket.copy()
  for
    (engine, terminal, ticket, fault_role) in [
      (
        0,
        @flux_tile.QueuedConcurrentFormalRole::LoadTerminal,
        @flux_tile.QueuedConcurrentFormalRole::LoadTerminalTicket,
        @flux_tile.QueuedConcurrentFormalRole::LoadTerminalFault,
      ),
      (1, ComputeTerminal, ComputeTerminalTicket, ComputeTerminalFault),
      (2, StoreTerminal, StoreTerminalTicket, StoreTerminalFault),
    ] {
    if read(terminal) == 1UL {
      assert_true(self.owned[engine])
      assert_eq(read(ticket), self.owner_ticket[engine].to_uint64())
      self.owned[engine] = false
      for slot in 0..<6 {
        if ((slot < 4 && engine == 0) || (slot >= 4 && engine == 1)) &&
          old_status[slot] == 1UL &&
          old_ticket[slot].to_uint64() == read(ticket) {
          self.status[slot] = if read(fault_role) == 0UL { 2UL } else { 3UL }
        }
      }
    }
  }
  let writer = if opcode == 0UL {
    Some(a)
  } else if opcode == 1UL {
    Some(2 + b)
  } else if opcode == 2UL {
    Some(4 + c)
  } else {
    None
  }
  if reject &&
    syntax_ok &&
    writer is Some(slot) &&
    old_status[slot] == 1UL &&
    old_ticket[slot] == self.head {
    self.status[slot] = 3UL
  }
  if (read(InnerCommandValid) == 1UL && read(InnerCommandReady) == 1UL) ||
    read(ComputeTerminal) == 1UL {
    self.authorization = None
  }
  for
    (engine, event) in [
      (0, @flux_tile.QueuedConcurrentFormalRole::LoadAccept),
      (1, ComputeAccept),
      (2, StoreAccept),
    ] {
    if read(event) == 1UL {
      self.owned[engine] = true
      self.owner_ticket[engine] = self.head
      if engine == 1 && read(ComputePreflight) == 0UL {
        self.authorization = Some([
          self.head.to_uint64(),
          a.to_uint64(),
          b.to_uint64(),
          c.to_uint64(),
          lanes[1] & 8191UL,
          (lanes[1] >> 16) & 8191UL,
          (lanes[1] >> 32) & 8191UL,
        ])
      }
    }
  }
  if read(HeadReserve) == 1UL {
    for index in 0..<2 {
      self.snapshot_status[index] = old_status[sources[index]]
      self.snapshot_ticket[index] = old_ticket[sources[index]]
    }
    self.head = self.next
    if syntax_ok && !halted && writer is Some(slot) {
      self.status[slot] = 1UL
      self.ticket[slot] = self.next
    }
    self.next += 1U
  }
}
