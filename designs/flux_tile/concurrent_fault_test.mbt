///|
fn concurrent_long_sources(
  host : PortableHost,
  simulator : @sim.Simulator,
) -> (Array[Int], Array[Int]) raise {
  let left = Array::makei(192, index => (index * 47 + 13) % 256 - 128)
  let right = Array::makei(128, index => (index * 83 + 231) % 256 - 128)
  concurrent_load(host, simulator, 0, 1, 3, 64, 512UL, 80UL, left)
  concurrent_load(host, simulator, 1, 1, 64, 2, 768UL, 8UL, right)
  (left, right)
}

///|
// Inject only the external response for an observed accepted transaction.
// The returned progress counts prior successful ACKs, not speculative issues.
fn concurrent_inject(
  host : PortableHost,
  simulator : @sim.Simulator,
  writing : Bool,
  occurrence : Int,
  protocol : Bool,
  status? : UInt64 = 0UL,
) -> (UInt64, UInt64, UInt64) raise {
  let mut matching = 0
  let mut reads = 0UL
  let mut writes = 0UL
  for _ in 0..<20000 {
    let count = host.requests.length()
    let acknowledged = host.pending is Some(p) &&
      p.remaining == 0 &&
      execute_read(simulator, "memory_response_ready") == 1UL
    if acknowledged {
      if host.requests[count - 1][0] == 1UL {
        writes += 4UL
      } else {
        reads += 1UL
      }
    }
    if !protocol &&
      matching + 1 == occurrence &&
      execute_read(simulator, "memory_request_valid") == 1UL &&
      (execute_read(simulator, "memory_request_write") == 1UL) == writing &&
      (!host.stalled || host.cycle % 4 == 3) {
      // Let the existing environment perform its documented partial failing
      // write before generating the remote failure response.
      host.fail_at = count
    }
    host.tick(simulator)
    if host.requests.length() == count + 1 &&
      (host.requests[count][0] == 1UL) == writing {
      matching += 1
      if matching == occurrence {
        guard host.pending is Some(p) else {
          fail("accepted transaction has no external pending response")
        }
        host.pending = Some({
          ..p,
          remaining: 0,
          tag: if protocol && status == 0UL {
            p.tag + 1UL
          } else {
            p.tag
          },
          fault: if protocol {
            status
          } else {
            1UL
          },
        })
        return (host.requests[count][1], reads, writes)
      }
    }
  }
  fail("target transaction not observed")
}

///|
test "concurrent matching remote failures stay local while independent engines progress and retry" {
  for writing in [false, true] {
    let host = PortableHost::new()
    let simulator = concurrent_prepare(3, 2, 64)
    let old = concurrent_seed_old(host, simulator)
    let (left, right) = concurrent_long_sources(host, simulator)
    let replacement = Array::make(192, -7)
    host.seed(32UL, 80UL, 3, 64, replacement)
    for byte in 0..<120 {
      host.memory[1536UL + byte.to_uint64()] = 165
    }
    concurrent_transfer_offer(simulator, "load", 81, 0, 3, 64, 32UL, 80UL)
    concurrent_transfer_offer(simulator, "store", 82, 0, 3, 2, 1536UL, 40UL)
    concurrent_compute_offer(simulator, 83, 3, 2, 64, a=1, b=1, c=1)
    host.tick(simulator)
    for channel in ["load", "store", "compute"] {
      concurrent_latched_noise(simulator, channel)
    }
    let (address, reads, writes) = concurrent_inject(
      host, simulator, writing, 2, false,
    )
    let active = execute_read(simulator, "active_cycles")
    assert_true(active > 0UL && active < 67UL)
    host.tick(simulator)
    assert_eq(execute_read(simulator, "active_cycles"), active + 1UL)
    let owner = if writing { "store" } else { "load" }
    concurrent_wait(host, simulator, owner, [
      if writing {
        82UL
      } else {
        81UL
      },
      9UL,
      if writing {
        writes
      } else {
        reads
      },
      address,
    ])
    assert_eq(execute_read(simulator, "transport_halted"), 0UL)
    concurrent_wait(host, simulator, "compute", [83UL, 0UL])
    if writing {
      concurrent_wait(host, simulator, "load", [81UL, 0UL, 192UL, 0UL])
      for byte in 0..<2 {
        assert_eq(
          host.memory[address + byte.to_uint64()],
          ((old[1].to_uint64() >> (byte * 8)) & 255UL).to_int(),
        )
      }
      assert_eq(host.memory[address + 2UL], 165)
      assert_eq(host.memory[address + 3UL], 165)
    } else {
      concurrent_wait(host, simulator, "store", [82UL, 0UL, 24UL, 0UL])
      concurrent_check_words(host, 1536UL, 3, 2, old)
    }
    for channel in ["load", "store", "compute"] {
      concurrent_ack(host, simulator, channel)
    }
    let expected = @flux_tile.matmul_int8_oracle(
      left,
      right,
      rows=3,
      columns=2,
      reduction=64,
    )
    concurrent_store(host, simulator, 1, 3, 2, 2048UL, expected)
    concurrent_store(host, simulator, 0, 3, 2, 1536UL, old)
    if !writing {
      concurrent_compute_offer(simulator, 84, 3, 2, 64, b=1, c=1)
      host.tick(simulator)
      concurrent_latched_noise(simulator, "compute")
      concurrent_wait(host, simulator, "compute", [84UL, 4UL])
      concurrent_ack(host, simulator, "compute")
      concurrent_load(host, simulator, 0, 0, 3, 64, 32UL, 80UL, replacement)
    }
    concurrent_compute(host, simulator, 3, 2, 64, b=1, c=1)
    let recovered = @flux_tile.matmul_int8_oracle(
      replacement,
      right,
      rows=3,
      columns=2,
      reduction=64,
    )
    concurrent_store(host, simulator, 1, 3, 2, 2048UL, recovered)
  }
}

