///|
fn slotted_host_prepare(
  rows : Int32,
  columns : Int32,
  capacity : Int32,
) -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(
    @flux_tile.slotted_portable_tile(
      rows~,
      columns~,
      max_reduction=capacity,
      host_bytes=4096UL,
    ),
  )
  for
    (name, width) in [
      ("reset", 1),
      ("command_valid", 1),
      ("command_opcode", 3),
      ("command_id", 32),
      ("command_rows", 13),
      ("command_columns", 13),
      ("command_reduction", 13),
      ("command_base", 32),
      ("command_stride", 32),
      ("command_a_slot", 1),
      ("command_b_slot", 1),
      ("command_c_slot", 1),
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
  assert_eq(execute_read(simulator, "command_ready"), 1UL)
  simulator
}

///|
fn slotted_host_select(
  simulator : @sim.Simulator,
  a : Int32,
  b : Int32,
  c : Int32,
) -> Unit raise {
  portable_put(simulator, "command_a_slot", 1, a.to_uint64())
  portable_put(simulator, "command_b_slot", 1, b.to_uint64())
  portable_put(simulator, "command_c_slot", 1, c.to_uint64())
}

///|
fn slotted_host_start(
  host : PortableHost,
  simulator : @sim.Simulator,
  opcode : Int32,
  id : Int32,
  rows : Int32,
  columns : Int32,
  reduction : Int32,
  base : UInt64,
  stride : UInt64,
  a~ : Int32 = 0,
  b~ : Int32 = 0,
  c~ : Int32 = 0,
) -> Unit raise {
  slotted_host_select(simulator, a, b, c)
  portable_start(
    host, simulator, opcode, id, rows, columns, reduction, base, stride,
  )
  // Accepted metadata must be independent of every subsequent live selector,
  // including the validation edge and actual request/response stalls.
  slotted_host_select(simulator, 1 - a, 1 - b, 1 - c)
}

///|
fn slotted_host_payload(
  simulator : @sim.Simulator,
) -> (UInt64, UInt64, UInt64, UInt64) raise {
  (
    execute_read(simulator, "completion_id"),
    execute_read(simulator, "completion_fault"),
    execute_read(simulator, "completion_bytes_completed"),
    execute_read(simulator, "completion_fault_address"),
  )
}

///|
fn slotted_host_command(
  host : PortableHost,
  simulator : @sim.Simulator,
  opcode : Int32,
  id : Int32,
  rows : Int32,
  columns : Int32,
  reduction : Int32,
  base : UInt64,
  stride : UInt64,
  a~ : Int32 = 0,
  b~ : Int32 = 0,
  c~ : Int32 = 0,
) -> (UInt64, UInt64, UInt64) raise {
  slotted_host_start(
    host,
    simulator,
    opcode,
    id,
    rows,
    columns,
    reduction,
    base,
    stride,
    a~,
    b~,
    c~,
  )
  for _ in 0..<10000 {
    if execute_read(simulator, "completion_valid") == 1UL {
      break
    }
    assert_eq(execute_read(simulator, "command_ready"), 0UL)
    host.tick(simulator)
  }
  assert_eq(execute_read(simulator, "completion_valid"), 1UL)
  let payload = slotted_host_payload(simulator)
  assert_eq(payload.0, id.to_uint64())
  for cycle in 0..<4 {
    slotted_host_select(simulator, cycle % 2, (cycle + 1) % 2, cycle % 2)
    portable_put(simulator, "command_valid", 1, 1UL)
    host.tick(simulator)
    assert_eq(execute_read(simulator, "completion_valid"), 1UL)
    assert_eq(execute_read(simulator, "command_ready"), 0UL)
    assert_eq(slotted_host_payload(simulator), payload)
    assert_eq(execute_read(simulator, "memory_request_valid"), 0UL)
  }
  portable_put(simulator, "command_valid", 1, 0UL)
  (payload.1, payload.2, payload.3)
}

///|
fn slotted_host_success(
  host : PortableHost,
  simulator : @sim.Simulator,
  opcode : Int32,
  id : Int32,
  rows : Int32,
  columns : Int32,
  reduction : Int32,
  base : UInt64,
  stride : UInt64,
  bytes : UInt64,
  a~ : Int32 = 0,
  b~ : Int32 = 0,
  c~ : Int32 = 0,
) -> Unit raise {
  assert_eq(
    slotted_host_command(
      host,
      simulator,
      opcode,
      id,
      rows,
      columns,
      reduction,
      base,
      stride,
      a~,
      b~,
      c~,
    ),
    (0UL, bytes, 0UL),
  )
  portable_ack(host, simulator, true)
}

///|
fn slotted_host_load(
  host : PortableHost,
  simulator : @sim.Simulator,
  opcode : Int32,
  slot : Int32,
  rows : Int32,
  columns : Int32,
  base : UInt64,
  stride : UInt64,
  values : Array[Int32],
) -> Unit raise {
  host.seed(base, stride, rows, columns, values)
  let first = host.requests.length()
  slotted_host_success(
    host,
    simulator,
    opcode,
    100 + opcode * 2 + slot,
    rows,
    columns,
    0,
    base,
    stride,
    (rows * columns).to_uint64(),
    a=if opcode == 0 { slot } else { 0 },
    b=if opcode == 1 { slot } else { 0 },
  )
  let addresses = Array::makei(rows * columns, index => {
    base +
    (index / columns).to_uint64() * stride +
    (index % columns).to_uint64()
  })
  assert_eq(host.requests[first:].map(request => request[1]), addresses)
  for request in host.requests[first:] {
    assert_eq(request[0], 0UL)
  }
}

///|
fn slotted_host_store_check(
  host : PortableHost,
  simulator : @sim.Simulator,
  slot : Int32,
  rows : Int32,
  columns : Int32,
  base : UInt64,
  expected : Array[Int32],
) -> Unit raise {
  for byte in 0..<(rows * 40) {
    host.memory[base + byte.to_uint64()] = 165
  }
  slotted_host_success(
    host,
    simulator,
    3,
    200 + slot,
    rows,
    columns,
    0,
    base,
    40UL,
    (rows * columns * 4).to_uint64(),
    c=slot,
  )
  for row in 0..<rows {
    for column in 0..<columns {
      assert_eq(
        host.word(base + row.to_uint64() * 40UL + column.to_uint64() * 4UL),
        expected[row * columns + column],
      )
    }
    for padding in (columns * 4)..<40 {
      assert_eq(
        host.memory[base + row.to_uint64() * 40UL + padding.to_uint64()],
        165,
      )
    }
  }
}

///|
fn slotted_host_check_reset_sources(
  host : PortableHost,
  simulator : @sim.Simulator,
) -> Unit raise {
  // Use the exact pre-reset shape. A stale B-valid bit must not hide behind
  // a shape mismatch when only fresh A1 has been loaded.
  slotted_host_load(host, simulator, 0, 1, 2, 2, 128UL, 13UL, [9, 8, 7, 6])
  let count = host.requests.length()
  for slot in [0, 1] {
    assert_eq(
      slotted_host_command(
        host,
        simulator,
        2,
        165,
        2,
        2,
        2,
        0UL,
        0UL,
        a=1,
        b=slot,
        c=1,
      ),
      (4UL, 0UL, 0UL),
    )
    portable_ack(host, simulator, true)
  }
  assert_eq(host.requests.length(), count)
}
