///|
test "queued tile empty no-bypass full refill and non-power-of-two wrap preserve raw ids" {
  let host = PortableHost::new()
  let simulator = frontend_prepare(3)
  frontend_enqueue(
    host,
    simulator,
    frontend_descriptor(4UL, 0xffffffffUL, 0UL, 0UL, 0UL, 0UL, 0UL),
  )
  assert_eq(execute_read(simulator, "queue_occupancy"), 1UL)
  assert_eq(execute_read(simulator, "completion_valid"), 0UL)
  host.tick(simulator)
  assert_eq(execute_read(simulator, "queue_occupancy"), 0UL)
  for id in 1..<4 {
    frontend_enqueue(
      host,
      simulator,
      frontend_descriptor(4UL, id.to_uint64(), 0UL, 0UL, 0UL, 0UL, 0UL),
    )
  }
  assert_eq(execute_read(simulator, "queue_occupancy"), 3UL)
  assert_eq(execute_read(simulator, "descriptor_ready"), 0UL)
  frontend_present(
    simulator,
    frontend_descriptor(4UL, 4UL, 0UL, 0UL, 0UL, 0UL, 0UL),
  )
  frontend_completion(host, simulator, 0xffffffffUL, 0UL, 0UL)
  assert_eq(execute_read(simulator, "queue_occupancy"), 3UL)
  frontend_ack(host, simulator)
  assert_eq(execute_read(simulator, "queue_occupancy"), 3UL)
  assert_eq(execute_read(simulator, "descriptor_ready"), 1UL)
  host.tick(simulator) // Full queue reads old head while replacing its slot.
  portable_put(simulator, "descriptor_valid", 1, 0UL)
  assert_eq(execute_read(simulator, "queue_occupancy"), 3UL)
  for id in 1..<5 {
    frontend_completion(host, simulator, id.to_uint64(), 0UL, 0UL)
    frontend_ack(host, simulator)
  }
  for id in 5..<17 {
    frontend_enqueue(
      host,
      simulator,
      frontend_descriptor(4UL, id.to_uint64(), 0UL, 0UL, 0UL, 0UL, 0UL),
    )
    frontend_completion(host, simulator, id.to_uint64(), 0UL, 0UL)
    frontend_ack(host, simulator)
  }
  assert_eq(host.requests.length(), 0)
  assert_eq(execute_read(simulator, "queue_occupancy"), 0UL)
}

///|
test "queued tile snapshots all lanes and validates syntax in completion order without issue" {
  let host = PortableHost::new()
  let simulator = frontend_prepare(3)
  let cases : Array[(Array[UInt64], UInt64)] = [
    ([0x1122334401070001UL, 0xffffffffffffffffUL, 0UL, 1UL], 12UL),
    ([0x1122334501070200UL, 0xffffffffffffffffUL, 0UL, 1UL], 12UL),
    ([0x1122334b000001ffUL, 0UL, 0UL, 0UL], 12UL),
    ([0x1122334c0000ff00UL, 0UL, 0UL, 0UL], 12UL),
    ([0x1122334601070100UL, 0xffffffffffffffffUL, 0UL, 1UL], 13UL),
    ([256UL | (7UL << 16) | (0x11223347UL << 32), 0xffffUL, 0UL, 0UL], 1UL),
    (frontend_descriptor(255UL, 0x1122334dUL, 0UL, 0UL, 0UL, 0UL, 0UL), 1UL),
    (frontend_descriptor(8UL, 0x1122334eUL, 1UL, 1UL, 0UL, 32UL, 1UL), 1UL),
    (frontend_descriptor(5UL, 0x1122334fUL, 0UL, 0UL, 0UL, 0UL, 0UL), 1UL),
    (frontend_descriptor(0UL, 0x11223348UL, 8192UL, 1UL, 0UL, 0UL, 1UL), 14UL),
    (frontend_descriptor(4UL, 0x11223349UL, 1UL, 0UL, 0UL, 0UL, 0UL), 2UL),
    (frontend_descriptor(0UL, 0x1122334aUL, 0UL, 1UL, 0UL, 0UL, 1UL), 3UL),
  ]
  for (lanes, fault) in cases {
    frontend_enqueue(host, simulator, lanes)
    // Post-handshake producer changes must not alter the queued snapshot.
    for index in 0..<4 {
      portable_put(simulator, "descriptor_lane_" + index.to_string(), 64, 0UL)
    }
    frontend_completion(host, simulator, lanes[0] >> 32, fault, 0UL)
    frontend_ack(host, simulator)
  }
  assert_eq(host.requests.length(), 0)
}

///|
test "queued tile repeated opaque IDs remain separate entries across held completions" {
  let host = PortableHost::new()
  let simulator = frontend_prepare(3)
  frontend_enqueue(
    host,
    simulator,
    frontend_descriptor(4UL, 77UL, 0UL, 0UL, 0UL, 0UL, 0UL),
  )
  frontend_enqueue(
    host,
    simulator,
    frontend_descriptor(8UL, 77UL, 0UL, 0UL, 0UL, 0UL, 0UL),
  )
  frontend_enqueue(
    host,
    simulator,
    frontend_descriptor(4UL, 77UL, 0UL, 0UL, 0UL, 0UL, 0UL),
  )
  for fault in [0UL, 1UL, 0UL] {
    frontend_completion(host, simulator, 77UL, fault, 0UL)
    frontend_ack(host, simulator)
  }
  for _ in 0..<8 {
    host.tick(simulator)
    assert_eq(execute_read(simulator, "completion_valid"), 0UL)
  }
  assert_eq(execute_read(simulator, "queue_occupancy"), 0UL)
  assert_eq(host.requests.length(), 0)
}

///|
test "queued tile checks every reserved byte and full-width dimension before narrowing" {
  let host = PortableHost::new()
  let simulator = frontend_prepare(3)
  for byte in [3, 14, 15, 24, 25, 26, 27, 28, 29, 30, 31] {
    let lanes = frontend_descriptor(
      4UL,
      byte.to_uint64(),
      0UL,
      0UL,
      0UL,
      0UL,
      0UL,
    )
    lanes[byte / 8] = lanes[byte / 8] | (1UL << (byte % 8 * 8))
    frontend_enqueue(host, simulator, lanes)
    frontend_completion(host, simulator, byte.to_uint64(), 13UL, 0UL)
    frontend_ack(host, simulator)
  }
  for index in 0..<3 {
    let dimensions = [1UL, 1UL, 0UL]
    dimensions[index] = 0xffffUL
    frontend_enqueue(
      host,
      simulator,
      frontend_descriptor(
        0UL,
        (100 + index).to_uint64(),
        dimensions[0],
        dimensions[1],
        dimensions[2],
        0UL,
        1UL,
      ),
    )
    frontend_completion(host, simulator, (100 + index).to_uint64(), 14UL, 0UL)
    frontend_ack(host, simulator)
  }
  assert_eq(host.requests.length(), 0)
}
