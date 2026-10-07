///|
priv struct RecordsEntry {
  valid : Bool
  terminal : Bool
  acknowledge : Bool
  collector : Bool
  record : Array[UInt64]
}

///|
priv struct RecordsPre {
  pointer : Int
  valid : Bool
  ready : Bool
  payload : Array[UInt64]
  entries : Array[RecordsEntry]
}

///|
priv struct RecordsResponse {
  tag : UInt64
  data : UInt64
  delay : Int
} derive(Debug, Eq)

///|
fn records_put(
  simulator : @sim.Simulator,
  name : String,
  width : Int,
  value : UInt64,
) -> Unit raise {
  simulator.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
}

///|
fn records_output(simulator : @sim.Simulator, name : String) -> UInt64 raise {
  let value = simulator.output(name)
  assert_true(value.is_fully_known())
  value.to_uint64()
}

///|
fn records_observe(
  fixture : @flux_tile.QueueConservationFixture,
  simulator : @sim.Simulator,
  role : @flux_tile.QueueConservationRole,
) -> UInt64 raise {
  let matches = fixture
    .observations()
    .filter(reference => reference.role() == role)
  assert_eq(matches.length(), 1)
  let value = simulator.value(matches[0].node())
  assert_true(value.is_fully_known())
  value.to_uint64()
}

///|
fn records_pre(
  fixture : @flux_tile.QueueConservationFixture,
  simulator : @sim.Simulator,
) -> RecordsPre raise {
  let read = role => records_observe(fixture, simulator, role)
  let pointer = read(RetirementReadPointer).to_int()
  assert_true(pointer >= 0 && pointer < 3)
  let entries = Array::makei(3, entry => {
    valid: read(EntryValid(entry)) == 1UL,
    terminal: read(EntryTerminal(entry)) == 1UL,
    acknowledge: read(EntryAcknowledge(entry)) == 1UL,
    collector: [0, 1, 2].any(engine => {
      read(EntryCollector(entry, engine)) == 1UL
    }),
    record: [
      read(EntryTicket(entry)),
      read(EntryId(entry)),
      read(EntryFault(entry)),
      read(EntryProgress(entry)),
      read(EntryAddress(entry)),
    ],
  })
  {
    pointer,
    valid: records_output(simulator, "completion_valid") == 1UL,
    ready: records_output(simulator, "completion_valid") == 1UL &&
    read(RetirementFire) == 1UL,
    payload: [
      records_output(simulator, "completion_id"),
      records_output(simulator, "completion_fault"),
      records_output(simulator, "completion_bytes_completed"),
      records_output(simulator, "completion_fault_address"),
    ],
    entries,
  }
}

///|
// Compare sampled observations only. No shadow queue/controller transitions.
fn records_check(
  previous : RecordsPre?,
  current : RecordsPre,
) -> (Bool, Bool, Bool) raise {
  let oldest = current.entries[current.pointer]
  assert_eq(current.valid, oldest.valid && oldest.terminal)
  if current.valid {
    assert_eq(current.payload, oldest.record[1:5].to_owned())
  }
  let blocked_younger = oldest.valid &&
    !oldest.terminal &&
    current.entries.any(entry => entry.valid && entry.terminal)
  if blocked_younger {
    assert_false(current.valid)
  }
  let mut collector_witness = false
  let mut release_witness = false
  if previous is Some(before) {
    for index, entry in before.entries {
      if entry.valid && entry.terminal && !entry.acknowledge {
        assert_true(
          current.entries[index].valid && current.entries[index].terminal,
        )
        assert_eq(current.entries[index].record, entry.record)
      }
    }
    if before.valid && !before.ready {
      // Current ready does not disable the preceding held-record obligation.
      assert_true(current.valid)
      assert_eq(current.pointer, before.pointer)
      assert_eq(current.payload, before.payload)
      assert_eq(oldest.record[0], before.entries[before.pointer].record[0])
      release_witness = current.ready
      if !current.ready {
        for index, entry in before.entries {
          if index != before.pointer &&
            entry.valid &&
            !entry.terminal &&
            entry.collector {
            assert_true(
              current.entries[index].valid && current.entries[index].terminal,
            )
            assert_eq(current.entries[index].record[0], entry.record[0])
            collector_witness = true
          }
        }
      }
    }
  }
  (blocked_younger, collector_witness, release_witness)
}

///|
fn records_packet(
  opcode : UInt64,
  rows : UInt64,
  columns : UInt64,
  reduction : UInt64,
  base : UInt64,
  stride : UInt64,
) -> Array[UInt64] {
  [
    (73UL << 32) | (opcode << 16) | 0x200UL,
    rows | (columns << 16) | (reduction << 32),
    base | (stride << 32),
    0UL,
  ]
}

