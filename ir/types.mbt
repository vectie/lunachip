///|
/// Failures raised while constructing or validating canonical LunaChip IR.
pub(all) suberror IrError {
  InvalidWidth(Int32)
  WidthOverflow(operation~ : String)
  InvalidNodeId(Int32)
  InvalidClockDomainId(Int32)
  NonCanonicalClockDomainId(expected~ : Int32, actual~ : Int32)
  ClockDomainIdCollision(
    id~ : Int32,
    first_clock~ : Int32,
    second_clock~ : Int32
  )
  UnknownClockDomainId(Int32)
  DuplicateInputTiming(input~ : Int32)
  DuplicateOutputTiming(String)
  UnknownInputTimingNode(Int32)
  InputTimingOnNonInput(Int32)
  InputTimingOnClock(Int32)
  UnknownInputTimingDomain(input~ : Int32, domain~ : Int32)
  MissingInputTiming(Int32)
  UnknownTimedOutput(String)
  OutputTimingOnClock(String)
  UnknownOutputTimingDomain(output~ : String, domain~ : Int32)
  MissingOutputTiming(String)
  InvalidAggregateBindingId(Int32)
  NonSequentialAggregateBindingId(expected~ : Int32, actual~ : Int32)
  AggregateDepthLimitExceeded(
    binding~ : Int32,
    maximum~ : Int32,
    actual~ : Int32
  )
  AggregateLeafLimitExceeded(
    binding~ : Int32,
    maximum~ : Int32,
    minimum~ : Int32
  )
  HeterogeneousAggregateVector(binding~ : Int32, depth~ : Int32, index~ : Int32)
  AggregateEndpointCountMismatch(
    binding~ : Int32,
    expected~ : Int32,
    actual~ : Int32
  )
  DuplicateAggregateNodeEndpoint(node~ : Int32)
  DuplicateAggregateOutputEndpoint(String)
  UnknownAggregateEndpointNode(binding~ : Int32, leaf~ : Int32, node~ : Int32)
  UnknownAggregateEndpointOutput(
    binding~ : Int32,
    leaf~ : Int32,
    output~ : String
  )
  AggregateEndpointRoleMismatch(
    binding~ : Int32,
    leaf~ : Int32,
    kind~ : AggregateBindingKind
  )
  AggregateEndpointTypeMismatch(
    binding~ : Int32,
    leaf~ : Int32,
    expected~ : SignalType,
    actual~ : SignalType
  )
  InvalidCdcPrimitiveId(Int32)
  CdcPrimitiveLimitExceeded(maximum~ : Int32, actual~ : Int32)
  NonSequentialCdcPrimitiveId(expected~ : Int32, actual~ : Int32)
  InvalidBitSynchronizerStageCount(primitive~ : Int32, actual~ : Int32)
  DuplicateCdcPrimitiveName(String)
  DuplicateCdcPrimitiveStage(node~ : Int32)
  CdcPrimitiveSourceIsStage(primitive~ : Int32, node~ : Int32)
  UnknownCdcPrimitiveSourceNode(primitive~ : Int32, node~ : Int32)
  InvalidCdcPrimitiveSourceType(primitive~ : Int32, node~ : Int32)
  UnknownCdcPrimitiveDomain(primitive~ : Int32, domain~ : Int32)
  EqualCdcPrimitiveDomains(primitive~ : Int32, domain~ : Int32)
  UnknownCdcPrimitiveStageNode(
    primitive~ : Int32,
    stage~ : Int32,
    node~ : Int32
  )
  InvalidCdcPrimitiveStageType(
    primitive~ : Int32,
    stage~ : Int32,
    node~ : Int32
  )
  InvalidCdcPrimitiveStageKind(
    primitive~ : Int32,
    stage~ : Int32,
    node~ : Int32
  )
  CdcPrimitiveStageDomainMismatch(
    primitive~ : Int32,
    stage~ : Int32,
    expected~ : Int32,
    actual~ : Int32
  )
  CdcPrimitiveStageNextMismatch(
    primitive~ : Int32,
    stage~ : Int32,
    expected~ : Int32,
    actual~ : Int32
  )
  CdcPrimitiveStageHasEnable(primitive~ : Int32, stage~ : Int32, node~ : Int32)
  CdcPrimitiveStageResetMismatch(
    primitive~ : Int32,
    stage~ : Int32,
    node~ : Int32
  )
  CdcPrimitiveIntermediateFanout(
    primitive~ : Int32,
    stage~ : Int32,
    node~ : Int32,
    consumer~ : String
  )
  InvalidToggleHandshakeStageCount(primitive~ : Int32, actual~ : Int32)
  EqualToggleHandshakeDomains(primitive~ : Int32, domain~ : Int32)
  UnknownToggleHandshakeDomain(
    primitive~ : Int32,
    role~ : String,
    domain~ : Int32
  )
  ToggleHandshakePayloadCountMismatch(
    primitive~ : Int32,
    expected~ : Int32,
    source~ : Int32,
    held~ : Int32,
    destination~ : Int32
  )
  ToggleHandshakeDuplicateNode(primitive~ : Int32, node~ : Int32)
  UnknownToggleHandshakeNode(primitive~ : Int32, role~ : String, node~ : Int32)
  ToggleHandshakeNodeTypeMismatch(
    primitive~ : Int32,
    role~ : String,
    node~ : Int32
  )
  ToggleHandshakeStructureMismatch(primitive~ : Int32, role~ : String)
  ToggleHandshakeResetMismatch(
    primitive~ : Int32,
    role~ : String,
    node~ : Int32
  )
  ToggleHandshakeHiddenFanout(
    primitive~ : Int32,
    role~ : String,
    node~ : Int32,
    consumer~ : String
  )
  InvalidAsyncFifoDepth(primitive~ : Int32, actual~ : Int32)
  InvalidAsyncFifoStageCount(primitive~ : Int32, actual~ : Int32)
  EqualAsyncFifoDomains(primitive~ : Int32, domain~ : Int32)
  UnknownAsyncFifoDomain(primitive~ : Int32, role~ : String, domain~ : Int32)
  AsyncFifoPayloadCountMismatch(
    primitive~ : Int32,
    expected~ : Int32,
    source~ : Int32,
    raw~ : Int32,
    visible~ : Int32
  )
  AsyncFifoPayloadWidth(primitive~ : Int32, actual~ : Int32)
  AsyncFifoDuplicateNode(primitive~ : Int32, node~ : Int32)
  UnknownAsyncFifoNode(primitive~ : Int32, role~ : String, node~ : Int32)
  AsyncFifoNodeTypeMismatch(primitive~ : Int32, role~ : String, node~ : Int32)
  AsyncFifoStructureMismatch(primitive~ : Int32, role~ : String)
  AsyncFifoResetMismatch(primitive~ : Int32, role~ : String, node~ : Int32)
  AsyncFifoHiddenFanout(
    primitive~ : Int32,
    role~ : String,
    node~ : Int32,
    consumer~ : String
  )
  InvalidMemoryId(Int32)
  InvalidMemoryPortId(role~ : MemoryPortRole, ordinal~ : Int32)
  InvalidMemoryDepth(Int32)
  EmptyName(kind~ : String)
  DuplicateName(kind~ : String, name~ : String)
  NonSequentialNodeId(expected~ : Int32, actual~ : Int32)
  NonSequentialMemoryId(expected~ : Int32, actual~ : Int32)
  NonSequentialMemoryPortId(
    memory~ : Int32,
    role~ : MemoryPortRole,
    expected~ : Int32,
    actual~ : Int32
  )
  UnknownNodeId(Int32)
  UnknownMemoryId(Int32)
  UnknownMemoryReadPort(memory~ : Int32, port~ : Int32)
  ForwardReference(node~ : Int32, operand~ : Int32)
  CombinationalCycle(Array[Int32])
  WidthMismatch(operation~ : String, expected~ : Int32, actual~ : Int32)
  TypeMismatch(operation~ : String)
  InvalidSliceBounds(width~ : Int32, msb~ : Int32, lsb~ : Int32)
  ExpectedUnsigned(operation~ : String, node~ : Int32)
  ExpectedSigned(operation~ : String, node~ : Int32)
  ExpectedClock(node~ : Int32)
  ExpectedReset(node~ : Int32)
  ExpectedEnable(node~ : Int32)
  UnsupportedAsynchronousReset(node~ : Int32)
  UnsupportedResetPolarity(node~ : Int32)
  ExpectedOneBit(node~ : Int32)
  ExpectedMemoryAddress(
    memory~ : Int32,
    role~ : MemoryPortRole,
    port~ : Int32,
    node~ : Int32
  )
  MemoryAddressWidth(
    memory~ : Int32,
    role~ : MemoryPortRole,
    port~ : Int32,
    expected~ : Int32,
    actual~ : Int32
  )
  ExpectedMemoryEnable(
    memory~ : Int32,
    role~ : MemoryPortRole,
    port~ : Int32,
    node~ : Int32
  )
  MemoryDataTypeMismatch(memory~ : Int32, port~ : Int32)
  MemoryMaskGranularity(
    memory~ : Int32,
    port~ : Int32,
    element~ : Int32,
    granule~ : Int32
  )
  MemoryMaskWidth(
    memory~ : Int32,
    port~ : Int32,
    expected~ : Int32,
    actual~ : Int32
  )
  ExpectedMemoryMask(memory~ : Int32, port~ : Int32, node~ : Int32)
  MemoryDomainMismatch(memory~ : Int32, role~ : MemoryPortRole, port~ : Int32)
  MemoryReadResultMismatch(memory~ : Int32, port~ : Int32, node~ : Int32)
  DuplicateMemoryReadResult(node~ : Int32)
  OrphanMemoryReadNode(node~ : Int32, memory~ : Int32, port~ : Int32)
  MemoryHasNoPorts(memory~ : Int32)
  InvalidMemoryElementType(memory~ : Int32)
  RejectedMemoryReadWriteCollision(memory~ : Int32)
  RejectedStaticMultiWriteCollision(
    memory~ : Int32,
    first~ : Int32,
    second~ : Int32
  )
  ConstantOutOfRange(width~ : Int32, value~ : UInt64)
  MissingTopModule(String)
} derive(Debug, Eq)

