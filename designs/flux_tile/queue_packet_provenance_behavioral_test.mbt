///|
// Distinct raw packets deliberately retain reserved/malformed bits in every
// lane. Version rejection wins before issue; repeated IDs cannot identify them.
fn packet_provenance_packets() -> Array[Array[UInt64]] raise {
  let base = queued_concurrent_packet(Fence, 73)
  Array::makei(8, index => {
    let ordinal = index.to_uint64() + 1UL
    [
      (base[0] ^ 768UL) | (ordinal << 16),
      0x0123456789abcdefUL ^ ordinal,
      0xfedcba9876543210UL ^ (ordinal << 32),
      0x8000000000000000UL | ordinal,
    ]
  })
}

///|
fn packet_provenance_input(
  fixture : @flux_tile.QueueConservationFixture,
  simulator : @sim.Simulator,
  name : String,
) -> UInt64 raise {
  for node in fixture.hardware().nodes() {
    if node.kind() is Input(input_name) && input_name == name {
      let value = simulator.value(node.id())
      if !value.is_fully_known() {
        fail("unknown public packet-provenance input: \{name}")
      }
      return value.to_uint64()
    }
  }
  fail("missing public packet-provenance input: \{name}")
}

///|
fn packet_provenance_epoch(
  fixture : @flux_tile.QueueConservationFixture,
  simulator : @sim.Simulator,
  host : PortableHost,
  cancel : Bool,
) -> Array[Int32] raise {
  let packets = packet_provenance_packets()
  let admitted_packets : Array[Array[UInt64]] = []
  let entries : Array[Int32] = []
  let tickets : Array[UInt64] = []
  let read = (role : @flux_tile.QueueConservationRole) => {
    queue_conservation_value(fixture, simulator, role)
  }
  let mut popped = 0
  let mut captured = 0
  let mut reserved = 0
  let mut retired = 0
  let mut hold_edges = 0
  // 0: fill/hold; 1: release one older entry; 2: wait for older pop;
  // 3: drain after the watched admission + older ACK on the same edge.
  let mut phase = 0
  let mut full_refill = false
  let mut joint_watch = false
  let mut watch_fifo_older = 0
  let mut watch_retire_older = 0
  let mut watch_popped = false
  let mut watch_captured = false
  let mut watch_reserved = false
  let mut watch_retired = false
  for _ in 0..<512 {
    let admitted = admitted_packets.length()
    let joint_edge = phase == 2 && read(HeadPop) == 1UL
    let present = (phase == 0 && admitted < 7) || joint_edge
    if present {
      frontend_present(simulator, packets[admitted])
    } else {
      portable_put(simulator, "descriptor_valid", 1, 0UL)
      // Change caller lanes after admission: FIFO/head must retain the snapshot.
      for lane in 0..<4 {
        portable_put(
          simulator,
          "descriptor_lane_\{lane}",
          64,
          255UL + lane.to_uint64(),
        )
      }
    }
    let ready = phase == 1 || joint_edge || phase == 3
    portable_put(
      simulator,
      "completion_ready",
      1,
      if ready {
        1UL
      } else {
        0UL
      },
    )
    queue_conservation_present_peer(host, simulator)
    let admit = packet_provenance_input(fixture, simulator, "descriptor_valid") ==
      1UL &&
      execute_read(simulator, "descriptor_ready") == 1UL
    let pop = read(HeadPop) == 1UL
    let capture = read(HeadCapture) == 1UL
    let reserve = read(HeadReserve) == 1UL
    let finish = read(HeadFinish) == 1UL
    let retire = read(RetirementFire) == 1UL
    let fifo_count = read(FifoOccupancy(0))
    let write_pointer = read(RetirementWritePointer).to_int()
    let read_pointer = read(RetirementReadPointer).to_int()
    let next_ticket = read(NextTicket)
    assert_eq(fifo_count, (admitted - popped).to_uint64())
    assert_eq(read(RetirementOccupancy), (reserved - retired).to_uint64())
    assert_true(write_pointer < 3 && read_pointer < 3)
    if pop {
      // The new public admission cannot be the older synchronous pop.
      assert_true(popped < admitted)
    }
    if capture {
      assert_eq(popped, captured + 1)
      for lane in 0..<4 {
        assert_eq(read(FifoResponseValid(lane)), 1UL)
        assert_eq(
          read(FifoResponseData(lane)),
          admitted_packets[captured][lane],
        )
      }
      if captured == 7 {
        assert_true(watch_popped)
        watch_captured = true
      }
    }
    if captured > reserved || read(HeadState) == 3UL {
      let ordinal = captured - 1
      for lane in 0..<4 {
        assert_eq(read(HeadLane(lane)), admitted_packets[ordinal][lane])
      }
    }
    if reserve {
      assert_eq(captured, reserved + 1)
      assert_eq(read(EntryValid(write_pointer)), 0UL)
    }
    if retire {
      assert_true(retired < reserved)
      assert_eq(read_pointer, entries[retired])
      assert_eq(read(EntryTicket(read_pointer)), tickets[retired])
      assert_eq(read(EntryTerminal(read_pointer)), 1UL)
      assert_eq(read(EntryId(read_pointer)), admitted_packets[retired][0] >> 32)
      assert_eq(queued_concurrent_payload(simulator), [73UL, 12UL, 0UL, 0UL])
      if retired == 7 {
        assert_true(watch_reserved && watch_retire_older == 0)
        watch_retired = true
      }
    }
    for entry in 0..<3 {
      assert_eq(
        read(EntryAcknowledge(entry)),
        if retire && entry == read_pointer {
          1UL
        } else {
          0UL
        },
      )
    }
    if read(RetirementValid) == 1UL && !ready {
      assert_eq(queued_concurrent_payload(simulator), [73UL, 12UL, 0UL, 0UL])
      assert_eq(read(EntryTicket(read_pointer)), tickets[retired])
    }
    if fifo_count == 3UL && pop && admit {
      full_refill = true
    }
    if joint_edge {
      assert_eq(admitted, 7)
      assert_eq(retired, 1)
      assert_true(admit && pop && retire)
      assert_eq(fifo_count, 3UL)
      // Public ordinal counters, not a private ticket or repeated caller ID,
      // determine the older packets on this watched admission edge.
      watch_fifo_older = admitted - popped - 1
      watch_retire_older = admitted - retired - 1
      assert_eq(watch_fifo_older, 2)
      assert_eq(watch_retire_older, 5)
      joint_watch = true
    } else if joint_watch {
      if pop {
        if watch_fifo_older == 0 {
          assert_eq(popped, 7)
          assert_false(watch_popped)
          watch_popped = true
        } else {
          assert_true(watch_fifo_older > 0)
          watch_fifo_older -= 1
        }
      }
      if retire && retired < 7 {
        assert_true(watch_retire_older > 0)
        watch_retire_older -= 1
      }
    }
    let saturated = phase == 0 &&
      admitted == 7 &&
      popped == 4 &&
      captured == 4 &&
      reserved == 3 &&
      read(HeadState) == 2UL &&
      read(EntryTerminal(0)) == 1UL &&
      read(EntryTerminal(1)) == 1UL &&
      read(EntryTerminal(2)) == 1UL
    if saturated {
      assert_true(full_refill)
      assert_eq(fifo_count, 3UL)
      assert_eq(read(RetirementOccupancy), 3UL)
      assert_eq(read(RetirementValid), 1UL)
      assert_false(retire || reserve || pop || admit)
      hold_edges += 1
    }
    // Save actual public lanes only on an accepted admission, before commit.
    if admit {
      let saved = Array::makei(4, lane => {
        packet_provenance_input(fixture, simulator, "descriptor_lane_\{lane}")
      })
      assert_eq(saved, packets[admitted])
      admitted_packets.push(saved)
    }
    host.tick(simulator)
    assert_eq(
      read(FifoOccupancy(0)),
      fifo_count +
      (if admit { 1UL } else { 0UL }) -
      (if pop { 1UL } else { 0UL }),
    )
    if pop {
      for lane in 0..<4 {
        assert_eq(read(FifoResponseValid(lane)), 1UL)
        assert_eq(read(FifoResponseData(lane)), admitted_packets[popped][lane])
      }
      popped += 1
    }
    if capture {
      for lane in 0..<4 {
        assert_eq(read(HeadLane(lane)), admitted_packets[captured][lane])
      }
      captured += 1
    }
    if reserve {
      assert_eq(read(HeadEntry), write_pointer.to_uint64())
      assert_eq(read(HeadTicket), next_ticket)
      assert_eq(read(NextTicket), next_ticket + 1UL)
      assert_eq(read(EntryValid(write_pointer)), 1UL)
      assert_eq(read(EntryTerminal(write_pointer)), 0UL)
      assert_eq(read(EntryTicket(write_pointer)), next_ticket)
      assert_eq(
        read(EntryId(write_pointer)),
        admitted_packets[reserved][0] >> 32,
      )
      entries.push(write_pointer)
      tickets.push(next_ticket)
      if reserved == 7 {
        assert_true(watch_captured)
        watch_reserved = true
      }
      reserved += 1
    }
    if retire {
      assert_eq(read(EntryValid(read_pointer)), 0UL)
      retired += 1
    }
    if !ready && read(RetirementValid) == 1UL {
      assert_eq(queued_concurrent_payload(simulator), [73UL, 12UL, 0UL, 0UL])
    }
    if finish {
      assert_eq(read(HeadState), 0UL)
    }
    assert_eq(host.requests.length(), 0)
    assert_true(host.pending is None && host.held is None)
    if phase == 0 && hold_edges == 8 {
      if cancel {
        // A captured unreserved head plus three queued packets and three live
        // held entries remain outstanding, not silently considered retired.
        assert_eq(
          [admitted_packets.length(), popped, captured, reserved, retired],
          [7, 4, 4, 3, 0],
        )
        return [7, 4, 4, 3, 0]
      }
      phase = 1
    } else if phase == 1 {
      assert_true(retire)
      assert_eq(retired, 1)
      phase = 2
    } else if joint_edge {
      phase = 3
    }
    if retired == 8 {
      break
    }
  }
  assert_true(full_refill && joint_watch)
  assert_true(watch_popped && watch_captured && watch_reserved && watch_retired)
  assert_eq(hold_edges, 8)
  assert_eq([admitted_packets.length(), popped, captured, reserved, retired], [
    8, 8, 8, 8, 8,
  ])
  assert_eq(read(FifoOccupancy(0)), 0UL)
  assert_eq(read(RetirementOccupancy), 0UL)
  assert_eq(read(RetirementValid), 0UL)
  [8, 8, 8, 8, 8]
}

