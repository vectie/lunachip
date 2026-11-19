///|
/// Construction failures specific to the LunaWire elaboration API.
pub(all) suberror WireError {
  BuilderFinished
  ForeignSignal
  ForeignOutput
  ForeignRegister
  ForeignMemory
  ForeignClockDomain
  ForeignReset
  DuplicateDriver(String)
  UndrivenOutput(String)
  DuplicateNextDriver(Int32)
  UndrivenRegister(Int32)
  DuplicateAggregateBinding(String)
  AggregateShapeMismatch
  CdcRejected(@cdc.CdcError)
} derive(Debug, Eq)

///|
/// A typed signal handle owned by one module builder.
pub struct Signal {
  owner : Array[Unit]
  id : @ir.NodeId
  signal_type : @ir.SignalType
}

///|
pub fn Signal::id(self : Signal) -> @ir.NodeId {
  self.id
}

///|
pub fn Signal::signal_type(self : Signal) -> @ir.SignalType {
  self.signal_type
}

///|
/// Forward ready/valid direction: producer-owned `valid` and payload signals.
///
/// Construction through `ModuleBuilder::ready_valid_forward` checks exact
/// one-bit control width, aggregate shape, data-only leaves, and ownership.
pub struct ReadyValidForward {
  owner : Array[Unit]
  valid : Signal
  payload : @aggregate.Aggregate[Signal]
}

///|
pub fn ReadyValidForward::valid(self : ReadyValidForward) -> Signal {
  self.valid
}

///|
pub fn ReadyValidForward::payload(
  self : ReadyValidForward,
) -> @aggregate.Aggregate[Signal] {
  self.payload
}

///|
/// Reverse ready/valid direction: consumer-owned `ready` signal.
pub struct ReadyValidBackward {
  owner : Array[Unit]
  ready : Signal
}

///|
pub fn ReadyValidBackward::ready(self : ReadyValidBackward) -> Signal {
  self.ready
}

///|
/// The two externally visible halves of a checked one-item toggle handshake.
///
/// `source` returns ready to the producer. `destination` presents valid and a
/// separately buffered payload to the consumer.
pub struct ToggleHandshake {
  source : ReadyValidBackward
  destination : ReadyValidForward
}

///|
pub fn ToggleHandshake::source(self : ToggleHandshake) -> ReadyValidBackward {
  self.source
}

///|
pub fn ToggleHandshake::destination(
  self : ToggleHandshake,
) -> ReadyValidForward {
  self.destination
}

///|
/// The source-ready and destination-forward halves of a checked asynchronous
/// FIFO. Storage and implementation nodes remain private to the builder.
pub struct AsyncFifo {
  source : ReadyValidBackward
  destination : ReadyValidForward
}

///|
pub fn AsyncFifo::source(self : AsyncFifo) -> ReadyValidBackward {
  self.source
}

///|
pub fn AsyncFifo::destination(self : AsyncFifo) -> ReadyValidForward {
  self.destination
}

///|
/// A builder-owned explicit rising-edge clock domain.
pub struct ClockDomain {
  owner : Array[Unit]
  clock : Signal
  canonical : @ir.ClockDomain
}

///|
pub fn ClockDomain::clock(self : ClockDomain) -> Signal {
  self.clock
}

///|
pub fn ClockDomain::edge(self : ClockDomain) -> @ir.ClockEdge {
  self.canonical.edge()
}

///|
pub fn ClockDomain::id(self : ClockDomain) -> @ir.ClockDomainId {
  self.canonical.id()
}

///|
/// A builder-owned synchronous reset control and its committed reset value.
pub struct SynchronousReset {
  owner : Array[Unit]
  signal : Signal
  canonical : @ir.ResetSpec
}

///|
pub fn SynchronousReset::signal(self : SynchronousReset) -> Signal {
  self.signal
}

///|
pub fn SynchronousReset::value(self : SynchronousReset) -> UInt64 {
  self.canonical.value()
}

