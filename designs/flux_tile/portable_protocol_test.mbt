///|
fn portable_reset_barrier(
  host : PortableHost,
  simulator : @sim.Simulator,
) -> Unit raise {
  portable_put(simulator, "reset", 1, 1UL)
  portable_put(simulator, "memory_response_valid", 1, 0UL)
  portable_put(simulator, "command_valid", 1, 0UL)
  assert_eq(execute_read(simulator, "memory_request_valid"), 0UL)
  assert_eq(execute_read(simulator, "memory_response_ready"), 0UL)
  assert_eq(execute_read(simulator, "completion_valid"), 0UL)
  simulator.rising_edge("clock")
  // Actual joint device/transport barrier: discard the old accepted request
  // and response before releasing reset. Previously performed writes remain.
  host.pending = None
  host.held = None
  host.requests.clear()
  host.fail_at = -1
  host.protocol_at = -1
  portable_put(simulator, "reset", 1, 0UL)
  assert_eq(execute_read(simulator, "command_ready"), 1UL)
}

///|
test "portable tile invalidates a partially failed operand reload and preserves old C" {
  let host = PortableHost::new()
  let simulator = portable_prepare(2, 2, 3, 4096UL)
  let left = [1, 2, 3, 4, 5, 6]
  let right = [7, 8, 9, 10, 11, 12]
  portable_workload(host, simulator, 2, 2, 3, left, right)
  let old_result = @flux_tile.matmul_int8_oracle(
    left,
    right,
    rows=2,
    columns=2,
    reduction=3,
  )
  let replacement = [-2, -3, -4, -5, -6, -7]
  host.seed(32UL, 13UL, 2, 3, replacement)
  host.fail_at = host.requests.length() + 2
  assert_eq(
    portable_command(host, simulator, 0, 40, 2, 3, 0, 32UL, 13UL),
    (9UL, 2UL, 34UL),
  )
  portable_ack(host, simulator, true)
  let requests = host.requests.length()
  assert_eq(
    portable_command(host, simulator, 2, 41, 2, 2, 3, 0UL, 0UL),
    (4UL, 0UL, 0UL),
  )
  assert_eq(host.requests.length(), requests)
  portable_ack(host, simulator, true)
  host.fail_at = -1
  portable_success(host, simulator, 3, 42, 2, 2, 0, 900UL, 16UL, 16UL)
  for row in 0..<2 {
    for column in 0..<2 {
      assert_eq(
        host.word(900UL + row.to_uint64() * 16UL + column.to_uint64() * 4UL),
        old_result[row * 2 + column],
      )
    }
  }
  portable_success(host, simulator, 0, 43, 2, 3, 0, 32UL, 13UL, 6UL)
  portable_success(host, simulator, 2, 44, 2, 2, 3, 0UL, 0UL, 0UL)
  let new_result = @flux_tile.matmul_int8_oracle(
    replacement,
    right,
    rows=2,
    columns=2,
    reduction=3,
  )
  for address in 1024..<1060 {
    host.memory[address.to_uint64()] = 165
  }
  host.fail_at = host.requests.length() + 1
  assert_eq(
    portable_command(host, simulator, 3, 45, 2, 2, 0, 1024UL, 16UL),
    (9UL, 4UL, 1028UL),
  )
  assert_eq(host.word(1024UL), new_result[0])
  for byte in 0..<2 {
    assert_eq(
      host.memory.get(1028UL + byte.to_uint64()).unwrap(),
      ((new_result[1].to_uint64() >> (byte * 8)) & 255UL).to_int(),
    )
  }
  assert_eq(host.memory.get(1030UL).unwrap(), 165)
  assert_eq(host.memory.get(1031UL).unwrap(), 165)
  assert_eq(host.memory.get(1040UL).unwrap(), 165)
  portable_ack(host, simulator, true)
  host.fail_at = -1
  portable_success(host, simulator, 3, 46, 2, 2, 0, 1024UL, 16UL, 16UL)
  assert_eq(host.word(1028UL), new_result[1])
  assert_eq(host.word(1040UL), new_result[2])
}

