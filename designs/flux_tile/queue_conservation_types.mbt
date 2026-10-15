///|
/// Existing-node roles for fixed direct q3 and fetched q2 queue fixtures.
/// Lane indices are 0..3, entry indices follow the fixture depth, and engine
/// indices are loader 0, compute 1, storer 2. Distinct roles may alias a node;
/// roles themselves are unique. Direct q3 has115 references; fetched q2 has102.
/// This metadata does not add hardware or establish a formal result.
pub(all) enum QueueConservationRole {
  FifoPushValid(Int)
  FifoPushReady(Int)
  FifoPopRequest(Int)
  FifoPopReady(Int)
  FifoResponseValid(Int)
  FifoResponseData(Int)
  FifoOccupancy(Int)
  FifoFull(Int)
  FifoEmpty(Int)
  HeadLane(Int)
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
  EntryValid(Int)
  EntryTerminal(Int)
  EntryTicket(Int)
  EntryId(Int)
  EntryFault(Int)
  EntryProgress(Int)
  EntryAddress(Int)
  EntryAllocate(Int)
  EntryAcknowledge(Int)
  EntryLocalTerminal(Int)
  EntryCollector(Int, Int)
  EngineAccept(Int)
  EngineState(Int)
  EngineTicket(Int)
  EngineTerminal(Int)
  EngineFault(Int)
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
/// The unchanged ordinary fixed-profile hardware with queue conservation
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
