///|
test "queued concurrent poisoned DMA owner and sibling retire in order while accepted compute drains" {
  for writing in [false, true] {
    let host = PortableHost::new()
    let simulator = queued_concurrent_prepare(16, capacity=64)
    ignore(queued_concurrent_seed_old(host, simulator))
    let left = Array::makei(192, index => (index * 47 + 13) % 256 - 128)
    let right = Array::makei(128, index => (index * 83 + 231) % 256 - 128)
    queued_concurrent_load(host, simulator, 0, 1, 3, 64, 512UL, 80UL, left)
    queued_concurrent_load(host, simulator, 1, 1, 64, 2, 768UL, 8UL, right)
    host.seed(32UL, 80UL, 3, 64, Array::make(192, -7))
    let malformed = queued_concurrent_packet(Fence, 105)
    malformed[0] = malformed[0] ^ 768UL
    for
      packet in [
        queued_concurrent_packet(
          LoadA,
          101,
          rows=3,
          columns=64,
          base=32UL,
          stride=80UL,
        ),
        queued_concurrent_packet(
          StoreC,
          102,
          rows=3,
          columns=2,
          base=1536UL,
          stride=40UL,
        ),
        queued_concurrent_packet(
          MatMul,
          103,
          rows=3,
          columns=2,
          reduction=64,
          a=1,
          b=1,
          c=1,
        ),
        // This intended C0 writer cannot issue until the pending A0 load succeeds.
        queued_concurrent_packet(
          MatMul,
          104,
          rows=3,
          columns=2,
          reduction=64,
          b=1,
        ),
        malformed,
        queued_concurrent_packet(Fence, 106),
      ] {
      queued_concurrent_enqueue(host, simulator, packet)
    }
    let (address, reads, writes) = concurrent_inject(
      host,
      simulator,
      writing,
      if writing {
        3
      } else {
        4
      },
      true,
    )
    assert_true(reads > 0UL && writes > 0UL)
    let active = execute_read(simulator, "active_cycles")
    assert_true(active > 0UL && active < 67UL)
    let count = host.requests.length()
    // Admission on the corrupt-response discovery edge is part of the accepted
    // prefix, even though the next edge closes all further packet admission.
    frontend_present(simulator, queued_concurrent_packet(Fence, 107))
    assert_eq(execute_read(simulator, "descriptor_ready"), 1UL)
    host.tick(simulator)
    portable_put(simulator, "descriptor_valid", 1, 0UL)
    assert_eq(execute_read(simulator, "descriptor_ready"), 0UL)
    assert_eq(execute_read(simulator, "halted"), 1UL)
    assert_eq(execute_read(simulator, "transport_fault_address"), address)
    assert_eq(execute_read(simulator, "active_cycles"), active + 1UL)
    let oldest = [
      101UL,
      if writing {
        15UL
      } else {
        10UL
      },
      reads,
      if writing {
        0UL
      } else {
        address
      },
    ]
    queued_concurrent_completion(host, simulator, oldest)
    for _ in 0..<200 {
      assert_eq(queued_concurrent_payload(simulator), oldest)
      if execute_read(simulator, "capture_cycles") == 6UL {
        break
      }
      host.tick(simulator)
    }
    assert_eq(execute_read(simulator, "active_cycles"), 67UL)
    assert_eq(execute_read(simulator, "capture_cycles"), 6UL)
    assert_eq(host.requests.length(), count)
    queued_concurrent_drain(host, simulator, [
      oldest,
      [
        102UL,
        if writing {
          10UL
        } else {
          15UL
        },
        writes,
        if writing {
          address
        } else {
          0UL
        },
      ],
      [103UL, 0UL, 0UL, 0UL],
      [104UL, 15UL, 0UL, 0UL],
      [105UL, 15UL, 0UL, 0UL],
      [106UL, 15UL, 0UL, 0UL],
      [107UL, 15UL, 0UL, 0UL],
    ])
    assert_eq(host.requests.length(), count)
    queued_concurrent_reset(host, simulator)
    queued_concurrent_enqueue(
      host,
      simulator,
      queued_concurrent_packet(
        MatMul,
        108,
        rows=1,
        columns=1,
        reduction=1,
        a=1,
        b=1,
        c=1,
      ),
    )
    queued_concurrent_drain(host, simulator, [[108UL, 4UL, 0UL, 0UL]])
    assert_eq(host.requests.length(), 0)
    queued_concurrent_load(host, simulator, 0, 0, 1, 1, 32UL, 1UL, [2])
    queued_concurrent_load(host, simulator, 1, 1, 1, 1, 256UL, 1UL, [3])
    queued_concurrent_compute(host, simulator, 1, 1, 1, b=1, c=1)
    queued_concurrent_store(host, simulator, 1, 1, 1, 2048UL, [6])
    assert_eq(host.requests[0][5], 0UL)
  }
}

