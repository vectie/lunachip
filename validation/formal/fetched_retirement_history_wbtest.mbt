///|
fn fetched_retirement_pre(
  fixture : @flux_tile.QueueConservationFixture,
  simulator : @sim.Simulator,
) -> RecordsPre raise {
  let read = role => records_observe(fixture, simulator, role)
  let pointer = read(RetirementReadPointer).to_int()
  assert_true(pointer < 2)
  let entries = Array::makei(2, entry => RecordsEntry::{
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
    entries,
    valid: records_output(simulator, "completion_valid") == 1UL,
    ready: records_output(simulator, "completion_valid") == 1UL &&
    read(RetirementFire) == 1UL,
    payload: [
      records_output(simulator, "completion_id"),
      records_output(simulator, "completion_fault"),
      records_output(simulator, "completion_bytes_completed"),
      records_output(simulator, "completion_fault_address"),
    ],
  }
}

///|
fn fetched_retirement_check_state(
  fixture : @flux_tile.QueueConservationFixture,
  simulator : @sim.Simulator,
  current : RecordsPre,
) -> Unit raise {
  let read = role => records_observe(fixture, simulator, role)
  let count = read(RetirementOccupancy).to_int()
  let write = read(RetirementWritePointer).to_int()
  assert_true(count <= 2 && write < 2 && read(HeadEntry) < 2UL)
  assert_eq(write, (current.pointer + count) % 2)
  let next = read(NextTicket).to_uint()
  for entry in 0..<2 {
    let rank = (entry - current.pointer + 2) % 2
    assert_eq(current.entries[entry].valid, rank < count)
    if rank < count {
      assert_eq(
        current.entries[entry].record[0].to_uint(),
        next - (count - rank).reinterpret_as_uint(),
      )
    }
    if read(EntryAllocate(entry)) == 1UL {
      assert_false(current.entries[entry].valid)
    }
    if read(EntryLocalTerminal(entry)) == 1UL {
      assert_eq(read(HeadState), 3UL)
      assert_eq(read(HeadEntry).to_int(), entry)
      assert_true(
        current.entries[entry].valid && !current.entries[entry].terminal,
      )
    }
  }
  if read(HeadState) == 3UL {
    let entry = read(HeadEntry).to_int()
    assert_eq(entry, (write + 1) % 2)
    assert_true(
      current.entries[entry].valid && !current.entries[entry].terminal,
    )
    assert_eq(current.entries[entry].record[0], read(HeadTicket))
    assert_eq(read(HeadTicket).to_uint(), next - 1U)
  }
  for engine in 0..<3 {
    if read(EngineState(engine)) != 0UL {
      assert_true(
        [0, 1].any(entry => {
          current.entries[entry].valid &&
          !current.entries[entry].terminal &&
          current.entries[entry].record[0] == read(EngineTicket(engine)) &&
          !(read(HeadState) == 3UL && read(HeadEntry).to_int() == entry)
        }),
      )
    }
  }
}

///|
test "fetched q2 actual held records allow younger collection release duplicate IDs and reset recovery" {
  let fixture = @flux_tile.ring_concurrent_queue_formal_fixture()
  let simulator = @sim.Simulator::prepare(fixture.hardware())
  assert_true(
    fixture
    .hardware()
    .nodes()
    .any(node => {
      node.kind() is MemoryRead(..) &&
      !simulator.value(node.id()).is_fully_known()
    }),
  )
  for node in fixture.hardware().nodes() {
    if node.kind() is Input(name) && name != "clock" {
      records_put(simulator, name, node.signal_type().width().bits(), 0UL)
    }
  }
  let mut configured = false
  let mut published = false
  let mut pending : FetchedUsefulNativeRequest? = None
  let mut previous : RecordsPre? = None
  let mut hold_age = 0
  let mut retired = 0
  let mut writes = 0
  let mut reset_next = false
  let mut later_reset = false
  let mut younger_seen = false
  let mut release_seen = false
  let mut reset_hold_seen = false
  let mut completed = false
  for edge in 0..<1200 {
    let reset = edge == 0 || reset_next
    if reset {
      if edge != 0 {
        assert_true(previous is Some({ valid: true, ready: false, .. }))
        later_reset = true
        reset_hold_seen = true
      }
      configured = false
      published = false
      pending = None
      previous = None
      hold_age = 0
      retired = 0
      reset_next = false
    }
    let ready = retired > 0 || hold_age >= 140
    let response_data = match pending {
      Some(r) if !r.write => fetched_useful_native_data(r.address)
      _ => 0UL
    }
    for
      (name, width, value) in [
        ("reset", 1, if reset { 1UL } else { 0UL }),
        ("config_valid", 1, if !reset && !configured { 1UL } else { 0UL }),
        ("config_base", 32, 0UL),
        ("config_origin", 32, 0UL),
        (
          "publish_valid",
          1,
          if !reset && configured && !published {
            1UL
          } else {
            0UL
          },
        ),
        ("publish_producer", 32, 4UL),
        ("completion_ready", 1, if ready { 1UL } else { 0UL }),
        ("memory_request_ready", 1, 1UL),
        (
          "memory_response_valid",
          1,
          if pending is Some(_) && !reset {
            1UL
          } else {
            0UL
          },
        ),
        ("memory_response_fault", 2, 0UL),
        ("memory_response_tag", 32, pending.map(r => r.tag).unwrap_or(0UL)),
        ("memory_response_data", 32, response_data),
      ] {
      records_put(simulator, name, width, value)
    }
    simulator.settle()
    if !reset {
      if !configured && records_output(simulator, "config_ready") == 1UL {
        configured = true
      } else if configured &&
        !published &&
        records_output(simulator, "publish_ready") == 1UL {
        published = true
      }
      let current = fetched_retirement_pre(fixture, simulator)
      fetched_retirement_check_state(fixture, simulator, current)
      let (_, younger, release) = records_check(previous, current)
      younger_seen = younger_seen || younger
      release_seen = release_seen || release
      if younger && !later_reset {
        reset_next = true
      }
      if current.valid && !ready {
        hold_age += 1
      }
      if current.valid && ready {
        assert_eq(current.payload[0], 73UL)
        assert_eq(current.payload[1], 0UL)
        retired += 1
      }
      previous = Some(current)
      if records_output(simulator, "memory_request_valid") == 1UL {
        assert_true(pending is None)
        let request : FetchedUsefulNativeRequest = {
          tag: records_output(simulator, "memory_request_tag"),
          address: records_output(simulator, "memory_request_address"),
          write: records_output(simulator, "memory_request_write") == 1UL,
          bytes: records_output(simulator, "memory_request_bytes"),
          mask: records_output(simulator, "memory_request_mask"),
          data: records_output(simulator, "memory_request_data"),
        }
        assert_true(request.address + request.bytes <= 1024UL)
        if request.write {
          assert_eq(
            (request.address, request.data, request.mask, request.bytes),
            (768UL, 4294967267UL, 15UL, 4UL),
          )
          writes += 1
        }
        pending = Some(request)
      } else if pending is Some(_) &&
        records_output(simulator, "memory_response_ready") == 1UL {
        pending = None
      }
      if later_reset && retired == 4 {
        completed = true
        break
      }
    } else {
      assert_eq(records_output(simulator, "completion_valid"), 0UL)
    }
    simulator.rising_edge("clock")
    simulator.settle()
  }
  assert_true(completed && younger_seen && release_seen && reset_hold_seen)
  assert_eq(writes, 1)
}
