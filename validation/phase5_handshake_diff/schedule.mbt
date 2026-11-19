///|
fn rational(
  numerator : UInt64,
  denominator : UInt64,
) -> @sim.RationalTicks raise {
  @sim.RationalTicks::checked(numerator, denominator)
}

///|
fn fixture_schedule(
  kind : HandshakeFixtureKind,
) -> @sim.NormalizedSchedule raise {
  let (source_period, source_phase, source_edges) = match kind {
    DirectedScalar => (rational(2UL, 1UL), rational(0UL, 1UL), 30)
    MultiLeafRational => (rational(2UL, 3UL), rational(1UL, 3UL), 38)
    CoincidentRefill => (rational(2UL, 1UL), rational(0UL, 1UL), 42)
    CoordinatedResetFlush => (rational(3UL, 2UL), rational(1UL, 2UL), 34)
    SeededRational => (rational(5UL, 3UL), rational(2UL, 3UL), 40)
  }
  let (destination_period, destination_phase, destination_edges) = match kind {
    DirectedScalar => (rational(3UL, 1UL), rational(0UL, 1UL), 24)
    MultiLeafRational => (rational(3UL, 5UL), rational(1UL, 3UL), 42)
    CoincidentRefill => (rational(4UL, 1UL), rational(0UL, 1UL), 24)
    CoordinatedResetFlush => (rational(5UL, 2UL), rational(1UL, 2UL), 28)
    SeededRational => (rational(7UL, 4UL), rational(2UL, 3UL), 38)
  }
  @sim.normalize_clock_schedules(
    [
      @sim.ClockSchedule::checked(
        source_domain_id(),
        source_period,
        source_phase,
        source_edges,
      ),
      @sim.ClockSchedule::checked(
        destination_domain_id(),
        destination_period,
        destination_phase,
        destination_edges,
      ),
    ],
    256,
  )
}

///|
fn contains_domain(
  event : @sim.TimestampEvent,
  domain : @ir.ClockDomainId,
) -> Bool {
  event.active_domains().any(id => id == domain)
}

///|
fn emitted_port_name(
  ports : ReadOnlyArray[@verilator.HarnessPort],
  source : String,
) -> String raise HandshakeFixtureError {
  for port in ports {
    if port.source_name() == source {
      return port.emitted_name()
    }
  }
  raise MissingPortMapping(source)
}

///|
fn source_port_name(
  ports : ReadOnlyArray[@verilator.HarnessPort],
  emitted : String,
) -> String raise HandshakeFixtureError {
  for port in ports {
    if port.emitted_name() == emitted {
      return port.source_name()
    }
  }
  raise MissingPortMapping(emitted)
}

///|
fn binary_bits(value : UInt64, width : Int32) -> String {
  let out = StringBuilder()
  for index in 0..<width {
    let shift = width - index - 1
    out.write_char(if ((value >> shift) & 1UL) == 0UL { '0' } else { '1' })
  }
  out.to_string()
}

///|
fn known_value(
  value : UInt64,
  width : Int32,
) -> @differential.NormalizedValue raise {
  @differential.NormalizedValue::from_planes(
    binary_bits(value, width),
    "1".repeat(width),
  )
}

///|
fn source_valid_for(kind : HandshakeFixtureKind, edge : Int32) -> Bool {
  match kind {
    DirectedScalar => edge == 7
    MultiLeafRational => edge == 7 || edge == 24
    CoincidentRefill => edge == 12 || edge == 27
    CoordinatedResetFlush => edge == 7 || edge == 24
    SeededRational => edge == 7 || edge == 20 || edge == 34
  }
}

///|
fn source_word_for(kind : HandshakeFixtureKind, edge : Int32) -> UInt64 {
  match kind {
    DirectedScalar => 0x2aUL
    MultiLeafRational => if edge < 20 { 0xa5UL } else { 0x3cUL }
    CoincidentRefill => if edge < 20 { 0x19UL } else { 0xe6UL }
    CoordinatedResetFlush => if edge < 20 { 0x5aUL } else { 0xc3UL }
    SeededRational => seeded_word(edge)
  }
}

