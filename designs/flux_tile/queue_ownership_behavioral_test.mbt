///|
test "queue ownership overlaps real engines and reuses compute behind held duplicate-ID retirement" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let simulator = queue_conservation_prepare(fixture)
  let host = PortableHost::new()
  host.stalled = false
  host.seed(32UL, 2UL, 1, 2, [2, 3])
  host.seed(64UL, 1UL, 2, 1, [5, 7])
  host.seed(128UL, 2UL, 1, 2, [-2, 4])
  host.seed(160UL, 1UL, 2, 1, [3, -1])
  // Establish C0 plus disjoint A1/B1 through genuine loads and compute. Every
  // setup edge is checked too; no internal register or memory is forced.
  let setup = [
    queued_concurrent_packet(
      LoadA,
      73,
      rows=1,
      columns=2,
      base=32UL,
      stride=2UL,
    ),
    queued_concurrent_packet(
      LoadB,
      73,
      rows=2,
      columns=1,
      base=64UL,
      stride=1UL,
    ),
    queued_concurrent_packet(MatMul, 73, rows=1, columns=1, reduction=2),
    queued_concurrent_packet(
      LoadA,
      73,
      rows=1,
      columns=2,
      base=128UL,
      stride=2UL,
      a=1,
    ),
    queued_concurrent_packet(
      LoadB,
      73,
      rows=2,
      columns=1,
      base=160UL,
      stride=1UL,
      b=1,
    ),
  ]
  for index, packet in setup {
    queue_ownership_enqueue(fixture, host, simulator, packet)
    queue_ownership_drain(fixture, host, simulator, [
      73UL,
      0UL,
      if index == 2 {
        0UL
      } else {
        2UL
      },
      0UL,
    ])
  }
  let read = (role : @flux_tile.QueueConservationRole) => {
    queue_conservation_value(fixture, simulator, role)
  }
  let oldest_ticket = read(NextTicket)
  let younger_ticket = (oldest_ticket + 1UL) & 0xffffffffUL
  let reused_ticket = (oldest_ticket + 2UL) & 0xffffffffUL
  let oldest_entry = read(RetirementWritePointer).to_int()
  host.latency = 100
  queue_ownership_enqueue(
    fixture,
    host,
    simulator,
    queued_concurrent_packet(
      StoreC,
      73,
      rows=1,
      columns=1,
      base=256UL,
      stride=4UL,
    ),
  )
  queue_ownership_enqueue(
    fixture,
    host,
    simulator,
    queued_concurrent_packet(
      MatMul,
      73,
      rows=1,
      columns=1,
      reduction=2,
      a=1,
      b=1,
      c=1,
    ),
  )
  let mut overlapping_edges = 0
  let mut younger_before_oldest = 0
  for _ in 0..<2048 {
    queue_conservation_present_peer(host, simulator)
    queue_ownership_check(fixture, simulator)
    if read(EngineState(1)) != 0UL && read(EngineState(2)) != 0UL {
      assert_eq(read(EngineTicket(1)), younger_ticket)
      assert_eq(read(EngineTicket(2)), oldest_ticket)
      overlapping_edges += 1
    }
    for entry in 0..<3 {
      if read(EntryCollector(entry, 1)) == 1UL {
        assert_eq(read(EntryTicket(entry)), younger_ticket)
        assert_eq(read(EntryTerminal(oldest_entry)), 0UL)
        assert_eq(read(RetirementValid), 0UL)
        younger_before_oldest += 1
      }
    }
    if read(RetirementValid) == 1UL {
      break
    }
    queue_ownership_tick(fixture, host, simulator)
  }
  assert_true(overlapping_edges > 0)
  assert_eq(younger_before_oldest, 1)
  assert_eq(read(RetirementValid), 1UL)
  assert_eq(read(RetirementFire), 0UL)
  assert_eq(read(RetirementReadPointer), oldest_entry.to_uint64())
  assert_eq(read(EntryTicket(oldest_entry)), oldest_ticket)
  assert_eq(queued_concurrent_payload(simulator), [73UL, 0UL, 4UL, 0UL])
  assert_eq(host.word(256UL), 31)
  assert_eq(read(EngineState(1)), 0UL)
  assert_eq(read(EngineState(2)), 0UL)
  assert_eq(read(RetirementOccupancy), 2UL)
  // The same compute engine accepts a fresh internal ticket while the oldest
  // external completion is genuinely valid and backpressured. Stale Idle
  // engine IDs and repeated caller ID 73 are not used as owners.
  queue_ownership_enqueue(
    fixture,
    host,
    simulator,
    queued_concurrent_packet(
      MatMul,
      73,
      rows=1,
      columns=1,
      reduction=2,
      a=1,
      b=1,
      c=1,
    ),
  )
  let mut reused_accepts = 0
  let mut held_collections = 0
  let mut held_edges = 0
  for _ in 0..<1024 {
    queue_conservation_present_peer(host, simulator)
    queue_ownership_check(fixture, simulator)
    assert_eq(read(RetirementValid), 1UL)
    assert_eq(read(RetirementFire), 0UL)
    assert_eq(read(EntryTicket(oldest_entry)), oldest_ticket)
    assert_eq(queued_concurrent_payload(simulator), [73UL, 0UL, 4UL, 0UL])
    held_edges += 1
    if read(EngineAccept(1)) == 1UL {
      assert_eq(read(HeadTicket), reused_ticket)
      assert_eq(read(EngineState(1)), 0UL)
      reused_accepts += 1
    }
    for entry in 0..<3 {
      if read(EntryCollector(entry, 1)) == 1UL {
        assert_true(entry != oldest_entry)
        assert_eq(read(EntryTicket(entry)), reused_ticket)
        held_collections += 1
      }
    }
    queue_ownership_tick(fixture, host, simulator)
    if held_collections == 1 {
      break
    }
  }
  assert_eq(reused_accepts, 1)
  assert_eq(held_collections, 1)
  assert_true(held_edges > 1)
  assert_eq(read(RetirementOccupancy), 3UL)
  assert_eq(read(EngineState(1)), 0UL)
  for ticket in [oldest_ticket, younger_ticket, reused_ticket] {
    let entry = read(RetirementReadPointer).to_int()
    assert_eq(read(EntryTicket(entry)), ticket)
    queue_ownership_drain(fixture, host, simulator, [
      73UL,
      0UL,
      if ticket == oldest_ticket {
        4UL
      } else {
        0UL
      },
      0UL,
    ])
  }
  assert_eq(read(RetirementOccupancy), 0UL)
  assert_eq(read(RetirementValid), 0UL)
  assert_true(host.pending is None && host.held is None)
  assert_eq(execute_read(simulator, "halted"), 0UL)
}

