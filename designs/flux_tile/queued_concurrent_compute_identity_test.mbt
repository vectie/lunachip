///|
// Read existing canonical registers through the published purpose-specific
// view. These tests neither alter the production graph nor patch device state.
fn queued_compute_identity(
  fixture : @flux_tile.QueuedConcurrentFormalFixture,
  simulator : @sim.Simulator,
) -> Array[UInt64] raise {
  let roles : Array[@flux_tile.QueuedConcurrentFormalRole] = [
    ComputeLatchedTicket,
    ComputeLatchedA,
    ComputeLatchedB,
    ComputeLatchedC,
    ComputeLatchedRows,
    ComputeLatchedColumns,
    ComputeLatchedReduction,
  ]
  roles.map(role => queued_concurrent_formal_value(fixture, simulator, role))
}

///|
test "queued concurrent compute identity survives genuine unrelated writer changes" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let simulator = queued_concurrent_formal_prepare(fixture)
  let host = PortableHost::new()
  let left = [-3, 7]
  let right = [5, -2]
  queued_concurrent_load(host, simulator, 0, 1, 1, 2, 32UL, 2UL, left)
  queued_concurrent_load(host, simulator, 1, 0, 2, 1, 256UL, 1UL, right)
  queued_concurrent_enqueue(
    host,
    simulator,
    queued_concurrent_packet(
      MatMul,
      83,
      rows=1,
      columns=1,
      reduction=2,
      a=1,
      b=0,
      c=1,
    ),
  )
  // The younger writer is syntactically valid but has an unused B selector.
  // It genuinely publishes then fails A0 while the accepted compute uses A1.
  // Duplicate caller IDs must not replace the accepted internal ticket.
  let younger = queued_concurrent_packet(
    LoadA,
    83,
    rows=1,
    columns=1,
    base=96UL,
    stride=1UL,
    b=1,
  )
  queued_concurrent_enqueue(host, simulator, younger)
  let mut accepted = false
  let mut ticket = 0UL
  let mut younger_ticket = 0UL
  let mut inner_edges = 0
  let mut seen_pending = false
  let mut seen_failed = false
  let mut seen_terminal = false
  for _ in 0..<128 {
    let accept = queued_concurrent_formal_value(
        fixture,
        simulator,
        ComputeAccept,
      ) ==
      1UL
    if accept {
      assert_false(accepted)
      ticket = queued_concurrent_formal_value(fixture, simulator, HeadTicket)
      assert_true(ticket != 83UL)
      assert_eq(
        queued_concurrent_formal_value(fixture, simulator, ComputePreflight),
        0UL,
      )
    }
    if queued_concurrent_formal_value(fixture, simulator, InnerCommandValid) ==
      1UL {
      assert_true(accepted)
      // Admission/whole-store ownership make this ordinary fixture's Issue
      // ready immediately. This is not a manufactured stalled-Issue test.
      assert_eq(
        queued_concurrent_formal_value(fixture, simulator, InnerCommandReady),
        1UL,
      )
      inner_edges += 1
      assert_eq(queued_compute_identity(fixture, simulator), [
        ticket, 1UL, 0UL, 1UL, 1UL, 1UL, 2UL,
      ])
    }
    let reserve = queued_concurrent_formal_value(
        fixture,
        simulator,
        HeadReserve,
      ) ==
      1UL &&
      queued_concurrent_formal_value(fixture, simulator, HeadLane(0)) ==
      younger[0]
    if reserve {
      assert_true(accepted)
      for lane in 0..<4 {
        assert_eq(
          queued_concurrent_formal_value(fixture, simulator, HeadLane(lane)),
          younger[lane],
        )
      }
      younger_ticket = queued_concurrent_formal_value(
        fixture,
        simulator,
        NextTicket,
      )
      assert_true(younger_ticket != ticket)
    }
    let reject = queued_concurrent_formal_value(fixture, simulator, LocalReject) ==
      1UL
    if reject {
      assert_eq(
        queued_concurrent_formal_value(fixture, simulator, LocalFault),
        2UL,
      )
    }
    if queued_concurrent_formal_value(fixture, simulator, ComputeTerminal) ==
      1UL {
      seen_terminal = true
      assert_eq(
        queued_concurrent_formal_value(
          fixture,
          simulator,
          ComputeTerminalTicket,
        ),
        ticket,
      )
      assert_eq(
        queued_concurrent_formal_value(fixture, simulator, ComputeTerminalFault),
        0UL,
      )
    }
    // Non-valid caller lanes may change freely, but neither the dispatch head
    // nor accepted compute identity may follow them.
    for lane in 0..<4 {
      portable_put(
        simulator,
        "descriptor_lane_\{lane}",
        64,
        255UL + lane.to_uint64(),
      )
    }
    host.tick(simulator)
    if accept {
      accepted = true
    }
    if accepted {
      assert_eq(queued_compute_identity(fixture, simulator), [
        ticket, 1UL, 0UL, 1UL, 1UL, 1UL, 2UL,
      ])
    }
    if reserve {
      seen_pending = true
      assert_eq(
        queued_concurrent_formal_value(fixture, simulator, WriterStatus(0)),
        1UL,
      )
      assert_eq(
        queued_concurrent_formal_value(fixture, simulator, WriterTicket(0)),
        younger_ticket,
      )
      assert_false(seen_terminal)
    }
    if reject {
      seen_failed = true
      assert_eq(
        queued_concurrent_formal_value(fixture, simulator, WriterStatus(0)),
        3UL,
      )
      assert_false(seen_terminal)
    }
    if seen_terminal &&
      seen_failed &&
      execute_read(simulator, "completion_valid") == 1UL {
      break
    }
  }
  assert_true(accepted && seen_pending && seen_failed && seen_terminal)
  assert_eq(inner_edges, 1)
  // Retirement may be held after the engine's identity-matching success.
  queued_concurrent_completion(host, simulator, [83UL, 0UL, 0UL, 0UL])
  assert_eq(queued_compute_identity(fixture, simulator), [
    ticket, 1UL, 0UL, 1UL, 1UL, 1UL, 2UL,
  ])
  queued_concurrent_drain(host, simulator, [
    [83UL, 0UL, 0UL, 0UL],
    [83UL, 2UL, 0UL, 0UL],
  ])
  queued_concurrent_store(
    host,
    simulator,
    1,
    1,
    1,
    512UL,
    @flux_tile.matmul_int8_oracle(left, right, rows=1, columns=1, reduction=2),
  )
}

