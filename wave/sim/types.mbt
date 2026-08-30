///|
/// Stable failures raised while preparing or driving the reference simulator.
pub(all) suberror SimulatorError {
  CdcRejected(@cdc.CdcError)
  UnsupportedWidth(node~ : Int, width~ : Int)
  UnsupportedMemoryDepth(memory~ : String, depth~ : Int, maximum~ : Int)
  UnsupportedTotalStateCells(total~ : UInt64, maximum~ : Int)
  UnknownInput(String)
  InputWidthMismatch(name~ : String, expected~ : Int, actual~ : Int)
  UnknownNode(Int)
  UnknownOutput(String)
  UnknownClock(String)
  ExpectedClockInput(String)
  MissingRegisterUpdate(Int)
  MissingMemoryReadUpdate(node~ : Int)
  MissingMemoryUpdate(memory~ : Int)
  AsyncFifoAddressOutOfRange(primitive~ : Int, address~ : UInt64, depth~ : Int)
  UnknownMemory(String)
  MemoryAddressUnknown(
    memory~ : String,
    role~ : @ir.MemoryPortRole,
    port~ : Int
  )
  MemoryAddressOutOfRange(
    memory~ : String,
    role~ : @ir.MemoryPortRole,
    port~ : Int,
    address~ : UInt64,
    depth~ : Int
  )
  MemoryWriteCollision(
    memory~ : String,
    address~ : UInt64,
    first_port~ : Int,
    second_port~ : Int
  )
  MemoryCellOutOfRange(memory~ : String, index~ : Int, depth~ : Int)
  SnapshotDesignMismatch
  EmptyTimestampEvent
  EmptyInputDriveName
  DuplicateInputDrive(String)
  DuplicateActiveDomain(Int)
  UnknownClockDomainId(Int)
  NonMonotonicTimestamp(previous~ : UInt64, actual~ : UInt64)
  TimestampOverflow
  EventOrdinalOverflow
  DomainEdgeCountOverflow(Int)
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
  { name, value }
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
  address : Int
  value : @wave.LogicValue
}

///|
priv struct MemoryUndoEntry {
  memory : Int
  address : Int
  value : @wave.LogicValue
}

///|
struct PreparedAsyncFifo {
  index : Int
  primitive : @ir.AsyncFifoPrimitive
  lanes : Array[Array[@wave.LogicValue]]
}

///|
struct AsyncFifoReadBinding {
  fifo : Int
  leaf : Int
}

///|
struct PendingAsyncFifoWrite {
  address : Int
  values : Array[@wave.LogicValue]
}

///|
priv struct AsyncFifoUndoEntry {
  fifo : Int
  leaf : Int
  address : Int
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
  ZeroClockPeriod(domain~ : Int)
  EmptyClockSchedule
  InvalidScheduleEdgeCount(Int)
  InvalidScheduleEventLimit(Int)
  DuplicateScheduleDomain(Int)
  ScheduleEventLimitExceeded(requested~ : Int, maximum~ : Int)
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
  field? : String = "rational",
) -> RationalTicks raise ScheduleError {
  if denominator == 0UL {
    raise ZeroRationalDenominator(field~)
  }
  if numerator == 0UL {
    return { numerator: 0UL, denominator: 1UL }
  }
  let divisor = schedule_gcd(numerator, denominator)
  { numerator: numerator / divisor, denominator: denominator / divisor }
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
  edge_count : Int
} derive(Debug, Eq)

///|
pub fn ClockSchedule::checked(
  domain : @ir.ClockDomainId,
  period : RationalTicks,
  phase : RationalTicks,
  edge_count : Int,
) -> ClockSchedule raise ScheduleError {
  if period.numerator() == 0UL {
    raise ZeroClockPeriod(domain=domain.ordinal())
  }
  if edge_count <= 0 {
    raise InvalidScheduleEdgeCount(edge_count)
  }
  { domain, period, phase, edge_count }
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
pub fn ClockSchedule::edge_count(self : ClockSchedule) -> Int {
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
