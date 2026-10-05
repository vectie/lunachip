///|
fn concurrent_prepare(
  rows : Int,
  columns : Int,
  capacity : Int,
) -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(
    @flux_tile.concurrent_engine_tile(
      rows~,
      columns~,
      max_reduction=capacity,
      host_bytes=4096UL,
    ),
  )
  for
    (name, width) in [
      ("reset", 1),
      ("memory_request_ready", 1),
      ("memory_response_valid", 1),
      ("memory_response_tag", 32),
      ("memory_response_fault", 2),
      ("memory_response_data", 32),
    ] {
    portable_put(simulator, name, width, 0UL)
  }
  for channel in ["load", "store", "compute"] {
    for
      (field, width) in [
        ("valid", 1),
        ("id", 32),
        ("rows", 13),
        ("columns", 13),
      ] {
      portable_put(simulator, channel + "_command_" + field, width, 0UL)
    }
    portable_put(simulator, channel + "_completion_ready", 1, 0UL)
  }
  for channel in ["load", "store"] {
    for (field, width) in [("slot", 1), ("base", 32), ("stride", 32)] {
      portable_put(simulator, channel + "_command_" + field, width, 0UL)
    }
  }
  portable_put(simulator, "load_command_operand", 1, 0UL)
  for field in ["a_slot", "b_slot", "c_slot"] {
    portable_put(simulator, "compute_command_" + field, 1, 0UL)
  }
  portable_put(simulator, "compute_command_reduction", 13, 0UL)
  portable_put(simulator, "reset", 1, 1UL)
  simulator.rising_edge("clock")
  portable_put(simulator, "reset", 1, 0UL)
  for channel in ["load", "store", "compute"] {
    assert_eq(execute_read(simulator, channel + "_command_ready"), 1UL)
  }
  simulator
}

///|
fn concurrent_transfer_offer(
  simulator : @sim.Simulator,
  channel : String,
  id : Int,
  slot : Int,
  rows : Int,
  columns : Int,
  base : UInt64,
  stride : UInt64,
  operand? : Int = 0,
) -> Unit raise {
  for
    (field, width, value) in [
      ("id", 32, id.to_uint64()),
      ("slot", 1, slot.to_uint64()),
      ("rows", 13, rows.to_uint64()),
      ("columns", 13, columns.to_uint64()),
      ("base", 32, base),
      ("stride", 32, stride),
    ] {
    portable_put(simulator, channel + "_command_" + field, width, value)
  }
  if channel == "load" {
    portable_put(simulator, "load_command_operand", 1, operand.to_uint64())
  }
  portable_put(simulator, channel + "_command_valid", 1, 1UL)
}

///|
fn concurrent_compute_offer(
  simulator : @sim.Simulator,
  id : Int,
  rows : Int,
  columns : Int,
  reduction : Int,
  a? : Int = 0,
  b? : Int = 0,
  c? : Int = 0,
) -> Unit raise {
  for
    (field, width, value) in [
      ("id", 32, id.to_uint64()),
      ("rows", 13, rows.to_uint64()),
      ("columns", 13, columns.to_uint64()),
      ("reduction", 13, reduction.to_uint64()),
      ("a_slot", 1, a.to_uint64()),
      ("b_slot", 1, b.to_uint64()),
      ("c_slot", 1, c.to_uint64()),
    ] {
    portable_put(simulator, "compute_command_" + field, width, value)
  }
  portable_put(simulator, "compute_command_valid", 1, 1UL)
}

