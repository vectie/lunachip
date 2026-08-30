///|
fn atomic_design() -> @ir.Design raise {
  let clock_a = @ir.NodeId::new(0)
  let clock_b = @ir.NodeId::new(1)
  let probe = @ir.NodeId::new(2)
  let next_a = @ir.NodeId::new(3)
  let next_b = @ir.NodeId::new(4)
  let state_a = @ir.NodeId::new(5)
  let state_b = @ir.NodeId::new(6)
  let eight = @ir.SignalType::UInt(@ir.Width::new(8))
  let domain_a = @ir.ClockDomain::rising(clock_a)
  let domain_b = @ir.ClockDomain::rising(clock_b)
  let hardware_module = @ir.Module::checked_with_metadata(
    "atomic",
    [domain_a, domain_b],
    [
      @ir.Node::new(clock_a, Clock, Input("clock_a")),
      @ir.Node::new(clock_b, Clock, Input("clock_b")),
      @ir.Node::new(probe, eight, Input("probe")),
      @ir.Node::new(next_a, eight, Constant(3UL)),
      @ir.Node::new(next_b, eight, Constant(4UL)),
      @ir.Node::new(
        state_a,
        eight,
        Register(@ir.RegisterSpec::new(domain_a, next_a, initial=1UL)),
      ),
      @ir.Node::new(
        state_b,
        eight,
        Register(@ir.RegisterSpec::new(domain_b, next_b, initial=2UL)),
      ),
    ],
    [],
    [
      @ir.OutputPort::new("probe_out", eight, probe),
      @ir.OutputPort::new("state_a", eight, state_a),
      @ir.OutputPort::new("state_b", eight, state_b),
    ],
    @ir.ModuleMetadata::checked_with_timing(
      [],
      [],
      [@ir.InputTimingBinding::new(probe, Asynchronous)],
      [
        @ir.OutputTimingBinding::checked("probe_out", Asynchronous),
        @ir.OutputTimingBinding::checked("state_a", ProducedIn(domain_a.id())),
        @ir.OutputTimingBinding::checked("state_b", ProducedIn(domain_b.id())),
      ],
    ),
  )
  @ir.Design::single("atomic-replay", hardware_module)
}

///|
fn atomic_digest() -> @replay.ReplayDigest raise {
  @replay.ReplayDigest::checked("fnv1a-64", "0000000000000000")
}

///|
fn atomic_taps() -> Array[@trace.TraceSignal] raise {
  [
    @trace.TraceSignal::checked("atomic", "probe_out", 8),
    @trace.TraceSignal::checked("atomic", "state_a", 8),
    @trace.TraceSignal::checked("atomic", "state_b", 8),
  ]
}

///|
fn atomic_input(name : String, value : UInt64) -> @replay.NamedInput raise {
  @replay.NamedInput::checked(
    name,
    @wave.LogicValue::from_uint64(width=8, value~),
  )
}

///|
const SEEDED_SCHEDULE_REPLAY_FIXTURE : UInt64 = 1592594996UL

///|
fn replay_rational(
  numerator : UInt64,
  denominator : UInt64,
) -> @sim.RationalTicks raise {
  @sim.RationalTicks::checked(numerator, denominator)
}

///|
fn seeded_replay_schedules(
  fixture : Int,
  permuted : Bool,
) -> Array[@sim.ClockSchedule] raise {
  let domain_a = @ir.ClockDomainId::new(0)
  let domain_b = @ir.ClockDomainId::new(1)
  let phase_variant = (SEEDED_SCHEDULE_REPLAY_FIXTURE + fixture.to_uint64()) %
    2UL
  let schedules = if fixture == 0 {
    // Coprime period denominators 3 and 4. The seed selects distinct non-zero
    // phases; both schedules coincide exactly at normalized time 66.
    [
      @sim.ClockSchedule::checked(
        domain_a,
        replay_rational(2UL, 3UL),
        replay_rational(1UL + phase_variant, 6UL),
        9,
      ),
      @sim.ClockSchedule::checked(
        domain_b,
        replay_rational(3UL, 4UL),
        replay_rational(1UL, 4UL),
        8,
      ),
    ]
  } else {
    // Non-coprime period denominators 4 and 6, including phase zero and
    // repeated exact coincidences.
    [
      @sim.ClockSchedule::checked(
        domain_a,
        replay_rational(1UL, 4UL),
        replay_rational(0UL, 1UL),
        5,
      ),
      @sim.ClockSchedule::checked(
        domain_b,
        replay_rational(1UL, 6UL),
        replay_rational(1UL + phase_variant, 6UL),
        7,
      ),
    ]
  }
  if permuted {
    [schedules[1], schedules[0]]
  } else {
    schedules
  }
}

