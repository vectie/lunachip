///|
/// A stable module-local memory identifier.
pub struct MemoryId(Int) derive(Debug, Eq, Compare)

///|
pub fn MemoryId::new(ordinal : Int) -> MemoryId raise IrError {
  if ordinal < 0 {
    raise InvalidMemoryId(ordinal)
  }
  MemoryId(ordinal)
}

///|
pub fn MemoryId::ordinal(self : MemoryId) -> Int {
  let MemoryId(ordinal) = self
  ordinal
}

///|
/// A typed memory-port role used by validation diagnostics.
pub(all) enum MemoryPortRole {
  ReadPort
  WritePort
} derive(Debug, Eq)

///|
/// A stable identifier in one memory's ordered read-port namespace.
pub struct MemoryReadPortId(Int) derive(Debug, Eq, Compare)

///|
pub fn MemoryReadPortId::new(ordinal : Int) -> MemoryReadPortId raise IrError {
  if ordinal < 0 {
    raise InvalidMemoryPortId(role=ReadPort, ordinal~)
  }
  MemoryReadPortId(ordinal)
}

///|
pub fn MemoryReadPortId::ordinal(self : MemoryReadPortId) -> Int {
  let MemoryReadPortId(ordinal) = self
  ordinal
}

///|
/// A stable identifier in one memory's ordered write-port namespace.
pub struct MemoryWritePortId(Int) derive(Debug, Eq, Compare)

///|
pub fn MemoryWritePortId::new(ordinal : Int) -> MemoryWritePortId raise IrError {
  if ordinal < 0 {
    raise InvalidMemoryPortId(role=WritePort, ordinal~)
  }
  MemoryWritePortId(ordinal)
}

///|
pub fn MemoryWritePortId::ordinal(self : MemoryWritePortId) -> Int {
  let MemoryWritePortId(ordinal) = self
  ordinal
}

///|
/// A strictly positive number of elements in a memory.
pub struct MemoryDepth(Int) derive(Debug, Eq, Compare)

///|
pub fn MemoryDepth::new(elements : Int) -> MemoryDepth raise IrError {
  if elements <= 0 {
    raise InvalidMemoryDepth(elements)
  }
  MemoryDepth(elements)
}

///|
pub fn MemoryDepth::elements(self : MemoryDepth) -> Int {
  let MemoryDepth(elements) = self
  elements
}

///|
/// The exact canonical address width, `max(1, ceil(log2(depth)))`.
pub fn MemoryDepth::address_width(self : MemoryDepth) -> Width {
  let mut value = self.elements() - 1
  let mut bits = 0
  while value > 0 {
    bits += 1
    value = value >> 1
  }
  Width(bits.max(1))
}

///|
/// Phase 4 supports exactly one registered read result per request.
pub(all) enum MemoryReadLatency {
  OneCycle
} derive(Debug, Eq)

///|
/// Behavior of the registered read result when its enable is deasserted.
pub(all) enum MemoryReadEnableBehavior {
  HoldLast
  Undefined
} derive(Debug, Eq)

///|
/// Same-edge, same-address behavior between a read and a resolved write.
/// `ReadNew` observes the result after per-granule write priority is applied.
pub(all) enum MemoryReadWritePolicy {
  ReadOld
  ReadNew
  NoChange
  Undefined
  Reject
} derive(Debug, Eq)

///|
/// Same-edge policy for two enabled writes to the same address.
/// `LowerPortIdWins` resolves each written granule independently after masks.
pub(all) enum MemoryMultiWritePolicy {
  Reject
  LowerPortIdWins
} derive(Debug, Eq)

///|
/// Runtime behavior for an address outside `[0, depth)`. `Fault` raises a
/// simulation fault and a generated property failure. `Undefined` returns X
/// for a read and suppresses a write.
pub(all) enum MemoryBoundsPolicy {
  Fault
  Undefined
} derive(Debug, Eq)

///|
/// An explicit write-mask shape. `All` writes the entire element. A granular
/// mask contains one bit per contiguous `granularity` bits of the element.
pub(all) enum MemoryWriteMask {
  All
  Granular(signal~ : NodeId, granularity~ : Width)
} derive(Debug, Eq)

///|
/// One synchronous read port. The result node is a registered state output;
/// it and all uninitialized memory cells begin unknown (X).
pub struct MemoryReadPort {
  id : MemoryReadPortId
  name : String
  domain : ClockDomain
  address : NodeId
  enable : NodeId?
  latency : MemoryReadLatency
  enable_behavior : MemoryReadEnableBehavior
  result : NodeId
} derive(Debug, Eq)

///|
pub fn MemoryReadPort::new(
  id : MemoryReadPortId,
  name : String,
  domain : ClockDomain,
  address : NodeId,
  enable? : NodeId,
  latency : MemoryReadLatency,
  enable_behavior : MemoryReadEnableBehavior,
  result : NodeId,
) -> MemoryReadPort {
  { id, name, domain, address, enable, latency, enable_behavior, result }
}

///|
pub fn MemoryReadPort::id(self : MemoryReadPort) -> MemoryReadPortId {
  self.id
}

