///|
test "queued tile ordinary memory failure does not cancel later accepted descriptors" {
  let host = PortableHost::new()
  host.fail_at = 0
  let simulator = frontend_prepare(3)
  frontend_enqueue(
    host,
    simulator,
    frontend_descriptor(0UL, 40UL, 1UL, 1UL, 0UL, 32UL, 1UL),
  )
  frontend_enqueue(
    host,
    simulator,
    frontend_descriptor(2UL, 41UL, 1UL, 1UL, 1UL, 0UL, 0UL),
  )
  frontend_enqueue(
    host,
    simulator,
    frontend_descriptor(4UL, 42UL, 0UL, 0UL, 0UL, 0UL, 0UL),
  )
  frontend_completion(host, simulator, 40UL, 9UL, 0UL, address=32UL)
  assert_eq(execute_read(simulator, "halted"), 0UL)
  frontend_ack(host, simulator)
  frontend_completion(host, simulator, 41UL, 4UL, 0UL)
  frontend_ack(host, simulator)
  frontend_completion(host, simulator, 42UL, 0UL, 0UL)
  frontend_ack(host, simulator)
  assert_eq(host.requests.length(), 1)
  assert_eq(execute_read(simulator, "descriptor_ready"), 1UL)
}

///|
test "queued tile protocol fault stops admission and drains accepted descriptors as unavailable" {
  let host = PortableHost::new()
  host.latency = 100
  host.protocol_at = 0
  host.memory[32UL] = 2
  let simulator = frontend_prepare(3)
  frontend_enqueue(
    host,
    simulator,
    frontend_descriptor(0UL, 10UL, 1UL, 1UL, 0UL, 32UL, 1UL),
  )
  for _ in 0..<40 {
    if host.pending is Some(_) {
      break
    }
    host.tick(simulator)
  }
  assert_true(host.pending is Some(_))
  frontend_enqueue(host, simulator, [11UL << 32, 0xffffffffffffffffUL, 0UL, 1UL])
  frontend_enqueue(
    host,
    simulator,
    frontend_descriptor(4UL, 12UL, 0UL, 0UL, 0UL, 0UL, 0UL),
  )
  // A descriptor accepted on the edge consuming the corrupt response also
  // belongs to the cancelled prefix, rather than disappearing or executing.
  let pending = host.pending.unwrap()
  host.pending = Some({ ..pending, remaining: 0, })
  frontend_present(
    simulator,
    frontend_descriptor(4UL, 13UL, 0UL, 0UL, 0UL, 0UL, 0UL),
  )
  assert_eq(execute_read(simulator, "descriptor_ready"), 1UL)
  host.tick(simulator)
  portable_put(simulator, "descriptor_valid", 1, 0UL)
  assert_eq(execute_read(simulator, "descriptor_ready"), 0UL)
  frontend_completion(host, simulator, 10UL, 10UL, 0UL, address=32UL)
  assert_eq(execute_read(simulator, "halted"), 1UL)
  assert_eq(execute_read(simulator, "descriptor_ready"), 0UL)
  frontend_ack(host, simulator)
  for id in 11..<14 {
    frontend_completion(host, simulator, id.to_uint64(), 15UL, 0UL)
    frontend_ack(host, simulator)
  }
  frontend_present(
    simulator,
    frontend_descriptor(4UL, 14UL, 0UL, 0UL, 0UL, 0UL, 0UL),
  )
  for _ in 0..<8 {
    host.tick(simulator)
    assert_eq(execute_read(simulator, "descriptor_ready"), 0UL)
    assert_eq(execute_read(simulator, "completion_valid"), 0UL)
    assert_eq(execute_read(simulator, "memory_request_valid"), 0UL)
  }
  assert_eq(host.requests.length(), 1)
  frontend_reset_barrier(host, simulator)
  frontend_enqueue(
    host,
    simulator,
    frontend_descriptor(4UL, 15UL, 0UL, 0UL, 0UL, 0UL, 0UL),
  )
  frontend_completion(host, simulator, 15UL, 0UL, 0UL)
  frontend_ack(host, simulator)
}

///|
test "queued tile reset suppresses offered descriptor response and completion handshakes" {
  let host = PortableHost::new()
  let simulator = frontend_prepare(3)
  frontend_enqueue(
    host,
    simulator,
    frontend_descriptor(4UL, 30UL, 0UL, 0UL, 0UL, 0UL, 0UL),
  )
  frontend_completion(host, simulator, 30UL, 0UL, 0UL)
  frontend_enqueue(
    host,
    simulator,
    frontend_descriptor(4UL, 31UL, 0UL, 0UL, 0UL, 0UL, 0UL),
  )
  frontend_present(
    simulator,
    frontend_descriptor(0UL, 32UL, 1UL, 1UL, 0UL, 32UL, 1UL),
  )
  portable_put(simulator, "memory_response_valid", 1, 1UL)
  portable_put(simulator, "completion_ready", 1, 1UL)
  portable_put(simulator, "reset", 1, 1UL)
  for
    name in [
      "descriptor_ready", "memory_response_ready", "completion_valid", "memory_request_valid",
    ] {
    assert_eq(execute_read(simulator, name), 0UL)
  }
  simulator.rising_edge("clock")
  portable_put(simulator, "descriptor_valid", 1, 0UL)
  portable_put(simulator, "memory_response_valid", 1, 0UL)
  portable_put(simulator, "completion_ready", 1, 0UL)
  portable_put(simulator, "reset", 1, 0UL)
  for _ in 0..<8 {
    host.tick(simulator)
    assert_eq(execute_read(simulator, "completion_valid"), 0UL)
    assert_eq(execute_read(simulator, "queue_occupancy"), 0UL)
  }
  assert_eq(host.requests.length(), 0)
}

///|
test "queued tile joint reset aborts an accepted transport command queue and held completion" {
  for pending_request in [false, true] {
    let host = PortableHost::new()
    host.latency = 100
    let simulator = frontend_prepare(3)
    frontend_enqueue(
      host,
      simulator,
      frontend_descriptor(
        if pending_request {
          0UL
        } else {
          4UL
        },
        20UL,
        if pending_request {
          1UL
        } else {
          0UL
        },
        if pending_request {
          1UL
        } else {
          0UL
        },
        0UL,
        if pending_request {
          32UL
        } else {
          0UL
        },
        if pending_request {
          1UL
        } else {
          0UL
        },
      ),
    )
    frontend_enqueue(
      host,
      simulator,
      frontend_descriptor(4UL, 21UL, 0UL, 0UL, 0UL, 0UL, 0UL),
    )
    for _ in 0..<40 {
      if (pending_request && host.pending is Some(_)) ||
        (!pending_request && execute_read(simulator, "completion_valid") == 1UL) {
        break
      }
      host.tick(simulator)
    }
    if pending_request {
      assert_true(host.pending is Some(_))
    } else {
      assert_eq(execute_read(simulator, "completion_valid"), 1UL)
    }
    frontend_reset_barrier(host, simulator)
    frontend_enqueue(
      host,
      simulator,
      frontend_descriptor(2UL, 22UL, 1UL, 1UL, 1UL, 0UL, 0UL),
    )
    frontend_completion(host, simulator, 22UL, 4UL, 0UL)
    frontend_ack(host, simulator)
    frontend_enqueue(
      host,
      simulator,
      frontend_descriptor(4UL, 23UL, 0UL, 0UL, 0UL, 0UL, 0UL),
    )
    frontend_completion(host, simulator, 23UL, 0UL, 0UL)
    frontend_ack(host, simulator)
    assert_eq(host.requests.length(), 0)
  }
}
