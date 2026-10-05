///|
test "ring concurrent bounded owners hold consumer until atomic admission across real origin wrap" {
  for depth in [2, 4, 8, 16] {
    let host = PortableHost::new()
    let simulator = ring_concurrent_prepare(
      ring_depth=depth,
      queue_depth=2,
      rows=1,
      columns=1,
      capacity=1,
    )
    let origin = 4294967294UL
    ring_concurrent_config(host, simulator, origin~)
    let mut sequence = origin
    let mut accepted = 0
    // Keep oldest retirement held while legitimately reusing only consumed
    // physical slots. The bounded frontend fits D retirement+D FIFO+one head.
    ring_concurrent_submit(
      host,
      simulator,
      sequence,
      Array::make(depth, queued_concurrent_packet(Fence, 91)),
      depth~,
    )
    sequence = sequence + depth.to_uint64()
    accepted = depth
    for _ in 0..<4 {
      for _ in 0..<2000 {
        host.tick(simulator)
      }
      if execute_read(simulator, "publish_ready") == 0UL {
        break
      }
      let consumer = execute_read(simulator, "consumer_count")
      let occupancy = ((sequence & 4294967295UL) - consumer) & 4294967295UL
      if occupancy < depth.to_uint64() {
        let count = depth - occupancy.to_int()
        ring_concurrent_submit(
          host,
          simulator,
          sequence,
          Array::make(count, queued_concurrent_packet(Fence, 91)),
          depth~,
        )
        sequence = sequence + count.to_uint64()
        accepted = accepted + count
      }
    }
    assert_true(accepted >= 6)
    assert_eq(execute_read(simulator, "completion_valid"), 1UL)
    assert_eq(queued_concurrent_payload(simulator), [91UL, 0UL, 0UL, 0UL])
    assert_eq(execute_read(simulator, "queue_occupancy"), 2UL)
    let consumer = execute_read(simulator, "consumer_count")
    assert_eq(consumer, 3UL) // origin+5 accepted into queue owners.
    let count = host.requests.length()
    let held_slot = consumer % depth.to_uint64()
    let held_bytes = Array::makei(32, i => {
      host.memory.get(8192UL + held_slot * 32UL + i.to_uint64()).unwrap()
    })
    for _ in 0..<200 {
      host.tick(simulator)
      assert_eq(execute_read(simulator, "consumer_count"), consumer)
      assert_eq(queued_concurrent_payload(simulator), [91UL, 0UL, 0UL, 0UL])
    }
    assert_eq(host.requests.length(), count)
    // The complete reader packet remains host-owned until queue handshake.
    assert_eq(
      Array::makei(32, i => {
        host.memory.get(8192UL + held_slot * 32UL + i.to_uint64()).unwrap()
      }),
      held_bytes,
    )
    queued_concurrent_drain(
      host,
      simulator,
      Array::make(accepted, [91UL, 0UL, 0UL, 0UL]),
    )
    assert_eq(
      execute_read(simulator, "consumer_count"),
      sequence & 4294967295UL,
    )
    assert_eq(
      execute_read(simulator, "producer_count"),
      sequence & 4294967295UL,
    )
    assert_eq(execute_read(simulator, "queue_occupancy"), 0UL)
    assert_eq(execute_read(simulator, "ring_fault_valid"), 0UL)
  }
}

///|
test "ring concurrent joint reset flushes an actual pending fetch and all bounded owners" {
  let host = PortableHost::new()
  let simulator = ring_concurrent_prepare(queue_depth=2)
  ring_concurrent_config(host, simulator)
  host.latency = 200
  ring_concurrent_submit(host, simulator, 0UL, [
    queued_concurrent_packet(Fence, 101),
  ])
  for _ in 0..<50 {
    if host.pending is Some(_) {
      break
    }
    host.tick(simulator)
  }
  assert_true(host.pending is Some(_))
  assert_eq(execute_read(simulator, "consumer_count"), 0UL)
  ring_concurrent_reset(host, simulator)
  host.latency = 1
  ring_concurrent_config(host, simulator, origin=4294967295UL)
  ring_concurrent_submit(host, simulator, 4294967295UL, [
    queued_concurrent_packet(MatMul, 102, rows=1, columns=1, reduction=1),
    queued_concurrent_packet(
      StoreC,
      103,
      rows=1,
      columns=1,
      base=4096UL,
      stride=4UL,
    ),
  ])
  queued_concurrent_drain(host, simulator, [
    [102UL, 4UL, 0UL, 0UL],
    [103UL, 5UL, 0UL, 0UL],
  ])
  assert_eq(execute_read(simulator, "consumer_count"), 1UL)
  assert_eq(host.requests[0][5], 0UL)
}
