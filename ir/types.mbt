///|
/// Failures raised while constructing or validating canonical LunaChip IR.
pub(all) suberror IrError {
  InvalidWidth(Int)
  WidthOverflow(operation~ : String)
  InvalidNodeId(Int)
  EmptyName(kind~ : String)
  DuplicateName(kind~ : String, name~ : String)
  NonSequentialNodeId(expected~ : Int, actual~ : Int)
  UnknownNodeId(Int)
  ForwardReference(node~ : Int, operand~ : Int)
  CombinationalCycle(Array[Int])
  WidthMismatch(operation~ : String, expected~ : Int, actual~ : Int)
  TypeMismatch(operation~ : String)
  InvalidSliceBounds(width~ : Int, msb~ : Int, lsb~ : Int)
  ExpectedUnsigned(operation~ : String, node~ : Int)
  ExpectedSigned(operation~ : String, node~ : Int)
  ExpectedClock(node~ : Int)
  ExpectedReset(node~ : Int)
  ExpectedEnable(node~ : Int)
  ExpectedOneBit(node~ : Int)
  ConstantOutOfRange(width~ : Int, value~ : UInt64)
  MissingTopModule(String)
} derive(Debug, Eq)

///|
/// A strictly positive hardware bit width.
pub struct Width(Int) derive(Debug, Eq, Compare)

///|
/// Construct a checked hardware width.
pub fn Width::new(bits : Int) -> Width raise IrError {
  if bits <= 0 {
    raise InvalidWidth(bits)
  }
  Width(bits)
}

///|
/// Return the number of bits represented by this width.
pub fn Width::bits(self : Width) -> Int {
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
pub struct NodeId(Int) derive(Debug, Eq, Compare)

///|
/// Construct a checked node identifier for low-level IR producers.
pub fn NodeId::new(ordinal : Int) -> NodeId raise IrError {
  if ordinal < 0 {
    raise InvalidNodeId(ordinal)
  }
  NodeId(ordinal)
}

///|
/// Return the stable module-local ordinal.
pub fn NodeId::ordinal(self : NodeId) -> Int {
  let NodeId(ordinal) = self
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
  clock : NodeId
  edge : ClockEdge
} derive(Debug, Eq)

///|
/// Construct the supported rising-edge clock domain.
pub fn ClockDomain::rising(clock : NodeId) -> ClockDomain {
  { clock, edge: Rising }
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
/// An optional synchronous reset control and the value committed when reset is
/// asserted. The enclosing module validates the control type and value width.
pub struct ResetSpec {
  signal : NodeId
  value : UInt64
} derive(Debug, Eq)

///|
pub fn ResetSpec::new(signal : NodeId, value : UInt64) -> ResetSpec {
  { signal, value }
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
/// Complete immutable semantics of one register.
///
/// On a rising edge, synchronous reset has highest priority, then enable, then
/// hold. `initial=None` means the simulator must initialize the state to X.
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
  { domain, next, reset, enable, initial }
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
  Slice(value~ : NodeId, msb~ : Int, lsb~ : Int)
  Concat(most_significant~ : NodeId, least_significant~ : NodeId)
  ZeroExtend(NodeId)
  SignExtend(NodeId)
  Truncate(NodeId)
  Reinterpret(NodeId)
  Mux(select~ : NodeId, when_true~ : NodeId, when_false~ : NodeId)
  Register(RegisterSpec)
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
  { id, signal_type, kind }
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
  { name, signal_type, driver }
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
