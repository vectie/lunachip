///|
// Fixed LoadA0/LoadB0 transcripts only, not a host-memory model.
fn arbiter_faults_request(
  observer : ArbiterCorrespondence,
  source : @sim.Simulator,
  address : UInt64,
  tag : UInt64,
) -> Unit raise {
  assert_eq(records_output(source, "memory_request_valid"), 1UL)
  assert_eq(records_output(source, "memory_request_write"), 0UL)
  assert_eq(records_output(source, "memory_request_address"), address)
  assert_eq(records_output(source, "memory_request_bytes"), 1UL)
  assert_eq(records_output(source, "memory_request_mask"), 1UL)
  assert_eq(records_output(source, "memory_request_data"), 0UL)
  assert_eq(records_output(source, "memory_request_tag"), tag)
  assert_eq(arbiter_correspondence_root(observer, source, "owner"), 0UL)
  assert_eq(arbiter_correspondence_root(observer, source, "local_tag"), tag)
}

///|
fn arbiter_faults_offer(
  observer : ArbiterCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  let packet = records_packet(0UL, 1UL, 2UL, 0UL, 32UL, 2UL)
  let mut admitted = false
  let mut offered = false
  records_put(source, "memory_request_ready", 1, 0UL)
  records_put(source, "memory_response_valid", 1, 0UL)
  for _ in 0..<128 {
    records_present(source, if admitted { None } else { Some(packet) })
    source.settle()
    let push = !admitted && records_output(source, "descriptor_ready") == 1UL
    arbiter_correspondence_tick(observer, source)
    if push {
      admitted = true
    }
    if arbiter_correspondence_root(observer, source, "state") == 1UL {
      offered = true
      break
    }
  }
  assert_true(admitted && offered)
  records_present(source, None)
  source.settle()
  arbiter_faults_request(observer, source, 32UL, 0UL)
  assert_eq(
    arbiter_correspondence_event(observer, source, "request_accept"),
    0UL,
  )
  assert_eq(observer.requests, [0, 0])
}

///|
fn arbiter_faults_accept_offer(
  observer : ArbiterCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  records_put(source, "memory_response_valid", 1, 0UL)
  records_put(source, "memory_request_ready", 1, 1UL)
  source.settle()
  arbiter_faults_request(observer, source, 32UL, 0UL)
  assert_eq(
    arbiter_correspondence_event(observer, source, "request_accept"),
    1UL,
  )
  arbiter_correspondence_tick(observer, source)
  assert_eq(arbiter_correspondence_root(observer, source, "state"), 2UL)
  assert_eq(records_observe(observer.fixture, source, EngineState(0)), 2UL)
  assert_eq(arbiter_correspondence_root(observer, source, "expected_tag"), 0UL)
  assert_eq(observer.requests, [1, 0])
}

///|
fn arbiter_faults_response(
  source : @sim.Simulator,
  tag : UInt64,
  status : UInt64,
  data : UInt64,
) -> Unit raise {
  records_put(source, "memory_response_valid", 1, 1UL)
  records_put(source, "memory_response_tag", 32, tag)
  records_put(source, "memory_response_fault", 2, status)
  records_put(source, "memory_response_data", 32, data)
  source.settle()
}

///|
fn arbiter_faults_joint_reset(
  observer : ArbiterCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  records_present(source, None)
  records_put(source, "reset", 1, 1UL)
  records_put(source, "memory_request_ready", 1, 1UL)
  arbiter_faults_response(source, 0UL, 0UL, 2UL)
  for
    event in [
      "offer", "grant", "request_accept", "response_ready", "response_accept", "reader_request_ready",
      "engine_request_ready", "reader_response_valid", "engine_response_valid",
    ] {
    assert_eq(arbiter_correspondence_event(observer, source, event), 0UL)
  }
  assert_eq(records_output(source, "memory_request_valid"), 0UL)
  assert_eq(records_output(source, "memory_response_ready"), 0UL)
  arbiter_correspondence_tick(observer, source)
  for root in observer.sequential.probe.roots {
    assert_eq(source.value(root.node).to_uint64(), 0UL)
  }
  // Flush the old host response before the public reset is deasserted.
  records_put(source, "memory_response_valid", 1, 0UL)
  records_put(source, "memory_response_fault", 2, 0UL)
  records_put(source, "reset", 1, 0UL)
  source.settle()
  assert_eq(arbiter_correspondence_root(observer, source, "state"), 0UL)
  assert_eq(records_output(source, "transport_halted"), 0UL)
}

///|
fn arbiter_faults_matching_recovery(
  observer : ArbiterCorrespondence,
  source : @sim.Simulator,
  start_tag : UInt64,
) -> Unit raise {
  let packet = records_packet(1UL, 2UL, 1UL, 0UL, 64UL, 1UL)
  let mut admitted = false
  let mut requests = 0
  let mut responses = 0
  let mut pending : Int? = None
  let mut completed = false
  for _ in 0..<128 {
    records_present(source, if admitted { None } else { Some(packet) })
    records_put(source, "memory_response_valid", 1, 0UL)
    if pending is Some(index) {
      arbiter_faults_response(
        source,
        start_tag + index.to_uint64(),
        0UL,
        [5UL, 7UL][index],
      )
    }
    source.settle()
    let push = !admitted && records_output(source, "descriptor_ready") == 1UL
    let request = arbiter_correspondence_event(
        observer, source, "request_accept",
      ) ==
      1UL
    let response = arbiter_correspondence_event(
        observer, source, "response_accept",
      ) ==
      1UL
    let retire = records_output(source, "completion_valid") == 1UL
    if request {
      assert_eq(pending, None)
      assert_true(requests < 2)
      arbiter_faults_request(
        observer,
        source,
        [64UL, 65UL][requests],
        start_tag + requests.to_uint64(),
      )
    }
    if response {
      guard pending is Some(index) else {
        fail("matching recovery response without fixed request")
      }
      assert_eq(
        arbiter_correspondence_root(observer, source, "expected_tag"),
        start_tag + index.to_uint64(),
      )
      assert_eq(
        arbiter_correspondence_root(observer, source, "local_tag"),
        start_tag + index.to_uint64(),
      )
      assert_eq(
        arbiter_correspondence_event(observer, source, "route_response_fault"),
        0UL,
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
        arbiter_correspondence_event(observer, source, "malformed_controller"),
        0UL,
      )
      responses += 1
    }
    if retire {
      assert_eq(records_output(source, "completion_id"), 73UL)
      assert_eq(records_output(source, "completion_fault"), 0UL)
      assert_eq(records_output(source, "completion_bytes_completed"), 2UL)
      assert_eq(records_output(source, "completion_fault_address"), 0UL)
    }
    assert_eq(records_output(source, "transport_halted"), 0UL)
    arbiter_correspondence_tick(observer, source)
    if push {
      admitted = true
    }
    if response {
      pending = None
    }
    if request {
      pending = Some(requests)
      requests += 1
    }
    if retire {
      completed = true
      break
    }
  }
  assert_true(admitted && completed)
  assert_eq(requests, 2)
  assert_eq(responses, 2)
  assert_eq(pending, None)
  records_present(source, None)
  records_put(source, "memory_response_valid", 1, 0UL)
}
