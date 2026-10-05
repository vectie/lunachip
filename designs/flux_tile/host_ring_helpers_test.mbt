///|
// Reuse only the observed byte-memory environment. It answers descriptor and
// operand reads alike, checks held external requests and global tags, and
// never constructs device descriptors, schedules engines, or computes C.
fn host_ring_prepare(
  ring_depth? : Int = 8,
  queue_depth? : Int = 3,
  capacity? : Int = 64,
) -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(
    @flux_tile.ring_tile(
      rows=3,
      columns=2,
      max_reduction=capacity,
      host_bytes=4096UL,
      ring_depth~,
      queue_depth~,
    ),
  )
  for
    (name, width) in [
      ("reset", 1), ("config_valid", 1), ("config_base", 32),
      ("config_origin", 32), ("publish_valid", 1),
      ("publish_producer", 32), ("completion_ready", 1),
      ("memory_request_ready", 1), ("memory_response_valid", 1),
      ("memory_response_tag", 32), ("memory_response_fault", 2),
      ("memory_response_data", 32),
    ] {
    portable_put(simulator, name, width, 0UL)
  }
  portable_put(simulator, "reset", 1, 1UL)
  simulator.rising_edge("clock")
  portable_put(simulator, "reset", 1, 0UL)
  assert_eq(execute_read(simulator, "config_ready"), 1UL)
  assert_eq(execute_read(simulator, "configured"), 0UL)
  assert_eq(execute_read(simulator, "transport_halted"), 0UL)
  simulator
}

///|
fn host_ring_seed_descriptor(
  host : PortableHost,
  slot : Int,
  descriptor : @descriptor.Descriptor,
  base? : UInt64 = 1024UL,
) -> Unit raise {
  let bytes = descriptor.encode()
  assert_eq(bytes.length(), 32)
  for index in 0..<32 {
    host.memory[base + slot.to_uint64() * 32UL + index.to_uint64()] =
      bytes[index].to_int()
  }
}

///|
fn host_ring_fence(id : UInt) -> @descriptor.Descriptor {
  {
    opcode: Fence,
    id,
    rows: 0U,
    columns: 0U,
    reduction: 0U,
    base: 0U,
    stride: 0U,
  }
}

///|
fn host_ring_config(
  host : PortableHost,
  simulator : @sim.Simulator,
  origin? : UInt64 = 0UL,
) -> Unit raise {
  assert_eq(execute_read(simulator, "config_ready"), 1UL)
  portable_put(simulator, "config_base", 32, 1024UL)
  portable_put(simulator, "config_origin", 32, origin)
  portable_put(simulator, "config_valid", 1, 1UL)
  host.tick(simulator)
  portable_put(simulator, "config_valid", 1, 0UL)
  for _ in 0..<20 {
    if execute_read(simulator, "configured") == 1UL { break }
    host.tick(simulator)
  }
  assert_eq(execute_read(simulator, "configured"), 1UL)
  assert_eq(execute_read(simulator, "producer_count"), origin)
  assert_eq(execute_read(simulator, "consumer_count"), origin)
}

///|
fn host_ring_publish(
  host : PortableHost,
  simulator : @sim.Simulator,
  producer : UInt64,
) -> Unit raise {
  portable_put(simulator, "publish_producer", 32, producer)
  portable_put(simulator, "publish_valid", 1, 1UL)
  for _ in 0..<30000 {
    if execute_read(simulator, "publish_ready") == 1UL { break }
    host.tick(simulator)
  }
  assert_eq(execute_read(simulator, "publish_ready"), 1UL)
  host.tick(simulator)
  portable_put(simulator, "publish_valid", 1, 0UL)
}

///|
fn host_ring_completion_payload(simulator : @sim.Simulator) -> Array[UInt64] raise {
  ["id", "fault", "bytes_completed", "fault_address"].map(field => {
    execute_read(simulator, "completion_" + field)
  })
}

///|
fn host_ring_completion(
  host : PortableHost,
  simulator : @sim.Simulator,
  id : UInt64,
  fault : UInt64,
  bytes : UInt64,
  address? : UInt64 = 0UL,
) -> Unit raise {
  for _ in 0..<30000 {
    if execute_read(simulator, "completion_valid") == 1UL { break }
    host.tick(simulator)
  }
  assert_eq(execute_read(simulator, "completion_valid"), 1UL)
  for _ in 0..<4 {
    assert_eq(host_ring_completion_payload(simulator), [id, fault, bytes, address])
    // Descriptor fetch may legitimately continue during a held completion.
    host.tick(simulator)
  }
}

///|
fn host_ring_ack(host : PortableHost, simulator : @sim.Simulator) -> Unit raise {
  portable_put(simulator, "completion_ready", 1, 1UL)
  host.tick(simulator)
  portable_put(simulator, "completion_ready", 1, 0UL)
  assert_eq(execute_read(simulator, "completion_valid"), 0UL)
}

///|
fn host_ring_last_address(host : PortableHost) -> UInt64 raise {
  assert_true(host.requests.length() > 0)
  host.requests[host.requests.length() - 1][1]
}

///|
fn host_ring_data_reads(host : PortableHost) -> Int {
  host.requests.filter(request => {
    request[0] == 0UL && request[1] >= 32UL && request[1] < 96UL
  }).length()
}

///|
fn host_ring_corrupt_pending(
  host : PortableHost,
  status? : UInt64 = 0UL,
) -> Unit {
  let pending = host.pending.unwrap()
  host.pending = Some({
    ..pending,
    remaining: 0,
    tag: if status == 0UL { pending.tag + 1UL } else { pending.tag },
    fault: status,
  })
}

///|
fn host_ring_load(id : UInt) -> @descriptor.Descriptor {
  {
    opcode: LoadA,
    id,
    rows: 1U,
    columns: 64U,
    reduction: 0U,
    base: 32U,
    stride: 64U,
  }
}

///|
fn host_ring_reset_barrier(
  host : PortableHost,
  simulator : @sim.Simulator,
) -> Unit raise {
  portable_put(simulator, "reset", 1, 1UL)
  for name in ["config_ready", "publish_ready", "completion_valid",
               "memory_request_valid", "memory_response_ready"] {
    assert_eq(execute_read(simulator, name), 0UL)
  }
  simulator.rising_edge("clock")
  // This is a real external transport flush, not unilateral device reset.
  host.pending = None
  host.held = None
  host.requests.clear()
  host.fail_at = -1
  host.protocol_at = -1
  portable_put(simulator, "config_valid", 1, 0UL)
  portable_put(simulator, "publish_valid", 1, 0UL)
  portable_put(simulator, "completion_ready", 1, 0UL)
  portable_put(simulator, "memory_response_valid", 1, 0UL)
  portable_put(simulator, "reset", 1, 0UL)
  assert_eq(execute_read(simulator, "configured"), 0UL)
  assert_eq(execute_read(simulator, "transport_halted"), 0UL)
  assert_eq(execute_read(simulator, "producer_count"), 0UL)
  assert_eq(execute_read(simulator, "consumer_count"), 0UL)
}