///|
fn records_present(
  simulator : @sim.Simulator,
  packet : Array[UInt64]?,
) -> Unit raise {
  records_put(
    simulator,
    "descriptor_valid",
    1,
    if packet is Some(_) {
      1UL
    } else {
      0UL
    },
  )
  if packet is Some(lanes) {
    for lane in 0..<4 {
      records_put(simulator, "descriptor_lane_\{lane}", 64, lanes[lane])
    }
  }
}

///|
test "real queued DUT preserves held terminal records through younger collector release and later reset" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  assert_eq(fixture.observations().length(), 115)
  let simulator = @sim.Simulator::prepare(fixture.hardware())
  // Reuse this real packet/host scenario for finite 30-root/59-event owner
  // projection correspondence, including all actual foreign LogicValue masks.
  let correspondence = queue_owner_correspondence_prepare(fixture)
  for node in fixture.hardware().nodes() {
    if node.kind() is Input(name) && name != "clock" {
      records_put(simulator, name, node.signal_type().width().bits(), 0UL)
    }
  }
  records_put(simulator, "reset", 1, 1UL)
  queue_owner_correspondence_pre(correspondence, simulator)
  simulator.rising_edge("clock")
  queue_owner_correspondence_post(correspondence, simulator)
  records_put(simulator, "reset", 1, 0UL)
  let packets = [
    records_packet(0UL, 1UL, 2UL, 0UL, 32UL, 2UL),
    records_packet(4UL, 1UL, 0UL, 0UL, 0UL, 0UL),
    records_packet(1UL, 2UL, 1UL, 0UL, 64UL, 1UL),
    records_packet(2UL, 1UL, 1UL, 2UL, 0UL, 0UL),
    records_packet(3UL, 1UL, 1UL, 0UL, 128UL, 4UL),
    records_packet(4UL, 0UL, 0UL, 0UL, 0UL, 0UL),
  ]
  let faults = [0UL, 2UL, 0UL, 0UL, 0UL, 0UL]
  let progress = [2UL, 0UL, 2UL, 0UL, 4UL, 0UL]
  let memory = Array::make(1024, 165UL)
  memory[32] = 2UL
  memory[33] = 3UL
  memory[64] = 5UL
  memory[65] = 7UL
  let mut previous : RecordsPre? = None
  let mut pending : RecordsResponse? = None
  let mut admitted = 0
  let mut retired = 0
  let mut requests = 0
  let mut acknowledgements = 0
  let mut held_edges = 0
  let mut release = false
  let mut no_bypass = false
  let mut younger_collector = false
  let mut release_checked = false
  let terminal_watched = Array::make(3, false)
  for _ in 0..<1024 {
    records_present(
      simulator,
      if admitted < 6 {
        Some(packets[admitted])
      } else {
        None
      },
    )
    records_put(
      simulator,
      "completion_ready",
      1,
      if release {
        1UL
      } else {
        0UL
      },
    )
    records_put(simulator, "memory_request_ready", 1, 1UL)
    let responding = pending is Some(response) && response.delay == 0
    records_put(
      simulator,
      "memory_response_valid",
      1,
      if responding {
        1UL
      } else {
        0UL
      },
    )
    if pending is Some(response) {
      records_put(simulator, "memory_response_tag", 32, response.tag)
      records_put(simulator, "memory_response_data", 32, response.data)
      records_put(simulator, "memory_response_fault", 2, 0UL)
    }
    simulator.settle()
    let current = records_pre(fixture, simulator)
    let (blocked, collected, released) = records_check(previous, current)
    no_bypass = no_bypass || blocked
    younger_collector = younger_collector || collected
    release_checked = release_checked || released
    for index, entry in current.entries {
      if entry.valid && entry.terminal && !entry.acknowledge {
        terminal_watched[index] = true
      }
    }
    if !release && current.entries.all(entry => entry.valid && entry.terminal) {
      held_edges += 1
      if held_edges == 16 {
        assert_true(no_bypass && younger_collector)
        release = true
      }
    }
    let push = admitted < 6 &&
      records_output(simulator, "descriptor_ready") == 1UL
    let response_ack = responding &&
      records_output(simulator, "memory_response_ready") == 1UL
    let accepted = records_output(simulator, "memory_request_valid") == 1UL
    let mut accepted_response : RecordsResponse? = None
    if accepted {
      assert_eq(pending, None)
      let address = records_output(simulator, "memory_request_address").to_int()
      let tag = records_output(simulator, "memory_request_tag")
      assert_eq(tag, requests.to_uint64())
      let write = records_output(simulator, "memory_request_write") == 1UL
      let data = records_output(simulator, "memory_request_data")
      if write {
        assert_eq(requests, 4)
        assert_eq(address, 128)
        assert_eq(records_output(simulator, "memory_request_bytes"), 4UL)
        assert_eq(records_output(simulator, "memory_request_mask"), 15UL)
        assert_eq(data, 31UL)
        for byte in 0..<4 {
          memory[address + byte] = (data >> (byte * 8)) & 255UL
        }
      } else {
        assert_true(requests < 4)
        assert_eq(address, [32, 33, 64, 65][requests])
        assert_eq(records_output(simulator, "memory_request_bytes"), 1UL)
        assert_eq(records_output(simulator, "memory_request_mask"), 1UL)
      }
      accepted_response = Some({
        tag,
        data: if write {
          0UL
        } else {
          memory[address]
        },
        delay: if requests == 0 {
          24
        } else {
          2
        },
      })
      requests += 1
    }
    if current.valid && current.ready {
      assert_true(retired < 6)
      assert_eq(current.entries[current.pointer].record[0], retired.to_uint64())
      assert_eq(current.payload, [73UL, faults[retired], progress[retired], 0UL])
      retired += 1
    }
    queue_owner_correspondence_pre(correspondence, simulator)
    simulator.rising_edge("clock")
    queue_owner_correspondence_post(correspondence, simulator)
    previous = Some(current)
    if push {
      admitted += 1
    }
    if response_ack {
      acknowledgements += 1
      pending = None
    } else if pending is Some(response) && response.delay > 0 {
      pending = Some({
        tag: response.tag,
        data: response.data,
        delay: response.delay - 1,
      })
    }
    if accepted_response is Some(response) {
      pending = Some(response)
    }
    if retired == 6 {
      break
    }
  }
  assert_eq(admitted, 6)
  assert_eq(retired, 6)
  assert_eq(requests, 5)
  assert_eq(acknowledgements, 5)
  assert_eq(pending, None)
  assert_true(no_bypass && younger_collector && release_checked)
  assert_true(terminal_watched.all(watched => watched))
  let expected = Array::make(1024, 165UL)
  expected[32] = 2UL
  expected[33] = 3UL
  expected[64] = 5UL
  expected[65] = 7UL
  for byte in 0..<4 {
    expected[128 + byte] = (31UL >> (byte * 8)) & 255UL
  }
  assert_eq(memory, expected)
  // A later reset flushes a genuinely held record, not just startup state.
  for epoch in 0..<2 {
    let mut pushed = false
    let mut holds = 0
    let mut seen : RecordsPre? = None
    records_put(simulator, "completion_ready", 1, 0UL)
    records_put(simulator, "memory_response_valid", 1, 0UL)
    for _ in 0..<128 {
      records_present(simulator, if pushed { None } else { Some(packets[5]) })
      simulator.settle()
      let current = records_pre(fixture, simulator)
      let _ = records_check(seen, current)
      let push = !pushed && records_output(simulator, "descriptor_ready") == 1UL
      assert_eq(records_output(simulator, "memory_request_valid"), 0UL)
      if current.valid {
        assert_eq(current.payload, [73UL, 0UL, 0UL, 0UL])
        assert_eq(
          current.entries[current.pointer].record[0],
          if epoch == 0 {
            6UL
          } else {
            0UL
          },
        )
        holds += 1
      }
      queue_owner_correspondence_pre(correspondence, simulator)
      simulator.rising_edge("clock")
      queue_owner_correspondence_post(correspondence, simulator)
      if push {
        pushed = true
      }
      seen = Some(current)
      if holds == 3 {
        break
      }
    }
    assert_true(pushed)
    assert_eq(holds, 3)
    records_present(simulator, None)
    records_put(simulator, "completion_ready", 1, 1UL)
    if epoch == 0 {
      // Asserted reset gates PRE handshakes, then resets all stored ownership.
      records_put(simulator, "reset", 1, 1UL)
      simulator.settle()
      for
        name in [
          "descriptor_ready", "completion_valid", "memory_request_valid", "memory_response_ready",
        ] {
        assert_eq(records_output(simulator, name), 0UL)
      }
      queue_owner_correspondence_pre(correspondence, simulator)
      simulator.rising_edge("clock")
      queue_owner_correspondence_post(correspondence, simulator)
      records_put(simulator, "reset", 1, 0UL)
      simulator.settle()
      assert_eq(records_observe(fixture, simulator, NextTicket), 0UL)
      assert_eq(records_observe(fixture, simulator, RetirementOccupancy), 0UL)
      assert_eq(records_output(simulator, "completion_valid"), 0UL)
      for entry in 0..<3 {
        assert_eq(records_observe(fixture, simulator, EntryValid(entry)), 0UL)
      }
      for
        name in [
          "accepted_steps", "active_cycles", "elapsed_cycles", "stall_cycles", "capture_cycles",
        ] {
        assert_eq(records_output(simulator, name), 0UL)
      }
    } else {
      simulator.settle()
      let released = records_pre(fixture, simulator)
      let (_, _, release_edge) = records_check(seen, released)
      assert_true(release_edge)
      queue_owner_correspondence_pre(correspondence, simulator)
      simulator.rising_edge("clock")
      queue_owner_correspondence_post(correspondence, simulator)
      assert_eq(records_observe(fixture, simulator, RetirementOccupancy), 0UL)
      assert_eq(records_output(simulator, "completion_valid"), 0UL)
    }
  }
  queue_owner_correspondence_finish(correspondence)
}
