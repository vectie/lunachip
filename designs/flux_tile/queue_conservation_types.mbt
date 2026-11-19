///|
/// Existing-node roles for direct q3 and fixed fetched q2 queue fixtures.
/// Lane indices are 0..3, entry indices follow the fixture depth, and engine
/// indices are loader 0, compute 1, storer 2. Distinct roles may alias a node;
/// roles themselves are unique. Direct q3 has115 references; fetched q2 has102.
/// This metadata does not add hardware or establish a formal result.
pub(all) enum QueueConservationRole {
  FifoPushValid(Int32)
  FifoPushReady(Int32)
  FifoPopRequest(Int32)
  FifoPopReady(Int32)
  FifoResponseValid(Int32)
  FifoResponseData(Int32)
  FifoOccupancy(Int32)
  FifoFull(Int32)
  FifoEmpty(Int32)
  HeadLane(Int32)
  HeadState
  HeadEntry
  HeadTicket
  NextTicket
  HeadReserve
  HeadPop
  HeadCapture
  HeadIssue
  HeadFinish
  HeadReject
  HeadFence
  HeadLocalFault
  RetirementReadPointer
  RetirementWritePointer
  RetirementOccupancy
  RetirementFire
  RetirementValid
  RetirementId
  RetirementFault
  RetirementProgress
  RetirementAddress
  EntryValid(Int32)
  EntryTerminal(Int32)
  EntryTicket(Int32)
  EntryId(Int32)
  EntryFault(Int32)
  EntryProgress(Int32)
  EntryAddress(Int32)
  EntryAllocate(Int32)
  EntryAcknowledge(Int32)
  EntryLocalTerminal(Int32)
  EntryCollector(Int32, Int32)
  EngineAccept(Int32)
  EngineState(Int32)
  EngineTicket(Int32)
  EngineTerminal(Int32)
  EngineFault(Int32)
} derive(Debug, Eq)

///|
/// Immutable role, canonical node and exact ground type captured at the
/// authoritative construction seam. Resolve backend names from the emitted
/// name manifest; do not guess node ordinals or add device debug ports.
pub struct QueueConservationObservation {
  role : QueueConservationRole
  node : @ir.NodeId
  signal_type : @ir.SignalType
} derive(Debug, Eq)

///|
pub fn QueueConservationObservation::role(
  self : QueueConservationObservation,
) -> QueueConservationRole {
  self.role
}

///|
pub fn QueueConservationObservation::node(
  self : QueueConservationObservation,
) -> @ir.NodeId {
  self.node
}

///|
pub fn QueueConservationObservation::signal_type(
  self : QueueConservationObservation,
) -> @ir.SignalType {
  self.signal_type
}

///|
/// The unchanged ordinary hardware with queue conservation
/// references. Construction exports no properties or proof
/// evidence and does not alter the separate 48-role dependency fixture.
pub struct QueueConservationFixture {
  hardware : @ir.Module
  observations : ReadOnlyArray[QueueConservationObservation]
} derive(Debug, Eq)

///|
pub fn QueueConservationFixture::hardware(
  self : QueueConservationFixture,
) -> @ir.Module {
  self.hardware
}

///|
pub fn QueueConservationFixture::observations(
  self : QueueConservationFixture,
) -> ReadOnlyArray[QueueConservationObservation] {
  self.observations
}

///|
pub extend QueueConservationRole with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend QueueConservationRole with Eq::{not_equal, equal}

///|
pub extend QueueConservationObservation with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend QueueConservationObservation with Eq::{not_equal, equal}

///|
pub extend QueueConservationFixture with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend QueueConservationFixture with Eq::{not_equal, equal}