///|
/// A strictly positive hardware bit width.
pub struct Width(Int32) derive(Debug, Eq, Compare)

///|
/// Construct a checked hardware width.
pub fn Width::new(bits : Int32) -> Width raise IrError {
  if bits <= 0 {
    raise InvalidWidth(bits)
  }
  Width(bits)
}

///|
/// Return the number of bits represented by this width.
pub fn Width::bits(self : Width) -> Int32 {
  let Width(bits) = self
  bits
}

///|
/// Canonical signal types. Clock is intentionally distinct from one-bit data.
pub(all) enum SignalType {
  Clock
  Reset
  Bits(Width)
  UInt(Width)
  SInt(Width)
} derive(Debug, Eq)

///|
/// Return the physical bit width of a signal type.
pub fn SignalType::width(self : SignalType) -> Width {
  match self {
    Clock | Reset => Width(1)
    Bits(width) | UInt(width) | SInt(width) => width
  }
}

///|
/// True only for the dedicated clock type.
pub fn SignalType::is_clock(self : SignalType) -> Bool {
  self is Clock
}

///|
/// True for data values that may participate in arithmetic and bitwise nodes.
pub fn SignalType::is_data(self : SignalType) -> Bool {
  match self {
    Bits(_) | UInt(_) | SInt(_) => true
    Clock | Reset => false
  }
}