///|
pub fn MemoryReadPort::name(self : MemoryReadPort) -> String {
  self.name
}

///|
pub fn MemoryReadPort::domain(self : MemoryReadPort) -> ClockDomain {
  self.domain
}

///|
pub fn MemoryReadPort::address(self : MemoryReadPort) -> NodeId {
  self.address
}

///|
pub fn MemoryReadPort::enable(self : MemoryReadPort) -> NodeId? {
  self.enable
}

///|
pub fn MemoryReadPort::latency(self : MemoryReadPort) -> MemoryReadLatency {
  self.latency
}

///|
pub fn MemoryReadPort::enable_behavior(
  self : MemoryReadPort,
) -> MemoryReadEnableBehavior {
  self.enable_behavior
}

///|
pub fn MemoryReadPort::result(self : MemoryReadPort) -> NodeId {
  self.result
}

///|
/// One synchronous write port.
pub struct MemoryWritePort {
  id : MemoryWritePortId
  name : String
  domain : ClockDomain
  address : NodeId
  data : NodeId
  enable : NodeId?
  mask : MemoryWriteMask
} derive(Debug, Eq)

///|
pub fn MemoryWritePort::new(
  id : MemoryWritePortId,
  name : String,
  domain : ClockDomain,
  address : NodeId,
  data : NodeId,
  enable? : NodeId,
  mask : MemoryWriteMask,
) -> MemoryWritePort {
  { id, name, domain, address, data, enable, mask }
}

///|
pub fn MemoryWritePort::id(self : MemoryWritePort) -> MemoryWritePortId {
  self.id
}

///|
pub fn MemoryWritePort::name(self : MemoryWritePort) -> String {
  self.name
}

///|
pub fn MemoryWritePort::domain(self : MemoryWritePort) -> ClockDomain {
  self.domain
}

///|
pub fn MemoryWritePort::address(self : MemoryWritePort) -> NodeId {
  self.address
}

///|
pub fn MemoryWritePort::data(self : MemoryWritePort) -> NodeId {
  self.data
}

///|
pub fn MemoryWritePort::enable(self : MemoryWritePort) -> NodeId? {
  self.enable
}

///|
pub fn MemoryWritePort::mask(self : MemoryWritePort) -> MemoryWriteMask {
  self.mask
}

///|
/// First-class canonical module state for one synchronous memory. The declared
/// domain is repeated on every port and checked for exact equality, preventing
/// accidental cross-domain memories before Phase 5.
pub struct MemorySpec {
  id : MemoryId
  name : String
  element_type : SignalType
  depth : MemoryDepth
  domain : ClockDomain
  read_ports : ReadOnlyArray[MemoryReadPort]
  write_ports : ReadOnlyArray[MemoryWritePort]
  read_write_policy : MemoryReadWritePolicy
  multi_write_policy : MemoryMultiWritePolicy
  bounds_policy : MemoryBoundsPolicy
} derive(Debug, Eq)

///|
pub fn MemorySpec::new(
  id : MemoryId,
  name : String,
  element_type : SignalType,
  depth : MemoryDepth,
  domain : ClockDomain,
  read_ports : ArrayView[MemoryReadPort],
  write_ports : ArrayView[MemoryWritePort],
  read_write_policy : MemoryReadWritePolicy,
  multi_write_policy : MemoryMultiWritePolicy,
  bounds_policy : MemoryBoundsPolicy,
) -> MemorySpec {
  {
    id,
    name,
    element_type,
    depth,
    domain,
    read_ports: ReadOnlyArray::from_array(read_ports),
    write_ports: ReadOnlyArray::from_array(write_ports),
    read_write_policy,
    multi_write_policy,
    bounds_policy,
  }
}

///|
pub fn MemorySpec::id(self : MemorySpec) -> MemoryId {
  self.id
}

///|
pub fn MemorySpec::name(self : MemorySpec) -> String {
  self.name
}

///|
pub fn MemorySpec::element_type(self : MemorySpec) -> SignalType {
  self.element_type
}

///|
pub fn MemorySpec::depth(self : MemorySpec) -> MemoryDepth {
  self.depth
}

///|
pub fn MemorySpec::domain(self : MemorySpec) -> ClockDomain {
  self.domain
}

///|
pub fn MemorySpec::read_ports(
  self : MemorySpec,
) -> ReadOnlyArray[MemoryReadPort] {
  self.read_ports
}

///|
pub fn MemorySpec::write_ports(
  self : MemorySpec,
) -> ReadOnlyArray[MemoryWritePort] {
  self.write_ports
}

///|
pub fn MemorySpec::read_write_policy(
  self : MemorySpec,
) -> MemoryReadWritePolicy {
  self.read_write_policy
}

///|
pub fn MemorySpec::multi_write_policy(
  self : MemorySpec,
) -> MemoryMultiWritePolicy {
  self.multi_write_policy
}

///|
pub fn MemorySpec::bounds_policy(self : MemorySpec) -> MemoryBoundsPolicy {
  self.bounds_policy
}
