///|
struct PortablePending {
  remaining : Int
  tag : UInt64
  fault : UInt64
  data : UInt64
}

///|
// External byte-addressed environment. This does not calculate device results
// or implement on-device banks; it only answers observed memory transactions.
struct PortableHost {
  memory : Map[UInt64, Int]
  requests : Array[Array[UInt64]]
  mut pending : PortablePending?
  mut held : Array[UInt64]?
  mut cycle : Int
  mut stalled : Bool
  mut latency : Int
  mut fail_at : Int
  mut protocol_at : Int
  mut protocol_status : UInt64
  failing_write_bytes : Int
}

///|
fn PortableHost::new() -> PortableHost {
  {
    memory: Map([]),
    requests: [],
    pending: None,
    held: None,
    cycle: 0,
    stalled: true,
    latency: 1,
    fail_at: -1,
    protocol_at: -1,
    protocol_status: 0UL,
    failing_write_bytes: 2,
  }
}

///|
fn portable_put(
  simulator : @sim.Simulator,
  name : String,
  width : Int,
  value : UInt64,
) -> Unit raise {
  simulator.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  simulator.settle()
}

///|
fn portable_prepare(
  rows : Int,
  columns : Int,
  capacity : Int,
  aperture : UInt64,
) -> @sim.Simulator raise {
  let simulator = @sim.Simulator::prepare(
    @flux_tile.portable_tile(
      rows~,
      columns~,
      max_reduction=capacity,
      host_bytes=aperture,
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
fn PortableHost::tick(
  self : PortableHost,
  simulator : @sim.Simulator,
) -> Unit raise {
  let ready = !self.stalled || self.cycle % 4 == 3
  portable_put(
    simulator,
    "memory_request_ready",
    1,
    if ready {
      1UL
    } else {
      0UL
    },
  )
  let response = match self.pending {
    Some(p) if p.remaining == 0 => Some(p)
    _ => None
  }
  portable_put(
    simulator,
    "memory_response_valid",
    1,
    if response is Some(_) {
      1UL
    } else {
      0UL
    },
  )
  if response is Some(p) {
    portable_put(simulator, "memory_response_tag", 32, p.tag)
    portable_put(simulator, "memory_response_fault", 2, p.fault)
    portable_put(simulator, "memory_response_data", 32, p.data)
  }
  let valid = execute_read(simulator, "memory_request_valid") == 1UL
  let request = if valid {
    ["write", "address", "bytes", "mask", "data", "tag"].map(field => {
      execute_read(simulator, "memory_request_" + field)
    })
  } else {
    []
  }
  if self.held is Some(previous) {
    assert_true(valid)
    assert_eq(request, previous)
  }
  self.held = if valid && !ready { Some(request) } else { None }
  let response_accepted = response is Some(_) &&
    execute_read(simulator, "memory_response_ready") == 1UL
  let request_accepted = valid && ready
  simulator.rising_edge("clock")
  if response_accepted {
    self.pending = None
  } else if self.pending is Some(p) && p.remaining > 0 {
    self.pending = Some({ ..p, remaining: p.remaining - 1, })
  }
  if request_accepted {
    assert_true(self.pending is None)
    let index = self.requests.length()
    assert_eq(request[5], index.to_uint64())
    assert_eq(request[2], if request[0] == 1UL { 4UL } else { 1UL })
    assert_eq(request[3], if request[0] == 1UL { 15UL } else { 1UL })
    if request[0] == 0UL {
      assert_eq(request[4], 0UL)
    }
    let fault = if index == self.protocol_at && self.protocol_status != 0UL {
      self.protocol_status
    } else if index == self.fail_at {
      1UL
    } else {
      0UL
    }
    let data = self.memory.get(request[1]).unwrap_or(0).to_uint64()
    if request[0] == 1UL {
      let count = if index == self.fail_at {
        self.failing_write_bytes
      } else {
        4
      }
      for byte in 0..<count {
        self.memory[request[1] + byte.to_uint64()] = ((request[4] >> (byte * 8)) &
        255UL).to_int()
      }
    }
    self.requests.push(request)
    self.pending = Some({
      remaining: self.latency + index % 3,
      tag: if index == self.protocol_at && self.protocol_status == 0UL {
        request[5] + 1UL
      } else {
        request[5]
      },
      fault,
      data,
    })
  }
  self.cycle += 1
}

///|
fn PortableHost::seed(
  self : PortableHost,
  base : UInt64,
  stride : UInt64,
  rows : Int,
  columns : Int,
  values : Array[Int],
) -> Unit {
  for row in 0..<rows {
    for column in 0..<columns {
      self.memory[base + row.to_uint64() * stride + column.to_uint64()] = values[row *
        columns +
        column] &
        255
    }
  }
}

///|
fn PortableHost::word(self : PortableHost, address : UInt64) -> Int {
  let mut bits = 0UL
  for byte in 0..<4 {
    bits = bits |
      (
        self.memory.get(address + byte.to_uint64()).unwrap_or(0).to_uint64() <<
        (byte * 8)
      )
  }
  if bits >= 0x80000000UL {
    (bits.reinterpret_as_int64() - 4294967296L).to_int()
  } else {
    bits.to_int()
  }
}

///|
fn portable_start(
  host : PortableHost,
  simulator : @sim.Simulator,
  opcode : Int,
  id : Int,
  rows : Int,
  columns : Int,
  reduction : Int,
  base : UInt64,
  stride : UInt64,
) -> Unit raise {
  assert_eq(execute_read(simulator, "command_ready"), 1UL)
  portable_put(simulator, "command_opcode", 3, opcode.to_uint64())
  portable_put(simulator, "command_id", 32, id.to_uint64())
  portable_put(simulator, "command_rows", 13, rows.to_uint64())
  portable_put(simulator, "command_columns", 13, columns.to_uint64())
  portable_put(simulator, "command_reduction", 13, reduction.to_uint64())
  portable_put(simulator, "command_base", 32, base)
  portable_put(simulator, "command_stride", 32, stride)
  portable_put(simulator, "command_valid", 1, 1UL)
  host.tick(simulator)
  portable_put(simulator, "command_valid", 1, 0UL)
}

///|
fn portable_command(
  host : PortableHost,
  simulator : @sim.Simulator,
  opcode : Int,
  id : Int,
  rows : Int,
  columns : Int,
  reduction : Int,
  base : UInt64,
  stride : UInt64,
) -> (UInt64, UInt64, UInt64) raise {
  portable_start(
    host, simulator, opcode, id, rows, columns, reduction, base, stride,
  )
  for _ in 0..<10000 {
    if execute_read(simulator, "completion_valid") == 1UL {
      break
    }
    host.tick(simulator)
  }
  assert_eq(execute_read(simulator, "completion_valid"), 1UL)
  assert_eq(execute_read(simulator, "completion_id"), id.to_uint64())
  assert_eq(execute_read(simulator, "command_ready"), 0UL)
  let completion = (
    execute_read(simulator, "completion_fault"),
    execute_read(simulator, "completion_bytes_completed"),
    execute_read(simulator, "completion_fault_address"),
  )
  for _ in 0..<3 {
    host.tick(simulator)
    assert_eq(execute_read(simulator, "completion_valid"), 1UL)
    assert_eq(execute_read(simulator, "command_ready"), 0UL)
    assert_eq(
      (
        execute_read(simulator, "completion_fault"),
        execute_read(simulator, "completion_bytes_completed"),
        execute_read(simulator, "completion_fault_address"),
      ),
      completion,
    )
    assert_eq(execute_read(simulator, "completion_id"), id.to_uint64())
    assert_eq(execute_read(simulator, "memory_request_valid"), 0UL)
  }
  completion
}

///|
fn portable_ack(
  host : PortableHost,
  simulator : @sim.Simulator,
  unlocked : Bool,
) -> Unit raise {
  portable_put(simulator, "completion_ready", 1, 1UL)
  host.tick(simulator)
  portable_put(simulator, "completion_ready", 1, 0UL)
  assert_eq(execute_read(simulator, "completion_valid"), 0UL)
  assert_eq(
    execute_read(simulator, "command_ready"),
    if unlocked {
      1UL
    } else {
      0UL
    },
  )
}

///|
fn portable_success(
  host : PortableHost,
  simulator : @sim.Simulator,
  opcode : Int,
  id : Int,
  rows : Int,
  columns : Int,
  reduction : Int,
  base : UInt64,
  stride : UInt64,
  bytes : UInt64,
) -> Unit raise {
  assert_eq(
    portable_command(
      host, simulator, opcode, id, rows, columns, reduction, base, stride,
    ),
    (0UL, bytes, 0UL),
  )
  portable_ack(host, simulator, true)
}