///|
pub fn SynchronousReset::polarity(self : SynchronousReset) -> @ir.ResetPolarity {
  self.canonical.polarity()
}

///|
pub fn SynchronousReset::mode(self : SynchronousReset) -> @ir.ResetMode {
  self.canonical.mode()
}

///|
/// A builder-owned asynchronous reset. Its distinct type prevents accidental
/// attachment through the existing synchronous-register APIs.
pub struct AsynchronousReset {
  owner : Array[Unit]
  signal : Signal
  canonical : @ir.ResetSpec
}

///|
pub fn AsynchronousReset::signal(self : AsynchronousReset) -> Signal {
  self.signal
}

///|
pub fn AsynchronousReset::value(self : AsynchronousReset) -> UInt64 {
  self.canonical.value()
}

///|
pub fn AsynchronousReset::polarity(
  self : AsynchronousReset,
) -> @ir.ResetPolarity {
  self.canonical.polarity()
}

///|
pub fn AsynchronousReset::mode(self : AsynchronousReset) -> @ir.ResetMode {
  self.canonical.mode()
}

///|
/// An output sink. It must receive exactly one driver before `finish`.
pub struct Output {
  owner : Array[Unit]
  index : Int32
  name : String
  signal_type : @ir.SignalType
}

///|
pub fn Output::name(self : Output) -> String {
  self.name
}

///|
pub fn Output::signal_type(self : Output) -> @ir.SignalType {
  self.signal_type
}

///|
/// A declared register whose value exists before its next-state logic.
pub struct RegisterHandle {
  owner : Array[Unit]
  index : Int32
  value : Signal
  domain : @ir.ClockDomain
  reset : @ir.ResetSpec?
  enable : @ir.NodeId?
  initial : UInt64?
}

///|
/// Return the register's old committed value signal.
pub fn RegisterHandle::value(self : RegisterHandle) -> Signal {
  self.value
}

///|
/// A builder-owned synchronous memory declaration.
///
/// Ports are added through the owning `ModuleBuilder`; the handle cannot be
/// used with another builder.
pub struct Memory {
  owner : Array[Unit]
  index : Int32
  id : @ir.MemoryId
  element_type : @ir.SignalType
  depth : @ir.MemoryDepth
}

///|
pub fn Memory::id(self : Memory) -> @ir.MemoryId {
  self.id
}

///|
pub fn Memory::element_type(self : Memory) -> @ir.SignalType {
  self.element_type
}

///|
pub fn Memory::depth(self : Memory) -> @ir.MemoryDepth {
  self.depth
}

///|
struct MemoryDeclaration {
  id : @ir.MemoryId
  name : String
  element_type : @ir.SignalType
  depth : @ir.MemoryDepth
  domain : ClockDomain
  read_write_policy : @ir.MemoryReadWritePolicy
  multi_write_policy : @ir.MemoryMultiWritePolicy
  bounds_policy : @ir.MemoryBoundsPolicy
  read_ports : Array[@ir.MemoryReadPort]
  write_ports : Array[@ir.MemoryWritePort]
}

///|
/// Stateful elaboration context for one module. Canonical order is call order.
pub struct ModuleBuilder {
  name : String
  owner : Array[Unit]
  nodes : Array[@ir.Node]
  outputs : Array[Output]
  drivers : Array[@ir.NodeId?]
  registers : Array[RegisterHandle]
  next_drivers : Array[@ir.NodeId?]
  memories : Array[MemoryDeclaration]
  domains : Array[ClockDomain]
  parameters : Array[@ir.ModuleParameter]
  aggregate_bindings : Array[@ir.AggregateBinding]
  input_timings : Array[@ir.InputTimingBinding]
  output_timings : Array[@ir.OutputTimingBinding]
  cdc_primitives : Array[@ir.CdcPrimitive]
  mut finished : Bool
}

///|
pub extend WireError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend WireError with Eq::{not_equal, equal}
