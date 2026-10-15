///|
test "fetched q2 local Fence and rejection cannot rewrite an older held terminal record" {
  let fixture = @flux_tile.ring_concurrent_queue_formal_fixture()
  let simulator = @sim.Simulator::prepare(fixture.hardware())
  for node in fixture.hardware().nodes() {
    if node.kind() is Input(name) && name != "clock" {
      records_put(simulator, name, node.signal_type().width().bits(), 0UL)
    }
  }
  let packets = [
    records_packet(4UL, 0UL, 0UL, 0UL, 0UL, 0UL),
    records_packet(4UL, 1UL, 0UL, 0UL, 0UL, 0UL),
  ]
  let mut pending : RecordsResponse? = None
  let mut previous : RecordsPre? = None
  let mut configured = false
  let mut published = false
  let mut release = false
  let mut local_while_held = false
  let mut release_seen = false
  let mut negative_seen = false
  let mut reads = 0
  let mut retired = 0
  for edge in 0..<512 {
    for
      (name, width, value) in [
        ("reset", 1, if edge == 0 { 1UL } else { 0UL }),
        ("config_valid", 1, if edge > 0 && !configured { 1UL } else { 0UL }),
        ("publish_valid", 1, if configured && !published { 1UL } else { 0UL }),
        ("publish_producer", 32, 2UL),
        ("completion_ready", 1, if release { 1UL } else { 0UL }),
        ("memory_request_ready", 1, 1UL),
        ("memory_response_valid", 1, if pending is Some(_) { 1UL } else { 0UL }),
        ("memory_response_tag", 32, pending.map(r => r.tag).unwrap_or(0UL)),
        ("memory_response_data", 32, pending.map(r => r.data).unwrap_or(0UL)),
      ] {
      records_put(simulator, name, width, value)
    }
    simulator.settle()
    if edge > 0 {
      if !configured && records_output(simulator, "config_ready") == 1UL {
        configured = true
      } else if configured &&
        !published &&
        records_output(simulator, "publish_ready") == 1UL {
        published = true
      }
      let current = fetched_retirement_pre(fixture, simulator)
      fetched_retirement_check_state(fixture, simulator, current)
      let (_, _, released) = records_check(previous, current)
      release_seen = release_seen || released
      if current.valid && !current.ready {
        for entry in 0..<2 {
          if entry != current.pointer &&
            records_observe(fixture, simulator, EntryLocalTerminal(entry)) ==
            1UL {
            local_while_held = true
          }
        }
        if current.entries.all(entry => entry.valid && entry.terminal) {
          release = true
        }
        if !negative_seen {
          let changed : RecordsPre = {
            ..current,
            ready: true,
            payload: [
              72UL,
              current.payload[1],
              current.payload[2],
              current.payload[3],
            ],
          }
          try records_check(Some(current), changed) catch {
            _ => negative_seen = true
          } noraise {
            _ => fail("wrong caller ID accepted on held-record release")
          }
        }
      }
      if current.valid && current.ready {
        assert_eq(current.payload, [
          73UL,
          if retired == 0 {
            0UL
          } else {
            2UL
          },
          0UL,
          0UL,
        ])
        retired += 1
      }
      previous = Some(current)
      if records_output(simulator, "memory_request_valid") == 1UL {
        assert_true(pending is None)
        assert_eq(records_output(simulator, "memory_request_write"), 0UL)
        let address = records_output(simulator, "memory_request_address").to_int()
        assert_true(address < 64)
        let packet = packets[address / 32]
        let offset = address % 32
        pending = Some({
          tag: records_output(simulator, "memory_request_tag"),
          data: (packet[offset / 8] >> (offset % 8 * 8)) & 255UL,
          delay: 0,
        })
        reads += 1
      } else if pending is Some(_) &&
        records_output(simulator, "memory_response_ready") == 1UL {
        pending = None
      }
      if retired == 2 {
        break
      }
    }
    simulator.rising_edge("clock")
    simulator.settle()
  }
  assert_eq((retired, reads), (2, 64))
  assert_true(local_while_held && release_seen && negative_seen)
}
