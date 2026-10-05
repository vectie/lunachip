///|
test "ring concurrent three real bus clients overlap Run capture and ordered duplicate retirement" {
  let host = PortableHost::new()
  let simulator = ring_concurrent_prepare()
  ring_concurrent_config(host, simulator)
  let old = ring_concurrent_seed(host, simulator, large=true)
  let expected = ring_concurrent_operands(host, simulator)
  host.seed(32UL, 80UL, 8, 64, Array::make(512, -7))
  host.memory[3000UL] = 9
  for base in [4096UL, 4608UL, 5120UL] {
    for byte in 0..<320 {
      host.memory[base + byte.to_uint64()] = 165
    }
  }
  ring_concurrent_submit(host, simulator, 5UL, [
    queued_concurrent_packet(
      LoadA,
      77,
      rows=8,
      columns=64,
      base=32UL,
      stride=80UL,
    ),
    queued_concurrent_packet(
      StoreC,
      77,
      rows=8,
      columns=8,
      base=4096UL,
      stride=40UL,
    ),
    queued_concurrent_packet(
      MatMul,
      77,
      rows=8,
      columns=8,
      reduction=64,
      a=1,
      b=1,
      c=1,
    ),
    queued_concurrent_packet(
      StoreC,
      77,
      rows=8,
      columns=8,
      base=5120UL,
      stride=40UL,
      c=1,
    ),
    queued_concurrent_packet(
      MatMul,
      77,
      rows=8,
      columns=8,
      reduction=64,
      a=1,
      b=1,
    ),
    queued_concurrent_packet(
      StoreC,
      77,
      rows=8,
      columns=8,
      base=4608UL,
      stride=40UL,
    ),
    queued_concurrent_packet(Fence, 78),
    queued_concurrent_packet(
      LoadB,
      79,
      rows=1,
      columns=1,
      base=3000UL,
      stride=1UL,
    ),
  ])
  let seen = Array::make(12, false)
  let mut younger_finished = false
  let mut held_progress = false
  let mut after_fence = false
  for _ in 0..<80000 {
    let held = execute_read(simulator, "completion_valid") == 1UL
    if held {
      assert_eq(queued_concurrent_payload(simulator), [77UL, 0UL, 512UL, 0UL])
    }
    let count = host.requests.length()
    let store_ack = host.pending is Some(p) &&
      p.remaining == 0 &&
      execute_read(simulator, "memory_response_ready") == 1UL &&
      count > 0 &&
      host.requests[count - 1][0] == 1UL &&
      host.requests[count - 1][1] == 4404UL
    ring_concurrent_observe(host, simulator, seen)
    if store_ack && execute_read(simulator, "completion_valid") == 0UL {
      younger_finished = true
    }
    if held && host.requests.length() > count {
      held_progress = true
    }
    if host.requests.length() > count && host.requests[count][1] == 3000UL {
      after_fence = true
    }
    if after_fence && host.pending is None {
      break
    }
  }
  // Distinct physical traffic classes and actual response ACKs, not inferred
  // busy flags: reader/loader/storer each coincide with advancing Run/capture.
  assert_eq(seen, Array::make(12, true))
  assert_true(younger_finished)
  assert_true(held_progress)
  assert_true(after_fence)
  concurrent_check_words(host, 4096UL, 8, 8, old)
  concurrent_check_words(host, 4608UL, 8, 8, expected)
  concurrent_check_words(host, 5120UL, 8, 8, expected)
  assert_eq(execute_read(simulator, "consumer_count"), 13UL)
  queued_concurrent_drain(host, simulator, [
    [77UL, 0UL, 512UL, 0UL],
    [77UL, 0UL, 256UL, 0UL],
    [77UL, 0UL, 0UL, 0UL],
    [77UL, 0UL, 256UL, 0UL],
    [77UL, 0UL, 0UL, 0UL],
    [77UL, 0UL, 256UL, 0UL],
    [78UL, 0UL, 0UL, 0UL],
    [79UL, 0UL, 1UL, 0UL],
  ])
  assert_eq(execute_read(simulator, "queue_occupancy"), 0UL)
  assert_eq(execute_read(simulator, "ring_fault_valid"), 0UL)
}
