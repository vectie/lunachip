///|
test "queue owner candidate probe preserves thirty exact roots events and reset masks" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let hardware = fixture.hardware()
  let before = @ir_codec.serialize(
    @ir.Design::single("QueuedConcurrentQueueConservationPilot", hardware),
  )
  let probe = queue_owner_probe(fixture)
  assert_eq(probe, queue_owner_probe(fixture))
  assert_eq(probe.roots.length(), 30)
  assert_eq(
    probe.roots
    .iter()
    .fold(init=0, (bits, root) => bits + root.signal_type.width().bits()),
    304,
  )
  assert_eq(probe.events.length(), 59)
  assert_eq(probe.production_digest, sha256_hex(before))
  assert_eq(
    probe.production_digest,
    "35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc",
  )
  assert_eq(
    @ir_codec.serialize(
      @ir.Design::single("QueuedConcurrentQueueConservationPilot", hardware),
    ),
    before,
  )
  for root in probe.roots {
    guard fixture
      .observations()
      .filter(observation => queue_role_name(observation.role()) == root.name)
      is [observation] else {
      fail("missing authoritative root role")
    }
    assert_eq(observation.node(), root.node)
    assert_eq(observation.signal_type(), root.signal_type)
    let original = dependency_generation_node(hardware, root.node)
    guard original.kind() is Register(spec) else {
      fail("essential root is not original state")
    }
    assert_eq(original.signal_type(), root.signal_type)
    assert_eq(root.spec, spec)
    assert_eq(spec.initial(), None)
    assert_eq(spec.domain(), @ir.ClockDomain::rising(probe.clock))
    guard spec.reset() is Some(reset) else {
      fail("essential state lost reset")
    }
    assert_eq(reset.signal(), probe.reset)
    assert_eq(reset.value(), 0UL)
    assert_eq(reset.mode(), Synchronous)
    assert_eq(reset.polarity(), ActiveHigh)
    assert_false(probe.candidates.any(leaf => leaf.original.id() == root.node))
  }
  for event in probe.events {
    assert_true(probe.cone.any(node => node.id() == event.node))
    assert_false(probe.candidates.any(leaf => leaf.original.id() == event.node))
    assert_eq(
      dependency_generation_node(hardware, event.node).signal_type(),
      event.signal_type,
    )
  }
  let (inactive, _) = dependency_generation_decoder_and(
    hardware,
    probe.events.filter(event => event.name == "public_halted")[0].node,
  )
  for engine in 0..<3 {
    let state = queue_control_binding(fixture, EngineState(engine))
    let terminal = queue_control_binding(fixture, EngineTerminal(engine))
    let (reset_gate, comparison) = dependency_generation_decoder_and(
      hardware,
      terminal.node,
    )
    assert_eq(reset_gate, inactive)
    assert_eq(
      dependency_generation_decoder_equal_constant(
        hardware,
        comparison,
        state.signal_type.width().bits(),
        if engine == 1 {
          3UL
        } else {
          4UL
        },
      ),
      state.node,
    )
    let accept = queue_control_binding(fixture, EngineAccept(engine))
    let ticket = queue_control_binding(fixture, EngineTicket(engine))
    guard probe.roots.filter(root => root.node == ticket.node) is [root] else {
      fail("missing engine ticket root")
    }
    let (capture, value, hold) = dependency_generation_decoder_mux(
      hardware,
      root.spec.next(),
    )
    assert_eq(capture, accept.node)
    assert_eq(value, queue_control_binding(fixture, HeadTicket).node)
    assert_eq(hold, ticket.node)
  }
  let finish = queue_control_binding(fixture, HeadFinish)
  guard dependency_generation_node(hardware, finish.node).kind()
    is BitOr(issue, local_terminal) &&
    dependency_generation_node(hardware, local_terminal).kind()
    is BitOr(reject, fence) else {
    fail("actual finish equation changed")
  }
  assert_eq(issue, queue_control_binding(fixture, HeadIssue).node)
  assert_eq(reject, queue_control_binding(fixture, HeadReject).node)
  assert_eq(fence, queue_control_binding(fixture, HeadFence).node)
  for entry in 0..<3 {
    let ticket = queue_control_binding(fixture, EntryTicket(entry))
    guard probe.roots.filter(root => root.node == ticket.node) is [root] else {
      fail("missing entry ticket root")
    }
    let (allocate, value, hold) = dependency_generation_decoder_mux(
      hardware,
      root.spec.next(),
    )
    assert_eq(
      allocate,
      queue_control_binding(fixture, EntryAllocate(entry)).node,
    )
    assert_eq(value, queue_control_binding(fixture, NextTicket).node)
    assert_eq(hold, ticket.node)
  }
  assert_true(probe.candidates.length() > 0)
  let mut previous = -1
  for leaf in probe.candidates {
    let node = leaf.original
    assert_true(node.id().ordinal() > previous)
    previous = node.id().ordinal()
    assert_eq(dependency_generation_node(hardware, node.id()), node)
    assert_eq(queue_owner_candidate_leaf(hardware, node, probe.reset), leaf)
    match node.kind() {
      Input(_) | Register(_) => assert_eq(leaf.memory, None)
      MemoryRead(memory~, ..) => {
        guard hardware.memories().filter(spec => spec.id() == memory) is [spec] else {
          fail("missing original memory")
        }
        assert_eq(leaf.memory, Some(spec))
      }
      _ => fail("combinational event was treated as a foreign leaf")
    }
  }
  for node in probe.cone {
    assert_true(node.signal_type().is_data())
    for operand in dependency_generation_operands(node.kind()) {
      assert_true(
        probe.roots.any(root => root.node == operand) ||
        probe.candidates.any(leaf => leaf.original.id() == operand) ||
        probe.cone.any(original => original.id() == operand),
      )
    }
  }
}

