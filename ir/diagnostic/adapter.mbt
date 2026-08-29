///|
fn node_path(
  node : Int,
) -> @diagnostics.SemanticPath raise @diagnostics.DiagnosticConstructionError {
  @diagnostics.SemanticPath::checked([Node(node)])
}

///|
fn root_path() -> @diagnostics.SemanticPath {
  @diagnostics.SemanticPath::root()
}

///|
fn memory_path(
  memory : Int,
) -> @diagnostics.SemanticPath raise @diagnostics.DiagnosticConstructionError {
  @diagnostics.SemanticPath::checked([Memory(memory)])
}

///|
fn role_name(role : @ir.MemoryPortRole) -> String {
  match role {
    ReadPort => "read"
    WritePort => "write"
  }
}

///|
fn error_code(error : @ir.IrError) -> @diagnostics.DiagnosticCode {
  match error {
    InvalidWidth(_) => InvalidWidth
    InvalidNodeId(_)
    | NonSequentialNodeId(_)
    | UnknownNodeId(_)
    | ForwardReference(_)
    | InvalidMemoryId(_)
    | InvalidMemoryPortId(_)
    | NonSequentialMemoryId(_)
    | NonSequentialMemoryPortId(_)
    | UnknownMemoryId(_)
    | UnknownMemoryReadPort(_)
    | OrphanMemoryReadNode(_) => InvalidReference
    EmptyName(_) => InvalidName
    DuplicateName(_) => DuplicateName
    CombinationalCycle(_) => CombinationalCycle
    WidthMismatch(_)
    | WidthOverflow(_)
    | MemoryAddressWidth(_)
    | MemoryMaskWidth(_)
    | MemoryMaskGranularity(_) => WidthMismatch
    TypeMismatch(_)
    | ExpectedReset(_)
    | ExpectedEnable(_)
    | ExpectedOneBit(_)
    | ExpectedMemoryAddress(_)
    | ExpectedMemoryEnable(_)
    | MemoryDataTypeMismatch(_)
    | ExpectedMemoryMask(_)
    | MemoryReadResultMismatch(_)
    | InvalidMemoryElementType(_) => TypeMismatch
    InvalidSliceBounds(_) => InvalidSlice
    ExpectedUnsigned(_) | ExpectedSigned(_) => InvalidSignedness
    ExpectedClock(_) | MemoryDomainMismatch(_) => InvalidClock
    ConstantOutOfRange(_) => InvalidConstant
    MissingTopModule(_) => MissingTopModule
    InvalidMemoryDepth(_)
    | DuplicateMemoryReadResult(_)
    | MemoryHasNoPorts(_)
    | RejectedMemoryReadWriteCollision(_)
    | RejectedStaticMultiWriteCollision(_) => InvalidMemory
  }
}

///|
fn error_path(
  error : @ir.IrError,
) -> @diagnostics.SemanticPath raise @diagnostics.DiagnosticConstructionError {
  match error {
    NonSequentialNodeId(actual~, ..) => node_path(actual)
    UnknownNodeId(node)
    | ExpectedClock(node~)
    | ExpectedReset(node~)
    | ExpectedEnable(node~)
    | ExpectedOneBit(node~)
    | ExpectedUnsigned(node~, ..)
    | ExpectedSigned(node~, ..) => node_path(node)
    ForwardReference(node~, ..) => node_path(node)
    InvalidMemoryId(memory)
    | NonSequentialMemoryId(actual=memory, ..)
    | UnknownMemoryId(memory)
    | RejectedMemoryReadWriteCollision(memory~)
    | MemoryHasNoPorts(memory~)
    | InvalidMemoryElementType(memory~) => memory_path(memory)
    InvalidMemoryPortId(ordinal~, ..) => memory_path(ordinal)
    NonSequentialMemoryPortId(memory~, ..)
    | UnknownMemoryReadPort(memory~, ..)
    | ExpectedMemoryAddress(memory~, ..)
    | MemoryAddressWidth(memory~, ..)
    | ExpectedMemoryEnable(memory~, ..)
    | MemoryDataTypeMismatch(memory~, ..)
    | MemoryMaskGranularity(memory~, ..)
    | MemoryMaskWidth(memory~, ..)
    | ExpectedMemoryMask(memory~, ..)
    | MemoryDomainMismatch(memory~, ..)
    | MemoryReadResultMismatch(memory~, ..)
    | OrphanMemoryReadNode(memory~, ..)
    | RejectedStaticMultiWriteCollision(memory~, ..) => memory_path(memory)
    DuplicateMemoryReadResult(node~) => node_path(node)
    CombinationalCycle(path) =>
      match path.get(0) {
        Some(node) => node_path(node)
        None => root_path()
      }
    _ => root_path()
  }
}

