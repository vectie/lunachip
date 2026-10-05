///|
fn queued_concurrent_prepare(
  depth : Int,
  rows? : Int = 3,
  columns? : Int = 2,
  capacity? : Int = 5,
) -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(
    @flux_tile.queued_concurrent_tile(
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
  simulator
}

///|
fn queued_concurrent_packet(
  opcode : @descriptor.Opcode,
  id : Int,
  rows? : Int = 0,
  columns? : Int = 0,
  reduction? : Int = 0,
  base? : UInt64 = 0UL,
  stride? : UInt64 = 0UL,
  a? : Int = 0,
  b? : Int = 0,
  c? : Int = 0,
) -> Array[UInt64] raise {
  let descriptor : @slotted_descriptor.Descriptor = {
    opcode,
    id: id.reinterpret_as_uint(),
    rows: rows.reinterpret_as_uint(),
    columns: columns.reinterpret_as_uint(),
    reduction: reduction.reinterpret_as_uint(),
    base: base.to_uint(),
    stride: stride.to_uint(),
    a_slot: a.reinterpret_as_uint(),
    b_slot: b.reinterpret_as_uint(),
    c_slot: c.reinterpret_as_uint(),
  }
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
fn queued_concurrent_enqueue(
  host : PortableHost,
  simulator : @sim.Simulator,
  lanes : Array[UInt64],
) -> Unit raise {
  frontend_enqueue(host, simulator, lanes)
  // Atomic admission must retain all lanes after the caller changes them.
  for index in 0..<4 {
    portable_put(simulator, "descriptor_lane_" + index.to_string(), 64, 0UL)
  }
}

///|
fn queued_concurrent_payload(simulator : @sim.Simulator) -> Array[UInt64] raise {
  ["id", "fault", "bytes_completed", "fault_address"].map(field => {
    execute_read(simulator, "completion_" + field)
  })
}

///|
fn queued_concurrent_completion(
  host : PortableHost,
  simulator : @sim.Simulator,
  expected : Array[UInt64],
) -> Unit raise {
  for _ in 0..<40000 {
    if execute_read(simulator, "completion_valid") == 1UL {
      break
    }
    host.tick(simulator)
  }
  assert_eq(execute_read(simulator, "completion_valid"), 1UL)
  for _ in 0..<4 {
    assert_eq(queued_concurrent_payload(simulator), expected)
    host.tick(simulator)
    assert_eq(execute_read(simulator, "completion_valid"), 1UL)
  }
  // Younger engines may use memory while an older retirement is held.
  assert_eq(queued_concurrent_payload(simulator), expected)
}

///|
fn queued_concurrent_ack(
  host : PortableHost,
  simulator : @sim.Simulator,
) -> Unit raise {
  assert_eq(execute_read(simulator, "completion_valid"), 1UL)
  portable_put(simulator, "completion_ready", 1, 1UL)
  host.tick(simulator)
  portable_put(simulator, "completion_ready", 1, 0UL)
  // The next already-terminal entry may be visible without a bubble.
}

///|
fn queued_concurrent_drain(
  host : PortableHost,
  simulator : @sim.Simulator,
  expected : Array[Array[UInt64]],
) -> Unit raise {
  for payload in expected {
    queued_concurrent_completion(host, simulator, payload)
    queued_concurrent_ack(host, simulator)
  }
}

///|
fn queued_concurrent_load(
  host : PortableHost,
  simulator : @sim.Simulator,
  operand : Int,
  slot : Int,
  rows : Int,
  columns : Int,
  base : UInt64,
  stride : UInt64,
  data : Array[Int],
) -> Unit raise {
  host.seed(base, stride, rows, columns, data)
  queued_concurrent_enqueue(
    host,
    simulator,
    queued_concurrent_packet(
      if operand == 0 {
        LoadA
      } else {
        LoadB
      },
      10,
      rows~,
      columns~,
      base~,
      stride~,
      a=if operand == 0 { slot } else { 0 },
      b=if operand == 1 { slot } else { 0 },
    ),
  )
  queued_concurrent_drain(host, simulator, [
    [10UL, 0UL, (rows * columns).to_uint64(), 0UL],
  ])
}

///|
fn queued_concurrent_compute(
  host : PortableHost,
  simulator : @sim.Simulator,
  rows : Int,
  columns : Int,
  reduction : Int,
  a? : Int = 0,
  b? : Int = 0,
  c? : Int = 0,
) -> Unit raise {
  queued_concurrent_enqueue(
    host,
    simulator,
    queued_concurrent_packet(
      MatMul,
      20,
      rows~,
      columns~,
      reduction~,
      a~,
      b~,
      c~,
    ),
  )
  queued_concurrent_drain(host, simulator, [[20UL, 0UL, 0UL, 0UL]])
}

///|
fn queued_concurrent_store(
  host : PortableHost,
  simulator : @sim.Simulator,
  slot : Int,
  rows : Int,
  columns : Int,
  base : UInt64,
  expected : Array[Int],
) -> Unit raise {
  for byte in 0..<(rows * 40) {
    host.memory[base + byte.to_uint64()] = 165
  }
  queued_concurrent_enqueue(
    host,
    simulator,
    queued_concurrent_packet(
      StoreC,
      30,
      rows~,
      columns~,
      base~,
      stride=40UL,
      c=slot,
    ),
  )
  queued_concurrent_drain(host, simulator, [
    [30UL, 0UL, (rows * columns * 4).to_uint64(), 0UL],
  ])
  concurrent_check_words(host, base, rows, columns, expected)
}

///|
fn queued_concurrent_seed_old(
  host : PortableHost,
  simulator : @sim.Simulator,
) -> Array[Int] raise {
  let left = [1, -2, 3, -4, 5, -6, 7, -8, 9, -10, 11, -12, 13, -14, 15]
  let right = [-128, 127, 5, -6, 7, -8, 9, -10, 11, -12]
  queued_concurrent_load(host, simulator, 0, 0, 3, 5, 32UL, 13UL, left)
  queued_concurrent_load(host, simulator, 1, 0, 5, 2, 256UL, 17UL, right)
  queued_concurrent_compute(host, simulator, 3, 2, 5)
  @flux_tile.matmul_int8_oracle(left, right, rows=3, columns=2, reduction=5)
}

///|
fn queued_concurrent_reset(
  host : PortableHost,
  simulator : @sim.Simulator,
) -> Unit raise {
  frontend_present(simulator, queued_concurrent_packet(Fence, 999))
  portable_put(simulator, "completion_ready", 1, 1UL)
  portable_put(simulator, "memory_response_valid", 1, 1UL)
  portable_put(simulator, "reset", 1, 1UL)
  for
    name in [
      "descriptor_ready", "completion_valid", "memory_request_valid", "memory_response_ready",
    ] {
    assert_eq(execute_read(simulator, name), 0UL)
  }
  simulator.rising_edge("clock")
  host.pending = None
  host.held = None
  host.requests.clear()
  host.fail_at = -1
  host.protocol_at = -1
  portable_put(simulator, "descriptor_valid", 1, 0UL)
  portable_put(simulator, "completion_ready", 1, 0UL)
  portable_put(simulator, "memory_response_valid", 1, 0UL)
  portable_put(simulator, "reset", 1, 0UL)
  for _ in 0..<4 {
    host.tick(simulator)
    assert_eq(execute_read(simulator, "completion_valid"), 0UL)
    assert_eq(execute_read(simulator, "queue_occupancy"), 0UL)
  }
  assert_eq(execute_read(simulator, "halted"), 0UL)
  assert_eq(execute_read(simulator, "descriptor_ready"), 1UL)
}