///|
/// True for signed or unsigned values with arithmetic interpretation.
pub fn SignalType::is_numeric(self : SignalType) -> Bool {
  match self {
    UInt(_) | SInt(_) => true
    Clock | Reset | Bits(_) => false
  }
}

///|
/// A module-local node identifier. Ordinals are stable construction order.
pub struct NodeId(Int32) derive(Debug, Eq, Compare)

///|
/// Construct a checked node identifier for low-level IR producers.
pub fn NodeId::new(ordinal : Int32) -> NodeId raise IrError {
  if ordinal < 0 {
    raise InvalidNodeId(ordinal)
  }
  NodeId(ordinal)
}

///|
/// Return the stable module-local ordinal.
pub fn NodeId::ordinal(self : NodeId) -> Int32 {
  let NodeId(ordinal) = self
  ordinal
}

///|
/// A stable module-local clock-domain identifier.
///
/// For the rising-edge-only schema-4 foundation the canonical identifier is
/// the clock node ordinal. This makes legacy migration and independently
/// elaborated domain interning converge without depending on map iteration or
/// the order in which a builder requests domain handles.
pub struct ClockDomainId(Int32) derive(Debug, Eq, Compare)

///|
/// Construct a checked clock-domain identifier for low-level IR producers.
pub fn ClockDomainId::new(ordinal : Int32) -> ClockDomainId raise IrError {
  if ordinal < 0 {
    raise InvalidClockDomainId(ordinal)
  }
  ClockDomainId(ordinal)
}

///|
/// Return the stable module-local ordinal.
pub fn ClockDomainId::ordinal(self : ClockDomainId) -> Int32 {
  let ClockDomainId(ordinal) = self
  ordinal
}

