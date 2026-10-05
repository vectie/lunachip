///|
test "concurrent new legal compute wins conflicting transfers and reserves sources through Issue" {
  let host = PortableHost::new()
  let simulator = concurrent_prepare(3, 2, 5)
  ignore(concurrent_seed_old(host, simulator))
  concurrent_transfer_offer(simulator, "load", 61, 0, 3, 5, 32UL, 13UL)
  concurrent_transfer_offer(simulator, "store", 62, 0, 3, 2, 1536UL, 40UL)
  concurrent_compute_offer(simulator, 63, 3, 2, 5)
  assert_eq(execute_read(simulator, "compute_command_ready"), 1UL)
  assert_eq(execute_read(simulator, "load_command_ready"), 0UL)
  assert_eq(execute_read(simulator, "store_command_ready"), 0UL)
  let count = host.requests.length()
  let previous_active = execute_read(simulator, "active_cycles")
  host.tick(simulator)
  concurrent_latched_noise(simulator, "compute")
  // These checks are on the edge immediately after admission, before any
  // core Run advance. An Issue-gap load must not slip into a reserved source.
  assert_eq(execute_read(simulator, "active_cycles"), previous_active)
  assert_eq(execute_read(simulator, "load_command_ready"), 0UL)
  assert_eq(execute_read(simulator, "store_command_ready"), 0UL)
  host.tick(simulator)
  assert_eq(execute_read(simulator, "active_cycles"), 0UL)
  assert_eq(host.requests.length(), count)
  let mut saw_last_capture = false
  for _ in 0..<100 {
    if execute_read(simulator, "load_command_ready") == 1UL {
      break
    }
    assert_eq(execute_read(simulator, "store_command_ready"), 0UL)
    if execute_read(simulator, "capture_cycles") == 5UL {
      saw_last_capture = true
      assert_eq(execute_read(simulator, "load_command_ready"), 0UL)
    }
    host.tick(simulator)
  }
  assert_true(saw_last_capture)
  assert_eq(execute_read(simulator, "capture_cycles"), 6UL)
  assert_eq(execute_read(simulator, "load_command_ready"), 1UL)
  assert_eq(execute_read(simulator, "store_command_ready"), 1UL)
  // Offered blocked transfers have not yet had an admission edge.
  portable_put(simulator, "load_command_valid", 1, 0UL)
  portable_put(simulator, "store_command_valid", 1, 0UL)
  concurrent_wait(host, simulator, "compute", [63UL, 0UL])
  assert_eq(host.requests.length(), count)
  concurrent_ack(host, simulator, "compute")
}

