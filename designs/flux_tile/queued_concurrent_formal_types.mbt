///|
/// Purpose-specific roles for the fixed directq3 and fetchedq2 dependency views. Indexed
/// roles use head lanes 0..3, writers A0/A1/B0/B1/C0/C1 as 0..5, and source
/// snapshots 0..1. These are existing canonical nodes, not extra device ports.
/// FIFO atomicity, retirement ordering and physical leases require later views.
/// Latched compute shape is available across Issue, but this view alone proves
/// neither command identity nor dependency authorization: it exports references.
pub(all) enum QueuedConcurrentFormalRole {
  HeadLane(Int32)
  HeadState
  HeadReserve
  NextTicket
  HeadTicket
  WriterStatus(Int32)
  WriterTicket(Int32)
  DependencyStatus(Int32)
  DependencyTicket(Int32)
  LocalReject
  LocalFault
  LoadAccept
  ComputeAccept
  StoreAccept
  LoadTerminal
  LoadTerminalTicket
  LoadTerminalFault
  ComputeTerminal
  ComputeTerminalTicket
  ComputeTerminalFault
  StoreTerminal
  StoreTerminalTicket
  StoreTerminalFault
  ComputePreflight
  InnerCommandValid
  InnerCommandReady
  ComputeLatchedTicket
  ComputeLatchedA
  ComputeLatchedB
  ComputeLatchedC
  ComputeLatchedRows
  ComputeLatchedColumns
  ComputeLatchedReduction
} derive(Debug, Eq)

///|
/// One immutable reference captured from the authoritative construction seam.
/// Resolve the actual NodeId with the backend's typed emitted-name manifest;
/// do not infer numeric ordinals, RTL hierarchy or hardware dependency truth.
pub struct QueuedConcurrentFormalObservation {
  role : QueuedConcurrentFormalRole
  node : @ir.NodeId
  signal_type : @ir.SignalType
} derive(Debug, Eq)

///|
pub fn QueuedConcurrentFormalObservation::role(
  self : QueuedConcurrentFormalObservation,
) -> QueuedConcurrentFormalRole {
  self.role
}

///|
pub fn QueuedConcurrentFormalObservation::node(
  self : QueuedConcurrentFormalObservation,
) -> @ir.NodeId {
  self.node
}

///|
pub fn QueuedConcurrentFormalObservation::signal_type(
  self : QueuedConcurrentFormalObservation,
) -> @ir.SignalType {
  self.signal_type
}

///|
/// An ordinary fixed directq3 or fetchedq2 module and dependency-only references.
/// Constructing this view does not export a property or produce proof evidence.
pub struct QueuedConcurrentFormalFixture {
  hardware : @ir.Module
  observations : ReadOnlyArray[QueuedConcurrentFormalObservation]
} derive(Debug, Eq)

///|
pub fn QueuedConcurrentFormalFixture::hardware(
  self : QueuedConcurrentFormalFixture,
) -> @ir.Module {
  self.hardware
}

///|
pub fn QueuedConcurrentFormalFixture::observations(
  self : QueuedConcurrentFormalFixture,
) -> ReadOnlyArray[QueuedConcurrentFormalObservation] {
  self.observations
}

///|
pub extend QueuedConcurrentFormalRole with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend QueuedConcurrentFormalRole with Eq::{not_equal, equal}

///|
pub extend QueuedConcurrentFormalObservation with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend QueuedConcurrentFormalObservation with Eq::{not_equal, equal}

///|
pub extend QueuedConcurrentFormalFixture with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend QueuedConcurrentFormalFixture with Eq::{not_equal, equal}