///|
fn replay_from_normalized_schedule(
  schedule : @sim.NormalizedSchedule,
  stop : @replay.StopCondition,
) -> @replay.ReplayBundle raise {
  let events : Array[@replay.AtomicReplayEvent] = []
  for index, event in schedule.events() {
    events.push(
      @replay.AtomicReplayEvent::checked(
        event.time().value(),
        index.to_uint64() + 1UL,
        [],
        event.active_domains(),
      ),
    )
  }
  @replay.ReplayBundle::checked_atomic(
    atomic_design(),
    "lunachip-semantics/2",
    [@replay.ReplayOption::checked("fixture-seed", "1592594996")],
    schedule.ticks_per_source_unit(),
    events,
    stop,
    atomic_taps(),
    atomic_digest(),
  )
}

///|
fn third_domain_edge_event(
  schedule : @sim.NormalizedSchedule,
  domain : @ir.ClockDomainId,
) -> Int {
  let mut count = 0
  for index, event in schedule.events() {
    for active in event.active_domains() {
      if active == domain {
        count += 1
      }
    }
    if count == 3 {
      return index
    }
  }
  abort("seeded fixture must contain three requested domain edges")
}

///|
fn replay_test_encode_text(value : String) -> String {
  let bytes = @utf8.encode(value)
  if bytes.is_empty() {
    return "-"
  }
  let builder = StringBuilder(size_hint=bytes.length() * 2)
  for byte in bytes {
    let encoded = byte.to_hex()
    if encoded.length() == 1 {
      builder.write_char('0')
    }
    builder.write_string(encoded)
  }
  builder.to_string()
}

///|
fn atomic_bundle() -> @replay.ReplayBundle raise {
  let domain_a = @ir.ClockDomainId::new(0)
  let domain_b = @ir.ClockDomainId::new(1)
  @replay.ReplayBundle::checked_atomic(
    atomic_design(),
    "lunachip-semantics/2",
    [@replay.ReplayOption::checked("event-model", "atomic")],
    6UL,
    [
      @replay.AtomicReplayEvent::checked(
        0UL,
        4UL,
        [atomic_input("probe", 7UL)],
        [domain_b, domain_a],
      ),
    ],
    AtDomainEdge(domain=domain_a, count=1UL),
    atomic_taps(),
    atomic_digest(),
  )
}

///|
test "schema 2 canonical golden round trips with sorted atomic fields" {
  let bundle = atomic_bundle()
  assert_eq(bundle.schema(), Atomic2)
  assert_eq(bundle.timebase(), Some(6UL))
  assert_eq(bundle.events()[0].domains()[0].ordinal(), 0)
  assert_eq(bundle.events()[0].domains()[1].ordinal(), 1)
  let encoded = @replay.serialize(bundle)
  let expected = (
      #|LUNACHIP-REPLAY 2
      #|SEMANTICS 6c756e61636869702d73656d616e746963732f32
      #|OPTIONS 1
      #|OPTION 6576656e742d6d6f64656c 61746f6d6963
      #|
    ) +
    "IR fnv1a-64 \{bundle.ir_digest().hex()} \{replay_test_encode_text(bundle.canonical_ir())}\n" +
    (
      #|TIMEBASE 6
      #|EVENTS 1
      #|EVENT 0 4 1 2
      #|INPUT 70726f6265 8 7 255
      #|DOMAIN 0
      #|DOMAIN 1
      #|STOP at_domain_edge 0 1
      #|TAPS 3
      #|TAP 8 61746f6d6963 70726f62655f6f7574
      #|TAP 8 61746f6d6963 73746174655f61
      #|TAP 8 61746f6d6963 73746174655f62
      #|EXPECTED fnv1a-64 0000000000000000
      #|END
      #|
    )
  assert_eq(encoded, expected)
  assert_eq(@replay.serialize(@replay.parse(encoded)), encoded)
  let sorted = @replay.AtomicReplayEvent::checked(
    3UL,
    9UL,
    [atomic_input("z", 1UL), atomic_input("a", 2UL)],
    [@ir.ClockDomainId::new(1), @ir.ClockDomainId::new(0)],
  )
  assert_eq(sorted.drives()[0].name(), "a")
  assert_eq(sorted.drives()[1].name(), "z")
  assert_eq(sorted.domains()[0].ordinal(), 0)
  assert_eq(sorted.domains()[1].ordinal(), 1)
}

