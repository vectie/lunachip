///|
fn queue_conservation_prepare(
  fixture : @flux_tile.QueueConservationFixture,
) -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(fixture.hardware())
  for node in fixture.hardware().nodes() {
    if node.kind() is Input(name) && name != "clock" {
      portable_put(simulator, name, node.signal_type().width().bits(), 0UL)
    }
  }
  portable_put(simulator, "reset", 1, 1UL)
  simulator.rising_edge("clock")
  portable_put(simulator, "reset", 1, 0UL)
  simulator
}

///|
fn queue_conservation_present_peer(
  host : PortableHost,
  simulator : @sim.Simulator,
) -> Unit raise {
  // Present exactly the values the existing native host's tick will sample.
  // This permits PRE observation before tick without duplicating its request,
  // response, byte-memory, latency or controller transition implementation.
  assert_false(host.stalled)
  portable_put(simulator, "memory_request_ready", 1, 1UL)
  let response = match host.pending {
    Some(p) if p.remaining == 0 => Some(p)
    _ => None
  }
  portable_put(
    simulator,
    "memory_response_valid",
    1,
    if response is Some(_) {
      1UL
    } else {
      0UL
    },
  )
  if response is Some(p) {
    portable_put(simulator, "memory_response_tag", 32, p.tag)
    portable_put(simulator, "memory_response_fault", 2, p.fault)
    portable_put(simulator, "memory_response_data", 32, p.data)
  }
}

