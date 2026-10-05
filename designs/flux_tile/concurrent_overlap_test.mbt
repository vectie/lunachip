///|
test "concurrent real load and store transfers overlap Run and capture with held completions" {
  let host = PortableHost::new()
  let simulator = concurrent_prepare(8, 8, 16)
  let old = concurrent_seed_old(host, simulator)
  let left = Array::makei(128, index => (index * 47 + 13) % 256 - 128)
  let right = Array::makei(128, index => (index * 83 + 231) % 256 - 128)
  let replacement = Array::makei(128, index => (index * 31 + 7) % 256 - 128)
  concurrent_load(host, simulator, 0, 1, 8, 16, 512UL, 24UL, left)
  concurrent_load(host, simulator, 1, 1, 16, 8, 768UL, 17UL, right)
  host.seed(32UL, 24UL, 8, 16, replacement)
  for byte in 0..<120 {
    host.memory[1536UL + byte.to_uint64()] = 165
  }
  // Duplicate caller IDs are independent channel identities, not tokens.
  concurrent_transfer_offer(simulator, "load", 55, 0, 8, 16, 32UL, 24UL)
  concurrent_transfer_offer(simulator, "store", 55, 0, 3, 2, 1536UL, 40UL)
  concurrent_compute_offer(simulator, 55, 8, 8, 16, a=1, b=1, c=1)
  for channel in ["load", "compute", "store"] {
    assert_eq(execute_read(simulator, channel + "_command_ready"), 1UL)
  }
  host.tick(simulator)
  for channel in ["load", "store"] {
    concurrent_latched_noise(simulator, channel)
  }
  concurrent_latched_noise(simulator, "compute", selectors=[0, 0, 0])
  let seen = Array::make(8, false)
  let mut progressed_with_held = false
  for _ in 0..<20000 {
    let held = execute_read(simulator, "compute_completion_valid") == 1UL &&
      execute_read(simulator, "store_completion_valid") == 1UL
    let acknowledged_load = host.pending is Some(p) &&
      p.remaining == 0 &&
      execute_read(simulator, "memory_response_ready") == 1UL &&
      host.requests[host.requests.length() - 1][0] == 0UL
    let observations = concurrent_observe_tick(host, simulator)
    for index in 0..<8 {
      seen[index] = seen[index] || observations[index]
    }
    if held && acknowledged_load {
      progressed_with_held = true
    }
    if execute_read(simulator, "compute_completion_valid") == 1UL {
      assert_eq(concurrent_payload(simulator, "compute"), [55UL, 0UL])
    }
    if execute_read(simulator, "store_completion_valid") == 1UL {
      assert_eq(concurrent_payload(simulator, "store"), [55UL, 0UL, 24UL, 0UL])
    }
    if execute_read(simulator, "load_completion_valid") == 1UL && held {
      break
    }
  }
  // The first four flags require accepted read/write requests on advancing
  // Run/capture edges; the last four require their actual response handshakes.
  assert_eq(seen, Array::make(8, true))
  assert_true(progressed_with_held)
  assert_eq(concurrent_payload(simulator, "load"), [55UL, 0UL, 128UL, 0UL])
  assert_eq(execute_read(simulator, "active_cycles"), 30UL)
  assert_eq(execute_read(simulator, "capture_cycles"), 64UL)
  concurrent_check_words(host, 1536UL, 3, 2, old)
  for channel in ["store", "compute", "load"] {
    concurrent_ack(host, simulator, channel)
  }
  let expected = @flux_tile.matmul_int8_oracle(
    left,
    right,
    rows=8,
    columns=8,
    reduction=16,
  )
  concurrent_store(host, simulator, 1, 8, 8, 2048UL, expected)
  // Observe the reloaded source through actual subsequent arithmetic, rather
  // than treating a read ACK as a software substitute for an SRAM write.
  concurrent_load(host, simulator, 1, 0, 16, 8, 256UL, 17UL, right)
  concurrent_compute(host, simulator, 8, 8, 16)
  let replaced = @flux_tile.matmul_int8_oracle(
    replacement,
    right,
    rows=8,
    columns=8,
    reduction=16,
  )
  concurrent_store(host, simulator, 0, 8, 8, 1536UL, replaced)
  concurrent_store(host, simulator, 1, 8, 8, 2048UL, expected)
}

