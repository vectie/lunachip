///|
test "host ring data-owned malformed response completes fault10 before ordered cancellation" {
  for status in [0UL, 2UL] {
    let host = PortableHost::new()
    let simulator = host_ring_prepare(ring_depth=4)
    host.seed(32UL, 64UL, 1, 64, Array::makei(64, index => index - 32))
    host_ring_seed_descriptor(host, 0, host_ring_load(100U))
    host_ring_seed_descriptor(host, 1, host_ring_fence(101U))
    host_ring_seed_descriptor(host, 2, host_ring_fence(102U))
    host_ring_config(host, simulator)
    host_ring_publish(host, simulator, 3UL)
    for _ in 0..<30000 {
      if execute_read(simulator, "consumer_count") >= 2UL &&
        host.pending is Some(_) &&
        host_ring_last_address(host) < 96UL {
        break
      }
      host.tick(simulator)
    }
    assert_true(host.pending is Some(_))
    let address = host_ring_last_address(host)
    assert_true(address >= 32UL && address < 96UL)
    let progress = address - 32UL
    host_ring_corrupt_pending(host, status~)
    host.tick(simulator)
    host_ring_completion(host, simulator, 100UL, 10UL, progress, address~)
    assert_eq(execute_read(simulator, "transport_halted"), 1UL)
    assert_eq(execute_read(simulator, "transport_fault_address"), address)
    let accepted = execute_read(simulator, "consumer_count")
    assert_true(accepted >= 2UL && accepted <= 3UL)
    host_ring_ack(host, simulator)
    for index in 1..<accepted.to_int() {
      host_ring_completion(
        host,
        simulator,
        (100 + index).to_uint64(),
        15UL,
        0UL,
      )
      host_ring_ack(host, simulator)
    }
    let requests = host.requests.length()
    for _ in 0..<12 {
      host.tick(simulator)
      assert_eq(execute_read(simulator, "consumer_count"), accepted)
      assert_eq(execute_read(simulator, "completion_valid"), 0UL)
      assert_eq(execute_read(simulator, "memory_request_valid"), 0UL)
      assert_eq(host.requests.length(), requests)
    }
    host_ring_reset_barrier(host, simulator)
    host_ring_seed_descriptor(host, 0, host_ring_fence(110U))
    host_ring_config(host, simulator)
    host_ring_publish(host, simulator, 1UL)
    host_ring_completion(host, simulator, 110UL, 0UL, 0UL)
    host_ring_ack(host, simulator)
  }
}

///|
test "host ring reader-owned poison cancels incomplete data work with committed progress" {
  let host = PortableHost::new()
  let simulator = host_ring_prepare(ring_depth=4)
  host.seed(32UL, 64UL, 1, 64, Array::makei(64, index => index - 32))
  host_ring_seed_descriptor(host, 0, host_ring_load(200U))
  host_ring_seed_descriptor(host, 1, host_ring_fence(201U))
  host_ring_config(host, simulator)
  host_ring_publish(host, simulator, 2UL)
  for _ in 0..<30000 {
    if host.pending is Some(_) &&
      host_ring_data_reads(host) > 0 &&
      host_ring_last_address(host) >= 1056UL &&
      host_ring_last_address(host) < 1088UL {
      break
    }
    host.tick(simulator)
  }
  assert_true(host.pending is Some(_))
  let address = host_ring_last_address(host)
  assert_true(address >= 1056UL && address < 1088UL)
  let progress = host_ring_data_reads(host).to_uint64()
  assert_true(progress > 0UL && progress < 64UL)
  assert_eq(execute_read(simulator, "consumer_count"), 1UL)
  host_ring_corrupt_pending(host)
  host.tick(simulator)
  host_ring_completion(host, simulator, 200UL, 15UL, progress)
  assert_eq(execute_read(simulator, "ring_fault_valid"), 1UL)
  assert_eq(execute_read(simulator, "ring_fault_code"), 5UL)
  assert_eq(execute_read(simulator, "ring_fault_address"), address)
  assert_eq(execute_read(simulator, "transport_halted"), 1UL)
  assert_eq(execute_read(simulator, "transport_fault_address"), address)
  host_ring_ack(host, simulator)
  let requests = host.requests.length()
  for _ in 0..<12 {
    host.tick(simulator)
    assert_eq(execute_read(simulator, "consumer_count"), 1UL)
    assert_eq(execute_read(simulator, "completion_valid"), 0UL)
    assert_eq(host.requests.length(), requests)
  }
}

