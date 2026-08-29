///|
/// Stable failures raised while constructing or decoding trace artifacts.
pub(all) suberror TraceError {
  EmptyPath
  EmptyName
  InvalidWidth(Int)
  DuplicateSignal(path~ : String, name~ : String)
  UnknownSignal(path~ : String, name~ : String)
  DuplicateSample(path~ : String, name~ : String)
  SampleWidthMismatch(
    path~ : String,
    name~ : String,
    expected~ : Int,
    actual~ : Int
  )
  MissingSample(path~ : String, name~ : String)
  NonMonotonicBoundary
  InvalidInteger(line~ : Int, field~ : String, value~ : String)
  InvalidEncodedText(line~ : Int, value~ : String)
  InvalidUtf8Text(line~ : Int)
  UnexpectedEnd(expected~ : String)
  UnexpectedLine(line~ : Int, expected~ : String, actual~ : String)
  UnsupportedVersion(String)
  UnknownSourceMapSignal(Int)
  DuplicateSourceMapSignal(Int)
  MissingSourceMapSignal(Int)
  SourceMapSignalMismatch(Int)
  InvalidVcdIdentifier(index~ : Int, actual~ : String)
  InvalidSourceMetadata(line~ : Int, field~ : String)
  NonCanonical
} derive(Debug, Eq)

///|
/// A canonical trace signal identity.
///
/// `path` names the owning hierarchy and `name` names the signal within that
/// hierarchy. They stay separate so no separator convention can alias names.
pub struct TraceSignal {
  path : String
  name : String
  width : Int
} derive(Debug, Eq)

///|
/// Construct a checked trace signal identity.
pub fn TraceSignal::checked(
  path : String,
  name : String,
  width : Int,
) -> TraceSignal raise TraceError {
  if path.length() == 0 {
    raise EmptyPath
  }
  if name.length() == 0 {
    raise EmptyName
  }
  if width < 1 || width > 64 {
    raise InvalidWidth(width)
  }
  { path, name, width }
}

///|
pub fn TraceSignal::path(self : TraceSignal) -> String {
  self.path
}

///|
pub fn TraceSignal::name(self : TraceSignal) -> String {
  self.name
}

///|
pub fn TraceSignal::width(self : TraceSignal) -> Int {
  self.width
}

///|
/// A value sampled for one canonical signal at an event boundary.
pub struct TraceSample {
  path : String
  name : String
  value : @wave.LogicValue
} derive(Debug, Eq)

///|
pub fn TraceSample::new(
  path : String,
  name : String,
  value : @wave.LogicValue,
) -> TraceSample {
  { path, name, value }
}

///|
pub fn TraceSample::path(self : TraceSample) -> String {
  self.path
}

///|
pub fn TraceSample::name(self : TraceSample) -> String {
  self.name
}

///|
pub fn TraceSample::value(self : TraceSample) -> @wave.LogicValue {
  self.value
}

///|
/// The semantic event whose settled state is captured by a trace frame.
pub(all) enum TraceEvent {
  Initial
  Settled
  InputDriven(String)
  RisingEdge(String)
  Marker(String)
} derive(Debug, Eq)

///|
/// One changed signal value, addressed by canonical signal-table index.
pub struct TraceChange {
  signal_index : Int
  value : @wave.LogicValue
} derive(Debug, Eq)

///|
pub fn TraceChange::signal_index(self : TraceChange) -> Int {
  self.signal_index
}

///|
pub fn TraceChange::value(self : TraceChange) -> @wave.LogicValue {
  self.value
}

///|
/// One preserved event boundary. Empty `changes` is meaningful and retained.
pub struct TraceFrame {
  cycle : UInt64
  boundary : UInt64
  event : TraceEvent
  changes : ReadOnlyArray[TraceChange]
} derive(Debug, Eq)

///|
pub fn TraceFrame::cycle(self : TraceFrame) -> UInt64 {
  self.cycle
}

///|
pub fn TraceFrame::boundary(self : TraceFrame) -> UInt64 {
  self.boundary
}

///|
pub fn TraceFrame::event(self : TraceFrame) -> TraceEvent {
  self.event
}

///|
pub fn TraceFrame::changes(self : TraceFrame) -> ReadOnlyArray[TraceChange] {
  self.changes
}

///|
/// An immutable deterministic native trace artifact.
pub struct Trace {
  signals : ReadOnlyArray[TraceSignal]
  frames : ReadOnlyArray[TraceFrame]
} derive(Debug, Eq)

///|
pub fn Trace::signals(self : Trace) -> ReadOnlyArray[TraceSignal] {
  self.signals
}

///|
pub fn Trace::frames(self : Trace) -> ReadOnlyArray[TraceFrame] {
  self.frames
}

///|
/// Mutable recorder that canonicalizes signal order and computes changed-only
/// frames from complete event-boundary samples.
pub struct TraceRecorder {
  signals : Array[TraceSignal]
  previous : Array[@wave.LogicValue?]
  frames : Array[TraceFrame]
  mut last_cycle : UInt64?
  mut last_boundary : UInt64?
}
