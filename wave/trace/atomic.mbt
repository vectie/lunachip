///|
const MAX_TRACE_SIGNALS : Int = 65536

///|
const MAX_TRACE_DOMAINS : Int = 65536

///|
const MAX_TRACE_FRAMES : Int = 1048576

///|
const MAX_TRACE_EVENT_MEMBERS : Int = 65536

///|
const MAX_TRACE_TOTAL_EVENT_MEMBERS : Int = 1048576

///|
const MAX_TRACE_TOTAL_CHANGES : Int = 4194304

///|
priv struct AtomicTraceTotals {
  drives : Int
  domains : Int
  changes : Int
}

///|
fn require_trace_limit(
  kind : String,
  actual : Int,
  maximum : Int,
) -> Unit raise TraceError {
  if actual > maximum {
    raise TraceResourceLimitExceeded(kind~, maximum~, actual~)
  }
}

///|
fn add_trace_total(
  kind : String,
  current : Int,
  added : Int,
  maximum : Int,
) -> Int raise TraceError {
  if added > maximum - current {
    raise TraceResourceLimitExceeded(kind~, maximum~, actual=maximum + 1)
  }
  current + added
}

///|
fn atomic_trace_totals(
  frames : ArrayView[AtomicTraceFrame],
) -> AtomicTraceTotals raise TraceError {
  let mut drives = 0
  let mut domains = 0
  let mut changes = 0
  let mut members = 0
  for frame in frames {
    members = add_trace_total(
      "total event members",
      members,
      frame.drives().length(),
      MAX_TRACE_TOTAL_EVENT_MEMBERS,
    )
    drives += frame.drives().length()
    members = add_trace_total(
      "total event members",
      members,
      frame.active_domains().length(),
      MAX_TRACE_TOTAL_EVENT_MEMBERS,
    )
    domains += frame.active_domains().length()
    changes = add_trace_total(
      "total changes",
      changes,
      frame.changes().length(),
      MAX_TRACE_TOTAL_CHANGES,
    )
  }
  { drives, domains, changes }
}

///|
fn atomic_trace_frame_checked(
  time : UInt64,
  boundary : UInt64,
  event : AtomicTraceEvent,
  declared_drives : ArrayView[String],
  declared_domains : ArrayView[Int],
  declared_changes : ArrayView[TraceChange],
) -> AtomicTraceFrame raise TraceError {
  require_trace_limit(
    "frame drives",
    declared_drives.length(),
    MAX_TRACE_EVENT_MEMBERS,
  )
  require_trace_limit(
    "frame domains",
    declared_domains.length(),
    MAX_TRACE_EVENT_MEMBERS,
  )
  require_trace_limit(
    "frame changes",
    declared_changes.length(),
    MAX_TRACE_SIGNALS,
  )
  let drives = declared_drives.to_owned()
  drives.sort_by(compare_text)
  for index, drive in drives {
    if drive.is_empty() {
      raise EmptyTraceDriveName
    }
    if index > 0 && drives[index - 1] == drive {
      raise DuplicateTraceDrive(drive)
    }
  }
  let active_domains = declared_domains.to_owned()
  active_domains.sort()
  for index, domain in active_domains {
    if domain < 0 {
      raise InvalidTraceDomainId(domain)
    }
    if index > 0 && active_domains[index - 1] == domain {
      raise DuplicateActiveTraceDomain(domain)
    }
  }
  match event {
    AtomicBatch if drives.is_empty() && active_domains.is_empty() =>
      raise EmptyAtomicBatch
    AtomicInitial if !drives.is_empty() || !active_domains.is_empty() =>
      raise InvalidAtomicInitialFrame
    AtomicMarker(_) | Legacy(_) if !drives.is_empty() ||
      !active_domains.is_empty() => raise InvalidAtomicEventMembers
    _ => ()
  }
  let changes = declared_changes.to_owned()
  changes.sort_by((left, right) => left.signal_index() - right.signal_index())
  for index, change in changes {
    if change.signal_index() < 0 {
      raise InvalidTraceChangeIndex(change.signal_index())
    }
    if index > 0 && changes[index - 1].signal_index() == change.signal_index() {
      raise DuplicateTraceChange(change.signal_index())
    }
  }
  {
    time,
    boundary,
    event,
    drives: ReadOnlyArray::from_array(drives),
    active_domains: ReadOnlyArray::from_array(active_domains),
    changes: ReadOnlyArray::from_array(changes),
  }
}