///|
test "queued concurrent compute identity exact-shape rejection never issues inner core" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let simulator = queued_concurrent_formal_prepare(fixture)
  let host = PortableHost::new()
  queued_concurrent_load(host, simulator, 0, 1, 1, 1, 32UL, 1UL, [3])
  queued_concurrent_load(host, simulator, 1, 0, 1, 1, 256UL, 1UL, [-2])
  queued_concurrent_compute(host, simulator, 1, 1, 1, a=1, b=0, c=0)
  let counters = [
    "accepted_steps", "elapsed_cycles", "active_cycles", "capture_cycles",
  ]
  let previous = counters.map(name => execute_read(simulator, name))
  assert_eq(previous[0], 1UL)
  let requests = host.requests.length()
  // Both saved dependency summaries are Success, but exact physical shapes
  // are K1, not this legal K2 candidate. The engine, not local decode, rejects.
  queued_concurrent_enqueue(
    host,
    simulator,
    queued_concurrent_packet(
      MatMul,
      84,
      rows=1,
      columns=1,
      reduction=2,
      a=1,
      b=0,
      c=1,
    ),
  )
  let mut accepted = false
  let mut terminal = false
  let mut ticket = 0UL
  for _ in 0..<128 {
    assert_eq(
      queued_concurrent_formal_value(fixture, simulator, InnerCommandValid),
      0UL,
    )
    assert_eq(counters.map(name => execute_read(simulator, name)), previous)
    let accept = queued_concurrent_formal_value(
        fixture,
        simulator,
        ComputeAccept,
      ) ==
      1UL
    if accept {
      assert_false(accepted)
      ticket = queued_concurrent_formal_value(fixture, simulator, HeadTicket)
      assert_eq(
        queued_concurrent_formal_value(fixture, simulator, ComputePreflight),
        4UL,
      )
      for source in 0..<2 {
        assert_eq(
          queued_concurrent_formal_value(
            fixture,
            simulator,
            DependencyStatus(source),
          ),
          2UL,
        )
      }
    }
    if queued_concurrent_formal_value(fixture, simulator, ComputeTerminal) ==
      1UL {
      terminal = true
      assert_true(accepted)
      assert_eq(
        queued_concurrent_formal_value(
          fixture,
          simulator,
          ComputeTerminalTicket,
        ),
        ticket,
      )
      assert_eq(
        queued_concurrent_formal_value(fixture, simulator, ComputeTerminalFault),
        4UL,
      )
    }
    host.tick(simulator)
    if accept {
      accepted = true
    }
    if accepted {
      assert_eq(queued_compute_identity(fixture, simulator), [
        ticket, 1UL, 0UL, 1UL, 1UL, 1UL, 2UL,
      ])
    }
    if terminal && execute_read(simulator, "completion_valid") == 1UL {
      break
    }
  }
  assert_true(accepted && terminal)
  assert_eq(host.requests.length(), requests)
  assert_eq(
    queued_concurrent_formal_value(fixture, simulator, WriterStatus(5)),
    3UL,
  )
  queued_concurrent_drain(host, simulator, [[84UL, 4UL, 0UL, 0UL]])
  // Rejected C1 does not invalidate the independently stored earlier C0.
  queued_concurrent_store(host, simulator, 0, 1, 1, 512UL, [-6])
}

