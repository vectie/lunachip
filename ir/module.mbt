///|
/// A validated, immutable canonical RTL module.
pub struct Module {
  name : String
  domains : ReadOnlyArray[ClockDomain]
  nodes : ReadOnlyArray[Node]
  memories : ReadOnlyArray[MemorySpec]
  outputs : ReadOnlyArray[OutputPort]
  metadata : ModuleMetadata
} derive(Debug, Eq)

///|
fn require_name(name : String, kind : String) -> Unit raise IrError {
  if name.is_empty() {
    raise EmptyName(kind~)
  }
}

///|
fn clock_domain_compare(left : ClockDomain, right : ClockDomain) -> Int {
  left.id().ordinal() - right.id().ordinal()
}

///|
fn canonical_domain_id(domain : ClockDomain) -> Int {
  match domain.edge() {
    Rising => domain.clock().ordinal()
  }
}

///|
fn validate_domain_definition(
  nodes : ArrayView[Node],
  domain : ClockDomain,
) -> Unit raise IrError {
  let expected = canonical_domain_id(domain)
  let actual = domain.id().ordinal()
  if actual != expected {
    raise NonCanonicalClockDomainId(expected~, actual~)
  }
  let clock = require_node(nodes, domain.clock())
  if !clock.signal_type().is_clock() {
    raise ExpectedClock(node=domain.clock().ordinal())
  }
}

///|
fn canonical_domains(
  nodes : ArrayView[Node],
  declared : ArrayView[ClockDomain],
) -> Array[ClockDomain] raise IrError {
  let domains = declared.to_owned()
  domains.sort_by(clock_domain_compare)
  let canonical : Array[ClockDomain] = []
  for domain in domains {
    validate_domain_definition(nodes, domain)
    if canonical.last() is Some(previous) && previous.id() == domain.id() {
      if previous != domain {
        raise ClockDomainIdCollision(
          id=domain.id().ordinal(),
          first_clock=previous.clock().ordinal(),
          second_clock=domain.clock().ordinal(),
        )
      }
    } else {
      canonical.push(domain)
    }
  }
  canonical
}

///|
fn require_domain(
  domains : ArrayView[ClockDomain],
  requested : ClockDomain,
) -> Unit raise IrError {
  for domain in domains {
    if domain.id() == requested.id() {
      if domain != requested {
        raise ClockDomainIdCollision(
          id=requested.id().ordinal(),
          first_clock=domain.clock().ordinal(),
          second_clock=requested.clock().ordinal(),
        )
      }
      return
    }
  }
  raise UnknownClockDomainId(requested.id().ordinal())
}

///|
fn referenced_domains(
  nodes : ArrayView[Node],
  memories : ArrayView[MemorySpec],
) -> Array[ClockDomain] {
  let domains : Array[ClockDomain] = []
  for node in nodes {
    match node.kind() {
      Register(spec) => domains.push(spec.domain())
      _ => ()
    }
  }
  for memory in memories {
    domains.push(memory.domain())
  }
  domains
}

///|
fn contains_name(names : ArrayView[String], name : String) -> Bool {
  names.any(existing => existing == name)
}

///|
fn require_prior_node(
  nodes : ArrayView[Node],
  current : Int,
  operand : NodeId,
) -> Node raise IrError {
  let ordinal = operand.ordinal()
  if ordinal < 0 || ordinal >= nodes.length() {
    raise UnknownNodeId(ordinal)
  }
  if ordinal >= current {
    raise ForwardReference(node=current, operand=ordinal)
  }
  nodes[ordinal]
}

///|
fn require_node(
  nodes : ArrayView[Node],
  operand : NodeId,
) -> Node raise IrError {
  let ordinal = operand.ordinal()
  if ordinal < 0 || ordinal >= nodes.length() {
    raise UnknownNodeId(ordinal)
  }
  nodes[ordinal]
}

///|
fn require_type(
  operation : String,
  expected : SignalType,
  actual : SignalType,
) -> Unit raise IrError {
  if expected != actual {
    let expected_width = expected.width().bits()
    let actual_width = actual.width().bits()
    if expected_width != actual_width {
      raise WidthMismatch(
        operation~,
        expected=expected_width,
        actual=actual_width,
      )
    }
    raise TypeMismatch(operation~)
  }
}