///|
fn error_message(error : @ir.IrError) -> String {
  match error {
    InvalidWidth(width) => "hardware width must be positive; received \{width}"
    InvalidNodeId(node) => "node identifier \{node} is negative"
    InvalidMemoryId(memory) => "memory identifier \{memory} is negative"
    InvalidMemoryPortId(role~, ordinal~) =>
      "\{role_name(role)} memory-port identifier \{ordinal} is negative"
    InvalidMemoryDepth(depth) =>
      "memory depth must be positive; received \{depth}"
    EmptyName(kind~) => "\{kind} name must not be empty"
    DuplicateName(kind~, name~) => "duplicate \{kind} name: \{name}"
    NonSequentialNodeId(expected~, actual~) =>
      "node ordinal \{actual} is not canonical; expected \{expected}"
    NonSequentialMemoryId(expected~, actual~) =>
      "memory ordinal \{actual} is not canonical; expected \{expected}"
    NonSequentialMemoryPortId(memory~, role~, expected~, actual~) =>
      "memory \{memory} \{role_name(role)} port ordinal \{actual} is not canonical; expected \{expected}"
    UnknownNodeId(node) => "node \{node} does not exist"
    UnknownMemoryId(memory) => "memory \{memory} does not exist"
    UnknownMemoryReadPort(memory~, port~) =>
      "memory \{memory} read port \{port} does not exist"
    ForwardReference(node~, operand~) =>
      "combinational node \{node} references later node \{operand}"
    CombinationalCycle(path) => "combinational cycle detected: \{Repr(path)}"
    WidthMismatch(operation~, expected~, actual~) =>
      "\{operation} expected width \{expected}, received \{actual}"
    WidthOverflow(operation~) =>
      "\{operation} result width overflowed the host width calculation"
    TypeMismatch(operation~) =>
      "\{operation} received an incompatible signal type"
    InvalidSliceBounds(width~, msb~, lsb~) =>
      "slice [\{msb}:\{lsb}] is outside width \{width}"
    ExpectedUnsigned(operation~, node~) =>
      "\{operation} requires unsigned node \{node}"
    ExpectedSigned(operation~, node~) =>
      "\{operation} requires signed node \{node}"
    ExpectedClock(node~) => "node \{node} is not a clock"
    ExpectedReset(node~) => "node \{node} is not a synchronous reset"
    ExpectedEnable(node~) => "node \{node} is not a one-bit enable"
    ExpectedOneBit(node~) => "node \{node} must be one-bit data"
    ExpectedMemoryAddress(memory~, role~, port~, node~) =>
      "memory \{memory} \{role_name(role)} port \{port} address node \{node} must be UInt"
    MemoryAddressWidth(memory~, role~, port~, expected~, actual~) =>
      "memory \{memory} \{role_name(role)} port \{port} address expected width \{expected}, received \{actual}"
    ExpectedMemoryEnable(memory~, role~, port~, node~) =>
      "memory \{memory} \{role_name(role)} port \{port} enable node \{node} must be one-bit data"
    MemoryDataTypeMismatch(memory~, port~) =>
      "memory \{memory} write port \{port} data type does not match its element type"
    MemoryMaskGranularity(memory~, port~, element~, granule~) =>
      "memory \{memory} write port \{port} granularity \{granule} does not divide element width \{element}"
    MemoryMaskWidth(memory~, port~, expected~, actual~) =>
      "memory \{memory} write port \{port} mask expected width \{expected}, received \{actual}"
    ExpectedMemoryMask(memory~, port~, node~) =>
      "memory \{memory} write port \{port} mask node \{node} must be Bits"
    MemoryDomainMismatch(memory~, role~, port~) =>
      "memory \{memory} \{role_name(role)} port \{port} uses a different clock domain"
    MemoryReadResultMismatch(memory~, port~, node~) =>
      "memory \{memory} read port \{port} result node \{node} has the wrong identity or type"
    DuplicateMemoryReadResult(node~) =>
      "memory read-result node \{node} is used by more than one port"
    OrphanMemoryReadNode(node~, memory~, port~) =>
      "memory-read node \{node} does not match memory \{memory} read port \{port}"
    MemoryHasNoPorts(memory~) => "memory \{memory} has no ports"
    InvalidMemoryElementType(memory~) =>
      "memory \{memory} element type must be data"
    RejectedMemoryReadWriteCollision(memory~) =>
      "memory \{memory} rejects configurations containing both read and write ports"
    RejectedStaticMultiWriteCollision(memory~, first~, second~) =>
      "memory \{memory} rejects statically identical write-port addresses \{first} and \{second}"
    ConstantOutOfRange(width~, value~) =>
      "constant \{value} does not fit width \{width}"
    MissingTopModule(name) => "top module \{name} is not present in the design"
  }
}

///|
/// Convert a checked IR construction failure into the stable LunaChip
/// diagnostic envelope without relying on enum ordinals or debug strings.
pub fn from_ir_error(
  error : @ir.IrError,
  primary_span? : @diagnostics.SourceSpan,
) -> @diagnostics.Diagnostic raise @diagnostics.DiagnosticConstructionError {
  @diagnostics.Diagnostic::checked(
    error_code(error),
    Error,
    error_message(error),
    primary_span,
    [],
    error_path(error),
    None,
  )
}