///|
test "queue ownership joint reset cancels genuine loader owner then starts a fresh duplicate-ID epoch" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let simulator = queue_conservation_prepare(fixture)
  let host = PortableHost::new()
  host.stalled = false
  host.latency = 100
  host.seed(32UL, 2UL, 1, 2, [2, 3])
  let read = (role : @flux_tile.QueueConservationRole) => {
    queue_conservation_value(fixture, simulator, role)
  }
  queue_ownership_enqueue(
    fixture,
    host,
    simulator,
    queued_concurrent_packet(
      LoadA,
      73,
      rows=1,
      columns=2,
      base=32UL,
      stride=2UL,
    ),
  )
  let mut owned_wait = false
  for _ in 0..<1024 {
    queue_conservation_present_peer(host, simulator)
    queue_ownership_check(fixture, simulator)
    if host.pending is Some(p) && p.remaining > 0 && read(EngineState(0)) == 2UL {
      assert_eq(read(EngineTicket(0)), 0UL)
      assert_eq(read(EntryValid(0)), 1UL)
      assert_eq(read(EntryTerminal(0)), 0UL)
      assert_eq(read(EntryTicket(0)), 0UL)
      assert_eq(read(EngineTerminal(0)), 0UL)
      owned_wait = true
      break
    }
    queue_ownership_tick(fixture, host, simulator)
  }
  assert_true(owned_wait)
  // Assert all public stimuli concurrently with synchronous reset. The old
  // owner remains in raw PRE state, but no admission, collection or ACK fires.
  frontend_present(simulator, queued_concurrent_packet(Fence, 73))
  portable_put(simulator, "completion_ready", 1, 1UL)
  portable_put(simulator, "memory_response_valid", 1, 1UL)
  portable_put(simulator, "memory_response_tag", 32, 0UL)
  portable_put(simulator, "memory_response_fault", 2, 0UL)
  portable_put(simulator, "memory_response_data", 32, 99UL)
  portable_put(simulator, "reset", 1, 1UL)
  assert_eq(read(EngineState(0)), 2UL)
  queue_ownership_check(fixture, simulator)
  simulator.rising_edge("clock")
  for
    role in [
      @flux_tile.QueueConservationRole::HeadState,
      HeadEntry,
      HeadTicket,
      NextTicket,
      RetirementReadPointer,
      RetirementWritePointer,
      RetirementOccupancy,
    ] {
    assert_eq(read(role), 0UL)
  }
  for entry in 0..<3 {
    assert_eq(read(EntryValid(entry)), 0UL)
    assert_eq(read(EntryTerminal(entry)), 0UL)
    assert_eq(read(EntryTicket(entry)), 0UL)
  }
  for engine in 0..<3 {
    assert_eq(read(EngineState(engine)), 0UL)
    assert_eq(read(EngineTicket(engine)), 0UL)
  }
  for lane in 0..<4 {
    assert_eq(read(FifoOccupancy(lane)), 0UL)
    assert_eq(read(FifoResponseValid(lane)), 0UL)
  }
  // Joint reset cancels the peer epoch as well; delayed old traffic crossing
  // reset is not part of the device's contract or a liveness premise here.
  host.pending = None
  host.held = None
  host.requests.clear()
  host.latency = 1
  portable_put(simulator, "descriptor_valid", 1, 0UL)
  portable_put(simulator, "completion_ready", 1, 0UL)
  portable_put(simulator, "memory_response_valid", 1, 0UL)
  portable_put(simulator, "reset", 1, 0UL)
  for _ in 0..<8 {
    queue_ownership_tick(fixture, host, simulator)
    assert_eq(read(RetirementValid), 0UL)
    assert_eq(read(RetirementOccupancy), 0UL)
  }
  host.seed(64UL, 2UL, 1, 2, [-7, 11])
  queue_ownership_enqueue(
    fixture,
    host,
    simulator,
    queued_concurrent_packet(
      LoadA,
      73,
      rows=1,
      columns=2,
      base=64UL,
      stride=2UL,
    ),
  )
  let mut fresh_accepts = 0
  let mut fresh_collections = 0
  for _ in 0..<1024 {
    queue_conservation_present_peer(host, simulator)
    queue_ownership_check(fixture, simulator)
    if read(EngineAccept(0)) == 1UL {
      assert_eq(read(HeadTicket), 0UL)
      fresh_accepts += 1
    }
    for entry in 0..<3 {
      if read(EntryCollector(entry, 0)) == 1UL {
        assert_eq(read(EntryTicket(entry)), 0UL)
        assert_eq(read(EntryId(entry)), 73UL)
        fresh_collections += 1
      }
    }
    queue_ownership_tick(fixture, host, simulator)
    if read(RetirementValid) == 1UL {
      break
    }
  }
  assert_eq(fresh_accepts, 1)
  assert_eq(fresh_collections, 1)
  assert_eq(host.requests.length(), 2)
  assert_eq(host.requests[0][1], 64UL)
  assert_eq(host.requests[1][1], 65UL)
  assert_eq(read(NextTicket), 1UL)
  queue_ownership_drain(fixture, host, simulator, [73UL, 0UL, 2UL, 0UL])
  assert_eq(read(RetirementOccupancy), 0UL)
  assert_true(host.pending is None && host.held is None)
  assert_eq(execute_read(simulator, "halted"), 0UL)
}
