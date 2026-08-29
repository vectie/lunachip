///|
/// Construct an unsigned data type with a checked width.
pub fn uint(width : Int) -> @ir.SignalType raise @ir.IrError {
  UInt(@ir.Width::new(width))
}

///|
/// Construct a signed data type with a checked width.
pub fn sint(width : Int) -> @ir.SignalType raise @ir.IrError {
  SInt(@ir.Width::new(width))
}

///|
/// Construct uninterpreted bits with a checked width.
pub fn bits(width : Int) -> @ir.SignalType raise @ir.IrError {
  Bits(@ir.Width::new(width))
}

///|
/// Return the dedicated clock type.
pub fn clock() -> @ir.SignalType {
  Clock
}

///|
/// Return the dedicated reset type.
pub fn reset() -> @ir.SignalType {
  Reset
}

///|
/// Begin deterministic elaboration of a named module.
pub fn ModuleBuilder::new(name : String) -> ModuleBuilder {
  {
    name,
    owner: [()],
    nodes: [],
    outputs: [],
    drivers: [],
    registers: [],
    next_drivers: [],
    finished: false,
  }
}

///|
fn ModuleBuilder::require_open(self : ModuleBuilder) -> Unit raise WireError {
  if self.finished {
    raise BuilderFinished
  }
}

///|
fn ModuleBuilder::require_signal(
  self : ModuleBuilder,
  signal : Signal,
) -> Unit raise WireError {
  if !physical_equal(self.owner, signal.owner) {
    raise ForeignSignal
  }
}

///|
fn ModuleBuilder::append(
  self : ModuleBuilder,
  signal_type : @ir.SignalType,
  kind : @ir.NodeKind,
) -> Signal raise {
  self.require_open()
  let id = @ir.NodeId::new(self.nodes.length())
  self.nodes.push(@ir.Node::new(id, signal_type, kind))
  { owner: self.owner, id, signal_type }
}

///|
fn ModuleBuilder::require_same_type(
  self : ModuleBuilder,
  operation : String,
  lhs : Signal,
  rhs : Signal,
) -> Unit raise {
  self.require_signal(lhs)
  self.require_signal(rhs)
  if lhs.signal_type != rhs.signal_type {
    let expected = lhs.signal_type.width().bits()
    let actual = rhs.signal_type.width().bits()
    if expected != actual {
      raise @ir.IrError::WidthMismatch(operation~, expected~, actual~)
    }
    raise @ir.IrError::TypeMismatch(operation~)
  }
}

///|
/// Add a named input node.
pub fn ModuleBuilder::input(
  self : ModuleBuilder,
  name : String,
  signal_type : @ir.SignalType,
) -> Signal raise {
  self.append(signal_type, Input(name))
}

///|
/// Add a raw-bit constant. Range validation occurs when the module is frozen.
pub fn ModuleBuilder::constant(
  self : ModuleBuilder,
  signal_type : @ir.SignalType,
  value : UInt64,
) -> Signal raise {
  self.append(signal_type, Constant(value))
}

///|
fn ModuleBuilder::binary(
  self : ModuleBuilder,
  operation : String,
  lhs : Signal,
  rhs : Signal,
  make_kind : (@ir.NodeId, @ir.NodeId) -> @ir.NodeKind,
) -> Signal raise {
  self.require_same_type(operation, lhs, rhs)
  if !lhs.signal_type.is_data() {
    raise @ir.IrError::TypeMismatch(operation~)
  }
  self.append(lhs.signal_type, make_kind(lhs.id, rhs.id))
}

///|
pub fn ModuleBuilder::add(
  self : ModuleBuilder,
  lhs : Signal,
  rhs : Signal,
) -> Signal raise {
  if !lhs.signal_type.is_numeric() {
    raise @ir.IrError::TypeMismatch(operation="add")
  }
  self.binary("add", lhs, rhs, (a, b) => Add(a, b))
}

///|
pub fn ModuleBuilder::bit_and(
  self : ModuleBuilder,
  lhs : Signal,
  rhs : Signal,
) -> Signal raise {
  self.binary("and", lhs, rhs, (a, b) => BitAnd(a, b))
}

///|
pub fn ModuleBuilder::bit_or(
  self : ModuleBuilder,
  lhs : Signal,
  rhs : Signal,
) -> Signal raise {
  self.binary("or", lhs, rhs, (a, b) => BitOr(a, b))
}

///|
pub fn ModuleBuilder::bit_xor(
  self : ModuleBuilder,
  lhs : Signal,
  rhs : Signal,
) -> Signal raise {
  self.binary("xor", lhs, rhs, (a, b) => BitXor(a, b))
}

///|
pub fn ModuleBuilder::bit_not(
  self : ModuleBuilder,
  operand : Signal,
) -> Signal raise {
  self.require_signal(operand)
  if !operand.signal_type.is_data() {
    raise @ir.IrError::TypeMismatch(operation="not")
  }
  self.append(operand.signal_type, BitNot(operand.id))
}

///|
pub fn ModuleBuilder::mux(
  self : ModuleBuilder,
  select : Signal,
  when_true : Signal,
  when_false : Signal,
) -> Signal raise {
  self.require_signal(select)
  self.require_same_type("mux", when_true, when_false)
  if !select.signal_type.is_data() || select.signal_type.width().bits() != 1 {
    raise @ir.IrError::ExpectedOneBit(node=select.id.ordinal())
  }
  self.append(
    when_true.signal_type,
    Mux(select=select.id, when_true=when_true.id, when_false=when_false.id),
  )
}

