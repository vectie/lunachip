///|
fn rational(n : UInt64, d : UInt64) -> @sim.RationalTicks raise {
  @sim.RationalTicks::checked(n, d)
}

///|
fn fixture_schedule(kind : FifoFixtureKind) -> @sim.NormalizedSchedule raise {
  let (sp, se, dp, de) = match kind {
    Depth4ScalarTwoStage => (rational(2UL, 3UL), 110, rational(3UL, 5UL), 125)
    Depth8AggregateThreeStage =>
      (rational(2UL, 1UL), 130, rational(4UL, 1UL), 80)
    Depth4AsymmetricFourStage =>
      (rational(1UL, 1UL), 180, rational(7UL, 1UL), 38)
  }
  @sim.normalize_clock_schedules(
    [
      @sim.ClockSchedule::checked(
        source_domain_id(),
        sp,
        rational(0UL, 1UL),
        se,
      ),
      @sim.ClockSchedule::checked(
        destination_domain_id(),
        dp,
        rational(0UL, 1UL),
        de,
      ),
    ],
    320,
  )
}

///|
fn emitted_port_name(
  ports : ReadOnlyArray[@verilator.HarnessPort],
  source : String,
) -> String raise FifoFixtureError {
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
) -> String raise FifoFixtureError {
  for port in ports {
    if port.emitted_name() == emitted {
      return port.source_name()
    }
  }
  raise MissingPortMapping(emitted)
}

///|
fn known(value : UInt64, width : Int) -> @differential.NormalizedValue raise {
  @verilator.normalized_known(width, value)
}

///|
fn payload_values(
  kind : FifoFixtureKind,
  token : Int,
) -> Array[(String, Int, UInt64)] {
  let seed = token.to_uint64()
  if kind.aggregate() {
    [
      ("source_word", 32, 0xa5000000UL | seed),
      ("source_tag", 8, (seed * 17UL + 3UL) & 0xffUL),
      ("source_lane0", 8, seed & 0xffUL),
      ("source_lane1", 8, (seed * 3UL + 1UL) & 0xffUL),
      ("source_lane2", 8, (seed * 5UL + 2UL) & 0xffUL),
    ]
  } else {
    [
      ("source_word", 32, 0UL),
      ("source_tag", 8, 0UL),
      ("source_lane0", 8, (seed * 29UL + 0x31UL) & 0xffUL),
      ("source_lane1", 8, 0UL),
      ("source_lane2", 8, 0UL),
    ]
  }
}

///|
fn project_schedule(
  kind : FifoFixtureKind,
  hardware_module : @ir.Module,
  schedule : @sim.NormalizedSchedule,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> @verilator.AtomicStimulus raise {
  let domains = [
    @verilator.StimulusDomain::checked(
      0,
      emitted_port_name(ports, "source_clock"),
    ),
    @verilator.StimulusDomain::checked(
      1,
      emitted_port_name(ports, "filler_clock1"),
    ),
    @verilator.StimulusDomain::checked(
      2,
      emitted_port_name(ports, "filler_clock2"),
    ),
    @verilator.StimulusDomain::checked(
      3,
      emitted_port_name(ports, "destination_clock"),
    ),
  ]
  let events : Array[@verilator.AtomicStimulusEvent] = []
  let mut source_edges = 0
  let mut destination_edges = 0
  let mut accepted = 0
  let mut holding = false
  let simulator = @sim.Simulator::prepare(hardware_module)
  let traffic_end = match kind {
    Depth4AsymmetricFourStage => 140
    _ => 90
  }
  for boundary, event in schedule.events() {
    let reset_source = source_edges < 2
    let reset_destination = destination_edges < 2
    let warm = kind.stages() + 4
    let coincident = event.active_domains().any(id => id == source_domain_id()) &&
      event.active_domains().any(id => id == destination_domain_id())
    let traffic_valid = match kind {
      Depth4ScalarTwoStage => source_edges % 4 != 0 || coincident
      Depth8AggregateThreeStage =>
        source_edges < warm + 18 || source_edges % 5 == 1
      Depth4AsymmetricFourStage =>
        source_edges < warm + 18 ||
        (source_edges >= 50 && source_edges < 75) ||
        (source_edges >= 105 && source_edges < 135)
    }
    if !holding &&
      !reset_source &&
      source_edges >= warm &&
      source_edges < traffic_end &&
      traffic_valid {
      holding = true
    }
    let valid = holding
    let ready = !reset_destination &&
      destination_edges >= warm &&
      (destination_edges >= 20 || destination_edges % 5 != 1)
    let token = accepted
    let drives : Array[@verilator.AtomicStimulusDrive] = [
      @verilator.AtomicStimulusDrive::checked(
        emitted_port_name(ports, "source_reset"),
        known(if reset_source { 1UL } else { 0UL }, 1),
      ),
      @verilator.AtomicStimulusDrive::checked(
        emitted_port_name(ports, "destination_reset"),
        known(if reset_destination { 1UL } else { 0UL }, 1),
      ),
      @verilator.AtomicStimulusDrive::checked(
        emitted_port_name(ports, "source_valid"),
        known(if valid { 1UL } else { 0UL }, 1),
      ),
      @verilator.AtomicStimulusDrive::checked(
        emitted_port_name(ports, "destination_ready"),
        known(if ready { 1UL } else { 0UL }, 1),
      ),
    ]
    for item in payload_values(kind, token) {
      if !kind.aggregate() && item.0 != "source_lane0" {
        continue
      }
      drives.push(
        @verilator.AtomicStimulusDrive::checked(
          emitted_port_name(ports, item.0),
          known(item.2, item.1),
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
    let pre_ready = simulator.output("source_ready").is_fully_known() &&
      simulator.output("source_ready").to_uint64() == 1UL
    simulator.apply_event(
      @sim.TimestampEvent::checked(
        event.time(),
        drives.map(d => {
          @sim.InputDrive::checked(
            source_port_name(ports, d.name()),
            drive_logic(d.value()),
          )
        }),
        event.active_domains(),
      ),
    )
    if event.active_domains().any(id => id == source_domain_id()) &&
      valid &&
      pre_ready {
      accepted += 1
      holding = false
    }
    if event.active_domains().any(id => id == source_domain_id()) {
      source_edges += 1
    }
    if event.active_domains().any(id => id == destination_domain_id()) {
      destination_edges += 1
    }
  }
  @verilator.AtomicStimulus::checked(
    schedule.ticks_per_source_unit(),
    domains,
    events,
  )
}
