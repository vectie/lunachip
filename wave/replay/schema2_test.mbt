///|
fn atomic_design() -> @ir.Design raise {
  let clock_a = @ir.NodeId::new(0)
  let clock_b = @ir.NodeId::new(1)
  let probe = @ir.NodeId::new(2)
  let state_a = @ir.NodeId::new(3)
  let state_b = @ir.NodeId::new(4)
  let eight = @ir.SignalType::UInt(@ir.Width::new(8))
  let hardware_module = @ir.Module::checked(
    "atomic",
    [
      @ir.Node::new(clock_a, Clock, Input("clock_a")),
      @ir.Node::new(clock_b, Clock, Input("clock_b")),
      @ir.Node::new(probe, eight, Input("probe")),
      @ir.Node::new(
        state_a,
        eight,
        Register(
          @ir.RegisterSpec::new(
            @ir.ClockDomain::rising(clock_a),
            state_b,
            initial=1UL,
          ),
        ),
      ),
      @ir.Node::new(
        state_b,
        eight,
        Register(
          @ir.RegisterSpec::new(
            @ir.ClockDomain::rising(clock_b),
            state_a,
            initial=2UL,
          ),
        ),
      ),
    ],
    [
      @ir.OutputPort::new("probe_out", eight, probe),
      @ir.OutputPort::new("state_a", eight, state_a),
      @ir.OutputPort::new("state_b", eight, state_b),
    ],
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
test "schema 2 execution is deterministic and samples coincident pre-edge state" {
  let first = @replay.execute(atomic_bundle())
  let second = @replay.execute(atomic_bundle())
  assert_eq(first.digest(), second.digest())
  assert_eq(@trace.serialize(first.trace()), @trace.serialize(second.trace()))
  assert_true(first.stop_reached())
  let frames = first.trace().frames()
  inspect(frames.length(), content="2")
  inspect(frames[1].changes()[0].value().to_uint64(), content="7")
  inspect(frames[1].changes()[1].value().to_uint64(), content="2")
  inspect(frames[1].changes()[2].value().to_uint64(), content="1")
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
  let migrated_frames = @replay.execute(migrated).trace().frames()
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
