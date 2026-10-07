///|
test "concurrent pregrant C0 read survives opposite C1 final capture then held Store Offer" {
  let host = PortableHost::new()
  let simulator = concurrent_prepare(3, 3, 5)
  let old = concurrent_seed_old(host, simulator)
  let left = [-128, 127, 3, -4]
  let right = [127, -128, 5, -6, 7, -8]
  let fresh = @flux_tile.matmul_int8_oracle(
    left,
    right,
    rows=2,
    columns=3,
    reduction=2,
  )
  concurrent_load(host, simulator, 0, 1, 2, 2, 512UL, 13UL, left)
  concurrent_load(host, simulator, 1, 1, 2, 3, 768UL, 17UL, right)
  for byte in 0..<120 {
    host.memory[1536UL + byte.to_uint64()] = 165
  }
  assert_true(host.pending is None)
  let first = host.requests.length()
  // A genuine accepted loader transaction prevents the arbiter from taking
  // its Store snapshot. Only the external memory response is delayed.
  host.latency = 200
  host.seed(32UL, 1UL, 1, 1, [42])
  concurrent_transfer_offer(simulator, "load", 101, 0, 1, 1, 32UL, 1UL)
  assert_eq(execute_read(simulator, "load_command_ready"), 1UL)
  host.tick(simulator)
  concurrent_latched_noise(simulator, "load")
  for _ in 0..<30 {
    if host.pending is Some(_) {
      break
    }
    host.tick(simulator)
  }
  assert_true(host.pending is Some(p) && p.remaining >= 190)
  assert_eq(host.requests.length(), first + 1)
  assert_eq(host.requests[first][0], 0UL)
  assert_eq(host.requests[first][1], 32UL)
  concurrent_transfer_offer(simulator, "store", 102, 0, 3, 2, 1536UL, 40UL)
  assert_eq(execute_read(simulator, "store_command_ready"), 1UL)
  host.tick(simulator)
  concurrent_latched_noise(simulator, "store", selectors=[1])
  // The unchanged production Store launches its sole synchronous indexed C0
  // read before C1 is admitted. These edges have no external Store grant.
  for _ in 0..<6 {
    assert_eq(execute_read(simulator, "memory_request_valid"), 0UL)
    assert_eq(execute_read(simulator, "store_completion_valid"), 0UL)
    host.tick(simulator)
  }
  concurrent_compute_offer(simulator, 103, 2, 3, 2, a=1, b=1, c=0)
  assert_eq(execute_read(simulator, "compute_command_ready"), 0UL)
  concurrent_compute_offer(simulator, 104, 2, 3, 2, a=1, b=1, c=1)
  assert_eq(execute_read(simulator, "compute_command_ready"), 1UL)
  host.tick(simulator)
  concurrent_latched_noise(simulator, "compute", selectors=[0, 0, 0])
  let mut run_edges = 0
  let mut capture_edges = 0
  let mut final_capture_edges = 0
  for _ in 0..<100 {
    if execute_read(simulator, "compute_completion_valid") == 1UL {
      break
    }
    assert_true(host.pending is Some(p) && p.remaining > 0)
    assert_eq(host.requests.length(), first + 1)
    assert_eq(execute_read(simulator, "memory_request_valid"), 0UL)
    assert_eq(execute_read(simulator, "store_completion_valid"), 0UL)
    let active = execute_read(simulator, "active_cycles")
    let capture = execute_read(simulator, "capture_cycles")
    host.tick(simulator)
    let active_after = execute_read(simulator, "active_cycles")
    let capture_after = execute_read(simulator, "capture_cycles")
    if active_after == active + 1UL {
      run_edges += 1
    }
    if capture_after == capture + 1UL {
      capture_edges += 1
      if capture == 5UL && capture_after == 6UL {
        final_capture_edges += 1
      }
    }
  }
  assert_eq(run_edges, 5)
  assert_eq(capture_edges, 6)
  assert_eq(final_capture_edges, 1)
  assert_eq(execute_read(simulator, "compute_completion_valid"), 1UL)
  assert_eq(concurrent_payload(simulator, "compute"), [104UL, 0UL])
  assert_eq(execute_read(simulator, "active_cycles"), 5UL)
  assert_eq(execute_read(simulator, "capture_cycles"), 6UL)
  assert_eq(host.requests.length(), first + 1)
  // Remove compute-busy as an explanation of same-C0 backpressure. Store's
  // whole-rectangle lease still excludes this otherwise legal overwrite.
  concurrent_ack(host, simulator, "compute")
  concurrent_compute_offer(simulator, 103, 2, 3, 2, a=1, b=1, c=0)
  assert_eq(execute_read(simulator, "compute_command_ready"), 0UL)
  let mut loader_ack_edges = 0
  for _ in 0..<250 {
    let ack = host.pending is Some(p) &&
      p.remaining == 0 &&
      execute_read(simulator, "memory_response_ready") == 1UL
    assert_eq(execute_read(simulator, "memory_request_valid"), 0UL)
    assert_eq(execute_read(simulator, "compute_command_ready"), 0UL)
    host.tick(simulator)
    if ack {
      loader_ack_edges += 1
      break
    }
  }
  assert_eq(loader_ack_edges, 1)
  assert_true(host.pending is None)
  assert_eq(host.requests.length(), first + 1)
  // From here, stall only the public host offer. No response is outstanding
  // and no external transaction can be lost during these device-only edges.
  portable_put(simulator, "memory_request_ready", 1, 0UL)
  portable_put(simulator, "memory_response_valid", 1, 0UL)
  for _ in 0..<10 {
    if execute_read(simulator, "memory_request_valid") == 1UL {
      break
    }
    simulator.rising_edge("clock")
  }
  assert_eq(execute_read(simulator, "memory_request_valid"), 1UL)
  let fields = ["write", "address", "bytes", "mask", "data", "tag"]
  let held = fields.map(field => {
    execute_read(simulator, "memory_request_" + field)
  })
  assert_eq(held, [
    1UL,
    1536UL,
    4UL,
    15UL,
    old[0].to_int64().reinterpret_as_uint64() & 0xffffffffUL,
    (first + 1).to_uint64(),
  ])
  let mut stalled_offer_edges = 0
  for _ in 0..<3 {
    assert_eq(execute_read(simulator, "memory_request_valid"), 1UL)
    assert_eq(
      fields.map(field => execute_read(simulator, "memory_request_" + field)),
      held,
    )
    assert_eq(execute_read(simulator, "compute_command_ready"), 0UL)
    simulator.rising_edge("clock")
    stalled_offer_edges += 1
  }
  assert_eq(stalled_offer_edges, 3)
  assert_eq(execute_read(simulator, "memory_request_valid"), 1UL)
  assert_eq(
    fields.map(field => execute_read(simulator, "memory_request_" + field)),
    held,
  )
  assert_eq(host.requests.length(), first + 1)
  host.latency = 1
  let mut final_store_ack_edges = 0
  for _ in 0..<1000 {
    assert_eq(execute_read(simulator, "compute_command_ready"), 0UL)
    let final_ack = host.requests.length() == first + 7 &&
      host.pending is Some(p) &&
      p.remaining == 0 &&
      execute_read(simulator, "memory_response_ready") == 1UL
    host.tick(simulator)
    if final_ack {
      final_store_ack_edges += 1
      break
    }
  }
  assert_eq(final_store_ack_edges, 1)
  assert_eq(execute_read(simulator, "store_completion_valid"), 1UL)
  assert_eq(concurrent_payload(simulator, "store"), [102UL, 0UL, 24UL, 0UL])
  assert_eq(execute_read(simulator, "compute_command_ready"), 1UL)
  portable_put(simulator, "compute_command_valid", 1, 0UL)
  assert_eq(host.requests.length(), first + 7)
  // Check every indexed word, not only the arbiter's first saved payload.
  for index in 0..<6 {
    let row = index / 2
    let column = index % 2
    assert_eq(host.requests[first + 1 + index], [
      1UL,
      1536UL + row.to_uint64() * 40UL + column.to_uint64() * 4UL,
      4UL,
      15UL,
      old[index].to_int64().reinterpret_as_uint64() & 0xffffffffUL,
      (first + 1 + index).to_uint64(),
    ])
  }
  concurrent_check_words(host, 1536UL, 3, 2, old)
  concurrent_wait(host, simulator, "load", [101UL, 0UL, 1UL, 0UL])
  concurrent_wait(host, simulator, "store", [102UL, 0UL, 24UL, 0UL])
  concurrent_ack(host, simulator, "load")
  concurrent_ack(host, simulator, "store")
  concurrent_store(host, simulator, 1, 2, 3, 2048UL, fresh)
  concurrent_check_words(host, 1536UL, 3, 2, old)
  assert_eq(execute_read(simulator, "transport_halted"), 0UL)
}
