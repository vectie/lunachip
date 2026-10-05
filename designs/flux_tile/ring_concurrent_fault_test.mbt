///|
fn ring_concurrent_fault_batch(
  host : PortableHost,
  simulator : @sim.Simulator,
) -> Array[Int] raise {
  ring_concurrent_config(host, simulator)
  ignore(ring_concurrent_seed(host, simulator, large=true))
  let expected = ring_concurrent_operands(host, simulator)
  host.seed(32UL, 80UL, 8, 64, Array::make(512, -7))
  for byte in 0..<320 {
    host.memory[4096UL + byte.to_uint64()] = 165
  }
  ring_concurrent_submit(host, simulator, 5UL, [
    queued_concurrent_packet(Fence, 200),
    queued_concurrent_packet(
      LoadA,
      201,
      rows=8,
      columns=64,
      base=32UL,
      stride=80UL,
    ),
    queued_concurrent_packet(
      StoreC,
      202,
      rows=8,
      columns=8,
      base=4096UL,
      stride=40UL,
    ),
    queued_concurrent_packet(
      MatMul,
      203,
      rows=8,
      columns=8,
      reduction=64,
      a=1,
      b=1,
      c=1,
    ),
    queued_concurrent_packet(
      StoreC,
      204,
      rows=8,
      columns=8,
      base=5120UL,
      stride=40UL,
      c=1,
    ),
    queued_concurrent_packet(Fence, 205),
  ])
  expected
}

///|
test "ring concurrent reader remote partial fetch stops only reader without fabricated completion" {
  let host = PortableHost::new()
  let simulator = ring_concurrent_prepare()
  let expected = ring_concurrent_fault_batch(host, simulator)
  let mut address = 0UL
  for _ in 0..<40000 {
    if host.pending is Some(p) && host.requests.length() > 0 {
      let request = host.requests[host.requests.length() - 1]
      // Sixth packet, byte9: five packets were already atomically admitted,
      // but this partial packet has no public command identity yet.
      if request[1] == 8192UL + 10UL * 32UL + 9UL {
        address = request[1]
        host.pending = Some({ ..p, remaining: 0, fault: 1UL, })
        break
      }
    }
    host.tick(simulator)
  }
  assert_true(address > 0UL)
  host.tick(simulator)
  for _ in 0..<20 {
    if execute_read(simulator, "ring_fault_valid") == 1UL {
      break
    }
    host.tick(simulator)
  }
  assert_eq(execute_read(simulator, "ring_fault_code"), 4UL)
  assert_eq(execute_read(simulator, "ring_fault_address"), address)
  assert_eq(execute_read(simulator, "consumer_count"), 10UL)
  assert_eq(execute_read(simulator, "transport_halted"), 0UL)
  queued_concurrent_drain(host, simulator, [
    [200UL, 0UL, 0UL, 0UL],
    [201UL, 0UL, 512UL, 0UL],
    [202UL, 0UL, 256UL, 0UL],
    [203UL, 0UL, 0UL, 0UL],
    [204UL, 0UL, 256UL, 0UL],
  ])
  let count = host.requests.length()
  for _ in 0..<100 {
    host.tick(simulator)
    assert_eq(execute_read(simulator, "completion_valid"), 0UL)
  }
  assert_eq(host.requests.length(), count)
  assert_true(
    host.requests.filter(r => r[1] >= 8192UL && r[1] > address).is_empty(),
  )
  // Already admitted dependent StoreC writes the actual computed result even
  // after the reader fails; no software replacement for the datapath is used.
  assert_eq(execute_read(simulator, "active_cycles"), 78UL)
  assert_eq(execute_read(simulator, "capture_cycles"), 64UL)
  for row in 0..<8 {
    for column in 0..<8 {
      assert_eq(
        host.word(5120UL + row.to_uint64() * 40UL + column.to_uint64() * 4UL),
        expected[row * 8 + column],
      )
    }
  }
}

