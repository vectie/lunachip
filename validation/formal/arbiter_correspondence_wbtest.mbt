///|
test "actual arbiter correspondence ties load store grant and holds a real contested Offer" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let source = @sim.Simulator::prepare(fixture.hardware())
  let observer = arbiter_correspondence_prepare(fixture)
  arbiter_correspondence_startup(observer, source)
  arbiter_transcript_setup(observer, source)
  let load_a1 = records_packet(0UL, 1UL, 2UL, 0UL, 128UL, 2UL)
  load_a1[3] = 1UL
  let packets = [load_a1, records_packet(3UL, 1UL, 1UL, 0UL, 256UL, 4UL)]
  let mut admitted = 0
  let mut completed = 0
  let mut requests = 4
  let mut pending : Int? = None
  let mut aligned_response = 0
  let mut stalled_edges = 0
  for _ in 0..<512 {
    records_present(
      source,
      if admitted < 2 {
        Some(packets[admitted])
      } else {
        None
      },
    )
    records_put(source, "memory_request_ready", 1, 1UL)
    records_put(source, "memory_response_valid", 1, 0UL)
    source.settle()
    if pending is Some(ordinal) {
      if ordinal != 4 ||
        records_observe(fixture, source, EngineAccept(2)) == 1UL {
        if ordinal == 4 {
          assert_eq(records_observe(fixture, source, EngineState(0)), 2UL)
          assert_eq(arbiter_correspondence_root(observer, source, "state"), 2UL)
        }
        arbiter_transcript_response(source, ordinal)
      }
    }
    source.settle()
    if records_output(source, "memory_request_valid") == 1UL &&
      arbiter_correspondence_root(observer, source, "owner") == 1UL &&
      stalled_edges < 3 {
      records_put(source, "memory_request_ready", 1, 0UL)
      assert_eq(
        arbiter_correspondence_boundary(observer, source, "reader_valid"),
        1UL,
      )
      assert_eq(
        arbiter_correspondence_boundary(observer, source, "engine_valid"),
        1UL,
      )
      stalled_edges += 1
    }
    source.settle()
    let push = admitted < 2 && records_output(source, "descriptor_ready") == 1UL
    let request = records_output(source, "memory_request_valid") == 1UL &&
      arbiter_correspondence_boundary(observer, source, "request_ready") == 1UL
    let response = arbiter_correspondence_event(
        observer, source, "response_accept",
      ) ==
      1UL
    let retire = records_output(source, "completion_valid") == 1UL
    if request {
      assert_eq(pending, None)
      arbiter_transcript_request(observer, source, requests)
    }
    if response {
      guard pending is Some(ordinal) else {
        fail("response outside fixed transcript")
      }
      assert_eq(
        arbiter_correspondence_root(observer, source, "expected_tag"),
        ordinal.to_uint64(),
      )
      assert_eq(
        arbiter_correspondence_event(observer, source, "route_response_fault"),
        0UL,
      )
      if ordinal == 4 {
        // Both witnesses are sampled from this same settled PRE edge.
        assert_eq(records_observe(fixture, source, EngineAccept(2)), 1UL)
        assert_eq(records_observe(fixture, source, EngineState(0)), 2UL)
        assert_eq(arbiter_correspondence_root(observer, source, "state"), 2UL)
        aligned_response += 1
      }
    }
    if arbiter_correspondence_event(observer, source, "grant") == 1UL &&
      arbiter_correspondence_boundary(observer, source, "reader_valid") == 1UL &&
      arbiter_correspondence_boundary(observer, source, "engine_valid") == 1UL {
      assert_eq(
        arbiter_correspondence_root(observer, source, "preference"),
        1UL,
      )
      assert_eq(
        arbiter_correspondence_event(observer, source, "choose_engine"),
        1UL,
      )
    }
    if retire {
      assert_true(completed < 2)
      assert_eq(records_output(source, "completion_id"), 73UL)
      assert_eq(records_output(source, "completion_fault"), 0UL)
      assert_eq(
        records_output(source, "completion_bytes_completed"),
        if completed == 0 {
          2UL
        } else {
          4UL
        },
      )
      assert_eq(records_output(source, "completion_fault_address"), 0UL)
    }
    arbiter_correspondence_tick(observer, source)
    if push {
      admitted += 1
    }
    if response {
      pending = None
    }
    if request {
      pending = Some(requests)
      requests += 1
    }
    if retire {
      completed += 1
    }
    if completed == 2 {
      break
    }
  }
  assert_eq(admitted, 2)
  assert_eq(completed, 2)
  assert_eq(requests, 7)
  assert_eq(pending, None)
  assert_eq(aligned_response, 1)
  assert_eq(stalled_edges, 3)
  assert_true(observer.tied_grants > 0)
  assert_true(observer.stalled_offers >= 3 && observer.stalled_competitors >= 3)
  assert_eq(observer.requests, [6, 1])
  assert_eq(observer.responses, [6, 1])
  assert_eq(observer.malformed_responses, 0)
  assert_eq(observer.poisoned_edges, 0)
  assert_eq(observer.reset_edges, 1)
  arbiter_correspondence_finish(observer)
}

