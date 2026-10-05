///|
test "host ring shares one tagged bus for fetched padded matrix commands and held completion" {
  let host = PortableHost::new()
  let simulator = host_ring_prepare()
  let left = Array::makei(15, index => (index * 47 + 13) % 256 - 128)
  let right = Array::makei(10, index => (index * 83 + 231) % 256 - 128)
  host.seed(32UL, 13UL, 3, 5, left)
  host.seed(256UL, 17UL, 5, 2, right)
  for address in 512..<632 {
    host.memory[address.to_uint64()] = 165
  }
  let commands : Array[@descriptor.Descriptor] = [
    {
      opcode: LoadA,
      id: 1U,
      rows: 3U,
      columns: 5U,
      reduction: 0U,
      base: 32U,
      stride: 13U,
    },
    {
      opcode: LoadB,
      id: 2U,
      rows: 5U,
      columns: 2U,
      reduction: 0U,
      base: 256U,
      stride: 17U,
    },
    {
      opcode: MatMul,
      id: 3U,
      rows: 3U,
      columns: 2U,
      reduction: 5U,
      base: 0U,
      stride: 0U,
    },
    {
      opcode: StoreC,
      id: 4U,
      rows: 3U,
      columns: 2U,
      reduction: 0U,
      base: 512U,
      stride: 40U,
    },
    host_ring_fence(5U),
  ]
  for index in 0..<commands.length() {
    host_ring_seed_descriptor(host, index, commands[index])
  }
  host_ring_config(host, simulator)
  host_ring_publish(host, simulator, 5UL)
  host_ring_completion(host, simulator, 1UL, 0UL, 15UL)
  for _ in 0..<30000 {
    if host.requests.length() == 175 && host.pending is None {
      break
    }
    assert_eq(host_ring_completion_payload(simulator), [1UL, 0UL, 15UL, 0UL])
    host.tick(simulator)
  }
  // D=3 queued entries plus one held active completion: the fifth fetched
  // packet cannot free its ring slot until the frontend accepts that packet.
  assert_eq(host.requests.length(), 175)
  assert_eq(execute_read(simulator, "consumer_count"), 4UL)
  for _ in 0..<12 {
    host.tick(simulator)
    assert_eq(host_ring_completion_payload(simulator), [1UL, 0UL, 15UL, 0UL])
    assert_eq(host.requests.length(), 175)
    assert_eq(execute_read(simulator, "consumer_count"), 4UL)
  }
  host_ring_ack(host, simulator)
  for (id, bytes) in [(2UL, 10UL), (3UL, 0UL), (4UL, 24UL), (5UL, 0UL)] {
    host_ring_completion(host, simulator, id, 0UL, bytes)
    host_ring_ack(host, simulator)
  }
  let expected = @flux_tile.matmul_int8_oracle(
    left,
    right,
    rows=3,
    columns=2,
    reduction=5,
  )
  for row in 0..<3 {
    for column in 0..<2 {
      assert_eq(
        host.word(512UL + row.to_uint64() * 40UL + column.to_uint64() * 4UL),
        expected[row * 2 + column],
      )
    }
    for byte in 8..<40 {
      assert_eq(
        host.memory
        .get(512UL + row.to_uint64() * 40UL + byte.to_uint64())
        .unwrap(),
        165,
      )
    }
  }
  assert_eq(host.requests.length(), 191)
  assert_eq(execute_read(simulator, "consumer_count"), 5UL)
  assert_eq(execute_read(simulator, "transport_halted"), 0UL)
  assert_eq(execute_read(simulator, "ring_fault_valid"), 0UL)
  assert_eq(execute_read(simulator, "active_cycles"), 8UL)
  assert_eq(execute_read(simulator, "capture_cycles"), 6UL)
  let mut saw_data = false
  let mut saw_later_descriptor = false
  for request in host.requests {
    if request[1] < 1024UL {
      saw_data = true
    }
    if saw_data && request[1] >= 1024UL {
      saw_later_descriptor = true
    }
  }
  assert_true(saw_later_descriptor)
}

///|
test "host ring legitimate origin wraps counters and physical slots through the shared bus" {
  let host = PortableHost::new()
  let simulator = host_ring_prepare(ring_depth=4)
  host_ring_seed_descriptor(host, 2, host_ring_fence(0xffffffffU))
  host_ring_seed_descriptor(host, 3, host_ring_fence(0U))
  host_ring_config(host, simulator, origin=0xfffffffeUL)
  host_ring_publish(host, simulator, 0UL)
  host_ring_completion(host, simulator, 0xffffffffUL, 0UL, 0UL)
  host_ring_ack(host, simulator)
  host_ring_completion(host, simulator, 0UL, 0UL, 0UL)
  host_ring_ack(host, simulator)
  assert_eq(execute_read(simulator, "consumer_count"), 0UL)
  assert_eq(host.requests.length(), 64)
  for index in 0..<64 {
    assert_eq(host.requests[index][1], 1088UL + index.to_uint64())
  }
  host_ring_seed_descriptor(host, 0, host_ring_fence(0U))
  host_ring_publish(host, simulator, 1UL)
  host_ring_completion(host, simulator, 0UL, 0UL, 0UL)
  host_ring_ack(host, simulator)
  assert_eq(execute_read(simulator, "consumer_count"), 1UL)
  assert_eq(host.requests.length(), 96)
  for index in 64..<96 {
    assert_eq(host.requests[index][1], 1024UL + (index - 64).to_uint64())
  }
}