///|
test "public packet provenance follows full refill joint older ACK held retirement and later reset" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let simulator = queue_conservation_prepare(fixture)
  let host = PortableHost::new()
  host.stalled = false
  assert_eq(packet_provenance_epoch(fixture, simulator, host, false), [
    8, 8, 8, 8, 8,
  ])
  assert_eq(queue_conservation_value(fixture, simulator, NextTicket), 8UL)
  assert_eq(packet_provenance_epoch(fixture, simulator, host, true), [
    7, 4, 4, 3, 0,
  ])
  assert_eq(queue_conservation_value(fixture, simulator, NextTicket), 11UL)
  // Joint reset cancels the second epoch's accepted prefix, captured head and
  // FIFO data. Deasserting reset must not revive a repeated-ID completion.
  portable_put(simulator, "descriptor_valid", 1, 0UL)
  portable_put(simulator, "completion_ready", 1, 0UL)
  portable_put(simulator, "reset", 1, 1UL)
  simulator.rising_edge("clock")
  portable_put(simulator, "reset", 1, 0UL)
  for
    role in [
      @flux_tile.QueueConservationRole::HeadState,
      NextTicket,
      RetirementOccupancy,
      RetirementValid,
    ] {
    assert_eq(queue_conservation_value(fixture, simulator, role), 0UL)
  }
  for lane in 0..<4 {
    assert_eq(
      queue_conservation_value(fixture, simulator, FifoOccupancy(lane)),
      0UL,
    )
    assert_eq(
      queue_conservation_value(fixture, simulator, FifoResponseValid(lane)),
      0UL,
    )
  }
  for entry in 0..<3 {
    assert_eq(
      queue_conservation_value(fixture, simulator, EntryValid(entry)),
      0UL,
    )
    assert_eq(
      queue_conservation_value(fixture, simulator, EntryTerminal(entry)),
      0UL,
    )
  }
  for _ in 0..<4 {
    host.tick(simulator)
    assert_eq(execute_read(simulator, "completion_valid"), 0UL)
  }
  assert_eq(packet_provenance_epoch(fixture, simulator, host, false), [
    8, 8, 8, 8, 8,
  ])
  assert_eq(queue_conservation_value(fixture, simulator, NextTicket), 8UL)
  assert_eq(execute_read(simulator, "halted"), 0UL)
}
