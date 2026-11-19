///|
fn queued_concurrent_formal_expected_roles() -> Array[
  (@flux_tile.QueuedConcurrentFormalRole, Int32),
] {
  let roles : Array[(@flux_tile.QueuedConcurrentFormalRole, Int32)] = []
  for index in 0..<4 {
    roles.push((HeadLane(index), 64))
  }
  let head_roles : Array[(@flux_tile.QueuedConcurrentFormalRole, Int32)] = [
    (HeadState, 2),
    (HeadReserve, 1),
    (NextTicket, 32),
    (HeadTicket, 32),
  ]
  for pair in head_roles {
    roles.push(pair)
  }
  for index in 0..<6 {
    roles.push((WriterStatus(index), 2))
    roles.push((WriterTicket(index), 32))
  }
  for index in 0..<2 {
    roles.push((DependencyStatus(index), 2))
    roles.push((DependencyTicket(index), 32))
  }
  let engine_roles : Array[(@flux_tile.QueuedConcurrentFormalRole, Int32)] = [
    (LoadAccept, 1),
    (ComputeAccept, 1),
    (StoreAccept, 1),
    (LoadTerminal, 1),
    (LoadTerminalTicket, 32),
    (LoadTerminalFault, 4),
    (ComputeTerminal, 1),
    (ComputeTerminalTicket, 32),
    (ComputeTerminalFault, 4),
    (StoreTerminal, 1),
    (StoreTerminalTicket, 32),
    (StoreTerminalFault, 4),
    (ComputePreflight, 4),
    (InnerCommandValid, 1),
    (InnerCommandReady, 1),
    (ComputeLatchedTicket, 32),
    (ComputeLatchedA, 1),
    (ComputeLatchedB, 1),
    (ComputeLatchedC, 1),
    (ComputeLatchedRows, 13),
    (ComputeLatchedColumns, 13),
    (ComputeLatchedReduction, 13),
    (LocalReject, 1),
    (LocalFault, 4),
  ]
  for pair in engine_roles {
    roles.push(pair)
  }
  roles
}

///|
fn queued_concurrent_formal_value(
  fixture : @flux_tile.QueuedConcurrentFormalFixture,
  simulator : @sim.Simulator,
  role : @flux_tile.QueuedConcurrentFormalRole,
) -> UInt64 raise {
  for observation in fixture.observations() {
    if observation.role() == role {
      return simulator.value(observation.node()).to_uint64()
    }
  }
  fail("missing queued-concurrent formal observation: \{Repr(role)}")
}

///|
fn queued_concurrent_formal_prepare(
  fixture : @flux_tile.QueuedConcurrentFormalFixture,
) -> @sim.Simulator raise {
  let hardware = fixture.hardware()
  let simulator = @sim.Simulator::prepare(hardware)
  for node in hardware.nodes() {
    if node.kind() is Input(name) && name != "clock" {
      portable_put(simulator, name, node.signal_type().width().bits(), 0UL)
    }
  }
  portable_put(simulator, "reset", 1, 1UL)
  simulator.rising_edge("clock")
  portable_put(simulator, "reset", 1, 0UL)
  simulator
}

///|
test "queued concurrent formal seam preserves the complete ordinary graph and RTL" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  assert_eq(fixture, @flux_tile.queued_concurrent_dependency_formal_fixture())
  let ordinary = @flux_tile.queued_concurrent_tile(
    rows=1,
    columns=1,
    max_reduction=2,
    host_bytes=1024UL,
    queue_depth=3,
  )
  assert_eq(fixture.hardware(), ordinary)
  let first = @wire.single_design(
    "QueuedConcurrentDependencyPilot",
    fixture.hardware(),
  )
  let second = @wire.single_design("QueuedConcurrentDependencyPilot", ordinary)
  assert_eq(@codec.serialize(first), @codec.serialize(second))
  assert_eq(
    @systemverilog.emit_design(first),
    @systemverilog.emit_design(second),
  )
  assert_eq(fixture.hardware().nodes().length(), ordinary.nodes().length())
  assert_eq(fixture.hardware().memories().length(), 10)
  assert_eq(fixture.hardware().outputs(), ordinary.outputs())
  assert_false(
    @systemverilog.emit_design(first).source().contains("lc_formal_observe_"),
  )
}

///|
test "queued concurrent formal seam resolves an exact typed inventory of existing nodes" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let expected = queued_concurrent_formal_expected_roles()
  assert_eq(expected.length(), 48)
  assert_eq(fixture.observations().length(), expected.length())
  let emitted = @systemverilog.emit_design(
    @wire.single_design("QueuedConcurrentDependencyPilot", fixture.hardware()),
  )
  for index, observation in fixture.observations() {
    let (role, width) = expected[index]
    assert_eq(observation.role(), role)
    assert_eq(observation.signal_type().width().bits(), width)
    guard fixture.hardware().node(observation.node()) is Some(node) else {
      fail("observation did not identify an existing canonical node")
    }
    assert_eq(node.signal_type(), observation.signal_type())
    let matches = emitted
      .manifest()
      .mappings()
      .filter(mapping => {
        mapping.kind() is Node &&
        mapping.module_ordinal() == emitted.manifest().top_module_ordinal() &&
        mapping.local_ordinal() == observation.node().ordinal()
      })
    assert_eq(matches.length(), 1)
    for prior in fixture.observations()[0:index] {
      assert_true(prior.role() != role)
    }
    match role {
      HeadLane(_)
      | HeadState
      | NextTicket
      | HeadTicket
      | WriterStatus(_)
      | WriterTicket(_)
      | DependencyStatus(_)
      | DependencyTicket(_)
      | ComputeLatchedTicket
      | ComputeLatchedA
      | ComputeLatchedB
      | ComputeLatchedC
      | ComputeLatchedRows
      | ComputeLatchedColumns
      | ComputeLatchedReduction => assert_true(node.kind() is Register(_))
      _ => ()
    }
  }
  // Distinct semantic roles may intentionally refer to the same physical
  // register: compute terminal identity and issued identity are one latch.
  let ticket_nodes = fixture
    .observations()
    .filter(observation => {
      observation.role() is ComputeTerminalTicket ||
      observation.role() is ComputeLatchedTicket
    })
  assert_eq(ticket_nodes.length(), 2)
  assert_eq(ticket_nodes[0].node(), ticket_nodes[1].node())
}

