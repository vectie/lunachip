///|
fn schedule_domain(ordinal : Int) -> @ir.ClockDomainId raise {
  @ir.ClockDomainId::new(ordinal)
}

///|
fn rational(
  numerator : UInt64,
  denominator : UInt64,
) -> @sim.RationalTicks raise {
  @sim.RationalTicks::checked(numerator, denominator)
}

///|
test "rational ticks reduce exactly" {
  let value = rational(6UL, 4UL)
  inspect(value.numerator(), content="3")
  inspect(value.denominator(), content="2")
  let zero = rational(0UL, 99UL)
  inspect(zero.numerator(), content="0")
  inspect(zero.denominator(), content="1")
}

///|
test "phase-zero schedules coalesce the first timestamp exactly" {
  let domain_a = schedule_domain(0)
  let domain_b = schedule_domain(1)
  let normalized = @sim.normalize_clock_schedules(
    [
      @sim.ClockSchedule::checked(
        domain_a,
        rational(1UL, 1UL),
        rational(0UL, 7UL),
        3,
      ),
      @sim.ClockSchedule::checked(
        domain_b,
        rational(2UL, 1UL),
        rational(0UL, 3UL),
        2,
      ),
    ],
    5,
  )
  let events = normalized.events()
  inspect(events.length(), content="3")
  inspect(events[0].time().value(), content="0")
  inspect(events[0].active_domains().length(), content="2")
  inspect(events[1].time().value(), content="1")
  inspect(events[2].time().value(), content="2")
  inspect(events[2].active_domains().length(), content="2")
}

///|
test "clock schedules reject a zero period" {
  try
    @sim.ClockSchedule::checked(
      schedule_domain(4),
      rational(0UL, 9UL),
      rational(0UL, 1UL),
      1,
    )
  catch {
    @sim.ScheduleError::ZeroClockPeriod(domain~) => assert_eq(domain, 4)
    error => fail("unexpected zero-period error: \{Repr(error)}")
  } noraise {
    _ => fail("expected zero-period rejection")
  }
}

///|
test "clock schedules normalize to an exact lattice and coalesce coincidences" {
  let domain_a = schedule_domain(0)
  let domain_b = schedule_domain(1)
  let first = @sim.normalize_clock_schedules(
    [
      @sim.ClockSchedule::checked(
        domain_a,
        rational(1UL, 2UL),
        rational(1UL, 2UL),
        3,
      ),
      @sim.ClockSchedule::checked(
        domain_b,
        rational(1UL, 3UL),
        rational(1UL, 3UL),
        3,
      ),
    ],
    6,
  )
  let permuted = @sim.normalize_clock_schedules(
    [
      @sim.ClockSchedule::checked(
        domain_b,
        rational(1UL, 3UL),
        rational(1UL, 3UL),
        3,
      ),
      @sim.ClockSchedule::checked(
        domain_a,
        rational(1UL, 2UL),
        rational(1UL, 2UL),
        3,
      ),
    ],
    6,
  )
  assert_eq(first, permuted)
  inspect(first.ticks_per_source_unit(), content="6")
  let events = first.events()
  inspect(events.length(), content="5")
  inspect(events[0].time().value(), content="2")
  inspect(events[1].time().value(), content="3")
  inspect(events[2].time().value(), content="4")
  inspect(events[3].time().value(), content="6")
  inspect(events[3].active_domains().length(), content="2")
  inspect(events[3].active_domains()[0].ordinal(), content="0")
  inspect(events[3].active_domains()[1].ordinal(), content="1")
  inspect(events[4].time().value(), content="9")
}

///|
test "clock schedules reject duplicate domains and resource excess" {
  let domain = schedule_domain(0)
  let schedule = @sim.ClockSchedule::checked(
    domain,
    rational(1UL, 1UL),
    rational(1UL, 1UL),
    2,
  )
  try @sim.normalize_clock_schedules([schedule, schedule], 4) catch {
    @sim.ScheduleError::DuplicateScheduleDomain(id) => assert_eq(id, 0)
    error => fail("unexpected duplicate schedule error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate schedule rejection")
  }
  try @sim.normalize_clock_schedules([schedule], 1) catch {
    @sim.ScheduleError::ScheduleEventLimitExceeded(requested~, maximum~) => {
      assert_eq(requested, 2)
      assert_eq(maximum, 1)
    }
    error => fail("unexpected schedule limit error: \{Repr(error)}")
  } noraise {
    _ => fail("expected schedule event limit rejection")
  }
}

///|
test "clock schedule arithmetic rejects lattice and timestamp overflow" {
  try
    @sim.normalize_clock_schedules(
      [
        @sim.ClockSchedule::checked(
          schedule_domain(0),
          rational(1UL, 18446744073709551615UL),
          rational(1UL, 1UL),
          1,
        ),
        @sim.ClockSchedule::checked(
          schedule_domain(1),
          rational(1UL, 18446744073709551614UL),
          rational(1UL, 1UL),
          1,
        ),
      ],
      2,
    )
  catch {
    @sim.ScheduleError::ScheduleArithmeticOverflow(operation~) =>
      assert_eq(operation, "lcm")
    error => fail("unexpected lattice overflow error: \{Repr(error)}")
  } noraise {
    _ => fail("expected lattice overflow rejection")
  }
  try
    @sim.normalize_clock_schedules(
      [
        @sim.ClockSchedule::checked(
          schedule_domain(0),
          rational(18446744073709551615UL, 1UL),
          rational(18446744073709551615UL, 1UL),
          2,
        ),
      ],
      2,
    )
  catch {
    @sim.ScheduleError::ScheduleArithmeticOverflow(operation~) =>
      assert_eq(operation, "schedule timestamp")
    error => fail("unexpected timestamp overflow error: \{Repr(error)}")
  } noraise {
    _ => fail("expected timestamp overflow rejection")
  }
}
