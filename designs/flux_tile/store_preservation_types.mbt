///|
pub(all) enum StorePreservationStoreField {
  State
  Slot
  Id
  Rows
  Columns
  Base
  Stride
  Row
  Column
  Tag
  ExpectedTag
  Progress
  Fault
  FaultAddress
} derive(Debug, Eq)

///|
pub(all) enum StorePreservationComputeField {
  State
  Leased
  Id
  A
  B
  C
  Rows
  Columns
  Reduction
  Fault
} derive(Debug, Eq)

///|
pub(all) enum StorePreservationSlottedField {
  State
  CaptureRow
  CaptureColumn
  Pending
  ActiveA
  ActiveB
  ActiveC
  ResponseSlot
} derive(Debug, Eq)

///|
pub(all) enum StorePreservationCoreField {
  State
  Rows
  Columns
  Reduction
  Id
  TotalSteps
  AcceptedSteps
  Fault
} derive(Debug, Eq)

///|
/// Existing original expressions, not independent event inputs or premises.
/// StoreTerminal is the controller's fault/cancellation event, not successful
/// Done. CoreFinalStep is its raw step comparison; ResponseData is SInt32.
pub(all) enum StorePreservationEvent {
  StoreAccept
  StoreActive
  StoreReadValid
  StoreRequestValid
  StoreRequestAccept
  StoreResponseGood
  StoreResponseRemote
  StoreResponseProtocol
  StoreInternalFault
  StoreCancelled
  StoreTerminal
  ComputeAccept
  ComputePreflight
  ComputeLegalAccept
  ComputeTerminal
  ComputeRelease
  CoreAccept
  CoreReady
  CoreLegal
  CoreClearing
  CoreRunning
  CoreDone
  CoreAdvance
  CoreFinalStep
  SlottedAccept
  SlottedLegalAccept
  OwnershipActive
  Capture
  FinalCapture
  ReadReady
  ReadAccept
  ResponseValid
  ResponseData
} derive(Debug, Eq)

///|
/// Purpose-specific Store/capture metadata; neither prior observation enum grows.
pub(all) enum StorePreservationRole {
  StoreRegister(StorePreservationStoreField)
  ComputeRegister(StorePreservationComputeField)
  SlottedRegister(StorePreservationSlottedField)
  CoreRegister(StorePreservationCoreField)
  ResultValid(Int)
  ResultRows(Int)
  ResultColumns(Int)
  ResponseId
  ResponseFault
  CReadData(Int)
  Event(StorePreservationEvent)
} derive(Debug, Eq)

///|
pub struct StorePreservationObservation {
  role : StorePreservationRole
  node : @ir.NodeId
  signal_type : @ir.SignalType
} derive(Debug, Eq)

///|
pub fn StorePreservationObservation::role(
  self : StorePreservationObservation,
) -> StorePreservationRole {
  self.role
}

///|
pub fn StorePreservationObservation::node(
  self : StorePreservationObservation,
) -> @ir.NodeId {
  self.node
}

///|
pub fn StorePreservationObservation::signal_type(
  self : StorePreservationObservation,
) -> @ir.SignalType {
  self.signal_type
}

///|
/// Complete original memory identity resolved from its actual read node.
pub struct StorePreservationMemory {
  slot : Int
  read_node : @ir.NodeId
  memory : @ir.MemorySpec
} derive(Debug, Eq)

///|
pub fn StorePreservationMemory::slot(self : StorePreservationMemory) -> Int {
  self.slot
}

///|
pub fn StorePreservationMemory::read_node(
  self : StorePreservationMemory,
) -> @ir.NodeId {
  self.read_node
}

///|
pub fn StorePreservationMemory::memory(
  self : StorePreservationMemory,
) -> @ir.MemorySpec {
  self.memory
}

///|
pub struct StorePreservationFixture {
  hardware : @ir.Module
  observations : ReadOnlyArray[StorePreservationObservation]
  c_memories : ReadOnlyArray[StorePreservationMemory]
} derive(Debug, Eq)

///|
pub fn StorePreservationFixture::hardware(
  self : StorePreservationFixture,
) -> @ir.Module {
  self.hardware
}

///|
pub fn StorePreservationFixture::observations(
  self : StorePreservationFixture,
) -> ReadOnlyArray[StorePreservationObservation] {
  self.observations
}

///|
pub fn StorePreservationFixture::c_memories(
  self : StorePreservationFixture,
) -> ReadOnlyArray[StorePreservationMemory] {
  self.c_memories
}

///|
pub(all) suberror StorePreservationError {
  InvalidReference(String)
} derive(Debug, Eq)
