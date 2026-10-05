///|
fn compare_text(left : String, right : String) -> Int {
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
fn compare_signal(left : TraceSignal, right : TraceSignal) -> Int {
  let path_order = compare_text(left.path(), right.path())
  if path_order != 0 {
    path_order
  } else {
    compare_text(left.name(), right.name())
  }
}

///|
fn signal_index(
  signals : ArrayView[TraceSignal],
  path : String,
  name : String,
) -> Int? {
  for index, signal in signals {
    if signal.path() == path && signal.name() == name {
      return Some(index)
    }
  }
  None
}

///|
/// Create a recorder with a canonical `(path, name)` signal table.
pub fn TraceRecorder::new(
  declared : ArrayView[TraceSignal],
) -> TraceRecorder raise TraceError {
  let signals = declared.to_owned()
  signals.sort_by(compare_signal)
  for index, signal in signals {
    if index > 0 {
      let previous = signals[index - 1]
      if previous.path() == signal.path() && previous.name() == signal.name() {
        raise DuplicateSignal(path=signal.path(), name=signal.name())
      }
    }
  }
  {
    signals,
    previous: Array::make(signals.length(), None),
    frames: [],
    last_cycle: None,
    last_boundary: None,
  }
}

///|
fn TraceRecorder::require_monotonic(
  self : TraceRecorder,
  cycle : UInt64,
  boundary : UInt64,
) -> Unit raise TraceError {
  match (self.last_cycle, self.last_boundary) {
    (Some(old_cycle), Some(old_boundary)) =>
      if cycle < old_cycle || (cycle == old_cycle && boundary <= old_boundary) {
        raise NonMonotonicBoundary
      }
    _ => ()
  }
}

///|
/// Record a complete settled sample at one event boundary.
///
/// Samples may arrive in any order. The stored changes are always in canonical
/// signal-table order, and unchanged values are omitted after the first frame.
pub fn TraceRecorder::record(
  self : TraceRecorder,
  cycle : UInt64,
  boundary : UInt64,
  event : TraceEvent,
  samples : ArrayView[TraceSample],
) -> Unit raise TraceError {
  self.require_monotonic(cycle, boundary)
  let values : Array[@wave.LogicValue?] = Array::make(
    self.signals.length(),
    None,
  )
  for sample in samples {
    guard signal_index(self.signals, sample.path(), sample.name())
      is Some(index) else {
      raise UnknownSignal(path=sample.path(), name=sample.name())
    }
    if values[index] is Some(_) {
      raise DuplicateSample(path=sample.path(), name=sample.name())
    }
    let expected = self.signals[index].width()
    let actual = sample.value().width()
    if expected != actual {
      raise SampleWidthMismatch(
        path=sample.path(),
        name=sample.name(),
        expected~,
        actual~,
      )
    }
    values[index] = Some(sample.value())
  }
  let changes : Array[TraceChange] = []
  for index, signal in self.signals {
    guard values[index] is Some(value) else {
      raise MissingSample(path=signal.path(), name=signal.name())
    }
    if self.previous[index] != Some(value) {
      changes.push({ signal_index: index, value, })
    }
    self.previous[index] = Some(value)
  }
  self.frames.push({
    cycle,
    boundary,
    event,
    changes: ReadOnlyArray::from_array(changes),
  })
  self.last_cycle = Some(cycle)
  self.last_boundary = Some(boundary)
}

///|
/// Snapshot the recorder into an immutable artifact.
pub fn TraceRecorder::finish(self : TraceRecorder) -> Trace {
  {
    schema: Legacy1,
    signals: ReadOnlyArray::from_array(self.signals),
    frames: ReadOnlyArray::from_array(self.frames),
    semantic_version: None,
    ir_digest: None,
    timebase: None,
    domains: ReadOnlyArray::from_array([]),
    atomic_frames: ReadOnlyArray::from_array([]),
  }
}