///|
fn require_value_fits(
  signal_type : SignalType,
  value : UInt64,
) -> Unit raise IrError {
  let width = signal_type.width().bits()
  if !signal_type.is_data() {
    raise TypeMismatch(operation="constant")
  }
  if width < 64 && value >> width != 0UL {
    raise ConstantOutOfRange(width~, value~)
  }
}

///|
fn validate_binary(
  nodes : ArrayView[Node],
  current : Int,
  result_type : SignalType,
  operation : String,
  lhs : NodeId,
  rhs : NodeId,
) -> Unit raise IrError {
  if !result_type.is_data() {
    raise TypeMismatch(operation~)
  }
  let left = require_prior_node(nodes, current, lhs)
  let right = require_prior_node(nodes, current, rhs)
  require_type(operation, result_type, left.signal_type())
  require_type(operation, result_type, right.signal_type())
}

///|
fn validate_add(
  nodes : ArrayView[Node],
  current : Int,
  result_type : SignalType,
  lhs : NodeId,
  rhs : NodeId,
) -> Unit raise IrError {
  if !result_type.is_numeric() {
    raise TypeMismatch(operation="add")
  }
  validate_binary(nodes, current, result_type, "add", lhs, rhs)
}

///|
fn validate_register(
  nodes : ArrayView[Node],
  domains : ArrayView[ClockDomain],
  current : Int,
  state_type : SignalType,
  spec : RegisterSpec,
) -> Unit raise IrError {
  if !state_type.is_data() {
    raise TypeMismatch(operation="register")
  }
  let domain = spec.domain()
  require_domain(domains, domain)
  let clock = domain.clock()
  let clock_node = require_prior_node(nodes, current, clock)
  if !clock_node.signal_type().is_clock() {
    raise ExpectedClock(node=clock.ordinal())
  }
  match domain.edge() {
    Rising => ()
  }
  if spec.reset() is Some(reset) {
    let reset_node = require_prior_node(nodes, current, reset.signal())
    if !(reset_node.signal_type() is Reset) {
      raise ExpectedReset(node=reset.signal().ordinal())
    }
    require_value_fits(state_type, reset.value())
    match reset.mode() {
      Synchronous => ()
      Asynchronous => raise UnsupportedAsynchronousReset(node=current)
    }
    match reset.polarity() {
      ActiveHigh => ()
      ActiveLow => raise UnsupportedResetPolarity(node=current)
    }
  }
  if spec.enable() is Some(enable) {
    let enable_node = require_prior_node(nodes, current, enable)
    if !enable_node.signal_type().is_data() ||
      enable_node.signal_type().width().bits() != 1 {
      raise ExpectedEnable(node=enable.ordinal())
    }
  }
  // A register is a combinational cycle break. Its next-state expression may
  // therefore be later in canonical order or be the register itself.
  let next_node = require_node(nodes, spec.next())
  require_type("register", state_type, next_node.signal_type())
  if spec.initial() is Some(value) {
    require_value_fits(state_type, value)
  }
}