///|
test "concurrent held compute completion does not retain released sources or C reservations" {
  let host = PortableHost::new()
  let simulator = concurrent_prepare(3, 2, 5)
  let old = concurrent_seed_old(host, simulator)
  concurrent_compute_offer(simulator, 56, 3, 2, 5)
  host.tick(simulator)
  concurrent_latched_noise(simulator, "compute")
  concurrent_wait(host, simulator, "compute", [56UL, 0UL])
  host.seed(32UL, 13UL, 3, 5, Array::make(15, -7))
  for byte in 0..<120 {
    host.memory[1536UL + byte.to_uint64()] = 165
  }
  concurrent_transfer_offer(simulator, "load", 57, 0, 3, 5, 32UL, 13UL)
  concurrent_transfer_offer(simulator, "store", 58, 0, 3, 2, 1536UL, 40UL)
  assert_eq(execute_read(simulator, "load_command_ready"), 1UL)
  assert_eq(execute_read(simulator, "store_command_ready"), 1UL)
  host.tick(simulator)
  concurrent_latched_noise(simulator, "load")
  concurrent_latched_noise(simulator, "store")
  concurrent_wait(host, simulator, "load", [57UL, 0UL, 15UL, 0UL])
  concurrent_wait(host, simulator, "store", [58UL, 0UL, 24UL, 0UL])
  assert_eq(concurrent_payload(simulator, "compute"), [56UL, 0UL])
  concurrent_check_words(host, 1536UL, 3, 2, old)
  for channel in ["load", "store", "compute"] {
    concurrent_ack(host, simulator, channel)
  }
}

///|
test "concurrent joint reset aborts all active engines and flushes accepted transport without rollback" {
  let host = PortableHost::new()
  let simulator = concurrent_prepare(3, 2, 16)
  let old = concurrent_seed_old(host, simulator)
  concurrent_load(host, simulator, 0, 1, 3, 16, 512UL, 24UL, Array::make(48, 7))
  concurrent_load(host, simulator, 1, 1, 16, 2, 768UL, 8UL, Array::make(32, -9))
  host.latency = 100
  concurrent_transfer_offer(simulator, "store", 94, 0, 3, 2, 1536UL, 40UL)
  host.tick(simulator)
  concurrent_latched_noise(simulator, "store")
  for _ in 0..<50 {
    if host.pending is Some(_) {
      break
    }
    host.tick(simulator)
  }
  assert_true(host.pending is Some(_))
  assert_eq(host.requests[host.requests.length() - 1][0], 1UL)
  assert_eq(host.word(1536UL), old[0])
  host.seed(32UL, 24UL, 3, 16, Array::make(48, 11))
  concurrent_transfer_offer(simulator, "load", 95, 0, 3, 16, 32UL, 24UL)
  concurrent_compute_offer(simulator, 96, 3, 2, 16, a=1, b=1, c=1)
  assert_eq(execute_read(simulator, "load_command_ready"), 1UL)
  assert_eq(execute_read(simulator, "compute_command_ready"), 1UL)
  host.tick(simulator)
  concurrent_latched_noise(simulator, "load")
  concurrent_latched_noise(simulator, "compute")
  for _ in 0..<20 {
    if execute_read(simulator, "active_cycles") == 1UL {
      break
    }
    host.tick(simulator)
  }
  assert_eq(execute_read(simulator, "active_cycles"), 1UL)
  for channel in ["load", "compute", "store"] {
    assert_eq(execute_read(simulator, channel + "_completion_valid"), 0UL)
  }
  concurrent_reset(host, simulator)
  assert_eq(host.word(1536UL), old[0])
  host.latency = 1
  for _ in 0..<4 {
    host.tick(simulator)
    for channel in ["load", "compute", "store"] {
      assert_eq(execute_read(simulator, channel + "_completion_valid"), 0UL)
    }
  }
  for slot in [0, 1] {
    concurrent_compute_offer(
      simulator,
      97,
      3,
      2,
      if slot == 0 {
        5
      } else {
        16
      },
      a=slot,
      b=slot,
      c=slot,
    )
    host.tick(simulator)
    concurrent_latched_noise(simulator, "compute")
    concurrent_wait(host, simulator, "compute", [97UL, 4UL])
    concurrent_ack(host, simulator, "compute")
    concurrent_transfer_offer(simulator, "store", 98, slot, 3, 2, 2048UL, 40UL)
    host.tick(simulator)
    concurrent_latched_noise(simulator, "store")
    concurrent_wait(host, simulator, "store", [98UL, 5UL, 0UL, 0UL])
    concurrent_ack(host, simulator, "store")
  }
  assert_eq(host.requests.length(), 0)
  for slot in [0, 1] {
    let k = if slot == 0 { 5 } else { 16 }
    concurrent_load(
      host,
      simulator,
      0,
      1,
      3,
      k,
      128UL,
      24UL,
      Array::make(3 * k, 7),
    )
    concurrent_compute_offer(simulator, 99, 3, 2, k, a=1, b=slot, c=1)
    host.tick(simulator)
    concurrent_latched_noise(simulator, "compute")
    concurrent_wait(host, simulator, "compute", [99UL, 4UL])
    concurrent_ack(host, simulator, "compute")
  }
  concurrent_load(host, simulator, 0, 0, 1, 1, 32UL, 1UL, [2])
  concurrent_load(host, simulator, 1, 0, 1, 1, 256UL, 1UL, [3])
  concurrent_compute(host, simulator, 1, 1, 1)
  concurrent_store(host, simulator, 0, 1, 1, 2048UL, [6])
  assert_eq(host.requests[0][5], 0UL)
}