///|
fn canonical_trace_signals(
  declared : ArrayView[TraceSignal],
) -> Array[TraceSignal] raise TraceError {
  require_trace_limit("signals", declared.length(), MAX_TRACE_SIGNALS)
  let signals = declared.to_owned()
  for index, signal in signals {
    if index > 0 {
      let previous = signals[index - 1]
      if previous.path() == signal.path() && previous.name() == signal.name() {
        raise DuplicateSignal(path=signal.path(), name=signal.name())
      }
      if compare_signal(previous, signal) >= 0 {
        // Signal-table indices are already embedded in every TraceChange.
        // Rejecting reordering avoids silently rebinding a value to another
        // signal; callers can canonicalize before assigning indices.
        raise NonCanonical
      }
    }
  }
  signals
}

///|
fn canonical_trace_domains(
  declared : ArrayView[TraceDomain],
) -> Array[TraceDomain] raise TraceError {
  require_trace_limit("domains", declared.length(), MAX_TRACE_DOMAINS)
  let domains = declared.to_owned()
  domains.sort_by((left, right) => left.id() - right.id())
  for index, domain in domains {
    if domain.id() < 0 {
      raise InvalidTraceDomainId(domain.id())
    }
    if domain.clock().is_empty() {
      raise EmptyTraceDomainClock
    }
    if index > 0 && domains[index - 1].id() == domain.id() {
      raise DuplicateTraceDomainId(domain.id())
    }
    for earlier in 0..<index {
      if domains[earlier].clock() == domain.clock() {
        raise DuplicateTraceDomainClock(domain.clock())
      }
    }
  }
  domains
}

///|
fn trace_domain_exists(
  domains : ArrayView[TraceDomain],
  requested : Int,
) -> Bool {
  for domain in domains {
    if domain.id() == requested {
      return true
    }
  }
  false
}

///|
fn atomic_event_rank(event : AtomicTraceEvent) -> Int {
  match event {
    AtomicInitial => 0
    AtomicBatch => 1
    Legacy(_) => 2
    AtomicMarker(_) => 3
  }
}

///|
fn atomic_event_changes_state(event : AtomicTraceEvent) -> Bool {
  match event {
    AtomicBatch | Legacy(Settled | InputDriven(_) | RisingEdge(_)) => true
    AtomicInitial | AtomicMarker(_) | Legacy(Initial | Marker(_)) => false
  }
}

