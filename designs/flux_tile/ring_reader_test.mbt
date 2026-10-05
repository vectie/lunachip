///|
test "ring reader fetches exact arbitrary packets through every depth and UInt32 physical wrap" {
  for depth in [2, 4, 8, 16] {
    let host = PortableHost::new()
    let simulator = ring_prepare(depth)
    let origin = 0xfffffffeUL
    ring_config(host, simulator, 1024UL, origin)
    assert_eq(execute_read(simulator, "configured"), 1UL)
    assert_eq(execute_read(simulator, "producer_count"), origin)
    assert_eq(execute_read(simulator, "consumer_count"), origin)
    for _ in 0..<5 {
      host.tick(simulator)
    }
    assert_eq(host.requests.length(), 0)
    // Unchanged producer is a legal publication, not an underflow or fault.
    ring_publish(host, simulator, origin)
    assert_eq(execute_read(simulator, "fault_valid"), 0UL)
    for offset in 0..<(depth + 2) {
      let consumer = (origin + offset.to_uint64()) & 0xffffffffUL
      let slot = consumer & (depth - 1).to_uint64()
      let address = 1024UL + slot * 32UL
      let lanes = ring_lanes(offset)
      ring_seed(host, address, lanes)
      ring_publish(host, simulator, (consumer + 1UL) & 0xffffffffUL)
      ring_packet(host, simulator, lanes, consumer)
      let start = offset * 32
      assert_eq(host.requests.length(), start + 32)
      for byte in 0..<32 {
        assert_eq(host.requests[start + byte][1], address + byte.to_uint64())
      }
      ring_ack(host, simulator, consumer)
    }
    let requests = host.requests.length()
    for _ in 0..<8 {
      host.tick(simulator)
      assert_eq(execute_read(simulator, "descriptor_valid"), 0UL)
      assert_eq(execute_read(simulator, "fault_valid"), 0UL)
    }
    assert_eq(host.requests.length(), requests)
  }
}

///|
test "ring reader publication stalls cannot disturb request or held packet handshakes" {
  let host = PortableHost::new()
  host.latency = 0
  let simulator = ring_prepare(2)
  let first = ring_lanes(20)
  let second = ring_lanes(21)
  ring_seed(host, 1024UL, first)
  ring_seed(host, 1056UL, second)
  ring_config(host, simulator, 1024UL, 0UL)
  ring_publish(host, simulator, 1UL)
  portable_put(simulator, "memory_request_ready", 1, 0UL)
  for _ in 0..<8 {
    if execute_read(simulator, "memory_request_valid") == 1UL {
      break
    }
    simulator.rising_edge("clock")
  }
  assert_eq(execute_read(simulator, "memory_request_valid"), 1UL)
  let payload = ["write", "address", "bytes", "mask", "data", "tag"].map(field => {
    execute_read(simulator, "memory_request_" + field)
  })
  portable_put(simulator, "publish_producer", 32, 2UL)
  portable_put(simulator, "publish_valid", 1, 1UL)
  for _ in 0..<4 {
    assert_eq(execute_read(simulator, "publish_ready"), 0UL)
    assert_eq(execute_read(simulator, "producer_count"), 1UL)
    assert_eq(
      ["write", "address", "bytes", "mask", "data", "tag"].map(field => {
        execute_read(simulator, "memory_request_" + field)
      }),
      payload,
    )
    simulator.rising_edge("clock")
  }
  ring_packet(host, simulator, first, 0UL)
  assert_eq(execute_read(simulator, "producer_count"), 1UL)
  // Publication becomes ready only once this packet is itself ready to drain.
  portable_put(simulator, "descriptor_ready", 1, 1UL)
  assert_eq(execute_read(simulator, "publish_ready"), 1UL)
  host.tick(simulator)
  portable_put(simulator, "descriptor_ready", 1, 0UL)
  portable_put(simulator, "publish_valid", 1, 0UL)
  assert_eq(execute_read(simulator, "consumer_count"), 1UL)
  assert_eq(execute_read(simulator, "producer_count"), 2UL)
  ring_packet(host, simulator, second, 1UL)
  ring_ack(host, simulator, 1UL)
}

///|
test "ring reader accepts full publication but grants no same-edge free credit" {
  for candidate in [10UL, 12UL] {
    let host = PortableHost::new()
    let simulator = ring_prepare(2)
    let origin = 9UL
    let lanes = ring_lanes(30)
    ring_seed(host, 1056UL, lanes)
    ring_config(host, simulator, 1024UL, origin)
    ring_publish(host, simulator, 11UL)
    assert_eq(execute_read(simulator, "producer_count"), 11UL)
    ring_packet(host, simulator, lanes, origin)
    portable_put(simulator, "descriptor_ready", 1, 1UL)
    // 10 moves backwards from producer despite fitting consumer capacity;
    // 12 moves forward but fits only after this edge's packet retirement.
    portable_put(simulator, "publish_producer", 32, candidate)
    portable_put(simulator, "publish_valid", 1, 1UL)
    assert_eq(execute_read(simulator, "publish_ready"), 1UL)
    host.tick(simulator)
    portable_put(simulator, "descriptor_ready", 1, 0UL)
    portable_put(simulator, "publish_valid", 1, 0UL)
    ring_fault(host, simulator, 3UL, 0UL, 1UL)
    assert_eq(execute_read(simulator, "consumer_count"), 10UL)
    assert_eq(execute_read(simulator, "producer_count"), 11UL)
    assert_eq(host.requests.length(), 32)
  }
}

///|
test "ring reader drains a full published ring without changing its producer sequence" {
  for depth in [2, 4, 8, 16] {
    let host = PortableHost::new()
    let simulator = ring_prepare(depth)
    for slot in 0..<depth {
      ring_seed(host, 1024UL + slot.to_uint64() * 32UL, ring_lanes(slot + 80))
    }
    ring_config(host, simulator, 1024UL, 0UL)
    ring_publish(host, simulator, depth.to_uint64())
    for consumer in 0..<depth {
      ring_packet(
        host,
        simulator,
        ring_lanes(consumer + 80),
        consumer.to_uint64(),
      )
      assert_eq(execute_read(simulator, "producer_count"), depth.to_uint64())
      assert_eq(host.requests.length(), (consumer + 1) * 32)
      ring_ack(host, simulator, consumer.to_uint64())
    }
    for _ in 0..<4 {
      host.tick(simulator)
    }
    assert_eq(execute_read(simulator, "consumer_count"), depth.to_uint64())
    assert_eq(host.requests.length(), depth * 32)
  }
}

///|
test "ring reader rejects backwards and overrun publication without advancing either counter" {
  for candidate in [99UL, 103UL, 0xffffffffUL] {
    let host = PortableHost::new()
    let simulator = ring_prepare(2)
    ring_config(host, simulator, 1024UL, 100UL)
    ring_publish(host, simulator, candidate)
    ring_fault(host, simulator, 3UL, 0UL, 1UL)
    assert_eq(execute_read(simulator, "producer_count"), 100UL)
    assert_eq(execute_read(simulator, "consumer_count"), 100UL)
    assert_eq(host.requests.length(), 0)
  }
}