///|
test "queued concurrent formal seam captures genuine raw reservation and rejected generation" {
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let simulator = queued_concurrent_formal_prepare(fixture)
  let packet = queued_concurrent_packet(
    LoadA,
    73,
    rows=1,
    columns=1,
    base=32UL,
    stride=1UL,
    b=1,
  )
  assert_eq(execute_read(simulator, "descriptor_ready"), 1UL)
  for lane in 0..<4 {
    portable_put(simulator, "descriptor_lane_\{lane}", 64, packet[lane])
  }
  portable_put(simulator, "descriptor_valid", 1, 1UL)
  simulator.rising_edge("clock")
  portable_put(simulator, "descriptor_valid", 1, 0UL)
  for lane in 0..<4 {
    portable_put(simulator, "descriptor_lane_\{lane}", 64, 0UL)
  }
  let mut seen_reserve = false
  let mut seen_reject = false
  for _ in 0..<16 {
    assert_eq(
      queued_concurrent_formal_value(fixture, simulator, LoadAccept),
      0UL,
    )
    assert_eq(
      queued_concurrent_formal_value(fixture, simulator, ComputeAccept),
      0UL,
    )
    assert_eq(
      queued_concurrent_formal_value(fixture, simulator, StoreAccept),
      0UL,
    )
    if queued_concurrent_formal_value(fixture, simulator, HeadReserve) == 1UL {
      seen_reserve = true
      for lane in 0..<4 {
        assert_eq(
          queued_concurrent_formal_value(fixture, simulator, HeadLane(lane)),
          packet[lane],
        )
      }
      assert_eq(
        queued_concurrent_formal_value(fixture, simulator, NextTicket),
        0UL,
      )
      simulator.rising_edge("clock")
      assert_eq(
        queued_concurrent_formal_value(fixture, simulator, WriterStatus(0)),
        1UL,
      )
      assert_eq(
        queued_concurrent_formal_value(fixture, simulator, WriterTicket(0)),
        0UL,
      )
    } else if queued_concurrent_formal_value(fixture, simulator, LocalReject) ==
      1UL {
      seen_reject = true
      assert_eq(
        queued_concurrent_formal_value(fixture, simulator, LocalFault),
        2UL,
      )
      simulator.rising_edge("clock")
      assert_eq(
        queued_concurrent_formal_value(fixture, simulator, WriterStatus(0)),
        3UL,
      )
    } else {
      simulator.rising_edge("clock")
    }
  }
  assert_true(seen_reserve && seen_reject)
  assert_eq(queued_concurrent_payload(simulator), [73UL, 2UL, 0UL, 0UL])
  assert_eq(execute_read(simulator, "memory_request_valid"), 0UL)
  for index in 1..<6 {
    assert_eq(
      queued_concurrent_formal_value(fixture, simulator, WriterStatus(index)),
      0UL,
    )
  }
}

///|
test "queued concurrent formal seam retains accepted identity and shape through inner Issue" {
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
      83,
      rows=1,
      columns=1,
      reduction=2,
      a=1,
      b=0,
      c=1,
    ),
  )
  let mut seen_accept = false
  let mut seen_inner = false
  let mut seen_terminal = false
  let mut accepted_ticket = 0UL
  for _ in 0..<128 {
    if queued_concurrent_formal_value(fixture, simulator, ComputeAccept) == 1UL {
      seen_accept = true
      accepted_ticket = queued_concurrent_formal_value(
        fixture,
        simulator,
        HeadTicket,
      )
      assert_eq(
        queued_concurrent_formal_value(fixture, simulator, ComputePreflight),
        0UL,
      )
    }
    if queued_concurrent_formal_value(fixture, simulator, InnerCommandValid) ==
      1UL &&
      queued_concurrent_formal_value(fixture, simulator, InnerCommandReady) ==
      1UL {
      seen_inner = true
      assert_true(seen_accept)
      assert_eq(
        queued_concurrent_formal_value(fixture, simulator, ComputeLatchedTicket),
        accepted_ticket,
      )
      let shape : Array[(@flux_tile.QueuedConcurrentFormalRole, UInt64)] = [
        (ComputeLatchedA, 1UL),
        (ComputeLatchedB, 0UL),
        (ComputeLatchedC, 1UL),
        (ComputeLatchedRows, 1UL),
        (ComputeLatchedColumns, 1UL),
        (ComputeLatchedReduction, 2UL),
      ]
      for (role, expected) in shape {
        assert_eq(
          queued_concurrent_formal_value(fixture, simulator, role),
          expected,
        )
      }
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
        accepted_ticket,
      )
      assert_eq(
        queued_concurrent_formal_value(fixture, simulator, ComputeTerminalFault),
        0UL,
      )
    }
    if execute_read(simulator, "completion_valid") == 1UL {
      break
    }
    host.tick(simulator)
  }
  assert_true(seen_accept && seen_inner && seen_terminal)
  assert_eq(queued_concurrent_payload(simulator), [83UL, 0UL, 0UL, 0UL])
  assert_eq(
    queued_concurrent_formal_value(fixture, simulator, WriterStatus(5)),
    2UL,
  )
}
