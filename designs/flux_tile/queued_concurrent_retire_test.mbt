///|
test "queued concurrent later compute and syntax failure finish before oldest memory failure but retire in order" {
  let host = PortableHost::new()
  let simulator = queued_concurrent_prepare(16)
  let old = queued_concurrent_seed_old(host, simulator)
  let left = [1, -2, 3, -4, 5, -6, 7, -8, 9, -10, 11, -12, 13, -14, 15]
  let right = [-128, 127, 5, -6, 7, -8, 9, -10, 11, -12]
  queued_concurrent_load(host, simulator, 0, 1, 3, 5, 512UL, 13UL, left)
  queued_concurrent_load(host, simulator, 1, 1, 5, 2, 768UL, 17UL, right)
  host.latency = 200
  host.memory[1376UL] = 9
  let malformed = queued_concurrent_packet(
    LoadA,
    41,
    rows=3,
    columns=5,
    base=512UL,
    stride=13UL,
    a=1,
  )
  malformed[0] = malformed[0] ^ 768UL // 0.2 -> rejected 0.1, without changing raw ID.
  for
    packet in [
      queued_concurrent_packet(
        LoadA,
        41,
        rows=3,
        columns=5,
        base=32UL,
        stride=13UL,
      ),
      queued_concurrent_packet(
        MatMul,
        41,
        rows=3,
        columns=2,
        reduction=5,
        a=1,
        b=1,
        c=1,
      ),
      queued_concurrent_packet(
        MatMul,
        41,
        rows=3,
        columns=2,
        reduction=5,
        a=1,
        b=1,
      ),
      malformed,
      queued_concurrent_packet(Fence, 42),
      queued_concurrent_packet(
        LoadB,
        43,
        rows=1,
        columns=1,
        base=1376UL,
        stride=1UL,
      ),
    ] {
    queued_concurrent_enqueue(host, simulator, packet)
  }
  let mut first_started = false
  let mut first_finished = false
  let mut second_started = false
  let mut second_finished = false
  for _ in 0..<150 {
    assert_eq(execute_read(simulator, "completion_valid"), 0UL)
    let capture = execute_read(simulator, "capture_cycles")
    if !first_finished && capture == 0UL {
      first_started = true
    }
    if first_started && capture == 6UL {
      first_finished = true
    }
    if first_finished && capture == 0UL {
      second_started = true
    }
    if second_started && capture == 6UL {
      second_finished = true
      break
    }
    host.tick(simulator)
  }
  assert_true(second_finished)
  guard host.pending is Some(p) else {
    fail("oldest transfer must still await external response")
  }
  assert_true(p.remaining > 0)
  let address = host.requests[host.requests.length() - 1][1]
  assert_eq(address, 32UL)
  host.pending = Some({ ..p, remaining: 0, fault: 1UL, })
  host.latency = 1
  queued_concurrent_completion(host, simulator, [41UL, 9UL, 0UL, address])
  let mut passed_fence = false
  for _ in 0..<1000 {
    assert_eq(queued_concurrent_payload(simulator), [41UL, 9UL, 0UL, address])
    let count = host.requests.length()
    host.tick(simulator)
    if host.requests.length() > count && host.requests[count][1] == 1376UL {
      passed_fence = true
    }
    if passed_fence && host.pending is None {
      break
    }
  }
  assert_true(passed_fence)
  queued_concurrent_drain(host, simulator, [
    [41UL, 9UL, 0UL, address],
    [41UL, 0UL, 0UL, 0UL],
    [41UL, 0UL, 0UL, 0UL],
    [41UL, 12UL, 0UL, 0UL],
    [42UL, 0UL, 0UL, 0UL],
    [43UL, 0UL, 1UL, 0UL],
  ])
  queued_concurrent_store(host, simulator, 0, 3, 2, 1536UL, old)
  queued_concurrent_store(host, simulator, 1, 3, 2, 2048UL, old)
}

