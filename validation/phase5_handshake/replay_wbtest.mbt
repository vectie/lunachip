///|
fn canonical_handshake_events(
  fixture : HandshakeFixture,
) -> Array[@sim.TimestampEvent] raise {
  [
    event(1UL, reset_drives(1UL), [
      fixture.source_domain,
      fixture.destination_domain,
    ]),
    event(
      2UL,
      [
        drive("source_reset", logic(1, 0UL)),
        drive("destination_reset", logic(1, 0UL)),
      ],
      [fixture.source_domain, fixture.destination_domain],
    ),
    event(
      3UL,
      [
        drive("source_valid", logic(1, 1UL)),
        drive("source_word", logic(8, 90UL)),
        drive("source_tag", logic(3, 3UL)),
      ],
      [fixture.source_domain],
    ),
    event(4UL, [], [fixture.destination_domain]),
    event(5UL, [], [fixture.destination_domain]),
    event(6UL, [], [fixture.destination_domain]),
    event(7UL, [drive("source_valid", logic(1, 0UL))], [fixture.source_domain]),
    event(8UL, [], [fixture.source_domain]),
    event(9UL, [drive("destination_ready", logic(1, 1UL))], [
      fixture.destination_domain,
    ]),
    @sim.TimestampEvent::drives_only(@sim.SimulationTime::from_uint64(10UL), [
      drive("source_word", logic(8, 90UL)),
    ]),
  ]
}

///|
fn replay_event_from_sim(
  boundary : UInt64,
  source : @sim.TimestampEvent,
) -> @replay.AtomicReplayEvent raise {
  let drives : Array[@replay.NamedInput] = []
  for item in source.drives() {
    drives.push(@replay.NamedInput::checked(item.name(), item.value()))
  }
  @replay.AtomicReplayEvent::checked(
    source.time().value(),
    boundary,
    drives,
    source.active_domains(),
  )
}

///|
fn handshake_taps(
  fixture : HandshakeFixture,
) -> Array[@trace.TraceSignal] raise {
  let path = fixture.hardware_module.name()
  [
    @trace.TraceSignal::checked(path, "source_ready", 1),
    @trace.TraceSignal::checked(path, "destination_valid", 1),
    @trace.TraceSignal::checked(path, "destination_word", 8),
    @trace.TraceSignal::checked(path, "destination_tag", 3),
  ]
}

///|
fn handshake_replay(
  fixture : HandshakeFixture,
  stop : @replay.StopCondition,
  reverse_members~ : Bool = false,
) -> @replay.ReplayBundle raise {
  let events : Array[@replay.AtomicReplayEvent] = []
  for index, source in canonical_handshake_events(fixture) {
    let boundary = index.to_uint64() + 1UL
    if reverse_members {
      let drives : Array[@replay.NamedInput] = []
      for index in 0..<source.drives().length() {
        let item = source.drives()[source.drives().length() - index - 1]
        drives.push(@replay.NamedInput::checked(item.name(), item.value()))
      }
      let domains : Array[@ir.ClockDomainId] = []
      for index in 0..<source.active_domains().length() {
        domains.push(
          source.active_domains()[source.active_domains().length() - index - 1],
        )
      }
      events.push(
        @replay.AtomicReplayEvent::checked(
          source.time().value(),
          boundary,
          drives,
          domains,
        ),
      )
    } else {
      events.push(replay_event_from_sim(boundary, source))
    }
  }
  @replay.ReplayBundle::checked_atomic(
    fixture.design,
    "lunachip-semantics/2",
    [
      @replay.ReplayOption::checked("arithmetic", "width-bounded"),
      @replay.ReplayOption::checked("unknown-policy", "conservative"),
    ],
    1UL,
    events,
    stop,
    handshake_taps(fixture),
    @replay.ReplayDigest::checked("fnv1a-64", "0000000000000000"),
  )
}

///|
fn direct_samples(
  fixture : HandshakeFixture,
  simulator : @sim.Simulator,
  taps : ArrayView[@trace.TraceSignal],
) -> Array[@trace.TraceSample] raise {
  let samples : Array[@trace.TraceSample] = []
  for tap in taps {
    samples.push(
      @trace.TraceSample::new(
        fixture.hardware_module.name(),
        tap.name(),
        simulator.output(tap.name()),
      ),
    )
  }
  samples
}