///|
test "concurrent whole store lease excludes C overwrite between words and through final ACK" {
  let host = PortableHost::new()
  let simulator = concurrent_prepare(3, 2, 5)
  let old = concurrent_seed_old(host, simulator)
  let replacement = Array::make(15, -7)
  let right = [-128, 127, 5, -6, 7, -8, 9, -10, 11, -12]
  concurrent_load(host, simulator, 0, 0, 3, 5, 32UL, 13UL, replacement)
  for byte in 0..<120 {
    host.memory[1536UL + byte.to_uint64()] = 165
  }
  let first = host.requests.length()
  concurrent_transfer_offer(simulator, "store", 64, 0, 3, 2, 1536UL, 40UL)
  host.tick(simulator)
  concurrent_latched_noise(simulator, "store")
  concurrent_compute_offer(simulator, 65, 0, 0, 0)
  portable_put(simulator, "compute_command_valid", 1, 0UL)
  assert_eq(execute_read(simulator, "compute_command_ready"), 0UL)
  concurrent_compute_offer(simulator, 65, 3, 2, 5)
  let mut saw_gap = false
  let mut saw_final_ack = false
  for _ in 0..<1000 {
    assert_eq(execute_read(simulator, "compute_command_ready"), 0UL)
    let words = host.requests.length() - first
    if words > 0 &&
      words < 6 &&
      host.pending is None &&
      execute_read(simulator, "memory_request_valid") == 0UL {
      saw_gap = true
    }
    let final_ack = words == 6 &&
      host.pending is Some(p) &&
      p.remaining == 0 &&
      execute_read(simulator, "memory_response_ready") == 1UL
    host.tick(simulator)
    if final_ack {
      saw_final_ack = true
      break
    }
  }
  assert_true(saw_gap)
  assert_true(saw_final_ack)
  assert_eq(execute_read(simulator, "store_completion_valid"), 1UL)
  assert_eq(concurrent_payload(simulator, "store"), [64UL, 0UL, 24UL, 0UL])
  assert_eq(execute_read(simulator, "compute_command_ready"), 1UL)
  concurrent_check_words(host, 1536UL, 3, 2, old)
  // No release-edge credit: compute was blocked on final response acceptance
  // and can accept only this following edge, while store completion is held.
  host.tick(simulator)
  concurrent_latched_noise(simulator, "compute")
  concurrent_wait(host, simulator, "compute", [65UL, 0UL])
  assert_eq(concurrent_payload(simulator, "store"), [64UL, 0UL, 24UL, 0UL])
  concurrent_check_words(host, 1536UL, 3, 2, old)
  concurrent_ack(host, simulator, "store")
  let expected = @flux_tile.matmul_int8_oracle(
    replacement,
    right,
    rows=3,
    columns=2,
    reduction=5,
  )
  concurrent_store(host, simulator, 0, 3, 2, 2048UL, expected)
  concurrent_ack(host, simulator, "compute")
}

///|
test "concurrent older loader wins until final physical bank commit not merely response ACK" {
  let host = PortableHost::new()
  let simulator = concurrent_prepare(3, 2, 5)
  ignore(concurrent_seed_old(host, simulator))
  let replacement = Array::make(15, -7)
  let right = [-128, 127, 5, -6, 7, -8, 9, -10, 11, -12]
  host.seed(32UL, 13UL, 3, 5, replacement)
  let first = host.requests.length()
  concurrent_transfer_offer(simulator, "load", 66, 0, 3, 5, 32UL, 13UL)
  host.tick(simulator)
  concurrent_latched_noise(simulator, "load")
  concurrent_compute_offer(simulator, 67, 3, 2, 5, c=1)
  let mut last_response = false
  for _ in 0..<1000 {
    assert_eq(execute_read(simulator, "compute_command_ready"), 0UL)
    let final_ack = host.requests.length() == first + 15 &&
      host.pending is Some(p) &&
      p.remaining == 0 &&
      execute_read(simulator, "memory_response_ready") == 1UL
    host.tick(simulator)
    if final_ack {
      last_response = true
      break
    }
  }
  assert_true(last_response)
  assert_eq(execute_read(simulator, "load_completion_valid"), 0UL)
  assert_eq(execute_read(simulator, "compute_command_ready"), 0UL)
  host.tick(simulator)
  assert_eq(execute_read(simulator, "load_completion_valid"), 1UL)
  assert_eq(execute_read(simulator, "compute_command_ready"), 1UL)
  host.tick(simulator)
  concurrent_latched_noise(simulator, "compute")
  concurrent_wait(host, simulator, "compute", [67UL, 0UL])
  assert_eq(concurrent_payload(simulator, "load"), [66UL, 0UL, 15UL, 0UL])
  let expected = @flux_tile.matmul_int8_oracle(
    replacement,
    right,
    rows=3,
    columns=2,
    reduction=5,
  )
  concurrent_store(host, simulator, 1, 3, 2, 2048UL, expected)
  concurrent_ack(host, simulator, "load")
  concurrent_ack(host, simulator, "compute")
}

