///|
test "ring reader accepts an aperture ending at 2^32 and rejects wrapped or unaligned configuration" {
  let host = PortableHost::new()
  let simulator = ring_prepare(2, aperture=4294967296UL)
  let lanes = ring_lanes(40)
  ring_seed(host, 0xffffffe0UL, lanes)
  ring_config(host, simulator, 0xffffffc0UL, 1UL)
  ring_publish(host, simulator, 2UL)
  ring_packet(host, simulator, lanes, 1UL)
  assert_eq(host.requests[0][1], 0xffffffe0UL)
  assert_eq(host.requests[31][1], 0xffffffffUL)
  ring_ack(host, simulator, 1UL)
  for
    (aperture, base, fault) in [
      (4294967296UL, 0xffffffe0UL, 2UL),
      (4096UL, 4064UL, 2UL),
      (4096UL, 4097UL, 1UL),
    ] {
    let bad_host = PortableHost::new()
    let bad = ring_prepare(2, aperture~)
    ring_config(bad_host, bad, base, 0xfffffffeUL)
    ring_fault(bad_host, bad, fault, base, 0UL)
    assert_eq(execute_read(bad, "producer_count"), 0UL)
    assert_eq(execute_read(bad, "consumer_count"), 0UL)
    assert_eq(bad_host.requests.length(), 0)
  }
}

///|
test "ring reader incomplete remote fetches never manufacture a packet or consume the slot" {
  for failed_byte in [0, 17, 31] {
    let host = PortableHost::new()
    host.fail_at = failed_byte
    let simulator = ring_prepare(2)
    ring_seed(host, 1024UL, ring_lanes(50))
    ring_config(host, simulator, 1024UL, 2UL)
    ring_publish(host, simulator, 3UL)
    portable_put(simulator, "descriptor_ready", 1, 1UL)
    for _ in 0..<1000 {
      assert_eq(execute_read(simulator, "descriptor_valid"), 0UL)
      if execute_read(simulator, "fault_valid") == 1UL {
        break
      }
      host.tick(simulator)
    }
    ring_fault(host, simulator, 4UL, 1024UL + failed_byte.to_uint64(), 1UL)
    assert_eq(host.requests.length(), failed_byte + 1)
    assert_eq(execute_read(simulator, "consumer_count"), 2UL)
    assert_eq(execute_read(simulator, "producer_count"), 3UL)
  }
}

///|
test "ring reader wrong tags and reserved statuses lock out with protocol priority over remote fault" {
  for status in [0UL, 2UL, 3UL] {
    let host = PortableHost::new()
    host.protocol_at = 0
    host.protocol_status = status
    host.fail_at = 0 // Wrong tag plus remote status1 must still be protocol5.
    let simulator = ring_prepare(2)
    ring_config(host, simulator, 1024UL, 0UL)
    ring_publish(host, simulator, 1UL)
    ring_fault(host, simulator, 5UL, 1024UL, 1UL)
    assert_eq(host.requests.length(), 1)
    assert_eq(execute_read(simulator, "consumer_count"), 0UL)
    portable_put(simulator, "publish_valid", 1, 1UL)
    portable_put(simulator, "config_valid", 1, 1UL)
    portable_put(simulator, "descriptor_ready", 1, 1UL)
    ring_fault(host, simulator, 5UL, 1024UL, 1UL)
    ring_reset_barrier(host, simulator)
    let lanes = ring_lanes(60)
    ring_seed(host, 1024UL, lanes)
    ring_config(host, simulator, 1024UL, 0UL)
    ring_publish(host, simulator, 1UL)
    ring_packet(host, simulator, lanes, 0UL)
    assert_eq(host.requests[0][5], 0UL)
    ring_ack(host, simulator, 0UL)
  }
}

///|
test "ring reader joint reset flushes an accepted request and a backpressured packet" {
  for pending_request in [true, false] {
    let host = PortableHost::new()
    host.latency = if pending_request { 100 } else { 0 }
    let simulator = ring_prepare(2)
    let old = ring_lanes(70)
    ring_seed(host, 1024UL, old)
    ring_config(host, simulator, 1024UL, 0UL)
    ring_publish(host, simulator, 1UL)
    if pending_request {
      for _ in 0..<20 {
        if host.pending is Some(_) {
          break
        }
        host.tick(simulator)
      }
      assert_true(host.pending is Some(_))
    } else {
      ring_packet(host, simulator, old, 0UL)
    }
    // Reset must dominate even simultaneous offered publication/configuration,
    // a response, and packet-ready. Flush actual external state before release.
    portable_put(simulator, "publish_valid", 1, 1UL)
    portable_put(simulator, "config_valid", 1, 1UL)
    portable_put(simulator, "memory_response_valid", 1, 1UL)
    portable_put(simulator, "descriptor_ready", 1, 1UL)
    ring_reset_barrier(host, simulator)
    for _ in 0..<4 {
      host.tick(simulator)
      assert_eq(execute_read(simulator, "descriptor_valid"), 0UL)
      assert_eq(execute_read(simulator, "fault_valid"), 0UL)
    }
    assert_eq(host.requests.length(), 0)
    host.latency = 0
    let replacement = ring_lanes(71)
    ring_seed(host, 1056UL, replacement)
    ring_config(host, simulator, 1024UL, 9UL)
    ring_publish(host, simulator, 10UL)
    ring_packet(host, simulator, replacement, 9UL)
    assert_eq(host.requests[0][5], 0UL)
    ring_ack(host, simulator, 9UL)
  }
}
