///|
/// Stable failures raised while preparing or driving the reference simulator.
pub(all) suberror SimulatorError {
  CdcRejected(@cdc.CdcError)
  UnsupportedWidth(node~ : Int32, width~ : Int32)
  UnsupportedMemoryDepth(memory~ : String, depth~ : Int32, maximum~ : Int32)
  UnsupportedTotalStateCells(total~ : UInt64, maximum~ : Int32)
  UnknownInput(String)
  InputWidthMismatch(name~ : String, expected~ : Int32, actual~ : Int32)
  UnknownNode(Int32)
  UnknownOutput(String)
  UnknownClock(String)
  ExpectedClockInput(String)
  MissingRegisterUpdate(Int32)
  MissingMemoryReadUpdate(node~ : Int32)
  MissingMemoryUpdate(memory~ : Int32)
  AsyncFifoAddressOutOfRange(
    primitive~ : Int32,
    address~ : UInt64,
    depth~ : Int32
  )
  UnknownMemory(String)
  MemoryAddressUnknown(
    memory~ : String,
    role~ : @ir.MemoryPortRole,
    port~ : Int32
  )
  MemoryAddressOutOfRange(
    memory~ : String,
    role~ : @ir.MemoryPortRole,
    port~ : Int32,
    address~ : UInt64,
    depth~ : Int32
  )
  MemoryWriteCollision(
    memory~ : String,
    address~ : UInt64,
    first_port~ : Int32,
    second_port~ : Int32
  )
  MemoryCellOutOfRange(memory~ : String, index~ : Int32, depth~ : Int32)
  SnapshotDesignMismatch
  EmptyTimestampEvent
  EmptyInputDriveName
  DuplicateInputDrive(String)
  DuplicateActiveDomain(Int32)
  UnknownClockDomainId(Int32)
  NonMonotonicTimestamp(previous~ : UInt64, actual~ : UInt64)
  TimestampOverflow
  EventOrdinalOverflow
  DomainEdgeCountOverflow(Int32)
} derive(Debug, Eq)

///|
/// A normalized unsigned simulation timestamp.
pub struct SimulationTime(UInt64) derive(Debug, Eq, Compare)

///|
pub fn SimulationTime::zero() -> SimulationTime {
  SimulationTime(0UL)
}

///|
pub fn SimulationTime::from_uint64(value : UInt64) -> SimulationTime {
  SimulationTime(value)
}

///|
pub fn SimulationTime::value(self : SimulationTime) -> UInt64 {
  let SimulationTime(value) = self
  value
}

///|
pub fn SimulationTime::next(
  self : SimulationTime,
) -> SimulationTime raise SimulatorError {
  if self.value() == 18446744073709551615UL {
    raise TimestampOverflow
  }
  SimulationTime(self.value() + 1UL)
}

///|
/// One named input update inside an atomic timestamp event.
pub struct InputDrive {
  name : String
  value : @wave.LogicValue
} derive(Debug, Eq)

///|
pub fn InputDrive::checked(
  name : String,
  value : @wave.LogicValue,
) -> InputDrive raise SimulatorError {
  if name.is_empty() {
    raise EmptyInputDriveName
  }
  { name, value, }
}

///|
pub fn InputDrive::name(self : InputDrive) -> String {
  self.name
}

///|
pub fn InputDrive::value(self : InputDrive) -> @wave.LogicValue {
  self.value
}

///|
/// One canonical atomic state-changing event at an exact timestamp.
pub struct TimestampEvent {
  time : SimulationTime
  drives : ReadOnlyArray[InputDrive]
  active_domains : ReadOnlyArray[@ir.ClockDomainId]
} derive(Debug, Eq)