///|
test "schema 2 rejects malformed and noncanonical event encodings" {
  let encoded = @replay.serialize(atomic_bundle())
  let reversed = encoded.replace(
    old="DOMAIN 0\nDOMAIN 1\n",
    new="DOMAIN 1\nDOMAIN 0\n",
  )
  try @replay.parse(reversed) catch {
    NonCanonical => ()
    error => fail("unexpected unsorted-domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unsorted domains to be noncanonical")
  }
  let duplicate = encoded.replace(old="DOMAIN 1\n", new="DOMAIN 0\n")
  try @replay.parse(duplicate) catch {
    DuplicateDomain(0) => ()
    error => fail("unexpected duplicate-domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate domain rejection")
  }
  let zero_timebase = encoded.replace(old="TIMEBASE 6\n", new="TIMEBASE 0\n")
  try @replay.parse(zero_timebase) catch {
    InvalidTimebase(0UL) => ()
    error => fail("unexpected timebase error: \{Repr(error)}")
  } noraise {
    _ => fail("expected zero timebase rejection")
  }
  let malformed = encoded.replace(old="EVENTS 1\n", new="STIMULI 1\n")
  try @replay.parse(malformed) catch {
    UnexpectedLine(..) => ()
    error => fail("unexpected mislabeled-section error: \{Repr(error)}")
  } noraise {
    _ => fail("expected mislabeled schema-2 section rejection")
  }
  let bundle = atomic_bundle()
  let event = bundle.events()[0]
  try
    @replay.ReplayBundle::checked_atomic(
      atomic_design(),
      bundle.semantic_version(),
      bundle.options(),
      6UL,
      [
        @replay.AtomicReplayEvent::checked(
          event.time(),
          4UL,
          event.drives(),
          event.domains(),
        ),
        @replay.AtomicReplayEvent::checked(event.time() + 1UL, 4UL, [], [
          @ir.ClockDomainId::new(0),
        ]),
      ],
      bundle.stop(),
      bundle.taps(),
      bundle.expected_result(),
    )
  catch {
    @replay.ReplayError::NonMonotonicEventBoundary(previous=4UL, actual=4UL) =>
      ()
    error => fail("unexpected boundary-order error: \{Repr(error)}")
  } noraise {
    _ => fail("expected repeated boundary rejection")
  }
  let two_events = @replay.ReplayBundle::checked_atomic(
    atomic_design(),
    bundle.semantic_version(),
    bundle.options(),
    6UL,
    [
      @replay.AtomicReplayEvent::checked(
        event.time(),
        4UL,
        event.drives(),
        event.domains(),
      ),
      @replay.AtomicReplayEvent::checked(event.time() + 1UL, 5UL, [], [
        @ir.ClockDomainId::new(0),
      ]),
    ],
    bundle.stop(),
    bundle.taps(),
    bundle.expected_result(),
  )
  let repeated_boundary = @replay.serialize(two_events).replace(
    old="EVENT 1 5 0 1\n",
    new="EVENT 1 4 0 1\n",
  )
  try @replay.parse(repeated_boundary) catch {
    NonMonotonicEventBoundary(previous=4UL, actual=4UL) => ()
    error => fail("unexpected parsed-boundary error: \{Repr(error)}")
  } noraise {
    _ => fail("expected parsed repeated boundary rejection")
  }
}

///|
test "schema 2 construction rejects nonmonotonic timestamps and unknown domains" {
  let domain_a = @ir.ClockDomainId::new(0)
  let event = @replay.AtomicReplayEvent::checked(3UL, 0UL, [], [domain_a])
  try
    @replay.ReplayBundle::checked_atomic(
      atomic_design(),
      "semantics/2",
      [],
      1UL,
      [event, event],
      AtTime(3UL),
      [],
      atomic_digest(),
    )
  catch {
    @replay.ReplayError::NonMonotonicEventTime(previous=3UL, actual=3UL) => ()
    error => fail("unexpected timestamp-order error: \{Repr(error)}")
  } noraise {
    _ => fail("expected repeated timestamp rejection")
  }
  try
    @replay.ReplayBundle::checked_atomic(
      atomic_design(),
      "semantics/2",
      [],
      1UL,
      [
        @replay.AtomicReplayEvent::checked(0UL, 0UL, [], [
          @ir.ClockDomainId::new(99),
        ]),
      ],
      AtTime(0UL),
      [],
      atomic_digest(),
    )
  catch {
    @replay.ReplayError::UnknownReplayDomain(99) => ()
    error => fail("unexpected unknown-domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unknown replay domain rejection")
  }
}

