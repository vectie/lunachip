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
    | InvalidClockDomainId(_)
    | NonCanonicalClockDomainId(_)
    | ClockDomainIdCollision(_)
    | UnknownClockDomainId(_)
    | InvalidAggregateBindingId(_)
    | NonSequentialAggregateBindingId(_)
    | InvalidCdcPrimitiveId(_)
    | NonSequentialCdcPrimitiveId(_)
    | CdcPrimitiveSourceIsStage(_)
    | DuplicateCdcPrimitiveStage(_)
    | ToggleHandshakeDuplicateNode(_)
    | AsyncFifoDuplicateNode(_)
    | UnknownCdcPrimitiveSourceNode(_)
    | UnknownCdcPrimitiveDomain(_)
    | UnknownCdcPrimitiveStageNode(_)
    | UnknownToggleHandshakeDomain(_)
    | UnknownToggleHandshakeNode(_)
    | UnknownAsyncFifoDomain(_)
    | UnknownAsyncFifoNode(_)
    | UnknownAggregateEndpointNode(_)
    | UnknownAggregateEndpointOutput(_)
    | DuplicateAggregateNodeEndpoint(_)
    | DuplicateAggregateOutputEndpoint(_)
    | UnknownInputTimingNode(_)
    | UnknownInputTimingDomain(_)
    | MissingInputTiming(_)
    | UnknownTimedOutput(_)
    | UnknownOutputTimingDomain(_)
    | MissingOutputTiming(_)
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
    DuplicateName(_)
    | DuplicateInputTiming(_)
    | DuplicateOutputTiming(_)
    | DuplicateCdcPrimitiveName(_) => DuplicateName
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
    | InvalidMemoryElementType(_)
    | InputTimingOnNonInput(_)
    | InputTimingOnClock(_)
    | OutputTimingOnClock(_) => TypeMismatch
    AggregateEndpointCountMismatch(_)
    | HeterogeneousAggregateVector(_)
    | AggregateEndpointRoleMismatch(_)
    | AggregateEndpointTypeMismatch(_)
    | InvalidCdcPrimitiveSourceType(_)
    | InvalidCdcPrimitiveStageType(_)
    | InvalidCdcPrimitiveStageKind(_)
    | CdcPrimitiveStageNextMismatch(_)
    | CdcPrimitiveStageHasEnable(_)
    | CdcPrimitiveStageResetMismatch(_)
    | CdcPrimitiveIntermediateFanout(_)
    | ToggleHandshakePayloadCountMismatch(_)
    | ToggleHandshakeNodeTypeMismatch(_)
    | ToggleHandshakeStructureMismatch(_)
    | ToggleHandshakeResetMismatch(_)
    | ToggleHandshakeHiddenFanout(_)
    | AsyncFifoPayloadCountMismatch(_)
    | AsyncFifoPayloadWidth(_)
    | AsyncFifoNodeTypeMismatch(_)
    | AsyncFifoStructureMismatch(_)
    | AsyncFifoResetMismatch(_)
    | AsyncFifoHiddenFanout(_) => TypeMismatch
    InvalidSliceBounds(_) => InvalidSlice
    ExpectedUnsigned(_) | ExpectedSigned(_) => InvalidSignedness
    ExpectedClock(_)
    | MemoryDomainMismatch(_)
    | EqualCdcPrimitiveDomains(_)
    | EqualToggleHandshakeDomains(_)
    | EqualAsyncFifoDomains(_)
    | CdcPrimitiveStageDomainMismatch(_) => InvalidClock
    ConstantOutOfRange(_) => InvalidConstant
    MissingTopModule(_) => MissingTopModule
    UnsupportedAsynchronousReset(_) | UnsupportedResetPolarity(_) =>
      UnsupportedFeature
    AggregateDepthLimitExceeded(_)
    | AggregateLeafLimitExceeded(_)
    | CdcPrimitiveLimitExceeded(_)
    | InvalidBitSynchronizerStageCount(_)
    | InvalidToggleHandshakeStageCount(_)
    | InvalidAsyncFifoStageCount(_) => UnsupportedFeature
    InvalidMemoryDepth(_)
    | InvalidAsyncFifoDepth(_)
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
    UnsupportedAsynchronousReset(node~) | UnsupportedResetPolarity(node~) =>
      node_path(node)
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
    UnknownAggregateEndpointNode(node~, ..)
    | DuplicateAggregateNodeEndpoint(node~)
    | UnknownInputTimingNode(node)
    | InputTimingOnNonInput(node)
    | InputTimingOnClock(node)
    | UnknownInputTimingDomain(input=node, ..)
    | MissingInputTiming(node) => node_path(node)
    ToggleHandshakeDuplicateNode(node~, ..)
    | UnknownToggleHandshakeNode(node~, ..)
    | ToggleHandshakeNodeTypeMismatch(node~, ..)
    | ToggleHandshakeResetMismatch(node~, ..)
    | ToggleHandshakeHiddenFanout(node~, ..) => node_path(node)
    AsyncFifoDuplicateNode(node~, ..)
    | UnknownAsyncFifoNode(node~, ..)
    | AsyncFifoNodeTypeMismatch(node~, ..)
    | AsyncFifoResetMismatch(node~, ..)
    | AsyncFifoHiddenFanout(node~, ..) => node_path(node)
    UnknownToggleHandshakeDomain(role~, ..) =>
      @diagnostics.SemanticPath::checked([
        Operation("toggle_handshake"),
        Field(role),
      ])
    UnknownAsyncFifoDomain(role~, ..) =>
      @diagnostics.SemanticPath::checked([
        Operation("asynchronous_fifo"),
        Field(role),
      ])
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
    InvalidClockDomainId(domain) =>
      "clock-domain identifier \{domain} is negative"
    NonCanonicalClockDomainId(expected~, actual~) =>
      "clock-domain identifier \{actual} is not canonical; expected \{expected}"
    ClockDomainIdCollision(id~, first_clock~, second_clock~) =>
      "clock-domain identifier \{id} aliases clock nodes \{first_clock} and \{second_clock}"
    UnknownClockDomainId(domain) =>
      "clock-domain identifier \{domain} is not declared by the module"
    DuplicateInputTiming(input~) =>
      "input node \{input} has more than one timing declaration"
    DuplicateOutputTiming(output) =>
      "output \{output} has more than one timing declaration"
    UnknownInputTimingNode(input) => "timed input node \{input} does not exist"
    InputTimingOnNonInput(input) =>
      "timing declaration node \{input} is not an input"
    InputTimingOnClock(input) =>
      "clock input node \{input} is represented by its domain, not port timing"
    UnknownInputTimingDomain(input~, domain~) =>
      "input node \{input} references unknown clock domain \{domain}"
    MissingInputTiming(input) =>
      "input node \{input} is missing required timing metadata"
    UnknownTimedOutput(output) =>
      "timing declaration references unknown output \{output}"
    OutputTimingOnClock(output) =>
      "clock output \{output} cannot carry data-port timing metadata"
    UnknownOutputTimingDomain(output~, domain~) =>
      "output \{output} references unknown clock domain \{domain}"
    MissingOutputTiming(output) =>
      "output \{output} is missing required timing metadata"
    InvalidAggregateBindingId(binding) =>
      "aggregate binding identifier \{binding} is negative"
    NonSequentialAggregateBindingId(expected~, actual~) =>
      "aggregate binding ordinal \{actual} is not canonical; expected \{expected}"
    AggregateDepthLimitExceeded(binding~, maximum~, actual~) =>
      "aggregate binding \{binding} depth \{actual} exceeds limit \{maximum}"
    AggregateLeafLimitExceeded(binding~, maximum~, minimum~) =>
      "aggregate binding \{binding} has at least \{minimum} leaves, exceeding limit \{maximum}"
    HeterogeneousAggregateVector(binding~, depth~, index~) =>
      "aggregate binding \{binding} vector at depth \{depth} has nonuniform element \{index}"
    AggregateEndpointCountMismatch(binding~, expected~, actual~) =>
      "aggregate binding \{binding} expected \{expected} endpoints, received \{actual}"
    DuplicateAggregateNodeEndpoint(node~) =>
      "aggregate node endpoint \{node} has more than one owner"
    DuplicateAggregateOutputEndpoint(output) =>
      "aggregate output endpoint \{output} has more than one owner"
    UnknownAggregateEndpointNode(binding~, leaf~, node~) =>
      "aggregate binding \{binding} leaf \{leaf} references missing node \{node}"
    UnknownAggregateEndpointOutput(binding~, leaf~, output~) =>
      "aggregate binding \{binding} leaf \{leaf} references missing output \{output}"
    AggregateEndpointRoleMismatch(binding~, leaf~, kind~) =>
      "aggregate binding \{binding} leaf \{leaf} has an endpoint incompatible with \{Repr(kind)}"
    AggregateEndpointTypeMismatch(binding~, leaf~, expected~, actual~) =>
      "aggregate binding \{binding} leaf \{leaf} expected \{Repr(expected)}, received \{Repr(actual)}"
    InvalidCdcPrimitiveId(primitive) =>
      "CDC primitive identifier \{primitive} is negative"
    CdcPrimitiveLimitExceeded(maximum~, actual~) =>
      "CDC primitive count \{actual} exceeds limit \{maximum}"
    NonSequentialCdcPrimitiveId(expected~, actual~) =>
      "CDC primitive ordinal \{actual} is not canonical; expected \{expected}"
    InvalidBitSynchronizerStageCount(primitive~, actual~) =>
      "bit synchronizer \{primitive} requires two through four stages; received \{actual}"
    DuplicateCdcPrimitiveName(name) => "duplicate CDC primitive name: \{name}"
    DuplicateCdcPrimitiveStage(node~) =>
      "CDC register stage node \{node} has more than one owner"
    CdcPrimitiveSourceIsStage(primitive~, node~) =>
      "CDC primitive \{primitive} source node \{node} is also one of its stages"
    UnknownCdcPrimitiveSourceNode(primitive~, node~) =>
      "CDC primitive \{primitive} source node \{node} does not exist"
    InvalidCdcPrimitiveSourceType(primitive~, node~) =>
      "CDC primitive \{primitive} source node \{node} must be exact one-bit data"
    UnknownCdcPrimitiveDomain(primitive~, domain~) =>
      "CDC primitive \{primitive} references unknown domain \{domain}"
    EqualCdcPrimitiveDomains(primitive~, domain~) =>
      "CDC primitive \{primitive} source and destination are both domain \{domain}"
    UnknownCdcPrimitiveStageNode(primitive~, stage~, node~) =>
      "CDC primitive \{primitive} stage \{stage} node \{node} does not exist"
    InvalidCdcPrimitiveStageType(primitive~, stage~, node~) =>
      "CDC primitive \{primitive} stage \{stage} node \{node} has the wrong one-bit type"
    InvalidCdcPrimitiveStageKind(primitive~, stage~, node~) =>
      "CDC primitive \{primitive} stage \{stage} node \{node} is not a register"
    CdcPrimitiveStageDomainMismatch(primitive~, stage~, expected~, actual~) =>
      "CDC primitive \{primitive} stage \{stage} uses domain \{actual}; expected \{expected}"
    CdcPrimitiveStageNextMismatch(primitive~, stage~, expected~, actual~) =>
      "CDC primitive \{primitive} stage \{stage} samples node \{actual}; expected \{expected}"
    CdcPrimitiveStageHasEnable(primitive~, stage~, node~) =>
      "CDC primitive \{primitive} stage \{stage} node \{node} must not have an enable"
    CdcPrimitiveStageResetMismatch(primitive~, stage~, node~) =>
      "CDC primitive \{primitive} stage \{stage} node \{node} does not use its declared reset"
    CdcPrimitiveIntermediateFanout(primitive~, stage~, node~, consumer~) =>
      "CDC primitive \{primitive} intermediate stage \{stage} node \{node} has forbidden consumer \{consumer}"
    InvalidToggleHandshakeStageCount(primitive~, actual~) =>
      "toggle handshake \{primitive} requires matching two-through-four-stage synchronizers; received \{actual}"
    EqualToggleHandshakeDomains(primitive~, domain~) =>
      "toggle handshake \{primitive} source and destination are both domain \{domain}"
    UnknownToggleHandshakeDomain(primitive~, role~, domain~) =>
      "toggle handshake \{primitive} role \{role} references unknown clock domain \{domain}"
    ToggleHandshakePayloadCountMismatch(
      primitive~,
      expected~,
      source~,
      held~,
      destination~
    ) =>
      "toggle handshake \{primitive} expected \{expected} payload leaves; source=\{source}, held=\{held}, destination=\{destination}"
    ToggleHandshakeDuplicateNode(primitive~, node~) =>
      "toggle handshake \{primitive} implementation node \{node} has more than one role"
    UnknownToggleHandshakeNode(primitive~, role~, node~) =>
      "toggle handshake \{primitive} role \{role} references missing node \{node}"
    ToggleHandshakeNodeTypeMismatch(primitive~, role~, node~) =>
      "toggle handshake \{primitive} role \{role} has incompatible node type at \{node}"
    ToggleHandshakeStructureMismatch(primitive~, role~) =>
      "toggle handshake \{primitive} role \{role} does not match the checked one-item structure"
    ToggleHandshakeResetMismatch(primitive~, role~, node~) =>
      "toggle handshake \{primitive} role \{role} has unsupported coordinated-idle reset at node \{node}"
    ToggleHandshakeHiddenFanout(primitive~, role~, node~, consumer~) =>
      "toggle handshake \{primitive} private role \{role} node \{node} has forbidden consumer \{consumer}"
    InvalidAsyncFifoDepth(primitive~, actual~) =>
      "asynchronous FIFO \{primitive} depth must be a power of two from 4 through 1048576; received \{actual}"
    InvalidAsyncFifoStageCount(primitive~, actual~) =>
      "asynchronous FIFO \{primitive} requires matching two-through-four-stage pointer synchronizers; received \{actual}"
    EqualAsyncFifoDomains(primitive~, domain~) =>
      "asynchronous FIFO \{primitive} source and destination are both domain \{domain}"
    UnknownAsyncFifoDomain(primitive~, role~, domain~) =>
      "asynchronous FIFO \{primitive} role \{role} references unknown clock domain \{domain}"
    AsyncFifoPayloadCountMismatch(
      primitive~,
      expected~,
      source~,
      raw~,
      visible~
    ) =>
      "asynchronous FIFO \{primitive} expected \{expected} payload leaves; source=\{source}, raw=\{raw}, visible=\{visible}"
    AsyncFifoPayloadWidth(primitive~, actual~) =>
      "asynchronous FIFO \{primitive} payload width must be from 1 through 64 bits; received \{actual}"
    AsyncFifoDuplicateNode(primitive~, node~) =>
      "asynchronous FIFO \{primitive} implementation node \{node} has more than one role"
    UnknownAsyncFifoNode(primitive~, role~, node~) =>
      "asynchronous FIFO \{primitive} role \{role} references missing node \{node}"
    AsyncFifoNodeTypeMismatch(primitive~, role~, node~) =>
      "asynchronous FIFO \{primitive} role \{role} has incompatible node type at \{node}"
    AsyncFifoStructureMismatch(primitive~, role~) =>
      "asynchronous FIFO \{primitive} role \{role} does not match the checked structure"
    AsyncFifoResetMismatch(primitive~, role~, node~) =>
      "asynchronous FIFO \{primitive} role \{role} has unsupported coordinated-idle reset at node \{node}"
    AsyncFifoHiddenFanout(primitive~, role~, node~, consumer~) =>
      "asynchronous FIFO \{primitive} private role \{role} node \{node} has forbidden consumer \{consumer}"
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
    ExpectedReset(node~) => "node \{node} is not a reset control"
    UnsupportedAsynchronousReset(node~) =>
      "register node \{node} uses asynchronous reset before event ordering is supported"
    UnsupportedResetPolarity(node~) =>
      "register node \{node} uses active-low reset before polarity normalization is supported"
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