///|
/// Edge semantics for a sequential clock domain.
///
/// Phase 2 intentionally supports only rising-edge state. Keeping the edge in
/// the canonical IR prevents a future backend from inferring it ambiently.
pub(all) enum ClockEdge {
  Rising
} derive(Debug, Eq)

///|
/// An explicit sequential clock domain. Domain identity is the clock node and
/// edge together; there is no process-wide or builder-wide default clock.
pub struct ClockDomain {
  id : ClockDomainId
  clock : NodeId
  edge : ClockEdge
} derive(Debug, Eq)

///|
/// Construct the supported rising-edge clock domain.
pub fn ClockDomain::rising(clock : NodeId) -> ClockDomain {
  { id: ClockDomainId(clock.ordinal()), clock, edge: Rising, }
}

///|
/// Construct an explicit low-level domain definition. `Module::checked*`
/// verifies that its identifier is canonical and that its clock is valid.
pub fn ClockDomain::new(
  id : ClockDomainId,
  clock : NodeId,
  edge : ClockEdge,
) -> ClockDomain {
  { id, clock, edge, }
}

///|
pub fn ClockDomain::id(self : ClockDomain) -> ClockDomainId {
  self.id
}

///|
pub fn ClockDomain::clock(self : ClockDomain) -> NodeId {
  self.clock
}

///|
pub fn ClockDomain::edge(self : ClockDomain) -> ClockEdge {
  self.edge
}

///|
/// Whether a reset is sampled on a clock edge or acts independently of it.
pub(all) enum ResetMode {
  Synchronous
  Asynchronous
} derive(Debug, Eq)

///|
/// The logic level that asserts a reset control.
pub(all) enum ResetPolarity {
  ActiveHigh
  ActiveLow
} derive(Debug, Eq)

///|
/// An explicit reset control and the value committed when it is asserted.
/// The enclosing module validates the control type and value width. Schema 4
/// supports every explicit mode/polarity pair.
pub struct ResetSpec {
  signal : NodeId
  value : UInt64
  mode : ResetMode
  polarity : ResetPolarity
} derive(Debug, Eq)

///|
pub fn ResetSpec::new(signal : NodeId, value : UInt64) -> ResetSpec {
  { signal, value, mode: Synchronous, polarity: ActiveHigh, }
}

///|
/// Construct a reset with fully explicit mode and polarity.
pub fn ResetSpec::explicit(
  signal : NodeId,
  value : UInt64,
  mode : ResetMode,
  polarity : ResetPolarity,
) -> ResetSpec {
  { signal, value, mode, polarity, }
}

///|
pub fn ResetSpec::signal(self : ResetSpec) -> NodeId {
  self.signal
}

///|
pub fn ResetSpec::value(self : ResetSpec) -> UInt64 {
  self.value
}

///|
pub fn ResetSpec::mode(self : ResetSpec) -> ResetMode {
  self.mode
}

///|
pub fn ResetSpec::polarity(self : ResetSpec) -> ResetPolarity {
  self.polarity
}

///|
/// Complete immutable semantics of one register.
///
/// On a rising edge, reset has highest priority, then enable, then hold.
/// Asynchronous mode additionally acts independently of an edge.
/// `initial=None` means the simulator must initialize the state to X.
pub struct RegisterSpec {
  domain : ClockDomain
  next : NodeId
  reset : ResetSpec?
  enable : NodeId?
  initial : UInt64?
} derive(Debug, Eq)

///|
/// The architectural action selected for a register on its active edge.
pub(all) enum RegisterAction {
  LoadReset
  LoadNext
  Hold
} derive(Debug, Eq)

///|
pub fn RegisterSpec::new(
  domain : ClockDomain,
  next : NodeId,
  reset? : ResetSpec,
  enable? : NodeId,
  initial? : UInt64,
) -> RegisterSpec {
  { domain, next, reset, enable, initial, }
}

///|
pub fn RegisterSpec::domain(self : RegisterSpec) -> ClockDomain {
  self.domain
}

///|
pub fn RegisterSpec::next(self : RegisterSpec) -> NodeId {
  self.next
}

///|
pub fn RegisterSpec::reset(self : RegisterSpec) -> ResetSpec? {
  self.reset
}

///|
pub fn RegisterSpec::enable(self : RegisterSpec) -> NodeId? {
  self.enable
}

///|
pub fn RegisterSpec::initial(self : RegisterSpec) -> UInt64? {
  self.initial
}

