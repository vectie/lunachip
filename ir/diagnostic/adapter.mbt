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
fn error_code(error : @ir.IrError) -> @diagnostics.DiagnosticCode {
  match error {
    InvalidWidth(_) => InvalidWidth
    InvalidNodeId(_)
    | NonSequentialNodeId(_)
    | UnknownNodeId(_)
    | ForwardReference(_) => InvalidReference
    EmptyName(_) => InvalidName
    DuplicateName(_) => DuplicateName
    CombinationalCycle(_) => CombinationalCycle
    WidthMismatch(_) | WidthOverflow(_) => WidthMismatch
    TypeMismatch(_) | ExpectedOneBit(_) => TypeMismatch
    InvalidSliceBounds(_) => InvalidSlice
    ExpectedUnsigned(_) | ExpectedSigned(_) => InvalidSignedness
    ExpectedClock(_) => InvalidClock
    ConstantOutOfRange(_) => InvalidConstant
    MissingTopModule(_) => MissingTopModule
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
    | ExpectedOneBit(node~)
    | ExpectedUnsigned(node~, ..)
    | ExpectedSigned(node~, ..) => node_path(node)
    ForwardReference(node~, ..) => node_path(node)
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
    EmptyName(kind~) => "\{kind} name must not be empty"
    DuplicateName(kind~, name~) => "duplicate \{kind} name: \{name}"
    NonSequentialNodeId(expected~, actual~) =>
      "node ordinal \{actual} is not canonical; expected \{expected}"
    UnknownNodeId(node) => "node \{node} does not exist"
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
    ExpectedOneBit(node~) => "node \{node} must be one-bit data"
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
