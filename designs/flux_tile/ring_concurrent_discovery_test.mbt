///|
fn ring_concurrent_discovery_fixture() -> (PortableHost, @sim.Simulator) raise {
  let host = PortableHost::new()
  let simulator = ring_concurrent_prepare(queue_depth=2)
  ring_concurrent_config(host, simulator)
  ignore(ring_concurrent_seed(host, simulator))
  host.seed(32UL, 80UL, 8, 64, Array::make(512, -7))
  let malformed = queued_concurrent_packet(Fence, 302)
  malformed[0] = malformed[0] ^ 768UL
  ring_concurrent_submit(host, simulator, 3UL, [
    queued_concurrent_packet(
      StoreC,
      300,
      rows=3,
      columns=2,
      base=4096UL,
      stride=40UL,
    ),
    queued_concurrent_packet(
      LoadA,
      301,
      rows=8,
      columns=64,
      base=32UL,
      stride=80UL,
    ),
    malformed,
    queued_concurrent_packet(Fence, 303),
    queued_concurrent_packet(Fence, 304),
    queued_concurrent_packet(Fence, 305),
  ])
  let mut found = false
  for _ in 0..<40000 {
    let fetched = host.requests
      .filter(r => r[0] == 0UL && r[1] >= 8448UL && r[1] < 8480UL)
      .length()
    if execute_read(simulator, "consumer_count") == 8UL &&
      fetched == 32 &&
      execute_read(simulator, "queue_occupancy") == 2UL &&
      execute_read(simulator, "completion_valid") == 1UL &&
      host.pending is Some(p) {
      let request = host.requests[host.requests.length() - 1]
      if request[0] == 0UL && request[1] < 8192UL {
        assert_eq(queued_concurrent_payload(simulator), [300UL, 0UL, 24UL, 0UL])
        host.pending = Some({ ..p, remaining: 100000, })
        found = true
        break
      }
    }
    host.tick(simulator)
  }
  assert_true(found)
  // A complete reader packet is backpressured, with a real external operand
  // response pending. Neither memory bytes nor hardware state is patched.
  for _ in 0..<8 {
    host.tick(simulator)
    assert_eq(execute_read(simulator, "consumer_count"), 8UL)
  }
  (host, simulator)
}

///|
test "ring concurrent packet admitted on malformed response discovery edge remains an ordered obligation" {
  // Calibrate using public consumer advancement, then replay identical host
  // stimuli with a bad response on that edge. No private-state/FSM timing is
  // assumed, and no simulated device state is modified or rewound.
  let (probe, probe_simulator) = ring_concurrent_discovery_fixture()
  queued_concurrent_ack(probe, probe_simulator)
  let mut edge = 0
  for index in 1..<100 {
    probe.tick(probe_simulator)
    if execute_read(probe_simulator, "consumer_count") == 9UL {
      edge = index
      break
    }
  }
  assert_true(edge > 0)
  let (host, simulator) = ring_concurrent_discovery_fixture()
  let address = host.requests[host.requests.length() - 1][1]
  let relative = address - 32UL
  let progress = relative / 80UL * 64UL + relative % 80UL
  assert_true(progress > 0UL && progress < 512UL)
  queued_concurrent_ack(host, simulator)
  for _ in 1..<edge {
    host.tick(simulator)
  }
  assert_eq(execute_read(simulator, "consumer_count"), 8UL)
  let pending = host.pending.unwrap()
  host.pending = Some({ ..pending, remaining: 0, fault: 3UL, })
  assert_eq(execute_read(simulator, "transport_halted"), 0UL)
  let count = host.requests.length()
  host.tick(simulator)
  assert_eq(execute_read(simulator, "transport_halted"), 1UL)
  assert_eq(execute_read(simulator, "consumer_count"), 9UL)
  assert_eq(execute_read(simulator, "ring_fault_valid"), 0UL)
  assert_eq(execute_read(simulator, "transport_fault_address"), address)
  queued_concurrent_drain(host, simulator, [
    [301UL, 10UL, progress, address],
    [302UL, 12UL, 0UL, 0UL],
    [303UL, 15UL, 0UL, 0UL],
    [304UL, 15UL, 0UL, 0UL],
    [305UL, 15UL, 0UL, 0UL],
  ])
  for _ in 0..<30 {
    host.tick(simulator)
    assert_eq(execute_read(simulator, "completion_valid"), 0UL)
    assert_eq(execute_read(simulator, "consumer_count"), 9UL)
  }
  assert_eq(host.requests.length(), count)
}