///|
fn validate_atomic_trace_frames(
  signals : ArrayView[TraceSignal],
  domains : ArrayView[TraceDomain],
  frames : ArrayView[AtomicTraceFrame],
) -> Unit raise TraceError {
  require_trace_limit("frames", frames.length(), MAX_TRACE_FRAMES)
  ignore(atomic_trace_totals(frames))
  if frames.is_empty() {
    return
  }
  let previous_values : Array[@wave.LogicValue?] = Array::make(
    signals.length(),
    None,
  )
  let mut previous_time : UInt64? = None
  let mut previous_boundary : UInt64? = None
  let mut previous_rank = -1
  let mut state_change_at_time : UInt64? = None
  for frame_index, frame in frames {
    if frame_index == 0 {
      let is_initial_snapshot = match frame.event() {
        AtomicInitial | Legacy(_) => true
        _ => false
      }
      if !is_initial_snapshot || frame.changes().length() != signals.length() {
        raise InvalidAtomicInitialFrame
      }
    } else if frame.event() is AtomicInitial {
      raise DuplicateAtomicInitialFrame
    }
    match previous_time {
      Some(old) if frame.time() < old =>
        raise NonMonotonicTraceTime(previous=old, actual=frame.time())
      Some(old) if frame.time() == old => {
        let rank = atomic_event_rank(frame.event())
        if rank < previous_rank {
          raise NonCanonical
        }
      }
      _ => previous_rank = -1
    }
    match previous_boundary {
      Some(old) if frame.boundary() < old =>
        raise NonMonotonicAtomicBoundary(previous=old, actual=frame.boundary())
      Some(old) if frame.boundary() == old => {
        // The synthetic initial snapshot is not a replay event. Permit only
        // its canonical boundary zero to be shared with the first stored
        // event, whose actual boundary may also be zero.
        let shared_initial_zero = frame_index == 1 &&
          old == 0UL &&
          frames[0].event() is AtomicInitial
        if !shared_initial_zero {
          raise NonMonotonicAtomicBoundary(
            previous=old,
            actual=frame.boundary(),
          )
        }
      }
      _ => ()
    }
    if atomic_event_changes_state(frame.event()) {
      if state_change_at_time == Some(frame.time()) {
        raise NonMonotonicTraceTime(previous=frame.time(), actual=frame.time())
      }
      state_change_at_time = Some(frame.time())
    }
    for domain in frame.active_domains() {
      if !trace_domain_exists(domains, domain) {
        raise UnknownActiveTraceDomain(domain)
      }
    }
    for change in frame.changes() {
      let index = change.signal_index()
      if index < 0 || index >= signals.length() {
        raise InvalidTraceChangeIndex(index)
      }
      if change.value().width() != signals[index].width() {
        raise SampleWidthMismatch(
          path=signals[index].path(),
          name=signals[index].name(),
          expected=signals[index].width(),
          actual=change.value().width(),
        )
      }
      if previous_values[index] == Some(change.value()) {
        raise NonCanonical
      }
      previous_values[index] = Some(change.value())
    }
    previous_time = Some(frame.time())
    previous_boundary = Some(frame.boundary())
    previous_rank = atomic_event_rank(frame.event())
  }
}

///|
/// Construct a canonical exact-time schema-2 trace.
pub fn Trace::checked_atomic(
  semantic_version : String,
  ir_digest : TraceDigest,
  timebase : UInt64,
  declared_domains : ArrayView[TraceDomain],
  declared_signals : ArrayView[TraceSignal],
  frames : ArrayView[AtomicTraceFrame],
) -> Trace raise TraceError {
  if semantic_version.is_empty() {
    raise EmptySemanticVersion
  }
  if timebase == 0UL {
    raise InvalidTraceTimebase(timebase)
  }
  let domains = canonical_trace_domains(declared_domains)
  let signals = canonical_trace_signals(declared_signals)
  validate_atomic_trace_frames(signals, domains, frames)
  {
    schema: Atomic2,
    signals: ReadOnlyArray::from_array(signals),
    frames: ReadOnlyArray::from_array([]),
    semantic_version: Some(semantic_version),
    ir_digest: Some(ir_digest),
    timebase: Some(timebase),
    domains: ReadOnlyArray::from_array(domains),
    atomic_frames: ReadOnlyArray::from_array(frames),
  }
}

///|
/// Purely migrate schema 1 without treating legacy edges as coincident or
/// inventing clock-domain identities. Every old frame receives its own time
/// and boundary on timebase 1 and retains its exact legacy event.
pub fn migrate_schema1(
  trace : Trace,
  semantic_version : String,
  ir_digest : TraceDigest,
) -> Trace raise TraceError {
  if trace.schema() != Legacy1 {
    raise MigrationRequiresSchema1
  }
  let frames : Array[AtomicTraceFrame] = []
  for index, frame in trace.frames() {
    let event = if index == 0 && frame.event() is Initial {
      AtomicInitial
    } else {
      Legacy(frame.event())
    }
    frames.push(
      AtomicTraceFrame::checked(
        index.to_uint64(),
        index.to_uint64(),
        event,
        [],
        [],
        frame.changes(),
      ),
    )
  }
  Trace::checked_atomic(
    semantic_version,
    ir_digest,
    1UL,
    [],
    trace.signals(),
    frames,
  )
}