///|
test "queue conservation seam follows genuine packets tickets collectors and held retirement" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let simulator = queue_conservation_prepare(fixture)
  let host = PortableHost::new()
  host.stalled = false
  host.seed(32UL, 2UL, 1, 2, [2, 3])
  host.seed(64UL, 1UL, 2, 1, [5, 7])
  // IDs deliberately repeat. Ordinal/ticket and saved packet lanes, not the
  // caller ID, identify each actual admission and terminal obligation.
  let packets = [
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
      StoreC,
      73,
      rows=1,
      columns=1,
      base=128UL,
      stride=4UL,
    ),
    queued_concurrent_packet(Fence, 73, rows=1),
    queued_concurrent_packet(Fence, 73),
  ]
  let faults = [0UL, 0UL, 0UL, 0UL, 2UL, 0UL]
  let progresses = [2UL, 2UL, 0UL, 4UL, 0UL, 0UL]
  let read = (role : @flux_tile.QueueConservationRole) => {
    queue_conservation_value(fixture, simulator, role)
  }
  let collected = Array::make(6, false)
  let accepted_engines = [0, 0, 0]
  let collected_engines = [0, 0, 0]
  let mut admitted = 0
  let mut popped = 0
  let mut captured = 0
  let mut reserved = 0
  let mut finished = 0
  let mut retired = 0
  let mut local_terminals = 0
  let mut reserve_ack_edges = 0
  let mut quiet_edges = 0
  let mut release = false
  for _ in 0..<1024 {
    if admitted < packets.length() {
      frontend_present(simulator, packets[admitted])
    } else {
      portable_put(simulator, "descriptor_valid", 1, 0UL)
      for lane in 0..<4 {
        portable_put(
          simulator,
          "descriptor_lane_\{lane}",
          64,
          255UL + lane.to_uint64(),
        )
      }
    }
    if quiet_edges == 16 {
      release = true
    }
    portable_put(
      simulator,
      "completion_ready",
      1,
      if release {
        1UL
      } else {
        0UL
      },
    )
    queue_conservation_present_peer(host, simulator)
    queue_ownership_check(fixture, simulator)
    let fifo_count = read(FifoOccupancy(0))
    let push = read(FifoPushValid(0)) == 1UL && read(FifoPushReady(0)) == 1UL
    let pop = read(HeadPop) == 1UL
    let capture = read(HeadCapture) == 1UL
    let reserve = read(HeadReserve) == 1UL
    let finish = read(HeadFinish) == 1UL
    let retire = read(RetirementFire) == 1UL
    let occupancy = read(RetirementOccupancy)
    let write_pointer = read(RetirementWritePointer).to_int()
    let read_pointer = read(RetirementReadPointer).to_int()
    let head_entry = read(HeadEntry).to_int()
    let head_ticket = read(HeadTicket)
    let allocations = Array::makei(3, entry => read(EntryAllocate(entry)))
    let acknowledgements = Array::makei(3, entry => {
      read(EntryAcknowledge(entry))
    })
    let locals = Array::makei(3, entry => read(EntryLocalTerminal(entry)))
    let collectors = Array::makei(3, entry => {
      Array::makei(3, engine => read(EntryCollector(entry, engine)))
    })
    let accepts = Array::makei(3, engine => read(EngineAccept(engine)))
    let entry_tickets = Array::makei(3, entry => read(EntryTicket(entry)))
    assert_true(fifo_count <= 3UL && occupancy <= 3UL)
    assert_true(write_pointer < 3 && read_pointer < 3 && head_entry < 3)
    assert_eq(
      occupancy,
      read(EntryValid(0)) + read(EntryValid(1)) + read(EntryValid(2)),
    )
    assert_eq(
      push,
      admitted < packets.length() &&
      execute_read(simulator, "descriptor_ready") == 1UL,
    )
    for lane in 0..<4 {
      assert_eq(read(FifoOccupancy(lane)), fifo_count)
      assert_eq(read(FifoPushValid(lane)), read(FifoPushValid(0)))
      assert_eq(read(FifoPushReady(lane)), read(FifoPushReady(0)))
      assert_eq(read(FifoPopRequest(lane)), read(FifoPopRequest(0)))
      assert_eq(read(FifoPopReady(lane)), read(FifoPopReady(0)))
      assert_eq(read(FifoResponseValid(lane)), read(FifoResponseValid(0)))
      assert_eq(read(FifoFull(lane)), if fifo_count == 3UL { 1UL } else { 0UL })
      assert_eq(
        read(FifoEmpty(lane)),
        if fifo_count == 0UL {
          1UL
        } else {
          0UL
        },
      )
      assert_eq(
        pop,
        read(FifoPopRequest(lane)) == 1UL && read(FifoPopReady(lane)) == 1UL,
      )
    }
    if pop {
      assert_true(popped < admitted)
      assert_eq(read(HeadState), 0UL)
    }
    if capture {
      assert_true(captured < popped)
      assert_eq(read(HeadState), 1UL)
      for lane in 0..<4 {
        assert_eq(read(FifoResponseValid(lane)), 1UL)
        assert_eq(read(FifoResponseData(lane)), packets[captured][lane])
      }
    }
    if reserve {
      assert_true(reserved < captured)
      assert_eq(read(HeadState), 2UL)
      assert_eq(read(NextTicket), reserved.to_uint64())
      assert_eq(read(EntryValid(write_pointer)), 0UL)
      for lane in 0..<4 {
        assert_eq(read(HeadLane(lane)), packets[reserved][lane])
      }
    }
    for entry in 0..<3 {
      assert_eq(
        allocations[entry],
        if reserve && entry == write_pointer {
          1UL
        } else {
          0UL
        },
      )
      assert_eq(
        acknowledgements[entry],
        if retire && entry == read_pointer {
          1UL
        } else {
          0UL
        },
      )
      for engine in 0..<3 {
        if collectors[entry][engine] == 1UL {
          assert_eq(read(EntryValid(entry)), 1UL)
          assert_eq(read(EntryTerminal(entry)), 0UL)
          assert_eq(read(EngineTerminal(engine)), 1UL)
          assert_eq(read(EngineTicket(engine)), entry_tickets[entry])
          assert_eq(read(EngineFault(engine)), 0UL)
          let ticket = entry_tickets[entry].to_int()
          assert_true(ticket < reserved && ticket < 4)
          assert_false(collected[ticket])
          collected[ticket] = true
          collected_engines[engine] += 1
        }
      }
      if locals[entry] == 1UL {
        assert_eq(entry, head_entry)
        assert_eq(read(EntryValid(entry)), 1UL)
        assert_eq(read(EntryTerminal(entry)), 0UL)
        assert_eq(entry_tickets[entry], head_ticket)
        assert_true(head_ticket == 4UL || head_ticket == 5UL)
        assert_eq(read(HeadReject), if head_ticket == 4UL { 1UL } else { 0UL })
        assert_eq(read(HeadFence), if head_ticket == 5UL { 1UL } else { 0UL })
        assert_eq(read(HeadLocalFault), faults[head_ticket.to_int()])
        local_terminals += 1
      }
    }
    for engine in 0..<3 {
      if accepts[engine] == 1UL {
        assert_eq(read(HeadIssue), 1UL)
        assert_eq(read(EntryValid(head_entry)), 1UL)
        assert_eq(read(EntryTerminal(head_entry)), 0UL)
        assert_eq(read(EntryTicket(head_entry)), head_ticket)
        assert_eq(head_ticket, (reserved - 1).to_uint64())
        assert_eq(
          engine,
          if head_ticket < 2UL {
            0
          } else if head_ticket == 2UL {
            1
          } else {
            2
          },
        )
        accepted_engines[engine] += 1
      }
    }
    assert_eq(
      read(HeadIssue),
      if accepts[0] == 1UL || accepts[1] == 1UL || accepts[2] == 1UL {
        1UL
      } else {
        0UL
      },
    )
    assert_eq(
      finish,
      read(HeadIssue) == 1UL ||
      read(HeadReject) == 1UL ||
      read(HeadFence) == 1UL,
    )
    let held = read(RetirementValid) == 1UL && !release
    if held {
      assert_eq(queued_concurrent_payload(simulator), [73UL, 0UL, 2UL, 0UL])
      assert_eq(read(EntryTicket(read_pointer)), 0UL)
      assert_eq(read(RetirementFire), 0UL)
    }
    let saturated = !release &&
      reserved == 3 &&
      finished == 3 &&
      captured == 4 &&
      read(EntryTerminal(0)) == 1UL &&
      read(EntryTerminal(1)) == 1UL &&
      read(EntryTerminal(2)) == 1UL
    if !release && quiet_edges > 0 {
      assert_true(saturated)
    }
    if saturated {
      assert_eq(admitted, 6)
      assert_eq(popped, 4)
      assert_eq(occupancy, 3UL)
      assert_eq(fifo_count, 2UL)
      assert_eq(read(HeadState), 2UL)
      assert_eq(read(HeadReserve), 0UL)
      assert_true(held)
      for entry in 0..<3 {
        assert_eq(read(EntryTerminal(entry)), 1UL)
      }
      assert_eq(collected_engines, [2, 1, 0])
      assert_true(host.pending is None && host.held is None)
      quiet_edges += 1
    }
    if retire {
      assert_true(retired < reserved)
      assert_eq(read(EntryTicket(read_pointer)), retired.to_uint64())
      assert_eq(read(RetirementId), 73UL)
      assert_eq(read(RetirementFault), faults[retired])
      assert_eq(read(RetirementProgress), progresses[retired])
      assert_eq(read(RetirementAddress), 0UL)
      assert_eq(queued_concurrent_payload(simulator), [
        73UL,
        faults[retired],
        progresses[retired],
        0UL,
      ])
    }
    if reserve && retire {
      reserve_ack_edges += 1
    }
    let requests = host.requests.length()
    host.tick(simulator)
    queue_ownership_check(fixture, simulator)
    assert_eq(
      read(FifoOccupancy(0)),
      fifo_count +
      (if push { 1UL } else { 0UL }) -
      (if pop { 1UL } else { 0UL }),
    )
    assert_eq(
      read(RetirementOccupancy),
      occupancy +
      (if reserve { 1UL } else { 0UL }) -
      (if retire { 1UL } else { 0UL }),
    )
    assert_eq(
      read(RetirementWritePointer),
      if reserve {
        ((write_pointer + 1) % 3).to_uint64()
      } else {
        write_pointer.to_uint64()
      },
    )
    assert_eq(
      read(RetirementReadPointer),
      if retire {
        ((read_pointer + 1) % 3).to_uint64()
      } else {
        read_pointer.to_uint64()
      },
    )
    if pop {
      for lane in 0..<4 {
        assert_eq(read(FifoResponseValid(lane)), 1UL)
        assert_eq(read(FifoResponseData(lane)), packets[popped][lane])
      }
      popped += 1
    }
    if capture {
      for lane in 0..<4 {
        assert_eq(read(HeadLane(lane)), packets[captured][lane])
      }
      captured += 1
    }
    if reserve {
      assert_eq(read(HeadEntry), write_pointer.to_uint64())
      assert_eq(read(HeadTicket), reserved.to_uint64())
      assert_eq(read(NextTicket), (reserved + 1).to_uint64())
      assert_eq(read(EntryValid(write_pointer)), 1UL)
      assert_eq(read(EntryTerminal(write_pointer)), 0UL)
      assert_eq(read(EntryTicket(write_pointer)), reserved.to_uint64())
      assert_eq(read(EntryId(write_pointer)), 73UL)
      reserved += 1
    }
    for entry in 0..<3 {
      if acknowledgements[entry] == 1UL {
        assert_eq(read(EntryValid(entry)), 0UL)
      }
      if locals[entry] == 1UL ||
        collectors[entry][0] == 1UL ||
        collectors[entry][1] == 1UL ||
        collectors[entry][2] == 1UL {
        let ticket = entry_tickets[entry].to_int()
        assert_eq(read(EntryTerminal(entry)), 1UL)
        assert_eq(read(EntryFault(entry)), faults[ticket])
        assert_eq(read(EntryProgress(entry)), progresses[ticket])
        assert_eq(read(EntryAddress(entry)), 0UL)
      }
    }
    for engine in 0..<3 {
      if accepts[engine] == 1UL {
        assert_eq(read(EngineTicket(engine)), head_ticket)
        assert_true(read(EngineState(engine)) != 0UL)
      }
    }
    if held {
      assert_eq(read(RetirementValid), 1UL)
      assert_eq(queued_concurrent_payload(simulator), [73UL, 0UL, 2UL, 0UL])
    }
    if !release && quiet_edges > 0 {
      assert_eq(host.requests.length(), requests)
    }
    if push {
      admitted += 1
    }
    if finish {
      finished += 1
    }
    if retire {
      retired += 1
    }
    if retired == packets.length() {
      break
    }
  }
  assert_eq([admitted, popped, captured, reserved, finished, retired], [
    6, 6, 6, 6, 6, 6,
  ])
  assert_eq(quiet_edges, 16)
  assert_eq(accepted_engines, [2, 1, 1])
  assert_eq(collected_engines, [2, 1, 1])
  assert_eq(local_terminals, 2)
  assert_true(reserve_ack_edges > 0)
  assert_eq(host.requests.length(), 5)
  assert_eq(host.word(128UL), 31)
  assert_true(host.pending is None && host.held is None)
  assert_eq(read(FifoOccupancy(0)), 0UL)
  assert_eq(read(RetirementOccupancy), 0UL)
  assert_eq(read(RetirementValid), 0UL)
  assert_eq(read(NextTicket), 6UL)
  assert_eq(execute_read(simulator, "halted"), 0UL)
}
