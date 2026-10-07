///|
fn queue_ownership_input(
  fixture : @flux_tile.QueueConservationFixture,
  simulator : @sim.Simulator,
  name : String,
) -> UInt64 raise {
  for node in fixture.hardware().nodes() {
    if node.kind() is Input(input_name) && input_name == name {
      let value = simulator.value(node.id())
      assert_true(value.is_fully_known())
      return value.to_uint64()
    }
  }
  fail("missing ownership fixture input: \{name}")
}

///|
// Check the actual 30-register ownership relation after reset establishment.
// Idle ticket and invalid terminal payload are deliberately not owners. This
// is a native finite-scenario check, not a new source premise or a proof.
fn queue_ownership_check(
  fixture : @flux_tile.QueueConservationFixture,
  simulator : @sim.Simulator,
) -> Unit raise {
  let read = (role : @flux_tile.QueueConservationRole) => {
    queue_conservation_value(fixture, simulator, role)
  }
  if queue_ownership_input(fixture, simulator, "reset") == 1UL {
    // Synchronous reset masks events immediately, but raw registers still
    // contain the previous epoch until the edge. Do not assert raw ownership.
    for
      role in [
        @flux_tile.QueueConservationRole::HeadPop,
        HeadCapture,
        HeadReserve,
        HeadIssue,
        HeadFinish,
        HeadReject,
        HeadFence,
        RetirementValid,
        RetirementFire,
      ] {
      assert_eq(read(role), 0UL)
    }
    for entry in 0..<3 {
      assert_eq(read(EntryAllocate(entry)), 0UL)
      assert_eq(read(EntryAcknowledge(entry)), 0UL)
      assert_eq(read(EntryLocalTerminal(entry)), 0UL)
      for engine in 0..<3 {
        assert_eq(read(EntryCollector(entry, engine)), 0UL)
      }
    }
    for engine in 0..<3 {
      assert_eq(read(EngineAccept(engine)), 0UL)
      assert_eq(read(EngineTerminal(engine)), 0UL)
    }
    assert_eq(execute_read(simulator, "descriptor_ready"), 0UL)
    assert_eq(execute_read(simulator, "memory_request_valid"), 0UL)
    assert_eq(execute_read(simulator, "memory_response_ready"), 0UL)
    return
  }
  let occupancy = read(RetirementOccupancy).to_int()
  let first = read(RetirementReadPointer).to_int()
  let next = read(RetirementWritePointer).to_int()
  let head = read(HeadState)
  let head_entry = read(HeadEntry).to_int()
  let head_ticket = read(HeadTicket)
  let next_ticket = read(NextTicket)
  assert_true(occupancy >= 0 && occupancy <= 3)
  assert_true(first < 3 && next < 3 && head_entry < 3)
  assert_true(head <= 3UL)
  assert_eq(next, (first + occupancy) % 3)
  for lane in 0..<4 {
    assert_eq(read(FifoOccupancy(lane)), read(FifoOccupancy(0)))
    assert_true(read(FifoOccupancy(lane)) <= 3UL)
    assert_eq(read(FifoResponseValid(lane)), read(FifoResponseValid(0)))
  }
  assert_eq(read(FifoResponseValid(0)), if head == 1UL { 1UL } else { 0UL })
  let busy = Array::makei(3, engine => read(EngineState(engine)) != 0UL)
  let tickets = Array::makei(3, engine => read(EngineTicket(engine)))
  let accepts = Array::makei(3, engine => read(EngineAccept(engine)))
  assert_true(accepts[0] + accepts[1] + accepts[2] <= 1UL)
  assert_eq(read(HeadIssue), accepts[0] + accepts[1] + accepts[2])
  assert_eq(
    read(HeadFinish),
    read(HeadIssue) + read(HeadReject) + read(HeadFence),
  )
  assert_eq(
    read(RetirementValid),
    if occupancy > 0 && read(EntryTerminal(first)) == 1UL {
      1UL
    } else {
      0UL
    },
  )
  assert_eq(
    read(RetirementFire),
    read(RetirementValid) *
    queue_ownership_input(fixture, simulator, "completion_ready"),
  )
  for engine in 0..<3 {
    let state = read(EngineState(engine))
    let done = if engine == 1 { 3UL } else { 4UL }
    assert_true(state <= done)
    assert_eq(
      read(EngineTerminal(engine)),
      if state == done {
        1UL
      } else {
        0UL
      },
    )
    if accepts[engine] == 1UL {
      assert_eq(state, 0UL)
      assert_eq(head, 3UL)
    }
    for other in 0..<engine {
      if busy[engine] && busy[other] {
        assert_true(tickets[engine] != tickets[other])
      }
    }
    let mut owned = 0
    let mut collectors = 0UL
    for entry in 0..<3 {
      if read(EntryValid(entry)) == 1UL &&
        read(EntryTerminal(entry)) == 0UL &&
        read(EntryTicket(entry)) == tickets[engine] {
        owned += 1
      }
      collectors += read(EntryCollector(entry, engine))
    }
    if busy[engine] {
      assert_eq(owned, 1)
    }
    assert_eq(collectors, read(EngineTerminal(engine)))
  }
  if head == 3UL {
    assert_eq(read(EntryValid(head_entry)), 1UL)
    assert_eq(read(EntryTerminal(head_entry)), 0UL)
    assert_eq(read(EntryTicket(head_entry)), head_ticket)
    assert_eq(head_entry, (next + 2) % 3)
    assert_eq(head_ticket, (next_ticket + 4294967295UL) & 0xffffffffUL)
  }
  for offset in 0..<3 {
    let entry = (first + offset) % 3
    let valid = read(EntryValid(entry)) == 1UL
    let terminal = read(EntryTerminal(entry)) == 1UL
    let ticket = read(EntryTicket(entry))
    assert_eq(valid, offset < occupancy)
    if valid {
      // UInt32 cyclic order, never caller-ID order or unsigned '<'. Adding
      // one modulus before subtraction avoids UInt64 underflow at wrap.
      assert_eq(
        ticket,
        (
          next_ticket +
          4294967296UL -
          occupancy.to_uint64() +
          offset.to_uint64()
        ) &
        0xffffffffUL,
      )
    }
    let mut owners = if head == 3UL && head_entry == entry { 1 } else { 0 }
    let mut collectors = 0UL
    for engine in 0..<3 {
      let matches = valid && !terminal && ticket == tickets[engine]
      if busy[engine] && matches {
        owners += 1
      }
      let expected = matches && read(EngineTerminal(engine)) == 1UL
      assert_eq(
        read(EntryCollector(entry, engine)),
        if expected {
          1UL
        } else {
          0UL
        },
      )
      collectors += read(EntryCollector(entry, engine))
    }
    assert_eq(owners, if valid && !terminal { 1 } else { 0 })
    assert_true(collectors <= 1UL)
    let allocate = read(HeadReserve) == 1UL && entry == next
    let acknowledge = read(RetirementFire) == 1UL && entry == first
    assert_eq(read(EntryAllocate(entry)), if allocate { 1UL } else { 0UL })
    assert_eq(
      read(EntryAcknowledge(entry)),
      if acknowledge {
        1UL
      } else {
        0UL
      },
    )
    if allocate {
      assert_false(valid)
      assert_eq(head, 2UL)
    }
    if acknowledge {
      assert_true(valid && terminal)
      assert_eq(collectors, 0UL)
    }
    if read(EntryLocalTerminal(entry)) == 1UL {
      assert_true(valid && !terminal)
      assert_eq(head, 3UL)
      assert_eq(entry, head_entry)
      assert_eq(ticket, head_ticket)
      assert_eq(collectors, 0UL)
      assert_eq(read(HeadIssue), 0UL)
    }
  }
}