///|
/// Resolve the known-control transition priority for this register.
///
/// An absent reset is treated as deasserted. An absent enable means the next
/// value is loaded on every active edge.
pub fn RegisterSpec::action(
  self : RegisterSpec,
  reset_asserted : Bool,
  enable_asserted : Bool,
) -> RegisterAction {
  if self.reset is Some(_) && reset_asserted {
    LoadReset
  } else if self.enable is None || enable_asserted {
    LoadNext
  } else {
    Hold
  }
}

///|
/// Canonical, elaborated node operations.
pub(all) enum NodeKind {
  Input(String)
  Constant(UInt64)
  Add(NodeId, NodeId)
  Sub(NodeId, NodeId)
  MulLow(NodeId, NodeId)
  MulFull(NodeId, NodeId)
  BitAnd(NodeId, NodeId)
  BitOr(NodeId, NodeId)
  BitXor(NodeId, NodeId)
  BitNot(NodeId)
  Equal(NodeId, NodeId)
  LessThan(NodeId, NodeId)
  LessEqual(NodeId, NodeId)
  ShiftLeft(value~ : NodeId, amount~ : NodeId)
  LogicalShiftRight(value~ : NodeId, amount~ : NodeId)
  ArithmeticShiftRight(value~ : NodeId, amount~ : NodeId)
  Slice(value~ : NodeId, msb~ : Int32, lsb~ : Int32)
  Concat(most_significant~ : NodeId, least_significant~ : NodeId)
  ZeroExtend(NodeId)
  SignExtend(NodeId)
  Truncate(NodeId)
  Reinterpret(NodeId)
  Mux(select~ : NodeId, when_true~ : NodeId, when_false~ : NodeId)
  Register(RegisterSpec)
  MemoryRead(memory~ : MemoryId, port~ : MemoryReadPortId)
  AsyncFifoRead(primitive~ : CdcPrimitiveId, leaf~ : Int32)
} derive(Debug, Eq)

///|
/// A typed canonical IR node.
pub struct Node {
  id : NodeId
  signal_type : SignalType
  kind : NodeKind
} derive(Debug, Eq)

///|
/// Construct a low-level node. `Module::checked` validates all invariants.
pub fn Node::new(
  id : NodeId,
  signal_type : SignalType,
  kind : NodeKind,
) -> Node {
  { id, signal_type, kind, }
}

///|
pub fn Node::id(self : Node) -> NodeId {
  self.id
}

///|
pub fn Node::signal_type(self : Node) -> SignalType {
  self.signal_type
}

///|
pub fn Node::kind(self : Node) -> NodeKind {
  self.kind
}

///|
/// A named output with exactly one canonical driver.
pub struct OutputPort {
  name : String
  signal_type : SignalType
  driver : NodeId
} derive(Debug, Eq)

///|
/// Construct a low-level output. `Module::checked` validates its driver.
pub fn OutputPort::new(
  name : String,
  signal_type : SignalType,
  driver : NodeId,
) -> OutputPort {
  { name, signal_type, driver, }
}

///|
pub fn OutputPort::name(self : OutputPort) -> String {
  self.name
}

///|
pub fn OutputPort::signal_type(self : OutputPort) -> SignalType {
  self.signal_type
}

///|
pub fn OutputPort::driver(self : OutputPort) -> NodeId {
  self.driver
}

///|
pub extend IrError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend IrError with Eq::{not_equal, equal}

///|
pub extend Width with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Width with Eq::{not_equal, equal}

///|
pub extend Width with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend SignalType with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SignalType with Eq::{not_equal, equal}

///|
pub extend NodeId with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend NodeId with Eq::{not_equal, equal}

///|
pub extend NodeId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend ClockDomainId with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ClockDomainId with Eq::{not_equal, equal}

///|
pub extend ClockDomainId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend ClockEdge with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ClockEdge with Eq::{not_equal, equal}

///|
pub extend ClockDomain with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ClockDomain with Eq::{not_equal, equal}

///|
pub extend ResetMode with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ResetMode with Eq::{not_equal, equal}

///|
pub extend ResetPolarity with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ResetPolarity with Eq::{not_equal, equal}

///|
pub extend ResetSpec with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ResetSpec with Eq::{not_equal, equal}

///|
pub extend RegisterSpec with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend RegisterSpec with Eq::{not_equal, equal}

///|
pub extend RegisterAction with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend RegisterAction with Eq::{not_equal, equal}

///|
pub extend NodeKind with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend NodeKind with Eq::{not_equal, equal}

///|
pub extend Node with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Node with Eq::{not_equal, equal}

///|
pub extend OutputPort with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend OutputPort with Eq::{not_equal, equal}
