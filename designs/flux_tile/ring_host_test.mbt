///|
fn ring_prepare(
  depth : Int,
  aperture? : UInt64 = 4096UL,
) -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(
    @flux_tile.descriptor_ring_reader(host_bytes=aperture, ring_depth=depth),
  )
  for
    (name, width) in [
      ("reset", 1),
      ("config_valid", 1),
      ("config_base", 32),
      ("config_origin", 32),
      ("publish_valid", 1),
      ("publish_producer", 32),
      ("descriptor_ready", 1),
      ("memory_request_ready", 1),
      ("memory_response_valid", 1),
      ("memory_response_tag", 32),
      ("memory_response_fault", 2),
      ("memory_response_data", 32),
    ] {
    portable_put(simulator, name, width, 0UL)
  }
  portable_put(simulator, "reset", 1, 1UL)
  simulator.rising_edge("clock")
  portable_put(simulator, "reset", 1, 0UL)
  assert_eq(execute_read(simulator, "config_ready"), 1UL)
  assert_eq(execute_read(simulator, "configured"), 0UL)
  assert_eq(execute_read(simulator, "publish_ready"), 0UL)
  simulator
}

///|
fn ring_config(
  host : PortableHost,
  simulator : @sim.Simulator,
  base : UInt64,
  origin : UInt64,
) -> Unit raise {
  assert_eq(execute_read(simulator, "config_ready"), 1UL)
  portable_put(simulator, "config_base", 32, base)
  portable_put(simulator, "config_origin", 32, origin)
  portable_put(simulator, "config_valid", 1, 1UL)
  host.tick(simulator)
  portable_put(simulator, "config_valid", 1, 0UL)
  assert_eq(execute_read(simulator, "configured"), 0UL)
  assert_eq(execute_read(simulator, "config_ready"), 0UL)
  host.tick(simulator)
}

///|
fn ring_publish(
  host : PortableHost,
  simulator : @sim.Simulator,
  producer : UInt64,
) -> Unit raise {
  assert_eq(execute_read(simulator, "publish_ready"), 1UL)
  portable_put(simulator, "publish_producer", 32, producer)
  portable_put(simulator, "publish_valid", 1, 1UL)
  host.tick(simulator)
  portable_put(simulator, "publish_valid", 1, 0UL)
}

///|
fn ring_seed(
  host : PortableHost,
  address : UInt64,
  lanes : Array[UInt64],
) -> Unit raise {
  assert_eq(lanes.length(), 4)
  for byte in 0..<32 {
    host.memory[address + byte.to_uint64()] = ((
      lanes[byte / 8] >> (byte % 8 * 8)
    ) &
    255UL).to_int()
  }
}

///|
fn ring_lanes(seed : Int) -> Array[UInt64] {
  Array::makei(4, lane => {
    let mut bits = 0UL
    for byte in 0..<8 {
      bits = bits |
        (((seed * 47 + lane * 83 + byte * 23) % 256).to_uint64() << (byte * 8))
    }
    bits
  })
}

///|
fn ring_packet(
  host : PortableHost,
  simulator : @sim.Simulator,
  expected : Array[UInt64],
  consumer : UInt64,
) -> Unit raise {
  for _ in 0..<10000 {
    if execute_read(simulator, "descriptor_valid") == 1UL {
      break
    }
    assert_eq(execute_read(simulator, "fault_valid"), 0UL)
    assert_eq(execute_read(simulator, "consumer_count"), consumer)
    host.tick(simulator)
  }
  assert_eq(execute_read(simulator, "descriptor_valid"), 1UL)
  let requests = host.requests.length()
  for _ in 0..<4 {
    assert_eq(
      Array::makei(4, index => {
        execute_read(simulator, "descriptor_lane_" + index.to_string())
      }),
      expected,
    )
    assert_eq(execute_read(simulator, "consumer_count"), consumer)
    assert_eq(execute_read(simulator, "publish_ready"), 0UL)
    assert_eq(execute_read(simulator, "memory_request_valid"), 0UL)
    host.tick(simulator)
    assert_eq(host.requests.length(), requests)
  }
}

///|
fn ring_ack(
  host : PortableHost,
  simulator : @sim.Simulator,
  consumer : UInt64,
) -> Unit raise {
  portable_put(simulator, "descriptor_ready", 1, 1UL)
  host.tick(simulator)
  portable_put(simulator, "descriptor_ready", 1, 0UL)
  assert_eq(
    execute_read(simulator, "consumer_count"),
    (consumer + 1UL) & 0xffffffffUL,
  )
  assert_eq(execute_read(simulator, "descriptor_valid"), 0UL)
}

///|
fn ring_fault(
  host : PortableHost,
  simulator : @sim.Simulator,
  code : UInt64,
  address : UInt64,
  configured : UInt64,
) -> Unit raise {
  for _ in 0..<1000 {
    if execute_read(simulator, "fault_valid") == 1UL {
      break
    }
    host.tick(simulator)
  }
  for _ in 0..<4 {
    assert_eq(execute_read(simulator, "fault_valid"), 1UL)
    assert_eq(execute_read(simulator, "fault_code"), code)
    assert_eq(execute_read(simulator, "fault_address"), address)
    assert_eq(execute_read(simulator, "configured"), configured)
    for
      name in [
        "config_ready", "publish_ready", "memory_request_valid", "memory_response_ready",
        "descriptor_valid",
      ] {
      assert_eq(execute_read(simulator, name), 0UL)
    }
    host.tick(simulator)
  }
}

///|
fn ring_reset_barrier(
  host : PortableHost,
  simulator : @sim.Simulator,
) -> Unit raise {
  portable_put(simulator, "reset", 1, 1UL)
  for
    name in [
      "config_ready", "publish_ready", "memory_request_valid", "memory_response_ready",
      "descriptor_valid", "fault_valid",
    ] {
    assert_eq(execute_read(simulator, name), 0UL)
  }
  simulator.rising_edge("clock")
  host.pending = None
  host.held = None
  host.requests.clear()
  host.fail_at = -1
  host.protocol_at = -1
  portable_put(simulator, "config_valid", 1, 0UL)
  portable_put(simulator, "publish_valid", 1, 0UL)
  portable_put(simulator, "memory_response_valid", 1, 0UL)
  portable_put(simulator, "descriptor_ready", 1, 0UL)
  portable_put(simulator, "reset", 1, 0UL)
  assert_eq(execute_read(simulator, "configured"), 0UL)
  assert_eq(execute_read(simulator, "producer_count"), 0UL)
  assert_eq(execute_read(simulator, "consumer_count"), 0UL)
  assert_eq(execute_read(simulator, "config_ready"), 1UL)
}