///|
fn validate_node(
  nodes : ArrayView[Node],
  domains : ArrayView[ClockDomain],
  current : Int,
) -> Unit raise IrError {
  let node = nodes[current]
  match node.kind() {
    Input(name) => require_name(name, "input")
    Constant(value) => require_value_fits(node.signal_type(), value)
    Add(lhs, rhs) => validate_add(nodes, current, node.signal_type(), lhs, rhs)
    Sub(lhs, rhs) =>
      validate_numeric_binary(
        nodes,
        current,
        node.signal_type(),
        "sub",
        lhs,
        rhs,
      )
    MulLow(lhs, rhs) =>
      validate_numeric_binary(
        nodes,
        current,
        node.signal_type(),
        "mul_low",
        lhs,
        rhs,
      )
    MulFull(lhs, rhs) =>
      validate_full_multiply(nodes, current, node.signal_type(), lhs, rhs)
    BitAnd(lhs, rhs) =>
      validate_binary(nodes, current, node.signal_type(), "and", lhs, rhs)
    BitOr(lhs, rhs) =>
      validate_binary(nodes, current, node.signal_type(), "or", lhs, rhs)
    BitXor(lhs, rhs) =>
      validate_binary(nodes, current, node.signal_type(), "xor", lhs, rhs)
    BitNot(operand) => {
      if !node.signal_type().is_data() {
        raise TypeMismatch(operation="not")
      }
      let input = require_prior_node(nodes, current, operand)
      require_type("not", node.signal_type(), input.signal_type())
    }
    Equal(lhs, rhs) =>
      validate_comparison(
        nodes,
        current,
        node.signal_type(),
        "equal",
        lhs,
        rhs,
        false,
      )
    LessThan(lhs, rhs) =>
      validate_comparison(
        nodes,
        current,
        node.signal_type(),
        "less_than",
        lhs,
        rhs,
        true,
      )
    LessEqual(lhs, rhs) =>
      validate_comparison(
        nodes,
        current,
        node.signal_type(),
        "less_equal",
        lhs,
        rhs,
        true,
      )
    ShiftLeft(value~, amount~) =>
      validate_shift(
        nodes,
        current,
        node.signal_type(),
        "shift_left",
        value,
        amount,
        false,
      )
    LogicalShiftRight(value~, amount~) =>
      validate_shift(
        nodes,
        current,
        node.signal_type(),
        "logical_shift_right",
        value,
        amount,
        false,
      )
    ArithmeticShiftRight(value~, amount~) =>
      validate_shift(
        nodes,
        current,
        node.signal_type(),
        "arithmetic_shift_right",
        value,
        amount,
        true,
      )
    Slice(value~, msb~, lsb~) =>
      validate_slice(nodes, current, node.signal_type(), value, msb, lsb)
    Concat(most_significant~, least_significant~) =>
      validate_concat(
        nodes,
        current,
        node.signal_type(),
        most_significant,
        least_significant,
      )
    ZeroExtend(value) =>
      validate_width_conversion(
        nodes,
        current,
        node.signal_type(),
        "zero_extend",
        value,
        (source, result) => result > source,
      )
    SignExtend(value) => {
      let input = require_prior_node(nodes, current, value)
      if !(input.signal_type() is SInt(_)) {
        raise ExpectedSigned(operation="sign_extend", node=value.ordinal())
      }
      validate_width_conversion(
        nodes,
        current,
        node.signal_type(),
        "sign_extend",
        value,
        (source, result) => result > source,
      )
    }
    Truncate(value) =>
      validate_width_conversion(
        nodes,
        current,
        node.signal_type(),
        "truncate",
        value,
        (source, result) => result < source,
      )
    Reinterpret(value) =>
      validate_reinterpret(nodes, current, node.signal_type(), value)
    Mux(select~, when_true~, when_false~) => {
      let selector = require_prior_node(nodes, current, select)
      if !selector.signal_type().is_data() ||
        selector.signal_type().width().bits() != 1 {
        raise ExpectedOneBit(node=select.ordinal())
      }
      let true_node = require_prior_node(nodes, current, when_true)
      let false_node = require_prior_node(nodes, current, when_false)
      require_type("mux", node.signal_type(), true_node.signal_type())
      require_type("mux", node.signal_type(), false_node.signal_type())
    }
    Register(spec) =>
      validate_register(nodes, domains, current, node.signal_type(), spec)
    MemoryRead(..) => ()
  }
}

///|
fn validate_node_ids(nodes : ArrayView[Node]) -> Unit raise IrError {
  for current in 0..<nodes.length() {
    let actual = nodes[current].id().ordinal()
    if actual != current {
      raise NonSequentialNodeId(expected=current, actual~)
    }
  }
}

///|
fn validate_input_names(nodes : ArrayView[Node]) -> Unit raise IrError {
  let names : Array[String] = []
  for node in nodes {
    match node.kind() {
      Input(name) => {
        if contains_name(names, name) {
          raise DuplicateName(kind="input", name~)
        }
        names.push(name)
      }
      _ => ()
    }
  }
}

///|
fn validate_outputs(
  nodes : ArrayView[Node],
  outputs : ArrayView[OutputPort],
) -> Unit raise IrError {
  let names : Array[String] = []
  for output in outputs {
    require_name(output.name(), "output")
    if contains_name(names, output.name()) {
      raise DuplicateName(kind="output", name=output.name())
    }
    names.push(output.name())
    let ordinal = output.driver().ordinal()
    if ordinal < 0 || ordinal >= nodes.length() {
      raise UnknownNodeId(ordinal)
    }
    require_type("output", output.signal_type(), nodes[ordinal].signal_type())
  }
}

///|
fn output_by_name(
  outputs : ArrayView[OutputPort],
  name : String,
) -> OutputPort? {
  for output in outputs {
    if output.name() == name {
      return Some(output)
    }
  }
  None
}

