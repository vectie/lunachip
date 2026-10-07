///|
test "actual arbiter matching remote fault routes without poison and recovers without reset" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let source = @sim.Simulator::prepare(fixture.hardware())
  let observer = arbiter_correspondence_prepare(fixture)
  arbiter_correspondence_startup(observer, source)
  arbiter_faults_offer(observer, source)
  arbiter_faults_accept_offer(observer, source)
  arbiter_faults_response(source, 0UL, 1UL, 2UL)
  assert_eq(arbiter_correspondence_root(observer, source, "state"), 2UL)
  assert_eq(arbiter_correspondence_root(observer, source, "expected_tag"), 0UL)
  assert_eq(arbiter_correspondence_root(observer, source, "local_tag"), 0UL)
  assert_eq(
    arbiter_correspondence_event(observer, source, "response_accept"),
    1UL,
  )
  assert_eq(
    arbiter_correspondence_event(observer, source, "reader_response_valid"),
    1UL,
  )
  assert_eq(
    arbiter_correspondence_event(observer, source, "engine_response_valid"),
    0UL,
  )
  assert_eq(
    arbiter_correspondence_event(observer, source, "route_response_fault"),
    1UL,
  )
  assert_eq(
    arbiter_correspondence_event(observer, source, "malformed_controller"),
    0UL,
  )
  arbiter_correspondence_tick(observer, source)
  assert_eq(observer.responses, [1, 0])
  assert_eq(arbiter_correspondence_root(observer, source, "state"), 0UL)
  assert_eq(records_output(source, "transport_halted"), 0UL)
  records_put(source, "memory_response_valid", 1, 0UL)
  let mut remote_retired = false
  for _ in 0..<128 {
    source.settle()
    let retire = records_output(source, "completion_valid") == 1UL
    assert_eq(records_output(source, "memory_request_valid"), 0UL)
    assert_eq(records_output(source, "transport_halted"), 0UL)
    if retire {
      assert_eq(records_output(source, "completion_id"), 73UL)
      assert_eq(records_output(source, "completion_fault"), 9UL)
      assert_eq(records_output(source, "completion_bytes_completed"), 0UL)
      assert_eq(records_output(source, "completion_fault_address"), 32UL)
    }
    arbiter_correspondence_tick(observer, source)
    if retire {
      remote_retired = true
      break
    }
  }
  assert_true(remote_retired)
  arbiter_faults_matching_recovery(observer, source, 1UL)
  assert_eq(observer.requests, [3, 0])
  assert_eq(observer.responses, [3, 0])
  assert_eq(observer.reset_edges, 1)
  assert_eq(observer.malformed_responses, 0)
  assert_eq(observer.poisoned_edges, 0)
  arbiter_correspondence_finish(observer)
}

///|
test "actual arbiter matching reserved statuses poison only on real response consumption" {
  for status in [2UL, 3UL] {
    let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
    let source = @sim.Simulator::prepare(fixture.hardware())
    let observer = arbiter_correspondence_prepare(fixture)
    arbiter_correspondence_startup(observer, source)
    arbiter_faults_offer(observer, source)
    // The same reserved response is unsolicited during a real stalled Offer.
    arbiter_faults_response(source, 0UL, status, 2UL)
    let mut unconsumed = 0
    for _ in 0..<2 {
      assert_eq(arbiter_correspondence_root(observer, source, "state"), 1UL)
      arbiter_faults_request(observer, source, 32UL, 0UL)
      assert_eq(
        arbiter_correspondence_event(observer, source, "malformed_controller"),
        1UL,
      )
      assert_eq(
        arbiter_correspondence_event(observer, source, "response_accept"),
        0UL,
      )
      assert_eq(records_output(source, "memory_response_ready"), 0UL)
      assert_eq(records_output(source, "transport_halted"), 0UL)
      arbiter_correspondence_tick(observer, source)
      unconsumed += 1
    }
    arbiter_faults_accept_offer(observer, source)
    // Reserved status alone, with no valid response, cannot enter poison.
    for _ in 0..<2 {
      assert_eq(arbiter_correspondence_root(observer, source, "state"), 2UL)
      assert_eq(
        arbiter_correspondence_root(observer, source, "expected_tag"),
        0UL,
      )
      assert_eq(
        arbiter_correspondence_event(observer, source, "malformed_controller"),
        1UL,
      )
      assert_eq(
        arbiter_correspondence_event(observer, source, "response_accept"),
        0UL,
      )
      assert_eq(
        arbiter_correspondence_event(observer, source, "reader_response_valid"),
        0UL,
      )
      assert_eq(records_output(source, "transport_halted"), 0UL)
      arbiter_correspondence_tick(observer, source)
      unconsumed += 1
    }
    assert_eq(unconsumed, 4)
    assert_eq(observer.responses, [0, 0])
    assert_eq(observer.malformed_responses, 0)
    assert_eq(observer.poisoned_edges, 0)
    arbiter_faults_response(source, 0UL, status, 2UL)
    assert_eq(arbiter_correspondence_root(observer, source, "state"), 2UL)
    assert_eq(arbiter_correspondence_root(observer, source, "local_tag"), 0UL)
    assert_eq(
      arbiter_correspondence_event(observer, source, "response_accept"),
      1UL,
    )
    assert_eq(
      arbiter_correspondence_event(observer, source, "reader_response_valid"),
      1UL,
    )
    assert_eq(
      arbiter_correspondence_event(observer, source, "engine_response_valid"),
      0UL,
    )
    assert_eq(
      arbiter_correspondence_event(observer, source, "route_response_fault"),
      2UL,
    )
    arbiter_correspondence_tick(observer, source)
    assert_eq(arbiter_correspondence_root(observer, source, "state"), 3UL)
    assert_eq(observer.responses, [1, 0])
    assert_eq(observer.malformed_responses, 1)
    for _ in 0..<3 {
      assert_eq(records_output(source, "transport_halted"), 1UL)
      assert_eq(records_output(source, "memory_request_valid"), 0UL)
      assert_eq(records_output(source, "memory_response_ready"), 0UL)
      arbiter_correspondence_tick(observer, source)
    }
    assert_true(observer.poisoned_edges >= 3)
    arbiter_faults_joint_reset(observer, source)
    arbiter_faults_matching_recovery(observer, source, 0UL)
    assert_eq(observer.requests, [3, 0])
    assert_eq(observer.responses, [3, 0])
    assert_eq(observer.reset_edges, 2)
    assert_eq(observer.malformed_responses, 1)
    arbiter_correspondence_finish(observer)
  }
}
