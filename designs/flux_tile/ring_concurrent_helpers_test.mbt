///|
fn ring_concurrent_prepare(
  ring_depth~ : Int32 = 16,
  queue_depth~ : Int32 = 16,
  rows~ : Int32 = 8,
  columns~ : Int32 = 8,
  capacity~ : Int32 = 64,
  word_reads~ : Bool = false,
) -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(
    if word_reads {
      @flux_tile.ring_concurrent_word_tile(
        rows~,
        columns~,
        max_reduction=capacity,
        host_bytes=16384UL,
        ring_depth~,
        queue_depth~,
      )
    } else {
      @flux_tile.ring_concurrent_tile(
        rows~,
        columns~,
        max_reduction=capacity,
        host_bytes=16384UL,
        ring_depth~,
        queue_depth~,
      )
    },
  )
  for
    (name, width) in [
      ("reset", 1),
      ("config_valid", 1),
      ("config_base", 32),
      ("config_origin", 32),
      ("publish_valid", 1),
      ("publish_producer", 32),
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
  assert_eq(execute_read(simulator, "config_ready"), 1UL)
  simulator
}

///|
fn ring_concurrent_config(
  host : PortableHost,
  simulator : @sim.Simulator,
  origin~ : UInt64 = 0UL,
) -> Unit raise {
  portable_put(simulator, "config_base", 32, 8192UL)
  portable_put(simulator, "config_origin", 32, origin)
  portable_put(simulator, "config_valid", 1, 1UL)
  assert_eq(execute_read(simulator, "config_ready"), 1UL)
  host.tick(simulator)
  portable_put(simulator, "config_valid", 1, 0UL)
  for _ in 0..<20 {
    if execute_read(simulator, "configured") == 1UL {
      break
    }
    host.tick(simulator)
  }
  assert_eq(execute_read(simulator, "configured"), 1UL)
  assert_eq(execute_read(simulator, "producer_count"), origin)
  assert_eq(execute_read(simulator, "consumer_count"), origin)
}

///|
// These are host-owned bytes, not a software queue/controller. Publication is
// the sole device stimulus; consumer_count grants physical slot reuse.
fn ring_concurrent_submit(
  host : PortableHost,
  simulator : @sim.Simulator,
  sequence : UInt64,
  packets : Array[Array[UInt64]],
  depth~ : Int32 = 16,
) -> Unit raise {
  assert_true(packets.length() <= depth)
  for index in 0..<packets.length() {
    let slot = (sequence + index.to_uint64()) % depth.to_uint64()
    for lane in 0..<4 {
      for byte in 0..<8 {
        host.memory[8192UL + slot * 32UL + (lane * 8 + byte).to_uint64()] = ((
          packets[index][lane] >> (byte * 8)
        ) &
        255UL).to_int()
      }
    }
  }
  host_ring_publish(
    host,
    simulator,
    (sequence + packets.length().to_uint64()) & 4294967295UL,
  )
}

///|
fn ring_concurrent_one(
  host : PortableHost,
  simulator : @sim.Simulator,
  sequence : UInt64,
  packet : Array[UInt64],
  expected : Array[UInt64],
) -> Unit raise {
  ring_concurrent_submit(host, simulator, sequence, [packet])
  queued_concurrent_drain(host, simulator, [expected])
  assert_eq(execute_read(simulator, "consumer_count"), sequence + 1UL)
}

///|
fn ring_concurrent_seed(
  host : PortableHost,
  simulator : @sim.Simulator,
  large~ : Bool = false,
) -> Array[Int32] raise {
  let rows = if large { 8 } else { 3 }
  let columns = if large { 8 } else { 2 }
  let left = Array::makei(rows * 5, i => (i * 47 + 13) % 256 - 128)
  let right = Array::makei(5 * columns, i => (i * 83 + 231) % 256 - 128)
  host.seed(32UL, 16UL, rows, 5, left)
  host.seed(256UL, 16UL, 5, columns, right)
  ring_concurrent_submit(host, simulator, 0UL, [
    queued_concurrent_packet(
      LoadA,
      10,
      rows~,
      columns=5,
      base=32UL,
      stride=16UL,
    ),
    queued_concurrent_packet(
      LoadB,
      11,
      rows=5,
      columns~,
      base=256UL,
      stride=16UL,
    ),
    queued_concurrent_packet(MatMul, 12, rows~, columns~, reduction=5),
  ])
  queued_concurrent_drain(host, simulator, [
    [10UL, 0UL, (rows * 5).to_uint64(), 0UL],
    [11UL, 0UL, (5 * columns).to_uint64(), 0UL],
    [12UL, 0UL, 0UL, 0UL],
  ])
  @flux_tile.matmul_int8_oracle(left, right, rows~, columns~, reduction=5)
}