///|
test "schema 2 execution is deterministic across independent domains" {
  let first = @replay.execute(atomic_bundle())
  let second = @replay.execute(atomic_bundle())
  assert_eq(first.digest(), second.digest())
  assert_eq(@trace.serialize(first.trace()), @trace.serialize(second.trace()))
  assert_true(first.stop_reached())
  assert_eq(first.trace().schema(), Atomic2)
  assert_eq(first.trace().semantic_version(), Some("lunachip-semantics/2"))
  assert_eq(first.trace().timebase(), Some(6UL))
  guard first.trace().ir_digest() is Some(trace_ir_digest) else {
    fail("schema-2 execution trace must retain the replay IR digest")
  }
  assert_eq(
    trace_ir_digest.algorithm(),
    atomic_bundle().ir_digest().algorithm(),
  )
  assert_eq(trace_ir_digest.hex(), atomic_bundle().ir_digest().hex())
  assert_eq(first.trace().domains()[0].clock(), "clock_a")
  assert_eq(first.trace().domains()[1].clock(), "clock_b")
  let frames = first.trace().atomic_frames()
  inspect(frames.length(), content="2")
  inspect(frames[1].time(), content="0")
  inspect(frames[1].boundary(), content="4")
  assert_eq(frames[1].drives()[0], "probe")
  assert_eq(frames[1].active_domains()[0], 0)
  assert_eq(frames[1].active_domains()[1], 1)
  inspect(frames[1].changes()[0].value().to_uint64(), content="7")
  inspect(frames[1].changes()[1].value().to_uint64(), content="3")
  inspect(frames[1].changes()[2].value().to_uint64(), content="4")
}

///|
fn legacy_atomic_bundle() -> @replay.ReplayBundle raise {
  @replay.ReplayBundle::checked(
    atomic_design(),
    "lunachip-semantics/1",
    [],
    [
      @replay.ReplayStimulus::drive(0UL, 8UL, [atomic_input("probe", 3UL)]),
      @replay.ReplayStimulus::rising_edge(0UL, 9UL, "clock_a"),
      @replay.ReplayStimulus::rising_edge(1UL, 10UL, "clock_b"),
    ],
    AtCycle(2UL),
    atomic_taps(),
    atomic_digest(),
  )
}

///|
test "schema 1 migration assigns distinct timestamps without inventing coincidence" {
  let legacy = legacy_atomic_bundle()
  let legacy_bytes = @replay.serialize(legacy)
  let migrated = @replay.migrate_schema1(legacy)
  assert_eq(@replay.serialize(legacy), legacy_bytes)
  assert_eq(migrated.schema(), Atomic2)
  assert_eq(migrated.timebase(), Some(1UL))
  inspect(migrated.events().length(), content="3")
  inspect(migrated.events()[0].time(), content="0")
  inspect(migrated.events()[1].time(), content="1")
  inspect(migrated.events()[2].time(), content="2")
  inspect(migrated.events()[1].domains().length(), content="1")
  inspect(migrated.events()[2].domains().length(), content="1")
  assert_true(migrated.events()[1].time() != migrated.events()[2].time())
  let encoded = @replay.serialize(migrated)
  assert_eq(@replay.serialize(@replay.parse(encoded)), encoded)
  let legacy_frames = @replay.execute(legacy).trace().frames()
  let migrated_frames = @replay.execute(migrated).trace().atomic_frames()
  assert_eq(legacy_frames.length(), migrated_frames.length())
  for index in 0..<legacy_frames.length() {
    assert_eq(legacy_frames[index].changes(), migrated_frames[index].changes())
  }
}

///|
test "schema 1 migration refuses to invent a domain for a stateless clock" {
  try @replay.migrate_schema1(replay_bundle()) catch {
    @replay.ReplayError::UnmappedLegacyClock("clk") => ()
    error => fail("unexpected unmapped-clock error: \{Repr(error)}")
  } noraise {
    _ => fail("expected stateless legacy clock migration rejection")
  }
}