///|
// Only the existing host performs transport transitions. Snapshot actual PRE
// identities so the POST checks do not mistake a freshly recomputed event for
// an event committed on the edge just taken.
fn queue_ownership_tick(
  fixture : @flux_tile.QueueConservationFixture,
  host : PortableHost,
  simulator : @sim.Simulator,
) -> Unit raise {
  queue_conservation_present_peer(host, simulator)
  queue_ownership_check(fixture, simulator)
  let read = (role : @flux_tile.QueueConservationRole) => {
    queue_conservation_value(fixture, simulator, role)
  }
  assert_eq(queue_ownership_input(fixture, simulator, "reset"), 0UL)
  let head_ticket = read(HeadTicket)
  let next_ticket = read(NextTicket)
  let reserve = read(HeadReserve) == 1UL
  let selected = read(RetirementWritePointer).to_int()
  let accepts = Array::makei(3, engine => read(EngineAccept(engine)))
  let busy = Array::makei(3, engine => read(EngineState(engine)) != 0UL)
  let engine_tickets = Array::makei(3, engine => read(EngineTicket(engine)))
  let done = Array::makei(3, engine => read(EngineTerminal(engine)))
  let allocated = Array::makei(3, entry => read(EntryAllocate(entry)))
  let acknowledged = Array::makei(3, entry => read(EntryAcknowledge(entry)))
  let terminalized = Array::makei(3, entry => {
    read(EntryLocalTerminal(entry)) +
    read(EntryCollector(entry, 0)) +
    read(EntryCollector(entry, 1)) +
    read(EntryCollector(entry, 2))
  })
  let tickets = Array::makei(3, entry => read(EntryTicket(entry)))
  let ids = Array::makei(3, entry => read(EntryId(entry)))
  host.tick(simulator)
  queue_ownership_check(fixture, simulator)
  assert_eq(
    read(NextTicket),
    (next_ticket + (if reserve { 1UL } else { 0UL })) & 0xffffffffUL,
  )
  if reserve {
    assert_eq(read(HeadEntry), selected.to_uint64())
    assert_eq(read(HeadTicket), next_ticket)
    assert_eq(read(EntryTicket(selected)), next_ticket)
    assert_eq(read(EntryValid(selected)), 1UL)
    assert_eq(read(EntryTerminal(selected)), 0UL)
  }
  for engine in 0..<3 {
    if accepts[engine] == 1UL {
      assert_eq(read(EngineTicket(engine)), head_ticket)
      assert_true(read(EngineState(engine)) != 0UL)
    } else if busy[engine] {
      assert_eq(read(EngineTicket(engine)), engine_tickets[engine])
    }
    if done[engine] == 1UL {
      assert_eq(read(EngineState(engine)), 0UL)
      assert_eq(accepts[engine], 0UL)
    }
  }
  for entry in 0..<3 {
    if allocated[entry] == 0UL {
      assert_eq(read(EntryTicket(entry)), tickets[entry])
      assert_eq(read(EntryId(entry)), ids[entry])
    }
    if terminalized[entry] != 0UL {
      assert_eq(terminalized[entry], 1UL)
      assert_eq(read(EntryValid(entry)), 1UL)
      assert_eq(read(EntryTerminal(entry)), 1UL)
      assert_eq(acknowledged[entry], 0UL)
    }
    if acknowledged[entry] == 1UL {
      assert_eq(read(EntryValid(entry)), 0UL)
    }
  }
}