///|
fn seeded_word(edge : Int32) -> UInt64 {
  let mut state = 0x5eed1234UL
  for _ in 0..<=edge {
    state = state * 6364136223846793005UL + 1442695040888963407UL
  }
  (state >> 24) & 0xffUL
}

///|
fn destination_ready_for(kind : HandshakeFixtureKind, edge : Int32) -> Bool {
  match kind {
    DirectedScalar => edge < 3 || edge >= 11
    MultiLeafRational => edge < 4 || (edge % 7 != 3 && edge % 7 != 4)
    CoincidentRefill => edge < 3 || edge >= 18
    CoordinatedResetFlush => edge < 3 || edge >= 13
    SeededRational => edge < 4 || (edge % 5 != 1 && edge % 5 != 2)
  }
}

///|
fn source_reset_for(kind : HandshakeFixtureKind, edge : Int32) -> Bool {
  if edge < 2 {
    true
  } else {
    match kind {
      CoordinatedResetFlush =>
        (edge >= 9 && edge < 11) || (edge >= 18 && edge < 20)
      _ => false
    }
  }
}

///|
fn destination_reset_for(kind : HandshakeFixtureKind, edge : Int32) -> Bool {
  if edge < 2 {
    true
  } else {
    match kind {
      CoordinatedResetFlush =>
        (edge >= 12 && edge < 14) || (edge >= 18 && edge < 20)
      _ => false
    }
  }
}

///|
fn project_schedule(
  kind : HandshakeFixtureKind,
  schedule : @sim.NormalizedSchedule,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> @verilator.AtomicStimulus raise {
  let domains : Array[@verilator.StimulusDomain] = [
    @verilator.StimulusDomain::checked(
      0,
      emitted_port_name(ports, "source_clock"),
    ),
    @verilator.StimulusDomain::checked(
      1,
      emitted_port_name(ports, "destination_clock"),
    ),
  ]
  let events : Array[@verilator.AtomicStimulusEvent] = []
  let mut source_edges = 0
  let mut destination_edges = 0
  for boundary, event in schedule.events() {
    let drives : Array[@verilator.AtomicStimulusDrive] = [
      @verilator.AtomicStimulusDrive::checked(
        emitted_port_name(ports, "source_reset"),
        known_value(
          if source_reset_for(kind, source_edges) {
            1UL
          } else {
            0UL
          },
          1,
        ),
      ),
      @verilator.AtomicStimulusDrive::checked(
        emitted_port_name(ports, "destination_reset"),
        known_value(
          if destination_reset_for(kind, destination_edges) {
            1UL
          } else {
            0UL
          },
          1,
        ),
      ),
      @verilator.AtomicStimulusDrive::checked(
        emitted_port_name(ports, "source_valid"),
        known_value(
          if source_valid_for(kind, source_edges) {
            1UL
          } else {
            0UL
          },
          1,
        ),
      ),
      @verilator.AtomicStimulusDrive::checked(
        emitted_port_name(ports, "source_word"),
        known_value(source_word_for(kind, source_edges), 8),
      ),
      @verilator.AtomicStimulusDrive::checked(
        emitted_port_name(ports, "destination_ready"),
        known_value(
          if destination_ready_for(kind, destination_edges) {
            1UL
          } else {
            0UL
          },
          1,
        ),
      ),
    ]
    if kind == MultiLeafRational {
      drives.push(
        @verilator.AtomicStimulusDrive::checked(
          emitted_port_name(ports, "source_tag"),
          known_value(if source_edges < 20 { 5UL } else { 2UL }, 3),
        ),
      )
    }
    events.push(
      @verilator.AtomicStimulusEvent::checked(
        event.time().value(),
        boundary.to_uint64(),
        drives,
        event.active_domains().map(id => id.ordinal()),
      ),
    )
    if contains_domain(event, source_domain_id()) {
      source_edges += 1
    }
    if contains_domain(event, destination_domain_id()) {
      destination_edges += 1
    }
  }
  @verilator.AtomicStimulus::checked(
    schedule.ticks_per_source_unit(),
    domains,
    events,
  )
}
