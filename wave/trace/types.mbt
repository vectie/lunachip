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
  EmptySemanticVersion
  UnsupportedTraceDigestAlgorithm(String)
  InvalidTraceDigestHex(String)
  InvalidTraceTimebase(UInt64)
  InvalidTraceDomainId(Int)
  EmptyTraceDomainClock
  DuplicateTraceDomainId(Int)
  DuplicateTraceDomainClock(String)
  EmptyAtomicBatch
  EmptyTraceDriveName
  DuplicateTraceDrive(String)
  DuplicateActiveTraceDomain(Int)
  UnknownActiveTraceDomain(Int)
  InvalidTraceChangeIndex(Int)
  DuplicateTraceChange(Int)
  NonMonotonicTraceTime(previous~ : UInt64, actual~ : UInt64)
  NonMonotonicAtomicBoundary(previous~ : UInt64, actual~ : UInt64)
  InvalidAtomicInitialFrame
  InvalidAtomicEventMembers
  DuplicateAtomicInitialFrame
  MigrationRequiresSchema1
  TraceResourceLimitExceeded(kind~ : String, maximum~ : Int, actual~ : Int)
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
  { path, name, width, }
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
  { path, name, value, }
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
/// Construct one changed-value entry for a schema-2 atomic frame. The owning
/// trace validates the signal index and changed-only invariant.
pub fn TraceChange::new(
  signal_index : Int,
  value : @wave.LogicValue,
) -> TraceChange {
  { signal_index, value, }
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
/// Canonical native trace schema generation.
pub(all) enum TraceSchema {
  Legacy1
  Atomic2
} derive(Debug, Eq)

///|
/// The embedded canonical-IR digest bound into schema 2.
pub struct TraceDigest {
  algorithm : String
  hex : String
} derive(Debug, Eq)

///|
pub fn TraceDigest::checked(
  algorithm : String,
  hex : String,
) -> TraceDigest raise TraceError {
  if algorithm != "fnv1a-64" {
    raise UnsupportedTraceDigestAlgorithm(algorithm)
  }
  if hex.length() != 16 {
    raise InvalidTraceDigestHex(hex)
  }
  for code in hex {
    if !((code >= '0' && code <= '9') || (code >= 'a' && code <= 'f')) {
      raise InvalidTraceDigestHex(hex)
    }
  }
  { algorithm, hex, }
}

///|
pub fn TraceDigest::algorithm(self : TraceDigest) -> String {
  self.algorithm
}

///|
pub fn TraceDigest::hex(self : TraceDigest) -> String {
  self.hex
}

///|
/// One canonical schema-2 clock-domain table entry.
pub struct TraceDomain {
  id : Int
  clock : String
} derive(Debug, Eq)

///|
pub fn TraceDomain::checked(
  id : Int,
  clock : String,
) -> TraceDomain raise TraceError {
  if id < 0 {
    raise InvalidTraceDomainId(id)
  }
  if clock.is_empty() {
    raise EmptyTraceDomainClock
  }
  { id, clock, }
}

///|
pub fn TraceDomain::id(self : TraceDomain) -> Int {
  self.id
}

///|
pub fn TraceDomain::clock(self : TraceDomain) -> String {
  self.clock
}

///|
/// Semantic kind of one schema-2 frame. `Legacy` is used only by explicit
/// schema-1 migration and retains the old event without inventing atomicity.
pub(all) enum AtomicTraceEvent {
  AtomicInitial
  AtomicBatch
  AtomicMarker(String)
  Legacy(TraceEvent)
} derive(Debug, Eq)

///|
/// One exact-time schema-2 frame. Drives and domains describe one atomic
/// timestamp batch; empty changes remain meaningful and are retained.
pub struct AtomicTraceFrame {
  time : UInt64
  boundary : UInt64
  event : AtomicTraceEvent
  drives : ReadOnlyArray[String]
  active_domains : ReadOnlyArray[Int]
  changes : ReadOnlyArray[TraceChange]
} derive(Debug, Eq)

///|
pub fn AtomicTraceFrame::checked(
  time : UInt64,
  boundary : UInt64,
  event : AtomicTraceEvent,
  declared_drives : ArrayView[String],
  declared_domains : ArrayView[Int],
  declared_changes : ArrayView[TraceChange],
) -> AtomicTraceFrame raise TraceError {
  atomic_trace_frame_checked(
    time, boundary, event, declared_drives, declared_domains, declared_changes,
  )
}

///|
pub fn AtomicTraceFrame::time(self : AtomicTraceFrame) -> UInt64 {
  self.time
}

///|
pub fn AtomicTraceFrame::boundary(self : AtomicTraceFrame) -> UInt64 {
  self.boundary
}

///|
pub fn AtomicTraceFrame::event(self : AtomicTraceFrame) -> AtomicTraceEvent {
  self.event
}

///|
pub fn AtomicTraceFrame::drives(
  self : AtomicTraceFrame,
) -> ReadOnlyArray[String] {
  self.drives
}

///|
pub fn AtomicTraceFrame::active_domains(
  self : AtomicTraceFrame,
) -> ReadOnlyArray[Int] {
  self.active_domains
}

///|
pub fn AtomicTraceFrame::changes(
  self : AtomicTraceFrame,
) -> ReadOnlyArray[TraceChange] {
  self.changes
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
  schema : TraceSchema
  signals : ReadOnlyArray[TraceSignal]
  frames : ReadOnlyArray[TraceFrame]
  semantic_version : String?
  ir_digest : TraceDigest?
  timebase : UInt64?
  domains : ReadOnlyArray[TraceDomain]
  atomic_frames : ReadOnlyArray[AtomicTraceFrame]
} derive(Debug, Eq)

///|
pub fn Trace::schema(self : Trace) -> TraceSchema {
  self.schema
}

///|
pub fn Trace::signals(self : Trace) -> ReadOnlyArray[TraceSignal] {
  self.signals
}

///|
pub fn Trace::frames(self : Trace) -> ReadOnlyArray[TraceFrame] {
  self.frames
}

///|
pub fn Trace::semantic_version(self : Trace) -> String? {
  self.semantic_version
}

///|
pub fn Trace::ir_digest(self : Trace) -> TraceDigest? {
  self.ir_digest
}

///|
pub fn Trace::timebase(self : Trace) -> UInt64? {
  self.timebase
}

///|
pub fn Trace::domains(self : Trace) -> ReadOnlyArray[TraceDomain] {
  self.domains
}

///|
pub fn Trace::atomic_frames(self : Trace) -> ReadOnlyArray[AtomicTraceFrame] {
  self.atomic_frames
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

///|
pub extend TraceError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TraceError with Eq::{not_equal, equal}

///|
pub extend TraceSignal with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TraceSignal with Eq::{not_equal, equal}

///|
pub extend TraceSample with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TraceSample with Eq::{not_equal, equal}

///|
pub extend TraceEvent with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TraceEvent with Eq::{not_equal, equal}

///|
pub extend TraceChange with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TraceChange with Eq::{not_equal, equal}

///|
pub extend TraceFrame with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TraceFrame with Eq::{not_equal, equal}

///|
pub extend TraceSchema with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TraceSchema with Eq::{not_equal, equal}

///|
pub extend TraceDigest with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TraceDigest with Eq::{not_equal, equal}

///|
pub extend TraceDomain with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TraceDomain with Eq::{not_equal, equal}

///|
pub extend AtomicTraceEvent with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AtomicTraceEvent with Eq::{not_equal, equal}

///|
pub extend AtomicTraceFrame with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AtomicTraceFrame with Eq::{not_equal, equal}

///|
pub extend Trace with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Trace with Eq::{not_equal, equal}