///|
fn direct_trace(
  fixture : HandshakeFixture,
  bundle : @replay.ReplayBundle,
) -> @trace.Trace raise {
  let simulator = @sim.Simulator::prepare(fixture.hardware_module)
  let recorder = @trace.TraceRecorder::new(bundle.taps())
  recorder.record(
    simulator.cycle().value(),
    0UL,
    Initial,
    direct_samples(fixture, simulator, bundle.taps()),
  )
  for index, item in bundle.events() {
    let drives : Array[@sim.InputDrive] = []
    for input in item.drives() {
      drives.push(@sim.InputDrive::checked(input.name(), input.value()))
    }
    simulator.apply_event(event(item.time(), drives, item.domains()))
    recorder.record(
      simulator.cycle().value(),
      index.to_uint64() + 1UL,
      Settled,
      direct_samples(fixture, simulator, bundle.taps()),
    )
  }
  let changed = recorder.finish()
  let frames : Array[@trace.AtomicTraceFrame] = [
    @trace.AtomicTraceFrame::checked(
      0UL,
      0UL,
      AtomicInitial,
      [],
      [],
      changed.frames()[0].changes(),
    ),
  ]
  for index, item in bundle.events() {
    let drive_names : Array[String] = []
    for input in item.drives() {
      drive_names.push(input.name())
    }
    let domain_ids : Array[Int32] = []
    for domain in item.domains() {
      domain_ids.push(domain.ordinal())
    }
    frames.push(
      @trace.AtomicTraceFrame::checked(
        item.time(),
        item.boundary(),
        AtomicBatch,
        drive_names,
        domain_ids,
        changed.frames()[index + 1].changes(),
      ),
    )
  }
  @trace.Trace::checked_atomic(
    bundle.semantic_version(),
    @trace.TraceDigest::checked(
      bundle.ir_digest().algorithm(),
      bundle.ir_digest().hex(),
    ),
    1UL,
    [
      @trace.TraceDomain::checked(
        fixture.source_domain.ordinal(),
        "source_clock",
      ),
      @trace.TraceDomain::checked(
        fixture.destination_domain.ordinal(),
        "destination_clock",
      ),
    ],
    bundle.taps(),
    frames,
  )
}

///|
test "schema two replay direct trace and VCD retain one canonical identity" {
  let fixture = handshake_fixture(2)
  let bundle = handshake_replay(fixture, AfterBoundary(10UL))
  let reversed = handshake_replay(
    fixture,
    AfterBoundary(10UL),
    reverse_members=true,
  )
  assert_eq(@replay.serialize(bundle), @replay.serialize(reversed))
  assert_eq(
    @replay.serialize(@replay.parse(@replay.serialize(bundle))),
    @replay.serialize(bundle),
  )
  let replayed = @replay.execute(bundle)
  assert_true(replayed.stop_reached())
  let direct = direct_trace(fixture, bundle)
  assert_eq(@trace.serialize(direct), @trace.serialize(replayed.trace()))
  assert_eq(
    @replay.trace_result_digest(direct),
    @replay.trace_result_digest(replayed.trace()),
  )
  assert_eq(direct.atomic_frames().length(), bundle.events().length() + 1)
  assert_eq(direct.atomic_frames()[10].changes().length(), 0)
  let vcd = @trace.to_vcd(direct)
  assert_eq(vcd, @trace.to_vcd(replayed.trace()))
  assert_true(vcd.contains("time=1 boundary=1"))
  assert_true(vcd.contains("domains=0,3"))
  assert_true(vcd.contains("time=10 boundary=10"))
  assert_eq(@codec.serialize(fixture.design), bundle.canonical_ir())
}

///|
test "schema two stop conditions retain time boundary cycle domain and endpoint meaning" {
  let fixture = handshake_fixture(2)
  for
    stop in [
      @replay.StopCondition::AtTime(6UL),
      AfterBoundary(6UL),
      AtCycle(6UL),
      AtDomainEdge(domain=fixture.source_domain, count=3UL),
      AtDomainEdge(domain=fixture.destination_domain, count=5UL),
      OutputEquals(name="destination_valid", value=logic(1, 1UL)),
      OutputEquals(name="destination_word", value=logic(8, 90UL)),
    ] {
    assert_true(@replay.execute(handshake_replay(fixture, stop)).stop_reached())
  }
}

///|
test "reduced rational schedules retain coincidences and asymmetric gaps" {
  let fixture = handshake_fixture(2)
  let coprime = @sim.normalize_clock_schedules(
    [
      @sim.ClockSchedule::checked(
        fixture.source_domain,
        @sim.RationalTicks::checked(3UL, 2UL, field="source period"),
        @sim.RationalTicks::checked(1UL, 2UL, field="source phase"),
        9,
      ),
      @sim.ClockSchedule::checked(
        fixture.destination_domain,
        @sim.RationalTicks::checked(5UL, 3UL, field="destination period"),
        @sim.RationalTicks::checked(0UL, 1UL, field="destination phase"),
        9,
      ),
    ],
    32,
  )
  assert_eq(coprime.ticks_per_source_unit(), 6UL)
  let mut coprime_coincidences = 0
  for item in coprime.events() {
    if item.active_domains().length() == 2 {
      coprime_coincidences += 1
    }
  }
  assert_true(coprime_coincidences > 0)
  let noncoprime = @sim.normalize_clock_schedules(
    [
      @sim.ClockSchedule::checked(
        fixture.source_domain,
        @sim.RationalTicks::checked(4UL, 1UL, field="source period"),
        @sim.RationalTicks::checked(0UL, 1UL, field="source phase"),
        8,
      ),
      @sim.ClockSchedule::checked(
        fixture.destination_domain,
        @sim.RationalTicks::checked(6UL, 1UL, field="destination period"),
        @sim.RationalTicks::checked(0UL, 1UL, field="destination phase"),
        8,
      ),
    ],
    32,
  )
  let mut noncoprime_coincidences = 0
  for item in noncoprime.events() {
    if item.active_domains().length() == 2 {
      noncoprime_coincidences += 1
    }
  }
  assert_true(noncoprime_coincidences >= 3)
}