///|
fn validate_aggregate_bindings(
  nodes : ArrayView[Node],
  outputs : ArrayView[OutputPort],
  metadata : ModuleMetadata,
) -> Unit raise IrError {
  for binding in metadata.aggregate_bindings() {
    let binding_id = binding.id().ordinal()
    for leaf in binding.leaves() {
      let ordinal = leaf.ordinal()
      let expected = leaf.signal_type()
      match (binding.kind(), leaf.target()) {
        (InputPort, Node(node_id)) => {
          let node_ordinal = node_id.ordinal()
          guard nodes.get(node_ordinal) is Some(node) else {
            raise UnknownAggregateEndpointNode(
              binding=binding_id,
              leaf=ordinal,
              node=node_ordinal,
            )
          }
          if !(node.kind() is Input(_)) {
            raise AggregateEndpointRoleMismatch(
              binding=binding_id,
              leaf=ordinal,
              kind=InputPort,
            )
          }
          if expected != node.signal_type() {
            raise AggregateEndpointTypeMismatch(
              binding=binding_id,
              leaf=ordinal,
              expected~,
              actual=node.signal_type(),
            )
          }
        }
        (OutputPort, Output(name)) => {
          guard output_by_name(outputs, name) is Some(output) else {
            raise UnknownAggregateEndpointOutput(
              binding=binding_id,
              leaf=ordinal,
              output=name,
            )
          }
          if expected != output.signal_type() {
            raise AggregateEndpointTypeMismatch(
              binding=binding_id,
              leaf=ordinal,
              expected~,
              actual=output.signal_type(),
            )
          }
        }
        (Internal, Node(node_id)) => {
          let node_ordinal = node_id.ordinal()
          guard nodes.get(node_ordinal) is Some(node) else {
            raise UnknownAggregateEndpointNode(
              binding=binding_id,
              leaf=ordinal,
              node=node_ordinal,
            )
          }
          if node.kind() is Input(_) {
            raise AggregateEndpointRoleMismatch(
              binding=binding_id,
              leaf=ordinal,
              kind=Internal,
            )
          }
          if expected != node.signal_type() {
            raise AggregateEndpointTypeMismatch(
              binding=binding_id,
              leaf=ordinal,
              expected~,
              actual=node.signal_type(),
            )
          }
        }
        (kind, _) =>
          raise AggregateEndpointRoleMismatch(
            binding=binding_id,
            leaf=ordinal,
            kind~,
          )
      }
    }
  }
}

///|
fn has_input_timing(metadata : ModuleMetadata, requested : NodeId) -> Bool {
  metadata.input_timings().any(binding => binding.input() == requested)
}

///|
fn has_output_timing(metadata : ModuleMetadata, requested : String) -> Bool {
  metadata.output_timings().any(binding => binding.output() == requested)
}

///|
fn validate_port_timings(
  domains : ArrayView[ClockDomain],
  nodes : ArrayView[Node],
  outputs : ArrayView[OutputPort],
  metadata : ModuleMetadata,
) -> Unit raise IrError {
  if !metadata.declares_port_timing() {
    return
  }
  for binding in metadata.input_timings() {
    let ordinal = binding.input().ordinal()
    guard nodes.get(ordinal) is Some(node) else {
      raise UnknownInputTimingNode(ordinal)
    }
    guard node.kind() is Input(_) else { raise InputTimingOnNonInput(ordinal) }
    if node.signal_type().is_clock() {
      raise InputTimingOnClock(ordinal)
    }
    match binding.timing() {
      Asynchronous => ()
      SampledIn(domain) =>
        if !domains.any(item => item.id() == domain) {
          raise UnknownInputTimingDomain(input=ordinal, domain=domain.ordinal())
        }
    }
  }
  for node in nodes {
    if node.kind() is Input(_) &&
      !node.signal_type().is_clock() &&
      !has_input_timing(metadata, node.id()) {
      raise MissingInputTiming(node.id().ordinal())
    }
  }
  for binding in metadata.output_timings() {
    guard output_by_name(outputs, binding.output()) is Some(output) else {
      raise UnknownTimedOutput(binding.output())
    }
    if output.signal_type().is_clock() {
      raise OutputTimingOnClock(binding.output())
    }
    match binding.timing() {
      Static | Asynchronous => ()
      ProducedIn(domain) =>
        if !domains.any(item => item.id() == domain) {
          raise UnknownOutputTimingDomain(
            output=binding.output(),
            domain=domain.ordinal(),
          )
        }
    }
  }
  for output in outputs {
    if !output.signal_type().is_clock() &&
      !has_output_timing(metadata, output.name()) {
      raise MissingOutputTiming(output.name())
    }
  }
}