///|
pub fn TimestampEvent::checked(
  time : SimulationTime,
  declared_drives : ArrayView[InputDrive],
  declared_domains : ArrayView[@ir.ClockDomainId],
) -> TimestampEvent raise SimulatorError {
  if declared_drives.is_empty() && declared_domains.is_empty() {
    raise EmptyTimestampEvent
  }
  let drives = declared_drives.to_owned()
  drives.sort_by((left, right) => sim_compare_text(left.name(), right.name()))
  for index in 1..<drives.length() {
    if drives[index - 1].name() == drives[index].name() {
      raise DuplicateInputDrive(drives[index].name())
    }
  }
  let active_domains = declared_domains.to_owned()
  active_domains.sort_by((left, right) => left.ordinal() - right.ordinal())
  for index in 1..<active_domains.length() {
    if active_domains[index - 1] == active_domains[index] {
      raise DuplicateActiveDomain(active_domains[index].ordinal())
    }
  }
  {
    time,
    drives: ReadOnlyArray::from_array(drives),
    active_domains: ReadOnlyArray::from_array(active_domains),
  }
}

///|
/// Construct an atomic drive-only timestamp. This is the public path for
/// asynchronous-reset assertion or deassertion without a coincident edge.
pub fn TimestampEvent::drives_only(
  time : SimulationTime,
  drives : ArrayView[InputDrive],
) -> TimestampEvent raise SimulatorError {
  TimestampEvent::checked(time, drives, [])
}

///|
pub fn TimestampEvent::time(self : TimestampEvent) -> SimulationTime {
  self.time
}

///|
pub fn TimestampEvent::drives(
  self : TimestampEvent,
) -> ReadOnlyArray[InputDrive] {
  self.drives
}

///|
pub fn TimestampEvent::active_domains(
  self : TimestampEvent,
) -> ReadOnlyArray[@ir.ClockDomainId] {
  self.active_domains
}

///|
struct PendingMemoryWrite {
  address : Int32
  value : @wave.LogicValue
}

///|
priv struct MemoryUndoEntry {
  memory : Int32
  address : Int32
  value : @wave.LogicValue
}

///|
struct PreparedAsyncFifo {
  index : Int32
  primitive : @ir.AsyncFifoPrimitive
  lanes : Array[Array[@wave.LogicValue]]
}

///|
struct AsyncFifoReadBinding {
  fifo : Int32
  leaf : Int32
}

///|
struct PendingAsyncFifoWrite {
  address : Int32
  values : Array[@wave.LogicValue]
}

///|
priv struct AsyncFifoUndoEntry {
  fifo : Int32
  leaf : Int32
  address : Int32
  value : @wave.LogicValue
}

///|
/// Mutable execution state for one validated canonical module.
///
/// The canonical module and its node order are immutable. Only external input
/// slots, register slots, settled combinational slots, and the cycle counter
/// change while the simulator runs.
pub struct Simulator {
  hardware_module : @ir.Module
  values : Array[@wave.LogicValue]
  pending_state : Array[@wave.LogicValue?]
  memory_cells : Array[Array[@wave.LogicValue]]
  pending_memories : Array[Array[PendingMemoryWrite]?]
  async_fifos : Array[PreparedAsyncFifo]
  async_fifo_reads : Array[AsyncFifoReadBinding?]
  pending_async_fifos : Array[PendingAsyncFifoWrite?]
  mut cycle : @wave.CycleCounter
  mut time : SimulationTime
  mut event_ordinal : UInt64
  domain_edge_counts : Array[UInt64]
}

///|
/// An immutable in-memory checkpoint of one exact validated module instance.
/// The retained canonical module prevents restoring shape-compatible state
/// into a semantically different design.
pub struct SimulatorSnapshot {
  hardware_module : @ir.Module
  values : ReadOnlyArray[@wave.LogicValue]
  memory_cells : ReadOnlyArray[ReadOnlyArray[@wave.LogicValue]]
  async_fifo_cells : ReadOnlyArray[
    ReadOnlyArray[ReadOnlyArray[@wave.LogicValue]],
  ]
  cycle : @wave.CycleCounter
  time : SimulationTime
  event_ordinal : UInt64
  domain_edge_counts : ReadOnlyArray[UInt64]
} derive(Debug, Eq)

///|
pub fn SimulatorSnapshot::cycle(self : SimulatorSnapshot) -> @wave.CycleCounter {
  self.cycle
}

///|
pub fn SimulatorSnapshot::time(self : SimulatorSnapshot) -> SimulationTime {
  self.time
}

///|
pub fn SimulatorSnapshot::event_ordinal(self : SimulatorSnapshot) -> UInt64 {
  self.event_ordinal
}

