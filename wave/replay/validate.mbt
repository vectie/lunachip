///|
fn replay_compare_text(left : String, right : String) -> Int {
  let left_bytes = @utf8.encode(left)
  let right_bytes = @utf8.encode(right)
  let common = left_bytes.length().min(right_bytes.length())
  for index in 0..<common {
    let delta = left_bytes[index].to_int() - right_bytes[index].to_int()
    if delta != 0 {
      return delta
    }
  }
  left_bytes.length() - right_bytes.length()
}

///|
fn compare_tap(left : @trace.TraceSignal, right : @trace.TraceSignal) -> Int {
  let path_order = replay_compare_text(left.path(), right.path())
  if path_order != 0 {
    path_order
  } else {
    replay_compare_text(left.name(), right.name())
  }
}

///|
fn validate_stimuli(
  stimuli : ArrayView[ReplayStimulus],
) -> Unit raise ReplayError {
  let mut last_cycle : UInt64? = None
  let mut last_boundary : UInt64? = None
  for stimulus in stimuli {
    match (last_cycle, last_boundary) {
      (Some(old_cycle), Some(old_boundary)) =>
        if stimulus.cycle() < old_cycle ||
          (stimulus.cycle() == old_cycle && stimulus.boundary() <= old_boundary) {
          raise NonMonotonicStimulus
        }
      _ => ()
    }
    match stimulus.action() {
      Drive(inputs) => {
        if inputs.length() == 0 {
          raise EmptyDrive
        }
        for index, input in inputs {
          if input.name().length() == 0 {
            raise EmptyInputName
          }
          if index > 0 &&
            replay_compare_text(inputs[index - 1].name(), input.name()) >= 0 {
            raise NonCanonical
          }
        }
      }
      RisingEdge(clock) => if clock.length() == 0 { raise EmptyClockName }
    }
    last_cycle = Some(stimulus.cycle())
    last_boundary = Some(stimulus.boundary())
  }
}

///|
fn validate_stop(stop : StopCondition) -> Unit raise ReplayError {
  match stop {
    OutputEquals(name~, ..) if name.length() == 0 => raise EmptyOutputName
    _ => ()
  }
}

///|
fn require_replay_domain(
  hardware_module : @ir.Module,
  domain : @ir.ClockDomainId,
) -> Unit raise ReplayError {
  if hardware_module.domain(domain) is None {
    raise UnknownReplayDomain(domain.ordinal())
  }
}

///|
fn validate_atomic_events(
  hardware_module : @ir.Module,
  events : ArrayView[AtomicReplayEvent],
) -> Unit raise ReplayError {
  let mut previous : UInt64? = None
  let mut previous_boundary : UInt64? = None
  for event in events {
    match previous {
      Some(old) if event.time() <= old =>
        raise NonMonotonicEventTime(previous=old, actual=event.time())
      _ => ()
    }
    match previous_boundary {
      Some(old) if event.boundary() <= old =>
        raise NonMonotonicEventBoundary(previous=old, actual=event.boundary())
      _ => ()
    }
    if event.drives().is_empty() && event.domains().is_empty() {
      raise EmptyAtomicEvent
    }
    for index, drive in event.drives() {
      if drive.name().is_empty() {
        raise EmptyInputName
      }
      if index > 0 &&
        replay_compare_text(event.drives()[index - 1].name(), drive.name()) >= 0 {
        raise NonCanonical
      }
    }
    for index, domain in event.domains() {
      require_replay_domain(hardware_module, domain)
      if index > 0 && event.domains()[index - 1].ordinal() >= domain.ordinal() {
        raise NonCanonical
      }
    }
    previous = Some(event.time())
    previous_boundary = Some(event.boundary())
  }
}

///|
fn canonical_options(
  declared : ArrayView[ReplayOption],
) -> Array[ReplayOption] raise ReplayError {
  let options = declared.to_owned()
  options.sort_by((left, right) => replay_compare_text(left.key(), right.key()))
  for index, option in options {
    if option.key().length() == 0 {
      raise EmptyOptionKey
    }
    if index > 0 && options[index - 1].key() == option.key() {
      raise DuplicateOption(option.key())
    }
  }
  options
}

///|
fn canonical_taps(
  declared : ArrayView[@trace.TraceSignal],
) -> Array[@trace.TraceSignal] raise ReplayError {
  let taps = declared.to_owned()
  taps.sort_by(compare_tap)
  for index, tap in taps {
    if index > 0 {
      let previous = taps[index - 1]
      if previous.path() == tap.path() && previous.name() == tap.name() {
        raise DuplicateTap(path=tap.path(), name=tap.name())
      }
    }
  }
  taps
}

///|
fn ir_digest_of(design : @ir.Design) -> ReplayDigest {
  let digest = @codec.content_digest(design)
  try! ReplayDigest::checked(digest.algorithm(), digest.to_hex())
}