///|
fn ring_concurrent_operands(
  host : PortableHost,
  simulator : @sim.Simulator,
) -> Array[Int32] raise {
  let left = Array::makei(512, i => (i * 47 + 13) % 256 - 128)
  let right = Array::makei(512, i => (i * 83 + 231) % 256 - 128)
  host.seed(512UL, 80UL, 8, 64, left)
  host.seed(1280UL, 16UL, 64, 8, right)
  ring_concurrent_submit(host, simulator, 3UL, [
    queued_concurrent_packet(
      LoadA,
      13,
      rows=8,
      columns=64,
      base=512UL,
      stride=80UL,
      a=1,
    ),
    queued_concurrent_packet(
      LoadB,
      14,
      rows=64,
      columns=8,
      base=1280UL,
      stride=16UL,
      b=1,
    ),
  ])
  queued_concurrent_drain(host, simulator, [
    [13UL, 0UL, 512UL, 0UL],
    [14UL, 0UL, 512UL, 0UL],
  ])
  @flux_tile.matmul_int8_oracle(left, right, rows=8, columns=8, reduction=64)
}

///|
fn ring_concurrent_observe(
  host : PortableHost,
  simulator : @sim.Simulator,
  seen : Array[Bool],
) -> Unit raise {
  let active = execute_read(simulator, "active_cycles")
  let capture = execute_read(simulator, "capture_cycles")
  let count = host.requests.length()
  let ack = host.pending is Some(p) &&
    p.remaining == 0 &&
    execute_read(simulator, "memory_response_ready") == 1UL
  let previous = if count > 0 { Some(host.requests[count - 1]) } else { None }
  host.tick(simulator)
  let run = execute_read(simulator, "active_cycles") > active
  let capturing = execute_read(simulator, "capture_cycles") > capture
  for
    (accepted, request, offset) in [
      (
        host.requests.length() > count,
        if host.requests.length() > count {
          Some(host.requests[count])
        } else {
          None
        },
        0,
      ),
      (ack, previous, 6),
    ] {
    if accepted && request is Some(r) {
      let owner = if r[0] == 1UL { 2 } else if r[1] >= 8192UL { 0 } else { 1 }
      if run {
        seen[offset + owner * 2] = true
      }
      if capturing {
        seen[offset + owner * 2 + 1] = true
      }
    }
  }
}

///|
fn ring_concurrent_reset(
  host : PortableHost,
  simulator : @sim.Simulator,
) -> Unit raise {
  portable_put(simulator, "config_valid", 1, 1UL)
  portable_put(simulator, "publish_valid", 1, 1UL)
  portable_put(simulator, "completion_ready", 1, 1UL)
  portable_put(simulator, "memory_response_valid", 1, 1UL)
  portable_put(simulator, "reset", 1, 1UL)
  for
    name in [
      "config_ready", "publish_ready", "completion_valid", "memory_request_valid",
      "memory_response_ready",
    ] {
    assert_eq(execute_read(simulator, name), 0UL)
  }
  simulator.rising_edge("clock")
  // Flush the actually outstanding external request/response before release.
  host.pending = None
  host.held = None
  host.requests.clear()
  host.fail_at = -1
  host.protocol_at = -1
  for
    name in [
      "config_valid", "publish_valid", "completion_ready", "memory_response_valid",
      "reset",
    ] {
    portable_put(simulator, name, 1, 0UL)
  }
  for _ in 0..<4 {
    host.tick(simulator)
  }
  for
    name in [
      "configured", "producer_count", "consumer_count", "queue_occupancy", "completion_valid",
      "ring_fault_valid", "transport_halted",
    ] {
    assert_eq(execute_read(simulator, name), 0UL)
  }
}