///|
test "seeded rational schedules replay identically after declaration permutation" {
  for fixture in 0..<2 {
    let first_schedule = @sim.normalize_clock_schedules(
      seeded_replay_schedules(fixture, false),
      32,
    )
    let permuted_schedule = @sim.normalize_clock_schedules(
      seeded_replay_schedules(fixture, true),
      32,
    )
    assert_eq(first_schedule, permuted_schedule)
    let events = first_schedule.events()
    let final_time = events[events.length() - 1].time().value()
    let stop = @replay.StopCondition::AtTime(final_time)
    let first_bundle = replay_from_normalized_schedule(first_schedule, stop)
    let permuted_bundle = replay_from_normalized_schedule(
      permuted_schedule, stop,
    )
    // From this point onward execution sees only the canonical stored replay
    // events. It does not receive or regenerate either clock schedule.
    let first_stored = @replay.parse(@replay.serialize(first_bundle))
    let permuted_stored = @replay.parse(@replay.serialize(permuted_bundle))
    assert_eq(
      @replay.serialize(first_stored),
      @replay.serialize(permuted_stored),
    )
    let first = @replay.execute(first_stored)
    let permuted = @replay.execute(permuted_stored)
    assert_true(first.stop_reached())
    assert_true(permuted.stop_reached())
    assert_eq(first.digest(), permuted.digest())
    let first_bytes = @trace.serialize(first.trace())
    let permuted_bytes = @trace.serialize(permuted.trace())
    assert_eq(first_bytes, permuted_bytes)
    assert_eq(@trace.serialize(@trace.parse(first_bytes)), first_bytes)
    let frames = first.trace().atomic_frames()
    assert_eq(frames.length(), events.length() + 1)
    assert_eq(frames[frames.length() - 1].time(), final_time)
    assert_eq(
      frames[frames.length() - 1].boundary(),
      events.length().to_uint64(),
    )
    let mut has_coincident_edge = false
    let mut has_empty_change_event = false
    for index in 0..<events.length() {
      assert_eq(frames[index + 1].time(), events[index].time().value())
      assert_eq(
        frames[index + 1].active_domains().length(),
        events[index].active_domains().length(),
      )
      if frames[index + 1].active_domains().length() == 2 {
        has_coincident_edge = true
        assert_eq(frames[index + 1].active_domains()[0], 0)
        assert_eq(frames[index + 1].active_domains()[1], 1)
      }
      if frames[index + 1].changes().is_empty() {
        has_empty_change_event = true
      }
    }
    assert_true(has_coincident_edge)
    assert_true(has_empty_change_event)
  }
}

///|
test "atomic replay stop conditions retain exact stored event time and boundary" {
  let schedule = @sim.normalize_clock_schedules(
    seeded_replay_schedules(0, false),
    32,
  )
  let domain_a = @ir.ClockDomainId::new(0)
  let stop_index = third_domain_edge_event(schedule, domain_a)
  let stored = @replay.parse(
    @replay.serialize(
      replay_from_normalized_schedule(
        schedule,
        AtDomainEdge(domain=domain_a, count=3UL),
      ),
    ),
  )
  let result = @replay.execute(stored)
  assert_true(result.stop_reached())
  let frames = result.trace().atomic_frames()
  assert_eq(frames.length(), stop_index + 2)
  let last = frames[frames.length() - 1]
  assert_eq(last.time(), schedule.events()[stop_index].time().value())
  assert_eq(last.boundary(), stop_index.to_uint64() + 1UL)
  let vcd = @trace.to_vcd(result.trace())
  assert_true(vcd.contains("#\{last.time()}\n"))
  assert_true(
    vcd.contains(
      "$comment lunachip_timebase=\{schedule.ticks_per_source_unit()} normalized_ticks_per_source_unit",
    ),
  )
  assert_false(vcd.contains("#\{frames.length()}\n"))
}

///|
test "atomic replay accepts an actual first event boundary of zero" {
  let domain_a = @ir.ClockDomainId::new(0)
  let clock_a = @replay.NamedInput::checked(
    "clock_a",
    @wave.LogicValue::from_uint64(width=1, value=1UL),
  )
  let clock_b = @replay.NamedInput::checked(
    "clock_b",
    @wave.LogicValue::from_uint64(width=1, value=1UL),
  )
  let bundle = @replay.ReplayBundle::checked_atomic(
    atomic_design(),
    "lunachip-semantics/2",
    [],
    1UL,
    [
      @replay.AtomicReplayEvent::checked(
        0UL,
        0UL,
        [atomic_input("probe", 9UL), clock_b, clock_a],
        [domain_a],
      ),
    ],
    AtDomainEdge(domain=domain_a, count=1UL),
    atomic_taps(),
    atomic_digest(),
  )
  let trace = @replay.execute(bundle).trace()
  assert_eq(trace.atomic_frames()[0].boundary(), 0UL)
  assert_eq(trace.atomic_frames()[1].boundary(), 0UL)
  assert_eq(trace.atomic_frames()[1].drives()[0], "clock_a")
  assert_eq(trace.atomic_frames()[1].drives()[1], "clock_b")
  assert_eq(trace.atomic_frames()[1].drives()[2], "probe")
  let encoded = @trace.serialize(trace)
  assert_eq(@trace.serialize(@trace.parse(encoded)), encoded)
}
