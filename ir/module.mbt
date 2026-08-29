///|
/// A validated, immutable canonical RTL module.
pub struct Module {
  name : String
  nodes : ReadOnlyArray[Node]
  outputs : ReadOnlyArray[OutputPort]
} derive(Debug, Eq)

///|
fn require_name(name : String, kind : String) -> Unit raise IrError {
  if name.is_empty() {
    raise EmptyName(kind~)
  }
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
fn validate_node(nodes : ArrayView[Node], current : Int) -> Unit raise IrError {
  let node = nodes[current]
  let actual = node.id().ordinal()
  if actual != current {
    raise NonSequentialNodeId(expected=current, actual~)
  }
  match node.kind() {
    Input(name) => require_name(name, "input")
    Constant(value) => require_value_fits(node.signal_type(), value)
    Add(lhs, rhs) => validate_add(nodes, current, node.signal_type(), lhs, rhs)
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
    Register(clock~, next~, initial~) => {
      let clock_node = require_prior_node(nodes, current, clock)
      if !clock_node.signal_type().is_clock() {
        raise ExpectedClock(node=clock.ordinal())
      }
      // Sequential state breaks dependency cycles, so next-state logic may be
      // constructed after the register value it reads.
      let next_node = require_node(nodes, next)
      require_type("register", node.signal_type(), next_node.signal_type())
      if initial is Some(value) {
        require_value_fits(node.signal_type(), value)
      }
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
/// Validate and freeze a canonical module. Node order is the canonical order.
pub fn Module::checked(
  name : String,
  nodes : ArrayView[Node],
  outputs : ArrayView[OutputPort],
) -> Module raise IrError {
  require_name(name, "module")
  for current in 0..<nodes.length() {
    validate_node(nodes, current)
  }
  validate_input_names(nodes)
  validate_outputs(nodes, outputs)
  {
    name,
    nodes: ReadOnlyArray::from_array(nodes),
    outputs: ReadOnlyArray::from_array(outputs),
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
pub fn Module::outputs(self : Module) -> ReadOnlyArray[OutputPort] {
  self.outputs
}

///|
pub fn Module::node(self : Module, id : NodeId) -> Node? {
  self.nodes.get(id.ordinal())
}