///|
/// Add a positive-edge register with an explicit clock and initial raw bits.
pub fn ModuleBuilder::register(
  self : ModuleBuilder,
  clock : Signal,
  next : Signal,
  initial? : UInt64,
) -> Signal raise {
  self.require_signal(clock)
  self.require_signal(next)
  if !clock.signal_type.is_clock() {
    raise @ir.IrError::ExpectedClock(node=clock.id.ordinal())
  }
  if !next.signal_type.is_data() {
    raise @ir.IrError::TypeMismatch(operation="register")
  }
  self.append(
    next.signal_type,
    Register(clock=clock.id, next=next.id, initial~),
  )
}

///|
/// Declare state before constructing its next-state logic.
///
/// Call `connect_next` exactly once before finishing. The returned handle's
/// value can be used immediately, including by its own next-state expression.
pub fn ModuleBuilder::register_state(
  self : ModuleBuilder,
  clock : Signal,
  signal_type : @ir.SignalType,
  initial? : UInt64,
) -> RegisterHandle raise {
  self.require_open()
  self.require_signal(clock)
  if !clock.signal_type.is_clock() {
    raise @ir.IrError::ExpectedClock(node=clock.id.ordinal())
  }
  if !signal_type.is_data() {
    raise @ir.IrError::TypeMismatch(operation="register")
  }
  let id = @ir.NodeId::new(self.nodes.length())
  let value : Signal = { owner: self.owner, id, signal_type }
  let index = self.registers.length()
  let handle : RegisterHandle = {
    owner: self.owner,
    index,
    value,
    clock: clock.id,
    initial,
  }
  // This temporary hold-state node is replaced by `connect_next`.
  self.nodes.push(
    @ir.Node::new(id, signal_type, Register(clock=clock.id, next=id, initial~)),
  )
  self.registers.push(handle)
  self.next_drivers.push(None)
  handle
}

///|
/// Connect the sole next-state driver of a declared register.
pub fn ModuleBuilder::connect_next(
  self : ModuleBuilder,
  register : RegisterHandle,
  next : Signal,
) -> Unit raise {
  self.require_open()
  if !physical_equal(self.owner, register.owner) {
    raise ForeignRegister
  }
  self.require_signal(next)
  let owned_register = self.registers.get(register.index)
  guard owned_register is Some(owned_register) &&
    owned_register.value.id == register.value.id else {
    raise ForeignRegister
  }
  if self.next_drivers[register.index] is Some(_) {
    raise DuplicateNextDriver(register.value.id.ordinal())
  }
  if register.value.signal_type != next.signal_type {
    let expected = register.value.signal_type.width().bits()
    let actual = next.signal_type.width().bits()
    if expected != actual {
      raise @ir.IrError::WidthMismatch(operation="register", expected~, actual~)
    }
    raise @ir.IrError::TypeMismatch(operation="register")
  }
  let node_index = register.value.id.ordinal()
  self.nodes[node_index] = @ir.Node::new(
    register.value.id,
    register.value.signal_type,
    Register(clock=register.clock, next=next.id, initial=register.initial),
  )
  self.next_drivers[register.index] = Some(next.id)
}

///|
/// Declare an output sink that must later be connected exactly once.
pub fn ModuleBuilder::output(
  self : ModuleBuilder,
  name : String,
  signal_type : @ir.SignalType,
) -> Output raise WireError {
  self.require_open()
  let index = self.outputs.length()
  let output = { owner: self.owner, index, name, signal_type }
  self.outputs.push(output)
  self.drivers.push(None)
  output
}

///|
/// Drive an output. A second connection is rejected, even to the same signal.
pub fn ModuleBuilder::connect(
  self : ModuleBuilder,
  output : Output,
  driver : Signal,
) -> Unit raise {
  self.require_open()
  if !physical_equal(self.owner, output.owner) {
    raise ForeignOutput
  }
  self.require_signal(driver)
  let owned_output = self.outputs.get(output.index)
  guard owned_output is Some(owned_output) && owned_output.name == output.name else {
    raise ForeignOutput
  }
  if self.drivers[output.index] is Some(_) {
    raise DuplicateDriver(output.name)
  }
  if owned_output.signal_type != driver.signal_type {
    let expected = owned_output.signal_type.width().bits()
    let actual = driver.signal_type.width().bits()
    if expected != actual {
      raise @ir.IrError::WidthMismatch(operation="connect", expected~, actual~)
    }
    raise @ir.IrError::TypeMismatch(operation="connect")
  }
  self.drivers[output.index] = Some(driver.id)
}

///|
/// Validate and freeze this builder. The builder cannot be reused afterward.
pub fn ModuleBuilder::finish(self : ModuleBuilder) -> @ir.Module raise {
  self.require_open()
  for index, register in self.registers {
    if self.next_drivers[index] is None {
      raise UndrivenRegister(register.value.id.ordinal())
    }
  }
  let canonical_outputs : Array[@ir.OutputPort] = []
  for index, output in self.outputs {
    match self.drivers[index] {
      Some(driver) =>
        canonical_outputs.push(
          @ir.OutputPort::new(output.name, output.signal_type, driver),
        )
      None => raise WireError::UndrivenOutput(output.name)
    }
  }
  let hardware_module = @ir.Module::checked(
    self.name,
    self.nodes,
    canonical_outputs,
  )
  self.finished = true
  hardware_module
}

///|
/// Wrap a single elaborated module in a deterministic design.
pub fn single_design(
  name : String,
  top : @ir.Module,
) -> @ir.Design raise @ir.IrError {
  @ir.Design::single(name, top)
}