///|
test "queue owner candidate probe rejects unknown control async storage and missing essential state" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let probe = queue_owner_probe(fixture)
  let hardware = fixture.hardware()
  try
    queue_owner_candidate_leaf(
      hardware,
      dependency_generation_node(hardware, probe.clock),
      probe.reset,
    )
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong control rejection")
  } noraise {
    _ => fail("unexpected clock leaf was accepted")
  }
  let asynchronous = @ir.Node::new(
    @ir.NodeId::new(0),
    @wire.bits(1),
    AsyncFifoRead(primitive=@ir.CdcPrimitiveId::new(0), leaf=0),
  )
  try queue_owner_candidate_leaf(hardware, asynchronous, probe.reset) catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong asynchronous leaf rejection")
  } noraise {
    _ => fail("asynchronous storage was accepted")
  }
  try queue_owner_probe_walk(hardware, probe.roots[1:], [], probe.reset) catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong missing-root rejection")
  } noraise {
    _ => fail("unretained essential state was accepted")
  }
  let derived = queue_control_binding(fixture, EngineAccept(0))
  try
    queue_owner_candidate_leaf(
      hardware,
      dependency_generation_node(hardware, derived.node),
      probe.reset,
    )
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("wrong derived-event rejection")
  } noraise {
    _ => fail("derived acceptance became a foreign leaf")
  }
}

