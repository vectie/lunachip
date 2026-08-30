///|
fn rational(
  numerator : UInt64,
  denominator : UInt64,
) -> @sim.RationalTicks raise {
  @sim.RationalTicks::checked(numerator, denominator)
}

///|
fn fixture_schedule(kind : SyncFixtureKind) -> @sim.NormalizedSchedule raise {
  match kind {
    AsyncTwoStage =>
      @sim.normalize_clock_schedules(
        [
          @sim.ClockSchedule::checked(
            destination_domain_id(kind),
            rational(1UL, 1UL),
            rational(0UL, 1UL),
            14,
          ),
        ],
        32,
      )
    TimedThreeStage =>
      @sim.normalize_clock_schedules(
        [
          @sim.ClockSchedule::checked(
            source_domain_id(),
            rational(2UL, 3UL),
            rational(1UL, 3UL),
            12,
          ),
          @sim.ClockSchedule::checked(
            destination_domain_id(kind),
            rational(3UL, 5UL),
            rational(1UL, 5UL),
            14,
          ),
        ],
        64,
      )
    TimedFourStage =>
      @sim.normalize_clock_schedules(
        [
          @sim.ClockSchedule::checked(
            source_domain_id(),
            rational(2UL, 1UL),
            rational(0UL, 1UL),
            13,
          ),
          @sim.ClockSchedule::checked(
            destination_domain_id(kind),
            rational(4UL, 1UL),
            rational(0UL, 1UL),
            7,
          ),
        ],
        64,
      )
  }
}

///|
fn known_normalized(value : UInt64) -> @differential.NormalizedValue raise {
  @differential.NormalizedValue::from_planes(
    if value == 0UL {
      "0"
    } else {
      "1"
    },
    "1",
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
) -> String raise SyncFixtureError {
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
) -> String raise SyncFixtureError {
  for port in ports {
    if port.emitted_name() == emitted {
      return port.source_name()
    }
  }
  raise MissingPortMapping(emitted)
}

///|
fn project_schedule(
  kind : SyncFixtureKind,
  schedule : @sim.NormalizedSchedule,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> @verilator.AtomicStimulus raise {
  let domains : Array[@verilator.StimulusDomain] = []
  let declared : Array[Int] = []
  for event in schedule.events() {
    for domain in event.active_domains() {
      if !declared.contains(domain.ordinal()) {
        declared.push(domain.ordinal())
      }
    }
  }
  declared.sort()
  for domain in declared {
    domains.push(
      @verilator.StimulusDomain::checked(
        domain,
        emitted_port_name(ports, domain_clock_name(kind, domain)),
      ),
    )
  }
  let events : Array[@verilator.AtomicStimulusEvent] = []
  let mut source_edges = 0
  let mut destination_edges = 0
  let destination = destination_domain_id(kind)
  for boundary, event in schedule.events() {
    let drives : Array[@verilator.AtomicStimulusDrive] = []
    match kind {
      AsyncTwoStage => {
        drives.push(
          @verilator.AtomicStimulusDrive::checked(
            emitted_port_name(ports, "reset"),
            known_normalized(if destination_edges < 2 { 1UL } else { 0UL }),
          ),
        )
        drives.push(
          @verilator.AtomicStimulusDrive::checked(
            emitted_port_name(ports, "source"),
            known_normalized(
              if boundary < 3 {
                0UL
              } else {
                (boundary % 2).to_uint64()
              },
            ),
          ),
        )
      }
      TimedThreeStage | TimedFourStage => {
        drives.push(
          @verilator.AtomicStimulusDrive::checked(
            emitted_port_name(ports, "destination_reset"),
            known_normalized(if destination_edges < 2 { 1UL } else { 0UL }),
          ),
        )
        drives.push(
          @verilator.AtomicStimulusDrive::checked(
            emitted_port_name(ports, "source_reset"),
            known_normalized(if source_edges < 2 { 1UL } else { 0UL }),
          ),
        )
        if contains_domain(event, source_domain_id()) {
          drives.push(
            @verilator.AtomicStimulusDrive::checked(
              emitted_port_name(ports, "source_next"),
              known_normalized((source_edges % 2).to_uint64()),
            ),
          )
        }
      }
    }
    events.push(
      @verilator.AtomicStimulusEvent::checked(
        event.time().value(),
        boundary.to_uint64(),
        drives,
        event.active_domains().map(id => id.ordinal()),
      ),
    )
    if contains_domain(event, destination) {
      destination_edges += 1
    }
    if kind != AsyncTwoStage && contains_domain(event, source_domain_id()) {
      source_edges += 1
    }
  }
  @verilator.AtomicStimulus::checked(
    schedule.ticks_per_source_unit(),
    domains,
    events,
  )
}