///|
test "concurrent rejected compute takes no new load or store reservation" {
  let host = PortableHost::new()
  let simulator = concurrent_prepare(3, 2, 5)
  let old = concurrent_seed_old(host, simulator)
  host.memory[32UL] = 9
  for byte in 0..<120 {
    host.memory[1536UL + byte.to_uint64()] = 165
  }
  concurrent_transfer_offer(simulator, "load", 68, 0, 1, 1, 32UL, 1UL)
  concurrent_transfer_offer(simulator, "store", 69, 0, 3, 2, 1536UL, 40UL)
  concurrent_compute_offer(simulator, 70, 0, 0, 0)
  for channel in ["load", "compute", "store"] {
    assert_eq(execute_read(simulator, channel + "_command_ready"), 1UL)
  }
  host.tick(simulator)
  for channel in ["load", "compute", "store"] {
    concurrent_latched_noise(simulator, channel)
  }
  concurrent_wait(host, simulator, "compute", [70UL, 3UL])
  concurrent_wait(host, simulator, "load", [68UL, 0UL, 1UL, 0UL])
  concurrent_wait(host, simulator, "store", [69UL, 0UL, 24UL, 0UL])
  concurrent_check_words(host, 1536UL, 3, 2, old)
  for channel in ["load", "compute", "store"] {
    concurrent_ack(host, simulator, channel)
  }
  concurrent_reset(host, simulator)
  concurrent_load(host, simulator, 1, 0, 1, 1, 256UL, 1UL, [3])
  concurrent_transfer_offer(simulator, "load", 71, 0, 1, 1, 32UL, 1UL)
  concurrent_compute_offer(simulator, 72, 1, 1, 1)
  assert_eq(execute_read(simulator, "load_command_ready"), 1UL)
  assert_eq(execute_read(simulator, "compute_command_ready"), 1UL)
  host.tick(simulator)
  concurrent_latched_noise(simulator, "load")
  concurrent_latched_noise(simulator, "compute")
  concurrent_wait(host, simulator, "compute", [72UL, 4UL])
  concurrent_wait(host, simulator, "load", [71UL, 0UL, 1UL, 0UL])
  concurrent_ack(host, simulator, "compute")
  concurrent_ack(host, simulator, "load")
  concurrent_compute(host, simulator, 1, 1, 1)
  concurrent_store(host, simulator, 0, 1, 1, 2048UL, [27])
}

///|
test "concurrent discovery edge admissions count accepted transfer cancels and compute drains" {
  let host = PortableHost::new()
  let simulator = concurrent_prepare(3, 2, 64)
  ignore(concurrent_seed_old(host, simulator))
  ignore(concurrent_long_sources(host, simulator))
  host.seed(32UL, 80UL, 3, 64, Array::make(192, -7))
  concurrent_transfer_offer(simulator, "load", 91, 0, 3, 64, 32UL, 80UL)
  host.tick(simulator)
  concurrent_latched_noise(simulator, "load")
  let (address, _, _) = concurrent_inject(host, simulator, false, 1, true)
  concurrent_transfer_offer(simulator, "store", 92, 0, 3, 2, 1536UL, 40UL)
  concurrent_compute_offer(simulator, 93, 3, 2, 64, a=1, b=1, c=1)
  assert_eq(execute_read(simulator, "transport_halted"), 0UL)
  assert_eq(execute_read(simulator, "store_command_ready"), 1UL)
  assert_eq(execute_read(simulator, "compute_command_ready"), 1UL)
  let count = host.requests.length()
  host.tick(simulator)
  concurrent_latched_noise(simulator, "store")
  concurrent_latched_noise(simulator, "compute")
  assert_eq(execute_read(simulator, "transport_halted"), 1UL)
  concurrent_wait(host, simulator, "load", [91UL, 10UL, 0UL, address])
  concurrent_wait(host, simulator, "store", [92UL, 15UL, 0UL, 0UL])
  concurrent_wait(host, simulator, "compute", [93UL, 0UL])
  assert_eq(execute_read(simulator, "active_cycles"), 67UL)
  assert_eq(execute_read(simulator, "capture_cycles"), 6UL)
  assert_eq(host.requests.length(), count)
}
