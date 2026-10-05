///|
// Manual descriptor construction is independent of the public codec. Each
// element is one atomic little-endian 64-bit lane of the 32-byte draft.
fn frontend_descriptor(
  opcode : UInt64,
  id : UInt64,
  rows : UInt64,
  columns : UInt64,
  reduction : UInt64,
  base : UInt64,
  stride : UInt64,
) -> Array[UInt64] {
  [
    256UL | (opcode << 16) | (id << 32),
    rows | (columns << 16) | (reduction << 32),
    base | (stride << 32),
    0UL,
  ]
}

///|
fn frontend_encoded(descriptor : @descriptor.Descriptor) -> Array[UInt64] raise {
  let bytes = descriptor.encode()
  Array::makei(4, lane => {
    let mut value = 0UL
    for byte in 0..<8 {
      value = value | (bytes[lane * 8 + byte].to_uint64() << (byte * 8))
    }
    value
  })
}

///|
fn frontend_prepare(
  depth : Int,
  rows? : Int = 3,
  columns? : Int = 2,
  capacity? : Int = 5,
) -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(
    @flux_tile.queued_tile(
      rows~,
      columns~,
      max_reduction=capacity,
      host_bytes=4096UL,
      queue_depth=depth,
    ),
  )
  for
    (name, width) in [
      ("reset", 1),
      ("descriptor_valid", 1),
      ("descriptor_lane_0", 64),
      ("descriptor_lane_1", 64),
      ("descriptor_lane_2", 64),
      ("descriptor_lane_3", 64),
      ("completion_ready", 1),
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
  assert_eq(execute_read(simulator, "descriptor_ready"), 1UL)
  assert_eq(execute_read(simulator, "queue_occupancy"), 0UL)
  assert_eq(execute_read(simulator, "halted"), 0UL)
  simulator
}

///|
fn frontend_present(
  simulator : @sim.Simulator,
  lanes : Array[UInt64],
) -> Unit raise {
  assert_eq(lanes.length(), 4)
  for index in 0..<4 {
    portable_put(
      simulator,
      "descriptor_lane_" + index.to_string(),
      64,
      lanes[index],
    )
  }
  portable_put(simulator, "descriptor_valid", 1, 1UL)
}

///|
fn frontend_enqueue(
  host : PortableHost,
  simulator : @sim.Simulator,
  lanes : Array[UInt64],
) -> Unit raise {
  frontend_present(simulator, lanes)
  for _ in 0..<10000 {
    if execute_read(simulator, "descriptor_ready") == 1UL {
      break
    }
    host.tick(simulator)
  }
  assert_eq(execute_read(simulator, "descriptor_ready"), 1UL)
  host.tick(simulator)
  portable_put(simulator, "descriptor_valid", 1, 0UL)
}

///|
fn frontend_completion(
  host : PortableHost,
  simulator : @sim.Simulator,
  id : UInt64,
  fault : UInt64,
  bytes : UInt64,
  address? : UInt64 = 0UL,
) -> Unit raise {
  for _ in 0..<10000 {
    if execute_read(simulator, "completion_valid") == 1UL {
      break
    }
    host.tick(simulator)
  }
  assert_eq(execute_read(simulator, "completion_valid"), 1UL)
  let expected = [id, fault, bytes, address]
  for _ in 0..<4 {
    assert_eq(
      ["id", "fault", "bytes_completed", "fault_address"].map(field => {
        execute_read(simulator, "completion_" + field)
      }),
      expected,
    )
    assert_eq(execute_read(simulator, "memory_request_valid"), 0UL)
    host.tick(simulator)
  }
}

///|
fn frontend_ack(host : PortableHost, simulator : @sim.Simulator) -> Unit raise {
  portable_put(simulator, "completion_ready", 1, 1UL)
  host.tick(simulator)
  portable_put(simulator, "completion_ready", 1, 0UL)
  assert_eq(execute_read(simulator, "completion_valid"), 0UL)
}

///|
fn frontend_reset_barrier(
  host : PortableHost,
  simulator : @sim.Simulator,
) -> Unit raise {
  portable_put(simulator, "reset", 1, 1UL)
  portable_put(simulator, "descriptor_valid", 1, 0UL)
  portable_put(simulator, "memory_response_valid", 1, 0UL)
  assert_eq(execute_read(simulator, "descriptor_ready"), 0UL)
  assert_eq(execute_read(simulator, "completion_valid"), 0UL)
  assert_eq(execute_read(simulator, "memory_request_valid"), 0UL)
  assert_eq(execute_read(simulator, "memory_response_ready"), 0UL)
  simulator.rising_edge("clock")
  // Flush the external transport as well; accepted host writes survive.
  host.pending = None
  host.held = None
  host.requests.clear()
  host.fail_at = -1
  host.protocol_at = -1
  portable_put(simulator, "reset", 1, 0UL)
  assert_eq(execute_read(simulator, "halted"), 0UL)
  assert_eq(execute_read(simulator, "queue_occupancy"), 0UL)
  assert_eq(execute_read(simulator, "descriptor_ready"), 1UL)
}