///|
fn concurrent_latched_noise(
  simulator : @sim.Simulator,
  channel : String,
  selectors? : Array[Int] = [1, 1, 1],
) -> Unit raise {
  portable_put(simulator, channel + "_command_valid", 1, 0UL)
  portable_put(simulator, channel + "_command_id", 32, 0xffffffffUL)
  portable_put(simulator, channel + "_command_rows", 13, 8191UL)
  portable_put(simulator, channel + "_command_columns", 13, 8191UL)
  if channel == "compute" {
    for index, field in ["a_slot", "b_slot", "c_slot"] {
      let name = "compute_command_" + field
      portable_put(simulator, name, 1, selectors[index].to_uint64())
    }
    portable_put(simulator, "compute_command_reduction", 13, 8191UL)
  } else {
    let name = channel + "_command_slot"
    portable_put(simulator, name, 1, selectors[0].to_uint64())
    portable_put(simulator, channel + "_command_base", 32, 4095UL)
    portable_put(simulator, channel + "_command_stride", 32, 0UL)
    if channel == "load" {
      portable_put(
        simulator,
        "load_command_operand",
        1,
        selectors[1].to_uint64(),
      )
    }
  }
}

///|
fn concurrent_payload(
  simulator : @sim.Simulator,
  channel : String,
) -> Array[UInt64] raise {
  let fields = if channel == "compute" {
    ["id", "fault"]
  } else {
    ["id", "fault", "bytes_completed", "fault_address"]
  }
  fields.map(field => execute_read(simulator, channel + "_completion_" + field))
}

///|
fn concurrent_wait(
  host : PortableHost,
  simulator : @sim.Simulator,
  channel : String,
  expected : Array[UInt64],
) -> Unit raise {
  for _ in 0..<20000 {
    if execute_read(simulator, channel + "_completion_valid") == 1UL {
      break
    }
    host.tick(simulator)
  }
  assert_eq(execute_read(simulator, channel + "_completion_valid"), 1UL)
  assert_eq(concurrent_payload(simulator, channel), expected)
  for _ in 0..<3 {
    host.tick(simulator)
    assert_eq(execute_read(simulator, channel + "_completion_valid"), 1UL)
    assert_eq(execute_read(simulator, channel + "_command_ready"), 0UL)
    assert_eq(concurrent_payload(simulator, channel), expected)
  }
}

///|
fn concurrent_ack(
  host : PortableHost,
  simulator : @sim.Simulator,
  channel : String,
) -> Unit raise {
  assert_eq(execute_read(simulator, channel + "_completion_valid"), 1UL)
  portable_put(simulator, channel + "_completion_ready", 1, 1UL)
  assert_eq(execute_read(simulator, channel + "_command_ready"), 0UL)
  host.tick(simulator)
  portable_put(simulator, channel + "_completion_ready", 1, 0UL)
  assert_eq(execute_read(simulator, channel + "_completion_valid"), 0UL)
}

///|
fn concurrent_load(
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
  concurrent_transfer_offer(
    simulator,
    "load",
    10,
    slot,
    rows,
    columns,
    base,
    stride,
    operand~,
  )
  assert_eq(execute_read(simulator, "load_command_ready"), 1UL)
  host.tick(simulator)
  concurrent_latched_noise(simulator, "load", selectors=[1 - slot, 1 - operand])
  concurrent_wait(host, simulator, "load", [
    10UL,
    0UL,
    (rows * columns).to_uint64(),
    0UL,
  ])
  concurrent_ack(host, simulator, "load")
}

///|
fn concurrent_compute(
  host : PortableHost,
  simulator : @sim.Simulator,
  rows : Int,
  columns : Int,
  reduction : Int,
  a? : Int = 0,
  b? : Int = 0,
  c? : Int = 0,
) -> Unit raise {
  concurrent_compute_offer(simulator, 20, rows, columns, reduction, a~, b~, c~)
  assert_eq(execute_read(simulator, "compute_command_ready"), 1UL)
  host.tick(simulator)
  concurrent_latched_noise(simulator, "compute", selectors=[1 - a, 1 - b, 1 - c])
  concurrent_wait(host, simulator, "compute", [20UL, 0UL])
  assert_eq(
    execute_read(simulator, "active_cycles"),
    (reduction + rows + columns - 2).to_uint64(),
  )
  assert_eq(
    execute_read(simulator, "capture_cycles"),
    (rows * columns).to_uint64(),
  )
  concurrent_ack(host, simulator, "compute")
}