///|
fn queue_ownership_enqueue(
  fixture : @flux_tile.QueueConservationFixture,
  host : PortableHost,
  simulator : @sim.Simulator,
  packet : Array[UInt64],
) -> Unit raise {
  frontend_present(simulator, packet)
  let mut admitted = false
  for _ in 0..<1024 {
    let ready = execute_read(simulator, "descriptor_ready") == 1UL
    queue_ownership_tick(fixture, host, simulator)
    if ready {
      admitted = true
      break
    }
  }
  assert_true(admitted)
  portable_put(simulator, "descriptor_valid", 1, 0UL)
}

///|
fn queue_ownership_drain(
  fixture : @flux_tile.QueueConservationFixture,
  host : PortableHost,
  simulator : @sim.Simulator,
  expected : Array[UInt64],
) -> Unit raise {
  for _ in 0..<2048 {
    if execute_read(simulator, "completion_valid") == 1UL {
      break
    }
    queue_ownership_tick(fixture, host, simulator)
  }
  assert_eq(execute_read(simulator, "completion_valid"), 1UL)
  assert_eq(queued_concurrent_payload(simulator), expected)
  portable_put(simulator, "completion_ready", 1, 1UL)
  queue_ownership_tick(fixture, host, simulator)
  portable_put(simulator, "completion_ready", 1, 0UL)
}