///|
test "actual arbiter correspondence consumes malformed tag poisons then resets and recovers" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let source = @sim.Simulator::prepare(fixture.hardware())
  let observer = arbiter_correspondence_prepare(fixture)
  arbiter_correspondence_startup(observer, source)
  let packet = records_packet(0UL, 1UL, 2UL, 0UL, 32UL, 2UL)
  let mut admitted = false
  let mut accepted = false
  let mut poisoned = false
  for _ in 0..<128 {
    records_present(source, if admitted { None } else { Some(packet) })
    records_put(
      source,
      "memory_response_valid",
      1,
      if accepted {
        1UL
      } else {
        0UL
      },
    )
    if accepted {
      records_put(source, "memory_response_tag", 32, 1UL) // actual expected global tag is zero
      records_put(source, "memory_response_data", 32, 2UL)
      records_put(source, "memory_response_fault", 2, 0UL)
    }
    source.settle()
    let push = !admitted && records_output(source, "descriptor_ready") == 1UL
    let request = records_output(source, "memory_request_valid") == 1UL
    let response = arbiter_correspondence_event(
        observer, source, "response_accept",
      ) ==
      1UL
    if request {
      assert_false(accepted)
      arbiter_transcript_request(observer, source, 0)
    }
    if response {
      assert_true(accepted)
      assert_eq(arbiter_correspondence_root(observer, source, "state"), 2UL)
      assert_eq(
        arbiter_correspondence_root(observer, source, "expected_tag"),
        0UL,
      )
      assert_eq(arbiter_correspondence_root(observer, source, "local_tag"), 0UL)
      assert_eq(
        arbiter_correspondence_event(observer, source, "route_response_fault"),
        2UL,
      )
      assert_eq(
        arbiter_correspondence_event(observer, source, "reader_response_valid"),
        1UL,
      )
      assert_eq(
        arbiter_correspondence_event(observer, source, "engine_response_valid"),
        0UL,
      )
    }
    arbiter_correspondence_tick(observer, source)
    if push {
      admitted = true
    }
    if request {
      accepted = true
    }
    if response {
      poisoned = true
      break
    }
  }
  assert_true(admitted && accepted && poisoned)
  records_present(source, None)
  // Changing unsolicited host payload cannot escape absorbing poison.
  for edge in 0..<4 {
    records_put(source, "memory_response_tag", 32, 70UL + edge.to_uint64())
    records_put(source, "memory_response_data", 32, 99UL + edge.to_uint64())
    source.settle()
    assert_eq(arbiter_correspondence_root(observer, source, "state"), 3UL)
    assert_eq(records_output(source, "transport_halted"), 1UL)
    assert_eq(records_output(source, "memory_request_valid"), 0UL)
    assert_eq(records_output(source, "memory_response_ready"), 0UL)
    arbiter_correspondence_tick(observer, source)
  }
  assert_eq(observer.malformed_responses, 1)
  assert_true(observer.poisoned_edges >= 4)
  records_put(source, "reset", 1, 1UL)
  arbiter_correspondence_tick(observer, source)
  records_put(source, "reset", 1, 0UL)
  records_put(source, "memory_response_valid", 1, 0UL)
  source.settle()
  assert_eq(arbiter_correspondence_root(observer, source, "state"), 0UL)
  assert_eq(records_output(source, "transport_halted"), 0UL)
  let fresh = records_packet(1UL, 2UL, 1UL, 0UL, 64UL, 1UL)
  let mut fresh_admitted = false
  let mut fresh_requests = 0
  let mut pending : Int? = None
  let mut fresh_completed = false
  for _ in 0..<128 {
    records_present(source, if fresh_admitted { None } else { Some(fresh) })
    records_put(source, "memory_response_valid", 1, 0UL)
    if pending is Some(index) {
      records_put(source, "memory_response_valid", 1, 1UL)
      records_put(source, "memory_response_tag", 32, index.to_uint64())
      records_put(source, "memory_response_fault", 2, 0UL)
      records_put(source, "memory_response_data", 32, [5UL, 7UL][index])
    }
    source.settle()
    let push = !fresh_admitted &&
      records_output(source, "descriptor_ready") == 1UL
    let request = records_output(source, "memory_request_valid") == 1UL
    let response = arbiter_correspondence_event(
        observer, source, "response_accept",
      ) ==
      1UL
    let retire = records_output(source, "completion_valid") == 1UL
    if request {
      assert_eq(pending, None)
      assert_true(fresh_requests < 2)
      assert_eq(
        records_output(source, "memory_request_address"),
        [64UL, 65UL][fresh_requests],
      )
      assert_eq(
        records_output(source, "memory_request_tag"),
        fresh_requests.to_uint64(),
      )
      assert_eq(records_output(source, "memory_request_write"), 0UL)
      assert_eq(records_output(source, "memory_request_bytes"), 1UL)
      assert_eq(records_output(source, "memory_request_mask"), 1UL)
      assert_eq(records_output(source, "memory_request_data"), 0UL)
      assert_eq(
        arbiter_correspondence_root(observer, source, "local_tag"),
        fresh_requests.to_uint64(),
      )
    }
    if retire {
      assert_eq(records_output(source, "completion_id"), 73UL)
      assert_eq(records_output(source, "completion_fault"), 0UL)
      assert_eq(records_output(source, "completion_bytes_completed"), 2UL)
      assert_eq(records_output(source, "completion_fault_address"), 0UL)
    }
    arbiter_correspondence_tick(observer, source)
    if push {
      fresh_admitted = true
    }
    if response {
      pending = None
    }
    if request {
      pending = Some(fresh_requests)
      fresh_requests += 1
    }
    if retire {
      fresh_completed = true
      break
    }
  }
  assert_true(fresh_admitted && fresh_completed)
  assert_eq(fresh_requests, 2)
  assert_eq(pending, None)
  assert_eq(observer.requests, [3, 0])
  assert_eq(observer.responses, [3, 0])
  assert_eq(observer.reset_edges, 2)
  assert_eq(observer.malformed_responses, 1)
  assert_eq(records_output(source, "transport_halted"), 0UL)
  arbiter_correspondence_finish(observer)
}
