///|
// Reuse the original fixed byte-host trajectory, not a transport-controller
// model. This finite run does not claim the five symbolic dependency covers or
// the older-terminal/new-intent same-edge priority witness.
test "dependency union corresponds through real three-engine transfer, drive-only hold and later reset" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let dependency_fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let source = @sim.Simulator::prepare(fixture.hardware())
  let observer = dependency_conjunction_correspondence_prepare(
    fixture, dependency_fixture,
  )
  for node in fixture.hardware().nodes() {
    if node.kind() is Input(name) && name != "clock" {
      records_put(source, name, node.signal_type().width().bits(), 0UL)
    }
  }
  records_put(source, "reset", 1, 1UL)
  dependency_conjunction_correspondence_tick(observer, source)
  records_put(source, "reset", 1, 0UL)
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
  let mut pending : RecordsResponse? = None
  let mut previous : RecordsPre? = None
  let mut admitted = 0
  let mut retired = 0
  let mut requests = 0
  let mut acknowledgements = 0
  let mut held_edges = 0
  let mut release = false
  let mut no_bypass = false
  let mut younger_collector = false
  let mut release_checked = false
  let mut nonrising_seen = false
  for _ in 0..<1024 {
    records_present(
      source,
      if admitted < 6 {
        Some(packets[admitted])
      } else {
        None
      },
    )
    records_put(source, "completion_ready", 1, if release { 1UL } else { 0UL })
    records_put(source, "memory_request_ready", 1, 1UL)
    let responding = pending is Some(response) && response.delay == 0
    records_put(
      source,
      "memory_response_valid",
      1,
      if responding {
        1UL
      } else {
        0UL
      },
    )
    if pending is Some(response) {
      records_put(source, "memory_response_tag", 32, response.tag)
      records_put(source, "memory_response_data", 32, response.data)
      records_put(source, "memory_response_fault", 2, 0UL)
      if requests == 1 && response.delay == 12 && !nonrising_seen {
        // A genuine accepted Load request still waits for its delayed ACK.
        source.settle()
        assert_false(responding)
        assert_eq(records_output(source, "memory_request_valid"), 0UL)
        assert_eq(observer.accepts[0], 1)
        assert_eq(observer.terminals[0], 0)
        dependency_conjunction_correspondence_nonrising(observer, source)
        nonrising_seen = true
      }
    }
    source.settle()
    let current = records_pre(fixture, source)
    let (blocked, collected, released) = records_check(previous, current)
    no_bypass = no_bypass || blocked
    younger_collector = younger_collector || collected
    release_checked = release_checked || released
    if !release && current.entries.all(entry => entry.valid && entry.terminal) {
      held_edges += 1
      if held_edges == 16 {
        assert_true(no_bypass && younger_collector)
        release = true
      }
    }
    let push = admitted < 6 && records_output(source, "descriptor_ready") == 1UL
    let response_ack = responding &&
      records_output(source, "memory_response_ready") == 1UL
    let accepted = records_output(source, "memory_request_valid") == 1UL
    let mut accepted_response : RecordsResponse? = None
    if accepted {
      assert_eq(pending, None)
      let address = records_output(source, "memory_request_address").to_int()
      let tag = records_output(source, "memory_request_tag")
      assert_eq(tag, requests.to_uint64())
      let write = records_output(source, "memory_request_write") == 1UL
      let data = records_output(source, "memory_request_data")
      if write {
        assert_eq(requests, 4)
        assert_eq(address, 128)
        assert_eq(records_output(source, "memory_request_bytes"), 4UL)
        assert_eq(records_output(source, "memory_request_mask"), 15UL)
        assert_eq(data, 31UL)
        for byte in 0..<4 {
          memory[address + byte] = (data >> (byte * 8)) & 255UL
        }
      } else {
        assert_true(requests < 4)
        assert_eq(address, [32, 33, 64, 65][requests])
        assert_eq(records_output(source, "memory_request_bytes"), 1UL)
        assert_eq(records_output(source, "memory_request_mask"), 1UL)
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
    dependency_conjunction_correspondence_tick(observer, source)
    previous = Some(current)
    if push {
      admitted += 1
    }
    if response_ack {
      acknowledgements += 1
      pending = None
    } else if pending is Some(response) && response.delay > 0 {
      pending = Some({ ..response, delay: response.delay - 1, })
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
  assert_eq(held_edges, 16)
  assert_true(
    nonrising_seen && no_bypass && younger_collector && release_checked,
  )
  let expected = Array::make(1024, 165UL)
  expected[32] = 2UL
  expected[33] = 3UL
  expected[64] = 5UL
  expected[65] = 7UL
  for byte in 0..<4 {
    expected[128 + byte] = (31UL >> (byte * 8)) & 255UL
  }
  assert_eq(memory, expected)
  // Later reset flushes actual held retirement state. Its synchronous register
  // reset must NOT clear original FIFO SRAM cells or HoldLast read results.
  for epoch in 0..<2 {
    let mut pushed = false
    let mut holds = 0
    let mut seen : RecordsPre? = None
    records_put(source, "completion_ready", 1, 0UL)
    records_put(source, "memory_response_valid", 1, 0UL)
    for _ in 0..<128 {
      records_present(source, if pushed { None } else { Some(packets[5]) })
      source.settle()
      let current = records_pre(fixture, source)
      let _ = records_check(seen, current)
      let push = !pushed && records_output(source, "descriptor_ready") == 1UL
      assert_eq(records_output(source, "memory_request_valid"), 0UL)
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
      dependency_conjunction_correspondence_tick(observer, source)
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
    records_present(source, None)
    records_put(source, "completion_ready", 1, 1UL)
    if epoch == 0 {
      let saved = dependency_conjunction_correspondence_storage(
        observer, source,
      )
      assert_true(saved.any(value => value.is_fully_known()))
      records_put(source, "reset", 1, 1UL)
      source.settle()
      for
        name in [
          "descriptor_ready", "completion_valid", "memory_request_valid", "memory_response_ready",
        ] {
        assert_eq(records_output(source, name), 0UL)
      }
      dependency_conjunction_correspondence_tick(observer, source)
      assert_eq(
        dependency_conjunction_correspondence_storage(observer, source),
        saved,
      )
      records_put(source, "reset", 1, 0UL)
      source.settle()
      assert_eq(records_observe(fixture, source, NextTicket), 0UL)
      assert_eq(records_observe(fixture, source, RetirementOccupancy), 0UL)
      assert_eq(records_output(source, "completion_valid"), 0UL)
      for entry in 0..<3 {
        assert_eq(records_observe(fixture, source, EntryValid(entry)), 0UL)
      }
    } else {
      source.settle()
      let released = records_pre(fixture, source)
      let (_, _, release_edge) = records_check(seen, released)
      assert_true(release_edge)
      dependency_conjunction_correspondence_tick(observer, source)
      assert_eq(records_observe(fixture, source, RetirementOccupancy), 0UL)
      assert_eq(records_output(source, "completion_valid"), 0UL)
    }
  }
  assert_false(observer.pre_pending)
  assert_eq(observer.pre_samples, observer.post_samples)
  assert_true(observer.pre_samples > 32)
  assert_eq(observer.accepts, [2, 1, 1])
  assert_true(observer.terminals.all(count => count > 0))
  assert_eq(observer.inner_accepts, 1)
  assert_eq(observer.reset_edges, 2)
  assert_eq(observer.nonrising_events, 3)
  assert_true(
    observer.unknown_roots > 0 &&
    observer.unknown_cuts > 0 &&
    observer.unknown_reads > 0 &&
    observer.unknown_cells > 0,
  )
  println(
    "DEPENDENCY-CONJUNCTION-NATIVE: pre=\{observer.pre_samples}; post=\{observer.post_samples}; accepts=\{Repr(observer.accepts)}; terminals=\{Repr(observer.terminals)}; inner=\{observer.inner_accepts}; nonrising=\{observer.nonrising_events}; reset=\{observer.reset_edges}; held=\{held_edges}; admitted=\{admitted}; retired=\{retired}; requests=\{requests}; acknowledgements=\{acknowledgements}; priority-witness=OPEN",
  )
}