///|
fn concurrent_check_words(
  host : PortableHost,
  base : UInt64,
  rows : Int,
  columns : Int,
  expected : Array[Int],
) -> Unit raise {
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
fn concurrent_store(
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
  concurrent_transfer_offer(
    simulator, "store", 30, slot, rows, columns, base, 40UL,
  )
  assert_eq(execute_read(simulator, "store_command_ready"), 1UL)
  host.tick(simulator)
  concurrent_latched_noise(simulator, "store", selectors=[1 - slot])
  concurrent_wait(host, simulator, "store", [
    30UL,
    0UL,
    (rows * columns * 4).to_uint64(),
    0UL,
  ])
  concurrent_check_words(host, base, rows, columns, expected)
  concurrent_ack(host, simulator, "store")
}

///|
// Only observes existing public handshakes/counters around the unchanged host
// environment. It neither schedules device work nor computes a device result.
fn concurrent_observe_tick(
  host : PortableHost,
  simulator : @sim.Simulator,
) -> Array[Bool] raise {
  let active = execute_read(simulator, "active_cycles")
  let capture = execute_read(simulator, "capture_cycles")
  let count = host.requests.length()
  let response = host.pending is Some(p) &&
    p.remaining == 0 &&
    execute_read(simulator, "memory_response_ready") == 1UL
  let response_write = response &&
    count > 0 &&
    host.requests[count - 1][0] == 1UL
  host.tick(simulator)
  let run = execute_read(simulator, "active_cycles") == active + 1UL
  let cap = execute_read(simulator, "capture_cycles") == capture + 1UL
  let accepted = host.requests.length() == count + 1
  let write = accepted && host.requests[count][0] == 1UL
  [
    accepted && !write && run,
    accepted && write && run,
    accepted && !write && cap,
    accepted && write && cap,
    response && !response_write && run,
    response && response_write && run,
    response && !response_write && cap,
    response && response_write && cap,
  ]
}

///|
fn concurrent_seed_old(
  host : PortableHost,
  simulator : @sim.Simulator,
) -> Array[Int] raise {
  let left = [1, -2, 3, -4, 5, -6, 7, -8, 9, -10, 11, -12, 13, -14, 15]
  let right = [-128, 127, 5, -6, 7, -8, 9, -10, 11, -12]
  concurrent_load(host, simulator, 0, 0, 3, 5, 32UL, 13UL, left)
  concurrent_load(host, simulator, 1, 0, 5, 2, 256UL, 17UL, right)
  concurrent_compute(host, simulator, 3, 2, 5)
  @flux_tile.matmul_int8_oracle(left, right, rows=3, columns=2, reduction=5)
}

///|
fn concurrent_reset(
  host : PortableHost,
  simulator : @sim.Simulator,
) -> Unit raise {
  portable_put(simulator, "reset", 1, 1UL)
  for channel in ["load", "compute", "store"] {
    portable_put(simulator, channel + "_command_valid", 1, 1UL)
    portable_put(simulator, channel + "_completion_ready", 1, 1UL)
    assert_eq(execute_read(simulator, channel + "_command_ready"), 0UL)
    assert_eq(execute_read(simulator, channel + "_completion_valid"), 0UL)
  }
  portable_put(simulator, "memory_response_valid", 1, 1UL)
  assert_eq(execute_read(simulator, "memory_request_valid"), 0UL)
  assert_eq(execute_read(simulator, "memory_response_ready"), 0UL)
  simulator.rising_edge("clock")
  // Actual joint transport barrier, not an invented device-state reset.
  host.pending = None
  host.held = None
  host.requests.clear()
  host.fail_at = -1
  host.protocol_at = -1
  for channel in ["load", "compute", "store"] {
    portable_put(simulator, channel + "_command_valid", 1, 0UL)
    portable_put(simulator, channel + "_completion_ready", 1, 0UL)
  }
  portable_put(simulator, "memory_response_valid", 1, 0UL)
  portable_put(simulator, "reset", 1, 0UL)
  assert_eq(execute_read(simulator, "transport_halted"), 0UL)
}