///|
test "host ring preserves already held completion when an unrelated reader response poisons" {
  let host = PortableHost::new()
  let simulator = host_ring_prepare(ring_depth=4)
  host_ring_seed_descriptor(host, 0, host_ring_fence(300U))
  host_ring_seed_descriptor(host, 1, host_ring_fence(301U))
  host_ring_config(host, simulator)
  host_ring_publish(host, simulator, 2UL)
  host_ring_completion(host, simulator, 300UL, 0UL, 0UL)
  for _ in 0..<30000 {
    if host.pending is Some(_) && host_ring_last_address(host) >= 1056UL {
      break
    }
    host.tick(simulator)
  }
  assert_true(host.pending is Some(_))
  let address = host_ring_last_address(host)
  assert_true(address >= 1056UL && address < 1088UL)
  host_ring_corrupt_pending(host)
  host.tick(simulator)
  for _ in 0..<12 {
    assert_eq(execute_read(simulator, "completion_valid"), 1UL)
    assert_eq(host_ring_completion_payload(simulator), [300UL, 0UL, 0UL, 0UL])
    host.tick(simulator)
  }
  assert_eq(execute_read(simulator, "transport_halted"), 1UL)
  assert_eq(execute_read(simulator, "ring_fault_code"), 5UL)
  assert_eq(execute_read(simulator, "ring_fault_address"), address)
  host_ring_ack(host, simulator)
  for _ in 0..<12 {
    host.tick(simulator)
    assert_eq(execute_read(simulator, "completion_valid"), 0UL)
    assert_eq(execute_read(simulator, "consumer_count"), 1UL)
  }
}

///|
test "host ring matching remote fetch fault stops reader but accepted data command still completes" {
  let host = PortableHost::new()
  let simulator = host_ring_prepare(ring_depth=4)
  host.seed(32UL, 64UL, 1, 64, Array::makei(64, index => index - 32))
  host_ring_seed_descriptor(host, 0, host_ring_load(400U))
  host_ring_seed_descriptor(host, 1, host_ring_fence(401U))
  host_ring_config(host, simulator)
  host_ring_publish(host, simulator, 2UL)
  for _ in 0..<30000 {
    if host.pending is Some(_) &&
      host_ring_data_reads(host) > 0 &&
      host_ring_last_address(host) >= 1056UL &&
      host_ring_last_address(host) < 1088UL {
      break
    }
    host.tick(simulator)
  }
  assert_true(host.pending is Some(_))
  let address = host_ring_last_address(host)
  assert_true(address >= 1056UL && address < 1088UL)
  let pending = host.pending.unwrap()
  host.pending = Some({ ..pending, remaining: 0, fault: 1UL, })
  host.tick(simulator)
  host_ring_completion(host, simulator, 400UL, 0UL, 64UL)
  assert_eq(execute_read(simulator, "ring_fault_valid"), 1UL)
  assert_eq(execute_read(simulator, "ring_fault_code"), 4UL)
  assert_eq(execute_read(simulator, "ring_fault_address"), address)
  assert_eq(execute_read(simulator, "transport_halted"), 0UL)
  assert_eq(execute_read(simulator, "consumer_count"), 1UL)
  assert_eq(host_ring_data_reads(host), 64)
  host_ring_ack(host, simulator)
  let requests = host.requests.length()
  for _ in 0..<12 {
    host.tick(simulator)
    assert_eq(execute_read(simulator, "completion_valid"), 0UL)
    assert_eq(host.requests.length(), requests)
  }
}