///|
test "queued concurrent compute identity reset interrupts genuine Issue before inner acceptance" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let simulator = queued_concurrent_formal_prepare(fixture)
  let host = PortableHost::new()
  queued_concurrent_load(host, simulator, 0, 1, 1, 2, 32UL, 2UL, [-3, 7])
  queued_concurrent_load(host, simulator, 1, 0, 2, 1, 256UL, 1UL, [5, -2])
  queued_concurrent_enqueue(
    host,
    simulator,
    queued_concurrent_packet(
      MatMul,
      85,
      rows=1,
      columns=1,
      reduction=2,
      a=1,
      b=0,
      c=1,
    ),
  )
  let mut accepted = false
  let mut ticket = 0UL
  for _ in 0..<128 {
    assert_eq(
      queued_concurrent_formal_value(fixture, simulator, InnerCommandValid),
      0UL,
    )
    if queued_concurrent_formal_value(fixture, simulator, ComputeAccept) == 1UL {
      ticket = queued_concurrent_formal_value(fixture, simulator, HeadTicket)
      host.tick(simulator)
      accepted = true
      break
    }
    host.tick(simulator)
  }
  assert_true(accepted)
  assert_eq(queued_compute_identity(fixture, simulator), [
    ticket, 1UL, 0UL, 1UL, 1UL, 1UL, 2UL,
  ])
  assert_eq(
    queued_concurrent_formal_value(fixture, simulator, InnerCommandValid),
    1UL,
  )
  assert_eq(
    queued_concurrent_formal_value(fixture, simulator, InnerCommandReady),
    1UL,
  )
  assert_eq(execute_read(simulator, "accepted_steps"), 0UL)
  // Reset is asserted before this offered inner handshake's rising edge.
  // The existing joint-reset helper also flushes the real external peer.
  queued_concurrent_reset(host, simulator)
  assert_eq(queued_compute_identity(fixture, simulator), Array::make(7, 0UL))
  for
    role in [
      @flux_tile.QueuedConcurrentFormalRole::ComputeAccept,
      InnerCommandValid,
      ComputeTerminal,
    ] {
    assert_eq(queued_concurrent_formal_value(fixture, simulator, role), 0UL)
  }
  for index in 0..<6 {
    assert_eq(
      queued_concurrent_formal_value(fixture, simulator, WriterStatus(index)),
      0UL,
    )
  }
  assert_eq(execute_read(simulator, "accepted_steps"), 0UL)
  // No completion is synthesized for the interrupted ticket. Fresh physical
  // loads and a new accepted identity can use the reset-cleared slots again.
  queued_concurrent_load(host, simulator, 0, 0, 1, 1, 64UL, 1UL, [-7])
  queued_concurrent_load(host, simulator, 1, 1, 1, 1, 288UL, 1UL, [4])
  queued_concurrent_compute(host, simulator, 1, 1, 1, a=0, b=1, c=0)
  queued_concurrent_store(host, simulator, 0, 1, 1, 512UL, [-28])
}
