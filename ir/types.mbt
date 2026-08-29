///|
/// Failures raised while constructing or validating canonical LunaChip IR.
pub(all) suberror IrError {
  InvalidWidth(Int)
  InvalidNodeId(Int)
  EmptyName(kind~ : String)
  DuplicateName(kind~ : String, name~ : String)
  NonSequentialNodeId(expected~ : Int, actual~ : Int)
  UnknownNodeId(Int)
  ForwardReference(node~ : Int, operand~ : Int)
  WidthMismatch(operation~ : String, expected~ : Int, actual~ : Int)
  TypeMismatch(operation~ : String)
  ExpectedClock(node~ : Int)
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
/// Canonical, elaborated node operations.
pub(all) enum NodeKind {
  Input(String)
  Constant(UInt64)
  Add(NodeId, NodeId)
  BitAnd(NodeId, NodeId)
  BitOr(NodeId, NodeId)
  BitXor(NodeId, NodeId)
  BitNot(NodeId)
  Mux(select~ : NodeId, when_true~ : NodeId, when_false~ : NodeId)
  Register(clock~ : NodeId, next~ : NodeId, initial~ : UInt64?)
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