///|
test "queued concurrent bounded retirement and FIFO fill then wrap without dropping entries" {
  let host = PortableHost::new()
  let simulator = queued_concurrent_prepare(3, rows=1, columns=1, capacity=1)
  queued_concurrent_enqueue(host, simulator, queued_concurrent_packet(Fence, 0))
  assert_eq(execute_read(simulator, "queue_occupancy"), 1UL)
  assert_eq(execute_read(simulator, "completion_valid"), 0UL)
  for id in 1..<7 {
    queued_concurrent_enqueue(
      host,
      simulator,
      queued_concurrent_packet(Fence, id),
    )
  }
  queued_concurrent_completion(host, simulator, [0UL, 0UL, 0UL, 0UL])
  for _ in 0..<40 {
    host.tick(simulator)
  }
  // D retirement entries + one blocked head + D FIFO entries, inferred
  // entirely from admission/backpressure and observed FIFO occupancy.
  assert_eq(execute_read(simulator, "queue_occupancy"), 3UL)
  assert_eq(execute_read(simulator, "descriptor_ready"), 0UL)
  frontend_present(simulator, queued_concurrent_packet(Fence, 7))
  for _ in 0..<8 {
    host.tick(simulator)
    assert_eq(execute_read(simulator, "descriptor_ready"), 0UL)
    assert_eq(queued_concurrent_payload(simulator), [0UL, 0UL, 0UL, 0UL])
    assert_eq(execute_read(simulator, "queue_occupancy"), 3UL)
  }
  queued_concurrent_ack(host, simulator)
  for _ in 0..<100 {
    if execute_read(simulator, "descriptor_ready") == 1UL {
      break
    }
    host.tick(simulator)
  }
  assert_eq(execute_read(simulator, "descriptor_ready"), 1UL)
  host.tick(simulator)
  portable_put(simulator, "descriptor_valid", 1, 0UL)
  for id in 1..<8 {
    queued_concurrent_completion(host, simulator, [
      id.to_uint64(),
      0UL,
      0UL,
      0UL,
    ])
    queued_concurrent_ack(host, simulator)
  }
  for id in 8..<23 {
    queued_concurrent_enqueue(
      host,
      simulator,
      queued_concurrent_packet(Fence, id),
    )
    queued_concurrent_completion(host, simulator, [
      id.to_uint64(),
      0UL,
      0UL,
      0UL,
    ])
    queued_concurrent_ack(host, simulator)
  }
  for _ in 0..<8 {
    host.tick(simulator)
  }
  assert_eq(execute_read(simulator, "completion_valid"), 0UL)
  assert_eq(execute_read(simulator, "queue_occupancy"), 0UL)
  assert_eq(host.requests.length(), 0)
}

///|
test "queued concurrent aligned final store ACK and compute terminal preserve both duplicate ID entries" {
  let host = PortableHost::new()
  let simulator = queued_concurrent_prepare(3, rows=1, columns=1, capacity=1)
  queued_concurrent_load(host, simulator, 0, 0, 1, 1, 32UL, 1UL, [2])
  queued_concurrent_load(host, simulator, 1, 0, 1, 1, 256UL, 1UL, [3])
  queued_concurrent_compute(host, simulator, 1, 1, 1)
  queued_concurrent_load(host, simulator, 0, 1, 1, 1, 512UL, 1UL, [-128])
  queued_concurrent_load(host, simulator, 1, 1, 1, 1, 768UL, 1UL, [127])
  host.latency = 200
  queued_concurrent_enqueue(
    host,
    simulator,
    queued_concurrent_packet(
      StoreC,
      90,
      rows=1,
      columns=1,
      base=1536UL,
      stride=40UL,
    ),
  )
  for _ in 0..<100 {
    if host.pending is Some(_) {
      break
    }
    host.tick(simulator)
  }
  assert_true(host.pending is Some(_))
  queued_concurrent_enqueue(
    host,
    simulator,
    queued_concurrent_packet(
      MatMul,
      90,
      rows=1,
      columns=1,
      reduction=1,
      a=1,
      b=1,
      c=1,
    ),
  )
  let mut began = false
  for _ in 0..<100 {
    if execute_read(simulator, "capture_cycles") == 0UL {
      began = true
    }
    if began && execute_read(simulator, "capture_cycles") == 1UL {
      break
    }
    host.tick(simulator)
  }
  assert_true(began)
  assert_eq(execute_read(simulator, "capture_cycles"), 1UL)
  assert_eq(execute_read(simulator, "completion_valid"), 0UL)
  guard host.pending is Some(p) else {
    fail("store final response no longer pending")
  }
  assert_true(p.remaining > 0)
  assert_eq(execute_read(simulator, "memory_response_ready"), 1UL)
  // The next edge processes the core terminal and the final store ACK. This
  // controls only a real external response, never the retirement/controller.
  host.pending = Some({ ..p, remaining: 0, })
  host.latency = 1
  host.tick(simulator)
  assert_true(host.pending is None)
  assert_eq(execute_read(simulator, "capture_cycles"), 1UL)
  assert_eq(host.word(1536UL), 6)
  queued_concurrent_completion(host, simulator, [90UL, 0UL, 4UL, 0UL])
  queued_concurrent_enqueue(
    host,
    simulator,
    queued_concurrent_packet(
      StoreC,
      91,
      rows=1,
      columns=1,
      base=2048UL,
      stride=40UL,
      c=1,
    ),
  )
  let first = host.requests.length()
  for _ in 0..<100 {
    assert_eq(queued_concurrent_payload(simulator), [90UL, 0UL, 4UL, 0UL])
    host.tick(simulator)
    if host.requests.length() > first && host.pending is None {
      break
    }
  }
  assert_eq(host.word(2048UL), -16256)
  queued_concurrent_drain(host, simulator, [
    [90UL, 0UL, 4UL, 0UL],
    [90UL, 0UL, 0UL, 0UL],
    [91UL, 0UL, 4UL, 0UL],
  ])
}
