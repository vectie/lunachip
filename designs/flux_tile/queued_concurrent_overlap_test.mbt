///|
test "queued concurrent real DMA overlaps compute while held oldest permits engine reuse and Fence" {
  let host = PortableHost::new()
  let simulator = queued_concurrent_prepare(16, rows=8, columns=8, capacity=16)
  let old = queued_concurrent_seed_old(host, simulator)
  let left = Array::makei(128, index => (index * 47 + 13) % 256 - 128)
  let right = Array::makei(128, index => (index * 83 + 231) % 256 - 128)
  queued_concurrent_load(host, simulator, 0, 1, 8, 16, 512UL, 24UL, left)
  queued_concurrent_load(host, simulator, 1, 1, 16, 8, 768UL, 17UL, right)
  host.seed(32UL, 24UL, 8, 16, Array::make(128, -7))
  host.memory[1376UL] = 9
  for (base, rows) in [(1536UL, 3), (2048UL, 8), (2560UL, 8)] {
    for byte in 0..<(rows * 40) {
      host.memory[base + byte.to_uint64()] = 165
    }
  }
  for
    packet in [
      queued_concurrent_packet(
        LoadA,
        77,
        rows=8,
        columns=16,
        base=32UL,
        stride=24UL,
      ),
      queued_concurrent_packet(
        StoreC,
        77,
        rows=3,
        columns=2,
        base=1536UL,
        stride=40UL,
      ),
      queued_concurrent_packet(
        MatMul,
        77,
        rows=8,
        columns=8,
        reduction=16,
        a=1,
        b=1,
        c=1,
      ),
      queued_concurrent_packet(
        StoreC,
        77,
        rows=8,
        columns=8,
        base=2560UL,
        stride=40UL,
        c=1,
      ),
      queued_concurrent_packet(
        MatMul,
        77,
        rows=8,
        columns=8,
        reduction=16,
        a=1,
        b=1,
      ),
      queued_concurrent_packet(
        StoreC,
        77,
        rows=8,
        columns=8,
        base=2048UL,
        stride=40UL,
      ),
      queued_concurrent_packet(Fence, 78),
      queued_concurrent_packet(
        LoadB,
        79,
        rows=1,
        columns=1,
        base=1376UL,
        stride=1UL,
      ),
    ] {
    queued_concurrent_enqueue(host, simulator, packet)
  }
  let seen = Array::make(8, false)
  let mut saw_after_fence = false
  let mut request_during_held = false
  let mut store_finished_before_oldest = false
  for _ in 0..<40000 {
    let held = execute_read(simulator, "completion_valid") == 1UL
    if held {
      assert_eq(queued_concurrent_payload(simulator), [77UL, 0UL, 128UL, 0UL])
    }
    let count = host.requests.length()
    let old_store_ack = host.pending is Some(p) &&
      p.remaining == 0 &&
      execute_read(simulator, "memory_response_ready") == 1UL &&
      count > 0 &&
      host.requests[count - 1][0] == 1UL &&
      host.requests[count - 1][1] == 1620UL
    let observations = concurrent_observe_tick(host, simulator)
    if old_store_ack && execute_read(simulator, "completion_valid") == 0UL {
      store_finished_before_oldest = true
    }
    for index in 0..<8 {
      seen[index] = seen[index] || observations[index]
    }
    if held && host.requests.length() > count {
      request_during_held = true
    }
    if host.requests.length() > count && host.requests[count][1] == 1376UL {
      saw_after_fence = true
    }
    if saw_after_fence && host.pending is None {
      break
    }
  }
  // No external ACK has occurred since baseline setup. A post-Fence request
  // proves Fence passed older terminal work, rather than waiting for ACKs.
  assert_true(saw_after_fence)
  assert_true(request_during_held)
  assert_true(store_finished_before_oldest)
  assert_eq(seen, Array::make(8, true))
  let expected = @flux_tile.matmul_int8_oracle(
    left,
    right,
    rows=8,
    columns=8,
    reduction=16,
  )
  concurrent_check_words(host, 1536UL, 3, 2, old)
  concurrent_check_words(host, 2048UL, 8, 8, expected)
  concurrent_check_words(host, 2560UL, 8, 8, expected)
  queued_concurrent_drain(host, simulator, [
    [77UL, 0UL, 128UL, 0UL],
    [77UL, 0UL, 24UL, 0UL],
    [77UL, 0UL, 0UL, 0UL],
    [77UL, 0UL, 256UL, 0UL],
    [77UL, 0UL, 0UL, 0UL],
    [77UL, 0UL, 256UL, 0UL],
    [78UL, 0UL, 0UL, 0UL],
    [79UL, 0UL, 1UL, 0UL],
  ])
  assert_eq(execute_read(simulator, "queue_occupancy"), 0UL)
  queued_concurrent_store(host, simulator, 1, 8, 8, 2560UL, expected)
}