///|
/// Validate and freeze a canonical module. Node order is the canonical order.
pub fn Module::checked(
  name : String,
  nodes : ArrayView[Node],
  outputs : ArrayView[OutputPort],
) -> Module raise IrError {
  Module::checked_with_memories(name, nodes, [], outputs)
}

///|
/// Validate and freeze a canonical module with first-class memory state.
pub fn Module::checked_with_memories(
  name : String,
  nodes : ArrayView[Node],
  memories : ArrayView[MemorySpec],
  outputs : ArrayView[OutputPort],
) -> Module raise IrError {
  Module::checked_with_domains(
    name,
    referenced_domains(nodes, memories),
    nodes,
    memories,
    outputs,
  )
}

///|
/// Validate and freeze a canonical module with an explicit domain table.
pub fn Module::checked_with_domains(
  name : String,
  domains : ArrayView[ClockDomain],
  nodes : ArrayView[Node],
  memories : ArrayView[MemorySpec],
  outputs : ArrayView[OutputPort],
) -> Module raise IrError {
  Module::checked_with_metadata(
    name,
    domains,
    nodes,
    memories,
    outputs,
    ModuleMetadata::empty(),
  )
}

///|
/// Validate and freeze a canonical module with explicit domains and immutable
/// elaboration metadata.
pub fn Module::checked_with_metadata(
  name : String,
  domains : ArrayView[ClockDomain],
  nodes : ArrayView[Node],
  memories : ArrayView[MemorySpec],
  outputs : ArrayView[OutputPort],
  metadata : ModuleMetadata,
) -> Module raise IrError {
  require_name(name, "module")
  validate_node_ids(nodes)
  let canonical_domain_table = canonical_domains(nodes, domains)
  validate_combinational_cycles(nodes)
  for current in 0..<nodes.length() {
    validate_node(nodes, canonical_domain_table, current)
  }
  for memory in memories {
    require_domain(canonical_domain_table, memory.domain())
  }
  validate_memories(nodes, memories)
  validate_input_names(nodes)
  validate_outputs(nodes, outputs)
  validate_aggregate_bindings(nodes, outputs, metadata)
  validate_port_timings(canonical_domain_table, nodes, outputs, metadata)
  {
    name,
    domains: ReadOnlyArray::from_array(canonical_domain_table),
    nodes: ReadOnlyArray::from_array(nodes),
    memories: ReadOnlyArray::from_array(memories),
    outputs: ReadOnlyArray::from_array(outputs),
    metadata,
  }
}

///|
pub fn Module::name(self : Module) -> String {
  self.name
}

///|
pub fn Module::nodes(self : Module) -> ReadOnlyArray[Node] {
  self.nodes
}

///|
/// Return the canonical module-local domain table in stable identifier order.
pub fn Module::domains(self : Module) -> ReadOnlyArray[ClockDomain] {
  self.domains
}

///|
/// Resolve one canonical clock-domain identifier.
pub fn Module::domain(self : Module, id : ClockDomainId) -> ClockDomain? {
  for domain in self.domains {
    if domain.id() == id {
      return Some(domain)
    }
  }
  None
}

///|
pub fn Module::memories(self : Module) -> ReadOnlyArray[MemorySpec] {
  self.memories
}

///|
pub fn Module::outputs(self : Module) -> ReadOnlyArray[OutputPort] {
  self.outputs
}

///|
pub fn Module::metadata(self : Module) -> ModuleMetadata {
  self.metadata
}

///|
pub fn Module::parameters(self : Module) -> ReadOnlyArray[ModuleParameter] {
  self.metadata.parameters()
}

///|
pub fn Module::aggregate_bindings(
  self : Module,
) -> ReadOnlyArray[AggregateBinding] {
  self.metadata.aggregate_bindings()
}

///|
pub fn Module::input_timings(
  self : Module,
) -> ReadOnlyArray[InputTimingBinding] {
  self.metadata.input_timings()
}

///|
pub fn Module::output_timings(
  self : Module,
) -> ReadOnlyArray[OutputTimingBinding] {
  self.metadata.output_timings()
}

///|
pub fn Module::node(self : Module, id : NodeId) -> Node? {
  self.nodes.get(id.ordinal())
}