///|
test "concurrent either poisoned DMA owner faults 10 sibling faults 15 and accepted compute continues" {
  for
    (writing, status) in [(false, 0UL), (true, 0UL), (false, 2UL), (true, 3UL)] {
    let host = PortableHost::new()
    let simulator = concurrent_prepare(3, 2, 64)
    ignore(concurrent_seed_old(host, simulator))
    ignore(concurrent_long_sources(host, simulator))
    host.seed(32UL, 80UL, 3, 64, Array::make(192, -7))
    concurrent_transfer_offer(simulator, "load", 85, 0, 3, 64, 32UL, 80UL)
    concurrent_transfer_offer(simulator, "store", 86, 0, 3, 2, 1536UL, 40UL)
    concurrent_compute_offer(simulator, 87, 3, 2, 64, a=1, b=1, c=1)
    host.tick(simulator)
    for channel in ["load", "store", "compute"] {
      concurrent_latched_noise(simulator, channel)
    }
    let (address, reads, writes) = concurrent_inject(
      host,
      simulator,
      writing,
      2,
      true,
      status~,
    )
    assert_true(reads > 0UL && writes > 0UL)
    let active = execute_read(simulator, "active_cycles")
    assert_true(active > 0UL && active < 67UL)
    let count = host.requests.length()
    host.tick(simulator)
    assert_eq(execute_read(simulator, "transport_halted"), 1UL)
    assert_eq(execute_read(simulator, "transport_fault_address"), address)
    assert_eq(execute_read(simulator, "active_cycles"), active + 1UL)
    let owner = if writing { "store" } else { "load" }
    let sibling = if writing { "load" } else { "store" }
    concurrent_wait(host, simulator, owner, [
      if writing {
        86UL
      } else {
        85UL
      },
      10UL,
      if writing {
        writes
      } else {
        reads
      },
      address,
    ])
    concurrent_wait(host, simulator, sibling, [
      if writing {
        85UL
      } else {
        86UL
      },
      15UL,
      if writing {
        reads
      } else {
        writes
      },
      0UL,
    ])
    concurrent_wait(host, simulator, "compute", [87UL, 0UL])
    assert_eq(execute_read(simulator, "active_cycles"), 67UL)
    assert_eq(execute_read(simulator, "capture_cycles"), 6UL)
    assert_eq(host.requests.length(), count)
    for channel in ["load", "store", "compute"] {
      concurrent_ack(host, simulator, channel)
    }
    for channel in ["load", "store", "compute"] {
      portable_put(simulator, channel + "_command_valid", 1, 1UL)
    }
    for _ in 0..<8 {
      host.tick(simulator)
      for channel in ["load", "store", "compute"] {
        assert_eq(execute_read(simulator, channel + "_command_ready"), 0UL)
        assert_eq(execute_read(simulator, channel + "_completion_valid"), 0UL)
      }
      assert_eq(execute_read(simulator, "memory_request_valid"), 0UL)
    }
    assert_eq(host.requests.length(), count)
    concurrent_reset(host, simulator)
    concurrent_load(host, simulator, 0, 0, 1, 1, 32UL, 1UL, [2])
    concurrent_load(host, simulator, 1, 1, 1, 1, 256UL, 1UL, [3])
    concurrent_compute(host, simulator, 1, 1, 1, b=1, c=1)
    concurrent_store(host, simulator, 1, 1, 1, 2048UL, [6])
    assert_eq(host.requests[0][5], 0UL)
  }
}

///|
test "concurrent already held transfer and compute completions survive later transport poison" {
  let host = PortableHost::new()
  let simulator = concurrent_prepare(3, 2, 5)
  let old = concurrent_seed_old(host, simulator)
  concurrent_compute_offer(simulator, 88, 3, 2, 5)
  host.tick(simulator)
  concurrent_latched_noise(simulator, "compute")
  concurrent_wait(host, simulator, "compute", [88UL, 0UL])
  for byte in 0..<120 {
    host.memory[1536UL + byte.to_uint64()] = 165
  }
  concurrent_transfer_offer(simulator, "store", 89, 0, 3, 2, 1536UL, 40UL)
  host.tick(simulator)
  concurrent_latched_noise(simulator, "store")
  concurrent_wait(host, simulator, "store", [89UL, 0UL, 24UL, 0UL])
  concurrent_transfer_offer(simulator, "load", 90, 1, 1, 1, 32UL, 1UL)
  host.tick(simulator)
  concurrent_latched_noise(simulator, "load")
  let (address, _, _) = concurrent_inject(host, simulator, false, 1, true)
  concurrent_wait(host, simulator, "load", [90UL, 10UL, 0UL, address])
  assert_eq(concurrent_payload(simulator, "store"), [89UL, 0UL, 24UL, 0UL])
  assert_eq(concurrent_payload(simulator, "compute"), [88UL, 0UL])
  concurrent_check_words(host, 1536UL, 3, 2, old)
}
