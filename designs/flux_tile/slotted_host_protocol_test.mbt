///|
test "slotted host failed selected reload invalidates only that operand and preserves both C slots" {
  for opcode in [0, 1] {
    let host = PortableHost::new()
    let simulator = slotted_host_prepare(2, 2, 3)
    let left = [1, 2, 3, 4, 5, 6]
    let right = [7, 8, 9, 10, 11, 12]
    let old = @flux_tile.matmul_int8_oracle(
      left,
      right,
      rows=2,
      columns=2,
      reduction=3,
    )
    for slot in [0, 1] {
      slotted_host_load(host, simulator, 0, slot, 2, 3, 32UL, 13UL, left)
      slotted_host_load(host, simulator, 1, slot, 3, 2, 256UL, 17UL, right)
      slotted_host_success(
        host,
        simulator,
        2,
        130 + slot,
        2,
        2,
        3,
        0UL,
        0UL,
        0UL,
        a=slot,
        b=slot,
        c=slot,
      )
    }
    let replacement = [-2, -3, -4, -5, -6, -7]
    let base = if opcode == 0 { 32UL } else { 256UL }
    let stride = if opcode == 0 { 13UL } else { 17UL }
    let rows = if opcode == 0 { 2 } else { 3 }
    let columns = if opcode == 0 { 3 } else { 2 }
    host.seed(base, stride, rows, columns, replacement)
    host.fail_at = host.requests.length() + 2
    assert_eq(
      slotted_host_command(
        host,
        simulator,
        opcode,
        132,
        rows,
        columns,
        0,
        base,
        stride,
        a=if opcode == 0 { 1 } else { 0 },
      ),
      (9UL, 2UL, if opcode == 0 { 34UL } else { 273UL }),
    )
    portable_ack(host, simulator, true)
    let count = host.requests.length()
    assert_eq(
      slotted_host_command(
        host,
        simulator,
        2,
        133,
        2,
        2,
        3,
        0UL,
        0UL,
        a=if opcode == 0 { 1 } else { 0 },
      ),
      (4UL, 0UL, 0UL),
    )
    portable_ack(host, simulator, true)
    assert_eq(host.requests.length(), count)
    host.fail_at = -1
    // A0/B1 are unaffected by either failing A1 or failing B0.
    slotted_host_success(host, simulator, 2, 134, 2, 2, 3, 0UL, 0UL, 0UL, b=1)
    slotted_host_store_check(host, simulator, 0, 2, 2, 1024UL, old)
    slotted_host_store_check(host, simulator, 1, 2, 2, 1536UL, old)
    slotted_host_load(
      host,
      simulator,
      opcode,
      if opcode == 0 {
        1
      } else {
        0
      },
      rows,
      columns,
      base,
      stride,
      replacement,
    )
    slotted_host_success(
      host,
      simulator,
      2,
      135,
      2,
      2,
      3,
      0UL,
      0UL,
      0UL,
      a=if opcode == 0 { 1 } else { 0 },
      c=1,
    )
    let recovered = @flux_tile.matmul_int8_oracle(
      if opcode == 0 {
        replacement
      } else {
        left
      },
      if opcode == 1 {
        replacement
      } else {
        right
      },
      rows=2,
      columns=2,
      reduction=3,
    )
    slotted_host_store_check(host, simulator, 1, 2, 2, 1536UL, recovered)
    slotted_host_store_check(host, simulator, 0, 2, 2, 1024UL, old)
  }
}