///|
test "portable tile locks out wrong tags and reserved response status until a joint reset" {
  for status in [0UL, 2UL, 3UL] {
    let host = PortableHost::new()
    host.protocol_at = 0
    host.protocol_status = status
    host.memory[32UL] = 2
    let simulator = portable_prepare(1, 1, 1, 4096UL)
    assert_eq(
      portable_command(host, simulator, 0, 50, 1, 1, 0, 32UL, 1UL),
      (10UL, 0UL, 32UL),
    )
    portable_ack(host, simulator, false)
    portable_put(simulator, "command_valid", 1, 1UL)
    for _ in 0..<8 {
      host.tick(simulator)
      assert_eq(execute_read(simulator, "command_ready"), 0UL)
      assert_eq(execute_read(simulator, "memory_request_valid"), 0UL)
    }
    assert_eq(host.requests.length(), 1)
    portable_reset_barrier(host, simulator)
    portable_success(host, simulator, 0, 51, 1, 1, 0, 32UL, 1UL, 1UL)
    assert_eq(host.requests[0][5], 0UL)
  }
}

///|
test "portable tile resets an accepted transport request with a real flush barrier" {
  for writing in [false, true] {
    let host = PortableHost::new()
    let simulator = portable_prepare(1, 1, 1, 4096UL)
    host.memory[32UL] = 128
    host.memory[256UL] = 127
    portable_success(host, simulator, 0, 60, 1, 1, 0, 32UL, 1UL, 1UL)
    portable_success(host, simulator, 1, 61, 1, 1, 0, 256UL, 1UL, 1UL)
    portable_success(host, simulator, 2, 62, 1, 1, 1, 0UL, 0UL, 0UL)
    host.latency = 100
    portable_put(
      simulator,
      "command_opcode",
      3,
      if writing {
        3UL
      } else {
        0UL
      },
    )
    portable_put(simulator, "command_id", 32, 63UL)
    portable_put(simulator, "command_rows", 13, 1UL)
    portable_put(simulator, "command_columns", 13, 1UL)
    portable_put(simulator, "command_reduction", 13, 0UL)
    portable_put(
      simulator,
      "command_base",
      32,
      if writing {
        512UL
      } else {
        32UL
      },
    )
    portable_put(
      simulator,
      "command_stride",
      32,
      if writing {
        4UL
      } else {
        1UL
      },
    )
    portable_put(simulator, "command_valid", 1, 1UL)
    host.tick(simulator)
    portable_put(simulator, "command_valid", 1, 0UL)
    for _ in 0..<30 {
      host.tick(simulator)
      if host.pending is Some(_) {
        break
      }
    }
    assert_true(host.pending is Some(_))
    if writing {
      assert_eq(host.word(512UL), -16256)
    }
    portable_reset_barrier(host, simulator)
    if writing {
      assert_eq(host.word(512UL), -16256)
    }
    host.latency = 1
    portable_workload(host, simulator, 1, 1, 1, [2], [3])
    assert_eq(host.requests[0][5], 0UL)
  }
}

///|
test "portable tile reset cancels compute capture and held completion" {
  for phase in ["compute", "capture", "done"] {
    let host = PortableHost::new()
    let simulator = portable_prepare(2, 2, 2, 4096UL)
    host.seed(32UL, 13UL, 2, 2, [1, 2, 3, 4])
    host.seed(256UL, 17UL, 2, 2, [5, 6, 7, 8])
    portable_success(host, simulator, 0, 70, 2, 2, 0, 32UL, 13UL, 4UL)
    portable_success(host, simulator, 1, 71, 2, 2, 0, 256UL, 17UL, 4UL)
    if phase == "done" {
      assert_eq(
        portable_command(host, simulator, 2, 72, 2, 2, 2, 0UL, 0UL),
        (0UL, 0UL, 0UL),
      )
    } else {
      portable_put(simulator, "command_opcode", 3, 2UL)
      portable_put(simulator, "command_id", 32, 72UL)
      portable_put(simulator, "command_rows", 13, 2UL)
      portable_put(simulator, "command_columns", 13, 2UL)
      portable_put(simulator, "command_reduction", 13, 2UL)
      portable_put(simulator, "command_base", 32, 0UL)
      portable_put(simulator, "command_stride", 32, 0UL)
      portable_put(simulator, "command_valid", 1, 1UL)
      host.tick(simulator)
      portable_put(simulator, "command_valid", 1, 0UL)
      for _ in 0..<40 {
        host.tick(simulator)
        if phase == "compute" && execute_read(simulator, "active_cycles") == 1UL {
          break
        }
        if phase == "capture" &&
          execute_read(simulator, "capture_cycles") == 1UL {
          break
        }
      }
      assert_eq(execute_read(simulator, "completion_valid"), 0UL)
      assert_eq(
        execute_read(
          simulator,
          if phase == "compute" {
            "active_cycles"
          } else {
            "capture_cycles"
          },
        ),
        1UL,
      )
    }
    portable_reset_barrier(host, simulator)
    assert_eq(
      portable_command(host, simulator, 3, 73, 2, 2, 0, 512UL, 8UL),
      (5UL, 0UL, 0UL),
    )
    portable_ack(host, simulator, true)
    portable_workload(host, simulator, 1, 1, 1, [2], [3])
  }
}