///|
/// Construct a strict replay artifact from a validated design.
pub fn ReplayBundle::checked(
  design : @ir.Design,
  semantic_version : String,
  options : ArrayView[ReplayOption],
  stimuli : ArrayView[ReplayStimulus],
  stop : StopCondition,
  taps : ArrayView[@trace.TraceSignal],
  expected_result : ReplayDigest,
) -> ReplayBundle raise ReplayError {
  if semantic_version.length() == 0 {
    raise EmptySemanticVersion
  }
  validate_stimuli(stimuli)
  validate_stop(stop)
  match stop {
    AtTime(_) | AtDomainEdge(..) => raise UnsupportedSchema1Stop
    _ => ()
  }
  {
    schema: Legacy1,
    canonical_ir: @codec.serialize(design),
    ir_digest: ir_digest_of(design),
    semantic_version,
    options: ReadOnlyArray::from_array(canonical_options(options)),
    stimuli: ReadOnlyArray::from_array(stimuli),
    timebase: None,
    events: ReadOnlyArray::from_array([]),
    stop,
    taps: ReadOnlyArray::from_array(canonical_taps(taps)),
    expected_result,
  }
}

///|
/// Construct a strict schema-2 replay artifact over normalized integer ticks.
pub fn ReplayBundle::checked_atomic(
  design : @ir.Design,
  semantic_version : String,
  options : ArrayView[ReplayOption],
  timebase : UInt64,
  events : ArrayView[AtomicReplayEvent],
  stop : StopCondition,
  taps : ArrayView[@trace.TraceSignal],
  expected_result : ReplayDigest,
) -> ReplayBundle raise ReplayError {
  if semantic_version.is_empty() {
    raise EmptySemanticVersion
  }
  if timebase == 0UL {
    raise InvalidTimebase(timebase)
  }
  guard design.top_module() is Some(hardware_module) else {
    raise MissingReplayTopModule
  }
  validate_atomic_events(hardware_module, events)
  validate_stop(stop)
  match stop {
    AtDomainEdge(domain~, ..) => require_replay_domain(hardware_module, domain)
    _ => ()
  }
  {
    schema: Atomic2,
    canonical_ir: @codec.serialize(design),
    ir_digest: ir_digest_of(design),
    semantic_version,
    options: ReadOnlyArray::from_array(canonical_options(options)),
    stimuli: ReadOnlyArray::from_array([]),
    timebase: Some(timebase),
    events: ReadOnlyArray::from_array(events),
    stop,
    taps: ReadOnlyArray::from_array(canonical_taps(taps)),
    expected_result,
  }
}

///|
fn legacy_clock_domain(
  hardware_module : @ir.Module,
  clock_name : String,
) -> @ir.ClockDomainId raise ReplayError {
  for node in hardware_module.nodes() {
    match node.kind() {
      Input(name) if name == clock_name && node.signal_type().is_clock() => {
        let id = @ir.ClockDomain::rising(node.id()).id()
        if hardware_module.domain(id) is Some(_) {
          return id
        }
        raise UnmappedLegacyClock(clock_name)
      }
      _ => ()
    }
  }
  raise UnmappedLegacyClock(clock_name)
}

///|
/// Purely migrate schema 1 to schema 2.
///
/// Each legacy action receives its own increasing integer timestamp. In
/// particular, separate legacy edges never become a coincident domain batch.
pub fn migrate_schema1(bundle : ReplayBundle) -> ReplayBundle raise ReplayError {
  if bundle.schema() != Legacy1 {
    raise MigrationRequiresSchema1
  }
  let design = @codec.parse(bundle.canonical_ir()) catch {
    error => raise InvalidCanonicalIr("\{Repr(error)}")
  }
  guard design.top_module() is Some(hardware_module) else {
    raise MissingReplayTopModule
  }
  let events : Array[AtomicReplayEvent] = []
  for index, stimulus in bundle.stimuli() {
    let (drives, domains) = match stimulus.action() {
      Drive(inputs) => (inputs.iter().to_array(), [])
      RisingEdge(clock) => ([], [legacy_clock_domain(hardware_module, clock)])
    }
    events.push(
      AtomicReplayEvent::checked(
        index.to_uint64(),
        stimulus.boundary(),
        drives,
        domains,
      ),
    )
  }
  ReplayBundle::checked_atomic(
    design,
    bundle.semantic_version(),
    bundle.options(),
    1UL,
    events,
    bundle.stop(),
    bundle.taps(),
    bundle.expected_result(),
  )
}

///|
/// Compute the deterministic bootstrap result digest over canonical trace text.
pub fn trace_result_digest(trace : @trace.Trace) -> ReplayDigest {
  let bytes = @utf8.encode(@trace.serialize(trace))
  let mut hash = 14695981039346656037UL
  for byte in bytes {
    hash = (hash ^ byte.to_uint64()) * 1099511628211UL
  }
  let hex = hash.to_string(radix=16).pad_start(16, '0')
  try! ReplayDigest::checked("fnv1a-64", hex)
}