///|
test "slotted host unused selectors reject before shape availability and address checks without effects" {
  let host = PortableHost::new()
  let simulator = slotted_host_prepare(1, 1, 1)
  for
    (opcode, a, b, c, expected) in [
      (0, 0, 1, 0, 2UL),
      (0, 1, 0, 1, 2UL),
      (1, 1, 0, 0, 2UL),
      (1, 0, 1, 1, 2UL),
      (3, 1, 0, 1, 2UL),
      (3, 0, 1, 0, 2UL),
      (4, 1, 0, 0, 2UL),
      (4, 0, 1, 0, 2UL),
      (4, 0, 0, 1, 2UL),
      (7, 1, 1, 1, 1UL),
    ] {
    assert_eq(
      slotted_host_command(
        host,
        simulator,
        opcode,
        140,
        0,
        0,
        0,
        0UL,
        0UL,
        a~,
        b~,
        c~,
      ),
      (expected, 0UL, 0UL),
    )
    portable_ack(host, simulator, true)
    assert_eq(host.requests.length(), 0)
  }
  for slot in [0, 1] {
    slotted_host_load(host, simulator, 0, slot, 1, 1, 32UL, 1UL, [
      if slot == 0 {
        2
      } else {
        5
      },
    ])
    slotted_host_load(host, simulator, 1, slot, 1, 1, 256UL, 1UL, [
      if slot == 0 {
        3
      } else {
        -7
      },
    ])
    slotted_host_success(
      host,
      simulator,
      2,
      141 + slot,
      1,
      1,
      1,
      0UL,
      0UL,
      0UL,
      a=slot,
      b=slot,
      c=slot,
    )
  }
  let count = host.requests.length()
  // Invalid unused B wins over bad A dimensions/stride/aperture and must not
  // invalidate already loaded A1 or either published result.
  assert_eq(
    slotted_host_command(
      host,
      simulator,
      0,
      143,
      0,
      8191,
      0,
      4095UL,
      0UL,
      a=1,
      b=1,
    ),
    (2UL, 0UL, 0UL),
  )
  portable_ack(host, simulator, true)
  assert_eq(host.requests.length(), count)
  slotted_host_store_check(host, simulator, 0, 1, 1, 1024UL, [6])
  slotted_host_store_check(host, simulator, 1, 1, 1, 1536UL, [-35])
  slotted_host_success(
    host,
    simulator,
    2,
    144,
    1,
    1,
    1,
    0UL,
    0UL,
    0UL,
    a=1,
    b=1,
    c=1,
  )
  slotted_host_store_check(host, simulator, 1, 1, 1, 1536UL, [-35])
}

///|
test "slotted host failed StoreC reports only acknowledged progress and retries selected persistent result" {
  let host = PortableHost::new()
  let simulator = slotted_host_prepare(2, 2, 3)
  let left = [1, -2, 3, -4, 5, -6]
  let right = [7, -8, 9, -10, 11, -12]
  let expected = @flux_tile.matmul_int8_oracle(
    left,
    right,
    rows=2,
    columns=2,
    reduction=3,
  )
  slotted_host_load(host, simulator, 0, 0, 2, 3, 32UL, 13UL, left)
  slotted_host_load(host, simulator, 1, 1, 3, 2, 256UL, 17UL, right)
  slotted_host_success(
    host,
    simulator,
    2,
    150,
    2,
    2,
    3,
    0UL,
    0UL,
    0UL,
    b=1,
    c=1,
  )
  for byte in 0..<80 {
    host.memory[1536UL + byte.to_uint64()] = 165
  }
  host.fail_at = host.requests.length() + 1
  assert_eq(
    slotted_host_command(host, simulator, 3, 151, 2, 2, 0, 1536UL, 40UL, c=1),
    (9UL, 4UL, 1540UL),
  )
  assert_eq(host.word(1536UL), expected[0])
  for byte in 0..<2 {
    assert_eq(
      host.memory[1540UL + byte.to_uint64()],
      ((expected[1].to_uint64() >> (byte * 8)) & 255UL).to_int(),
    )
  }
  assert_eq(host.memory[1542UL], 165)
  assert_eq(host.memory[1543UL], 165)
  assert_eq(host.memory[1576UL], 165)
  portable_ack(host, simulator, true)
  host.fail_at = -1
  slotted_host_store_check(host, simulator, 1, 2, 2, 1536UL, expected)
  let count = host.requests.length()
  assert_eq(
    slotted_host_command(host, simulator, 3, 152, 2, 2, 0, 1024UL, 40UL),
    (5UL, 0UL, 0UL),
  )
  portable_ack(host, simulator, true)
  assert_eq(host.requests.length(), count)
}