///|
test "ring concurrent protocol ownership cancels unfinished siblings with progress while compute drains" {
  for owner in [0, 1, 2] {
    let host = PortableHost::new()
    let simulator = ring_concurrent_prepare()
    ignore(ring_concurrent_fault_batch(host, simulator))
    let mut reads = 0UL
    let mut writes = 0UL
    let mut address = 0UL
    let mut armed = false
    for _ in 0..<40000 {
      if host.pending is Some(p) && host.requests.length() > 0 {
        let request = host.requests[host.requests.length() - 1]
        let class = if request[0] == 1UL {
          2
        } else if request[1] >= 8192UL {
          0
        } else {
          1
        }
        let active = execute_read(simulator, "active_cycles")
        if class == owner &&
          reads > 0UL &&
          writes > 0UL &&
          execute_read(simulator, "consumer_count") >= 9UL &&
          execute_read(simulator, "capture_cycles") == 0UL &&
          active > 0UL &&
          active < 78UL {
          address = request[1]
          host.pending = Some({
            ..p,
            remaining: 0,
            tag: if owner == 0 {
              p.tag + 1UL
            } else {
              p.tag
            },
            fault: if owner == 0 {
              0UL
            } else {
              2UL
            },
          })
          armed = true
          break
        }
      }
      let ack = host.pending is Some(p) &&
        p.remaining == 0 &&
        execute_read(simulator, "memory_response_ready") == 1UL
      if ack {
        let request = host.requests[host.requests.length() - 1]
        if request[0] == 1UL {
          writes = writes + 4UL
        } else if request[1] < 8192UL {
          reads = reads + 1UL
        }
      }
      host.tick(simulator)
    }
    assert_true(armed)
    let active = execute_read(simulator, "active_cycles")
    let consumer = execute_read(simulator, "consumer_count")
    assert_true(consumer >= 9UL)
    let count = host.requests.length()
    host.tick(simulator)
    for _ in 0..<20 {
      if execute_read(simulator, "transport_halted") == 1UL {
        break
      }
      host.tick(simulator)
    }
    assert_eq(execute_read(simulator, "transport_halted"), 1UL)
    assert_eq(execute_read(simulator, "transport_fault_address"), address)
    assert_eq(execute_read(simulator, "publish_ready"), 0UL)
    assert_eq(queued_concurrent_payload(simulator), [200UL, 0UL, 0UL, 0UL])
    if owner == 0 {
      assert_eq(execute_read(simulator, "ring_fault_valid"), 1UL)
      assert_eq(execute_read(simulator, "ring_fault_code"), 5UL)
      assert_eq(execute_read(simulator, "ring_fault_address"), address)
    } else {
      assert_eq(execute_read(simulator, "ring_fault_valid"), 0UL)
    }
    let oldest = [
      201UL,
      if owner == 1 {
        10UL
      } else {
        15UL
      },
      reads,
      if owner == 1 {
        address
      } else {
        0UL
      },
    ]
    queued_concurrent_completion(host, simulator, [200UL, 0UL, 0UL, 0UL])
    for _ in 0..<200 {
      assert_eq(queued_concurrent_payload(simulator), [200UL, 0UL, 0UL, 0UL])
      if execute_read(simulator, "capture_cycles") == 64UL {
        break
      }
      host.tick(simulator)
    }
    assert_true(active < execute_read(simulator, "active_cycles"))
    assert_eq(execute_read(simulator, "active_cycles"), 78UL)
    assert_eq(execute_read(simulator, "capture_cycles"), 64UL)
    assert_eq(host.requests.length(), count)
    let terminal = [
      [200UL, 0UL, 0UL, 0UL],
      oldest,
      [
        202UL,
        if owner == 2 {
          10UL
        } else {
          15UL
        },
        writes,
        if owner == 2 {
          address
        } else {
          0UL
        },
      ],
      [203UL, 0UL, 0UL, 0UL],
    ]
    queued_concurrent_drain(host, simulator, terminal)
    // Only complete packets admitted before/discovery edge are obligations.
    for index in 9..<consumer.to_int() {
      queued_concurrent_drain(host, simulator, [
        [195UL + index.to_uint64(), 15UL, 0UL, 0UL],
      ])
    }
    for _ in 0..<30 {
      host.tick(simulator)
      assert_eq(execute_read(simulator, "completion_valid"), 0UL)
    }
    assert_eq(execute_read(simulator, "consumer_count"), consumer)
    assert_eq(host.requests.length(), count)
    ring_concurrent_reset(host, simulator)
    ring_concurrent_config(host, simulator)
    ring_concurrent_one(
      host,
      simulator,
      0UL,
      queued_concurrent_packet(
        MatMul,
        206,
        rows=1,
        columns=1,
        reduction=1,
        a=1,
        b=1,
        c=1,
      ),
      [206UL, 4UL, 0UL, 0UL],
    )
    assert_eq(host.requests[0][5], 0UL)
  }
}