///|
test "portable tile reset covers validation request stall bank commit and SRAM read boundaries" {
  for boundary in ["validation", "request-stall", "bank-commit", "store-read"] {
    let host = PortableHost::new()
    host.stalled = false
    host.latency = 0
    let simulator = portable_prepare(1, 1, 1, 4096UL)
    host.memory[32UL] = 2
    if boundary == "store-read" {
      host.memory[256UL] = 3
      portable_success(host, simulator, 0, 80, 1, 1, 0, 32UL, 1UL, 1UL)
      portable_success(host, simulator, 1, 81, 1, 1, 0, 256UL, 1UL, 1UL)
      portable_success(host, simulator, 2, 82, 1, 1, 1, 0UL, 0UL, 0UL)
    }
    portable_start(
      host,
      simulator,
      if boundary == "store-read" {
        3
      } else {
        0
      },
      83,
      1,
      1,
      0,
      if boundary == "store-read" {
        512UL
      } else {
        32UL
      },
      if boundary == "store-read" {
        4UL
      } else {
        1UL
      },
    )
    let requests_before = host.requests.length()
    if boundary == "request-stall" {
      portable_put(simulator, "memory_request_ready", 1, 0UL)
      for _ in 0..<10 {
        if execute_read(simulator, "memory_request_valid") == 1UL {
          break
        }
        simulator.rising_edge("clock")
      }
      assert_eq(execute_read(simulator, "memory_request_valid"), 1UL)
      assert_eq(host.requests.length(), requests_before)
    } else if boundary == "bank-commit" {
      let mut seen_request = false
      for _ in 0..<20 {
        host.tick(simulator)
        if host.pending is Some(_) {
          seen_request = true
        }
        if seen_request && host.pending is None {
          break
        }
      }
      assert_true(seen_request)
      assert_eq(host.requests.length(), requests_before + 1)
      assert_eq(execute_read(simulator, "completion_valid"), 0UL)
    } else if boundary == "store-read" {
      // The first post-accept edge validates and enters StoreRead; no host
      // request exists until its synchronous C read has committed.
      host.tick(simulator)
      assert_eq(execute_read(simulator, "memory_request_valid"), 0UL)
      assert_eq(host.requests.length(), requests_before)
    }
    portable_reset_barrier(host, simulator)
    portable_workload(host, simulator, 1, 1, 1, [2], [3])
    assert_eq(host.requests[0][5], 0UL)
  }
}

///|
test "portable tile deterministic artifacts add no duplicate operand or result memories" {
  for (rows, columns, max_reduction) in [(1, 1, 1), (2, 3, 5), (8, 8, 3)] {
    let first = @wire.single_design(
      "Portable",
      @flux_tile.portable_tile(
        rows~,
        columns~,
        max_reduction~,
        host_bytes=4294967296UL,
      ),
    )
    let second = @wire.single_design(
      "Portable",
      @flux_tile.portable_tile(
        rows~,
        columns~,
        max_reduction~,
        host_bytes=4294967296UL,
      ),
    )
    assert_eq(@codec.serialize(first), @codec.serialize(second))
    assert_eq(
      @systemverilog.emit_design(first).source() catch {
        error => fail("emission failure: \{Repr(error)}")
      },
      @systemverilog.emit_design(second).source(),
    )
    assert_eq(first.modules()[0].memories().length(), rows + columns + 1)
  }
  for value in [0UL, 4294967297UL] {
    try
      @flux_tile.portable_tile(
        rows=1,
        columns=1,
        max_reduction=1,
        host_bytes=value,
      )
    catch {
      @flux_tile.PortableTileError::InvalidHostBytes(value=actual, maximum~) => {
        assert_eq(actual, value)
        assert_eq(maximum, 4294967296UL)
      }
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("invalid aperture accepted")
    }
  }
}