///|
test "slotted host joint reset clears every source and C slot while retaining committed host writes" {
  for phase in ["load-response", "compute", "capture", "done", "store-response"] {
    let host = PortableHost::new()
    let simulator = slotted_host_prepare(2, 2, 3)
    for slot in [0, 1] {
      slotted_host_load(host, simulator, 0, slot, 2, 2, 32UL, 13UL, [1, 2, 3, 4])
      slotted_host_load(host, simulator, 1, slot, 2, 2, 256UL, 17UL, [
        5, 6, 7, 8,
      ])
      slotted_host_success(
        host,
        simulator,
        2,
        160 + slot,
        2,
        2,
        2,
        0UL,
        0UL,
        0UL,
        a=slot,
        b=slot,
        c=slot,
      )
    }
    if phase == "done" {
      assert_eq(
        slotted_host_command(host, simulator, 4, 162, 0, 0, 0, 0UL, 0UL),
        (0UL, 0UL, 0UL),
      )
    } else if phase == "load-response" || phase == "store-response" {
      host.latency = 100
      slotted_host_start(
        host,
        simulator,
        if phase == "load-response" {
          0
        } else {
          3
        },
        162,
        2,
        2,
        0,
        if phase == "load-response" {
          32UL
        } else {
          1536UL
        },
        if phase == "load-response" {
          13UL
        } else {
          40UL
        },
        a=if phase == "load-response" { 1 } else { 0 },
        c=if phase == "store-response" { 1 } else { 0 },
      )
      for _ in 0..<40 {
        if host.pending is Some(_) {
          break
        }
        host.tick(simulator)
      }
      assert_true(host.pending is Some(_))
      if phase == "store-response" {
        assert_eq(host.word(1536UL), 19)
      }
    } else {
      slotted_host_start(
        host,
        simulator,
        2,
        162,
        2,
        2,
        2,
        0UL,
        0UL,
        a=1,
        b=1,
        c=1,
      )
      let counter = if phase == "compute" {
        "active_cycles"
      } else {
        "capture_cycles"
      }
      for _ in 0..<40 {
        if execute_read(simulator, counter) == 1UL {
          break
        }
        host.tick(simulator)
      }
      assert_eq(execute_read(simulator, counter), 1UL)
      assert_eq(execute_read(simulator, "completion_valid"), 0UL)
    }
    portable_reset_barrier(host, simulator)
    if phase == "store-response" {
      assert_eq(host.word(1536UL), 19)
    }
    host.latency = 1
    for slot in [0, 1] {
      assert_eq(
        slotted_host_command(
          host,
          simulator,
          2,
          163,
          2,
          2,
          2,
          0UL,
          0UL,
          a=slot,
          b=slot,
          c=slot,
        ),
        (4UL, 0UL, 0UL),
      )
      portable_ack(host, simulator, true)
      assert_eq(
        slotted_host_command(
          host,
          simulator,
          3,
          164,
          2,
          2,
          0,
          1024UL,
          40UL,
          c=slot,
        ),
        (5UL, 0UL, 0UL),
      )
      portable_ack(host, simulator, true)
    }
    assert_eq(host.requests.length(), 0)
    slotted_host_check_reset_sources(host, simulator)
    slotted_host_load(host, simulator, 0, 1, 1, 1, 128UL, 1UL, [9])
    assert_eq(
      slotted_host_command(
        host,
        simulator,
        2,
        165,
        1,
        1,
        1,
        0UL,
        0UL,
        a=1,
        b=1,
        c=1,
      ),
      (4UL, 0UL, 0UL),
    )
    portable_ack(host, simulator, true)
    slotted_host_load(host, simulator, 1, 0, 1, 1, 512UL, 1UL, [-7])
    slotted_host_success(
      host,
      simulator,
      2,
      166,
      1,
      1,
      1,
      0UL,
      0UL,
      0UL,
      a=1,
      c=1,
    )
    slotted_host_store_check(host, simulator, 1, 1, 1, 1536UL, [-63])
    assert_eq(host.requests[0][5], 0UL)
  }
}