///|
/// Exact-rational schedule construction failures.
pub(all) suberror ScheduleError {
  ZeroRationalDenominator(field~ : String)
  ZeroClockPeriod(domain~ : Int32)
  EmptyClockSchedule
  InvalidScheduleEdgeCount(Int32)
  InvalidScheduleEventLimit(Int32)
  DuplicateScheduleDomain(Int32)
  ScheduleEventLimitExceeded(requested~ : Int32, maximum~ : Int32)
  ScheduleArithmeticOverflow(operation~ : String)
} derive(Debug, Eq)

///|
/// A non-negative reduced rational number of source time units.
/// Zero has the single canonical representation `0/1`.
pub struct RationalTicks {
  numerator : UInt64
  denominator : UInt64
} derive(Debug, Eq)

///|
pub fn RationalTicks::checked(
  numerator : UInt64,
  denominator : UInt64,
  field~ : String = "rational",
) -> RationalTicks raise ScheduleError {
  if denominator == 0UL {
    raise ZeroRationalDenominator(field~)
  }
  if numerator == 0UL {
    return { numerator: 0UL, denominator: 1UL, }
  }
  let divisor = schedule_gcd(numerator, denominator)
  { numerator: numerator / divisor, denominator: denominator / divisor, }
}

///|
pub fn RationalTicks::numerator(self : RationalTicks) -> UInt64 {
  self.numerator
}

///|
pub fn RationalTicks::denominator(self : RationalTicks) -> UInt64 {
  self.denominator
}

///|
/// One finite exact-rational clock schedule.
pub struct ClockSchedule {
  domain : @ir.ClockDomainId
  period : RationalTicks
  phase : RationalTicks
  edge_count : Int32
} derive(Debug, Eq)

///|
pub fn ClockSchedule::checked(
  domain : @ir.ClockDomainId,
  period : RationalTicks,
  phase : RationalTicks,
  edge_count : Int32,
) -> ClockSchedule raise ScheduleError {
  if period.numerator() == 0UL {
    raise ZeroClockPeriod(domain=domain.ordinal())
  }
  if edge_count <= 0 {
    raise InvalidScheduleEdgeCount(edge_count)
  }
  { domain, period, phase, edge_count, }
}

///|
pub fn ClockSchedule::domain(self : ClockSchedule) -> @ir.ClockDomainId {
  self.domain
}

///|
pub fn ClockSchedule::period(self : ClockSchedule) -> RationalTicks {
  self.period
}

///|
pub fn ClockSchedule::phase(self : ClockSchedule) -> RationalTicks {
  self.phase
}

///|
pub fn ClockSchedule::edge_count(self : ClockSchedule) -> Int32 {
  self.edge_count
}

///|
/// A finite schedule normalized to one exact integer tick lattice.
pub struct NormalizedSchedule {
  ticks_per_source_unit : UInt64
  events : ReadOnlyArray[TimestampEvent]
} derive(Debug, Eq)

///|
pub fn NormalizedSchedule::ticks_per_source_unit(
  self : NormalizedSchedule,
) -> UInt64 {
  self.ticks_per_source_unit
}

///|
pub fn NormalizedSchedule::events(
  self : NormalizedSchedule,
) -> ReadOnlyArray[TimestampEvent] {
  self.events
}

///|
pub extend SimulatorError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SimulatorError with Eq::{not_equal, equal}

///|
pub extend SimulationTime with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SimulationTime with Eq::{not_equal, equal}

///|
pub extend SimulationTime with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend InputDrive with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend InputDrive with Eq::{not_equal, equal}

///|
pub extend TimestampEvent with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TimestampEvent with Eq::{not_equal, equal}

///|
pub extend SimulatorSnapshot with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SimulatorSnapshot with Eq::{not_equal, equal}

///|
pub extend ScheduleError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ScheduleError with Eq::{not_equal, equal}

///|
pub extend RationalTicks with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend RationalTicks with Eq::{not_equal, equal}

///|
pub extend ClockSchedule with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ClockSchedule with Eq::{not_equal, equal}

///|
pub extend NormalizedSchedule with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend NormalizedSchedule with Eq::{not_equal, equal}