///|
test "queue owner complete candidate signatures require inspection before any projection" {
  let probe = queue_owner_probe(
    @flux_tile.queued_concurrent_queue_formal_fixture(),
  )
  let report = queue_owner_probe_report(probe)
  assert_eq(report, queue_owner_probe_report(probe))
  assert_true(
    report.contains("CANDIDATE-PROBE ONLY-not-accepted-projection-or-proof"),
  )
  assert_eq(report.split("\nROOT ").count() - 1, 30)
  assert_eq(report.split("\nEVENT ").count() - 1, 59)
  assert_eq(
    report.split("\nCANDIDATE node ").count() - 1,
    probe.candidates.length(),
  )
  // Complete signatures inspected by root and an independent source reviewer.
  // This snapshot freezes candidate discovery, not an accepted cut allowlist.
  inspect(
    report,
    content=(
      #|CANDIDATE-PROBE ONLY-not-accepted-projection-or-proof
      #|PRODUCTION sha256 35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc
      #|ESSENTIAL roots 30 bits304
      #|CANDIDATES 82 CONE 1155 EVENTS 59
      #|ROOT fifo_occupancy_0 node 1636 type UInt(Width(2)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(1669),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT fifo_response_valid_0 node 1649 type Bits(Width(1)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(1643),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT fifo_occupancy_1 node 1675 type UInt(Width(2)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(1708),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT fifo_response_valid_1 node 1688 type Bits(Width(1)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(1682),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT fifo_occupancy_2 node 1714 type UInt(Width(2)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(1747),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT fifo_response_valid_2 node 1727 type Bits(Width(1)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(1721),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT fifo_occupancy_3 node 1753 type UInt(Width(2)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(1786),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT fifo_response_valid_3 node 1766 type Bits(Width(1)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(1760),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT head_state node 15 type UInt(Width(2)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(1832),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT head_entry node 21 type UInt(Width(5)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(1834),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT retirement_read_pointer node 23 type UInt(Width(5)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(2249),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT retirement_write_pointer node 24 type UInt(Width(5)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(2256),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT retirement_occupancy node 25 type UInt(Width(5)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(2263),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT entry_valid_0 node 26 type Bits(Width(1)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(2117),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT entry_valid_1 node 33 type Bits(Width(1)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(2169),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT entry_valid_2 node 40 type Bits(Width(1)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(2221),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT head_ticket node 20 type UInt(Width(32)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(1833),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT next_ticket node 22 type UInt(Width(32)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(1837),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT entry_terminal_0 node 27 type Bits(Width(1)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(2121),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT entry_ticket_0 node 28 type UInt(Width(32)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(2123),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT entry_terminal_1 node 34 type Bits(Width(1)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(2173),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT entry_ticket_1 node 35 type UInt(Width(32)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(2175),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT entry_terminal_2 node 41 type Bits(Width(1)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(2225),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT entry_ticket_2 node 42 type UInt(Width(32)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(2227),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT engine_state_0 node 425 type UInt(Width(3)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(1355),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT engine_ticket_0 node 427 type UInt(Width(32)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(1266),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT engine_state_1 node 455 type UInt(Width(2)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(1509),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT engine_ticket_1 node 457 type UInt(Width(32)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(1483),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT engine_state_2 node 441 type UInt(Width(3)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(1467),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|ROOT engine_ticket_2 node 443 type UInt(Width(32)) spec {  domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },  next: NodeId(1357),  reset: Some(    {      signal: NodeId(1),      value: 0,      mode: Synchronous,      polarity: ActiveHigh,    },  ),  enable: None,  initial: None,}
      #|EVENT fifo_push_valid_0 node 1631 type Bits(Width(1))
      #|EVENT fifo_push_ready_0 node 1646 type Bits(Width(1))
      #|EVENT fifo_pop_request_0 node 246 type Bits(Width(1))
      #|EVENT fifo_pop_ready_0 node 1642 type Bits(Width(1))
      #|EVENT fifo_full_0 node 1640 type Bits(Width(1))
      #|EVENT fifo_empty_0 node 1639 type Bits(Width(1))
      #|EVENT fifo_push_valid_1 node 1670 type Bits(Width(1))
      #|EVENT fifo_push_ready_1 node 1685 type Bits(Width(1))
      #|EVENT fifo_pop_request_1 node 246 type Bits(Width(1))
      #|EVENT fifo_pop_ready_1 node 1681 type Bits(Width(1))
      #|EVENT fifo_full_1 node 1679 type Bits(Width(1))
      #|EVENT fifo_empty_1 node 1678 type Bits(Width(1))
      #|EVENT fifo_push_valid_2 node 1709 type Bits(Width(1))
      #|EVENT fifo_push_ready_2 node 1724 type Bits(Width(1))
      #|EVENT fifo_pop_request_2 node 246 type Bits(Width(1))
      #|EVENT fifo_pop_ready_2 node 1720 type Bits(Width(1))
      #|EVENT fifo_full_2 node 1718 type Bits(Width(1))
      #|EVENT fifo_empty_2 node 1717 type Bits(Width(1))
      #|EVENT fifo_push_valid_3 node 1748 type Bits(Width(1))
      #|EVENT fifo_push_ready_3 node 1763 type Bits(Width(1))
      #|EVENT fifo_pop_request_3 node 246 type Bits(Width(1))
      #|EVENT fifo_pop_ready_3 node 1759 type Bits(Width(1))
      #|EVENT fifo_full_3 node 1757 type Bits(Width(1))
      #|EVENT fifo_empty_3 node 1756 type Bits(Width(1))
      #|EVENT head_pop node 1805 type Bits(Width(1))
      #|EVENT head_capture node 1809 type Bits(Width(1))
      #|EVENT head_reserve node 258 type Bits(Width(1))
      #|EVENT retirement_valid node 2083 type Bits(Width(1))
      #|EVENT retirement_fire node 2084 type Bits(Width(1))
      #|EVENT entry_allocate_0 node 2089 type Bits(Width(1))
      #|EVENT entry_acknowledge_0 node 2092 type Bits(Width(1))
      #|EVENT entry_allocate_1 node 2141 type Bits(Width(1))
      #|EVENT entry_acknowledge_1 node 2144 type Bits(Width(1))
      #|EVENT entry_allocate_2 node 2193 type Bits(Width(1))
      #|EVENT entry_acknowledge_2 node 2196 type Bits(Width(1))
      #|EVENT descriptor_ready node 1790 type Bits(Width(1))
      #|EVENT public_halted node 2289 type Bits(Width(1))
      #|EVENT head_issue node 1818 type Bits(Width(1))
      #|EVENT head_finish node 1820 type Bits(Width(1))
      #|EVENT head_reject node 1796 type Bits(Width(1))
      #|EVENT head_fence node 1801 type Bits(Width(1))
      #|EVENT engine_accept_0 node 700 type Bits(Width(1))
      #|EVENT engine_terminal_0 node 479 type Bits(Width(1))
      #|EVENT engine_accept_1 node 623 type Bits(Width(1))
      #|EVENT engine_terminal_1 node 557 type Bits(Width(1))
      #|EVENT engine_accept_2 node 1264 type Bits(Width(1))
      #|EVENT engine_terminal_2 node 538 type Bits(Width(1))
      #|EVENT entry_local_terminal_0 node 2110 type Bits(Width(1))
      #|EVENT entry_collector_0_0 node 2097 type Bits(Width(1))
      #|EVENT entry_collector_0_1 node 2102 type Bits(Width(1))
      #|EVENT entry_collector_0_2 node 2107 type Bits(Width(1))
      #|EVENT entry_local_terminal_1 node 2162 type Bits(Width(1))
      #|EVENT entry_collector_1_0 node 2149 type Bits(Width(1))
      #|EVENT entry_collector_1_1 node 2154 type Bits(Width(1))
      #|EVENT entry_collector_1_2 node 2159 type Bits(Width(1))
      #|EVENT entry_local_terminal_2 node 2214 type Bits(Width(1))
      #|EVENT entry_collector_2_0 node 2201 type Bits(Width(1))
      #|EVENT entry_collector_2_1 node 2206 type Bits(Width(1))
      #|EVENT entry_collector_2_2 node 2211 type Bits(Width(1))
      #|CANDIDATE node 1 type Reset kind Input("reset")
      #|CANDIDATE node 4 type Bits(Width(1)) kind Input("descriptor_valid")
      #|CANDIDATE node 9 type Bits(Width(1)) kind Input("completion_ready")
      #|CANDIDATE node 10 type Bits(Width(1)) kind Input("memory_request_ready")
      #|CANDIDATE node 11 type Bits(Width(1)) kind Input("memory_response_valid")
      #|CANDIDATE node 12 type UInt(Width(32)) kind Input("memory_response_tag")
      #|CANDIDATE node 13 type UInt(Width(2)) kind Input("memory_response_fault")
      #|CANDIDATE node 16 type Bits(Width(64)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1810),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 17 type Bits(Width(64)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1811),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 18 type Bits(Width(64)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1812),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 19 type Bits(Width(64)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1813),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 47 type UInt(Width(2)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1933),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 48 type UInt(Width(32)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1934),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 49 type UInt(Width(2)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1960),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 50 type UInt(Width(32)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1961),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 51 type UInt(Width(2)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1987),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 52 type UInt(Width(32)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1988),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 53 type UInt(Width(2)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(2014),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 54 type UInt(Width(32)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(2015),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 55 type UInt(Width(2)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(2041),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 56 type UInt(Width(32)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(2042),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 57 type UInt(Width(2)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(2068),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 58 type UInt(Width(32)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(2069),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 59 type UInt(Width(2)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1859),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 60 type UInt(Width(2)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1891),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 61 type UInt(Width(32)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1875),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 62 type UInt(Width(32)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1907),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 387 type UInt(Width(2)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1628),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 388 type Bits(Width(1)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1605),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 391 type UInt(Width(32)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1607),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 392 type UInt(Width(32)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1604),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 426 type UInt(Width(1)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1265),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 428 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1267),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 429 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1268),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 432 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1303),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 433 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1310),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 435 type UInt(Width(32)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1315),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 439 type UInt(Width(1)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1271),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 442 type UInt(Width(1)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1356),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 444 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1358),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 445 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1359),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 448 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1402),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 449 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1409),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 451 type UInt(Width(32)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1423),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 456 type Bits(Width(1)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1482),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 458 type UInt(Width(1)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1484),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 459 type UInt(Width(1)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1485),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 460 type UInt(Width(1)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1486),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 461 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1487),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 462 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1488),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 463 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1489),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 558 type Bits(Width(1)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1525),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 559 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1526),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 560 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1527),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 561 type Bits(Width(1)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1543),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 562 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1544),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 563 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1545),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 564 type Bits(Width(1)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1561),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 565 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1562),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 566 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1563),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 567 type Bits(Width(1)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1579),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 568 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1580),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 569 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1581),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 704 type UInt(Width(2)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1059),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 707 type Bits(Width(1)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1075),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 708 type UInt(Width(1)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1018),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 709 type UInt(Width(1)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1019),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 710 type UInt(Width(1)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1020),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 711 type UInt(Width(1)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1071),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 733 type UInt(Width(2)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(984),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 791 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(895),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 796 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(913),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 822 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(941),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 827 type UInt(Width(13)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(959),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 1082 type Bits(Width(1)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1086),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 1087 type UInt(Width(4)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(748),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: Some(NodeId(1081)),    initial: None,  },)
      #|CANDIDATE node 1088 type UInt(Width(4)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(749),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: Some(NodeId(1081)),    initial: None,  },)
      #|CANDIDATE node 1131 type Bits(Width(1)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1135),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: None,    initial: None,  },)
      #|CANDIDATE node 1136 type UInt(Width(4)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(748),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: Some(NodeId(1130)),    initial: None,  },)
      #|CANDIDATE node 1137 type UInt(Width(4)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(749),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: Some(NodeId(1130)),    initial: None,  },)
      #|CANDIDATE node 1177 type UInt(Width(2)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(1176),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: Some(NodeId(1070)),    initial: None,  },)
      #|CANDIDATE node 1178 type UInt(Width(32)) kind Register(  {    domain: { id: ClockDomainId(0), clock: NodeId(0), edge: Rising },    next: NodeId(443),    reset: Some(      {        signal: NodeId(1),        value: 0,        mode: Synchronous,        polarity: ActiveHigh,      },    ),    enable: Some(NodeId(1070)),    initial: None,  },)
      #|
    ),
  )
}