///|
test "queued concurrent joint reset flushes active transport dispatch retirement and latest writers" {
  for writing in [false, true] {
    let host = PortableHost::new()
    let simulator = queued_concurrent_prepare(16, capacity=16)
    let old = queued_concurrent_seed_old(host, simulator)
    queued_concurrent_load(
      host,
      simulator,
      0,
      1,
      3,
      16,
      512UL,
      24UL,
      Array::make(48, 7),
    )
    queued_concurrent_load(
      host,
      simulator,
      1,
      1,
      16,
      2,
      768UL,
      8UL,
      Array::make(32, -9),
    )
    host.latency = 100
    host.seed(32UL, 24UL, 3, 16, Array::make(48, 11))
    for
      packet in [
        if writing {
          queued_concurrent_packet(
            StoreC,
            201,
            rows=3,
            columns=2,
            base=1536UL,
            stride=40UL,
          )
        } else {
          queued_concurrent_packet(Fence, 201)
        },
        queued_concurrent_packet(
          LoadA,
          202,
          rows=3,
          columns=16,
          base=32UL,
          stride=24UL,
        ),
        queued_concurrent_packet(
          MatMul,
          203,
          rows=3,
          columns=2,
          reduction=16,
          a=1,
          b=1,
          c=1,
        ),
        queued_concurrent_packet(Fence, 204),
        queued_concurrent_packet(Fence, 205),
      ] {
      queued_concurrent_enqueue(host, simulator, packet)
    }
    for _ in 0..<100 {
      if host.pending is Some(_) &&
        execute_read(simulator, "active_cycles") == 1UL {
        break
      }
      host.tick(simulator)
    }
    assert_true(host.pending is Some(_))
    assert_eq(execute_read(simulator, "active_cycles"), 1UL)
    if writing {
      assert_eq(host.word(1536UL), old[0])
    }
    queued_concurrent_reset(host, simulator)
    if writing {
      assert_eq(host.word(1536UL), old[0])
    }
    host.latency = 1
    for
      packet in [
        queued_concurrent_packet(
          StoreC,
          206,
          rows=3,
          columns=2,
          base=1536UL,
          stride=40UL,
        ),
        queued_concurrent_packet(
          MatMul,
          207,
          rows=3,
          columns=2,
          reduction=16,
          a=1,
          b=1,
          c=1,
        ),
        queued_concurrent_packet(
          StoreC,
          208,
          rows=3,
          columns=2,
          base=2048UL,
          stride=40UL,
          c=1,
        ),
      ] {
      queued_concurrent_enqueue(host, simulator, packet)
    }
    queued_concurrent_drain(host, simulator, [
      [206UL, 5UL, 0UL, 0UL],
      [207UL, 4UL, 0UL, 0UL],
      [208UL, 5UL, 0UL, 0UL],
    ])
    assert_eq(host.requests.length(), 0)
    queued_concurrent_load(host, simulator, 0, 0, 1, 1, 32UL, 1UL, [2])
    queued_concurrent_load(host, simulator, 1, 1, 1, 1, 256UL, 1UL, [3])
    queued_concurrent_compute(host, simulator, 1, 1, 1, b=1, c=1)
    queued_concurrent_store(host, simulator, 1, 1, 1, 2048UL, [6])
    assert_eq(host.requests[0][5], 0UL)
  }
}
