///|
const SCHEDULE_MAX_UINT64 : UInt64 = 18446744073709551615UL

///|
fn schedule_gcd(left : UInt64, right : UInt64) -> UInt64 {
  for a = left, b = right; b != 0UL; {
    continue b, a % b
  } nobreak {
    a
  }
}

///|
fn schedule_checked_mul(
  left : UInt64,
  right : UInt64,
  operation : String,
) -> UInt64 raise ScheduleError {
  if left != 0UL && right > SCHEDULE_MAX_UINT64 / left {
    raise ScheduleArithmeticOverflow(operation~)
  }
  left * right
}

///|
fn schedule_checked_add(
  left : UInt64,
  right : UInt64,
  operation : String,
) -> UInt64 raise ScheduleError {
  if right > SCHEDULE_MAX_UINT64 - left {
    raise ScheduleArithmeticOverflow(operation~)
  }
  left + right
}

///|
fn schedule_lcm(left : UInt64, right : UInt64) -> UInt64 raise ScheduleError {
  schedule_checked_mul(left / schedule_gcd(left, right), right, "lcm")
}

///|
priv struct ScheduledDomainEdge {
  time : UInt64
  domain : @ir.ClockDomainId
}

///|
fn compare_scheduled_edge(
  left : ScheduledDomainEdge,
  right : ScheduledDomainEdge,
) -> Int32 {
  if left.time < right.time {
    -1
  } else if left.time > right.time {
    1
  } else {
    left.domain.ordinal() - right.domain.ordinal()
  }
}

///|
/// Normalize finite exact-rational clock schedules to integer timestamp events.
/// Equal timestamps are coalesced and their domain IDs are canonicalized by
/// `TimestampEvent::checked`. Floating-point arithmetic is never used.
pub fn normalize_clock_schedules(
  declared : ArrayView[ClockSchedule],
  maximum_events : Int32,
) -> NormalizedSchedule raise {
  if declared.is_empty() {
    raise EmptyClockSchedule
  }
  if maximum_events <= 0 {
    raise InvalidScheduleEventLimit(maximum_events)
  }
  let schedules = declared.to_owned()
  schedules.sort_by((left, right) => {
    left.domain().ordinal() - right.domain().ordinal()
  })
  let mut requested = 0
  let mut lattice = 1UL
  for index, schedule in schedules {
    if index > 0 && schedules[index - 1].domain() == schedule.domain() {
      raise DuplicateScheduleDomain(schedule.domain().ordinal())
    }
    if schedule.edge_count() > maximum_events - requested {
      raise ScheduleEventLimitExceeded(
        requested=requested + schedule.edge_count(),
        maximum=maximum_events,
      )
    }
    requested += schedule.edge_count()
    lattice = schedule_lcm(lattice, schedule.period().denominator())
    lattice = schedule_lcm(lattice, schedule.phase().denominator())
  }
  let edges : Array[ScheduledDomainEdge] = []
  for schedule in schedules {
    let period = schedule_checked_mul(
      schedule.period().numerator(),
      lattice / schedule.period().denominator(),
      "period normalization",
    )
    let phase = schedule_checked_mul(
      schedule.phase().numerator(),
      lattice / schedule.phase().denominator(),
      "phase normalization",
    )
    for index in 0..<schedule.edge_count() {
      let offset = schedule_checked_mul(
        index.to_uint64(),
        period,
        "schedule edge offset",
      )
      edges.push({
        time: schedule_checked_add(phase, offset, "schedule timestamp"),
        domain: schedule.domain(),
      })
    }
  }
  edges.sort_by(compare_scheduled_edge)
  let events : Array[TimestampEvent] = []
  let mut index = 0
  while index < edges.length() {
    let time = edges[index].time
    let domains : Array[@ir.ClockDomainId] = []
    while index < edges.length() && edges[index].time == time {
      domains.push(edges[index].domain)
      index += 1
    }
    events.push(
      TimestampEvent::checked(SimulationTime::from_uint64(time), [], domains),
    )
  }
  { ticks_per_source_unit: lattice, events: ReadOnlyArray::from_array(events), }
}
