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
    memories: [],
    domains: [],
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
/// Bind a clock signal to the supported rising-edge domain.
///
/// Domains are explicit values; the builder never installs an ambient clock.
pub fn ModuleBuilder::rising_edge(
  self : ModuleBuilder,
  clock : Signal,
) -> ClockDomain raise {
  self.require_open()
  self.require_signal(clock)
  if !clock.signal_type.is_clock() {
    raise @ir.IrError::ExpectedClock(node=clock.id.ordinal())
  }
  for domain in self.domains {
    if domain.clock.id == clock.id {
      return domain
    }
  }
  let domain = {
    owner: self.owner,
    clock,
    canonical: @ir.ClockDomain::rising(clock.id),
  }
  self.domains.push(domain)
  domain
}

///|
/// Construct a synchronous reset control. Its raw value is checked against
/// each register type when the reset is attached.
pub fn ModuleBuilder::synchronous_reset(
  self : ModuleBuilder,
  signal : Signal,
  value : UInt64,
) -> SynchronousReset raise {
  self.require_open()
  self.require_signal(signal)
  if !(signal.signal_type is Reset) {
    raise @ir.IrError::ExpectedReset(node=signal.id.ordinal())
  }
  { owner: self.owner, signal, canonical: @ir.ResetSpec::new(signal.id, value) }
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
fn require_raw_value_fits(
  operation : String,
  signal_type : @ir.SignalType,
  value : UInt64,
) -> Unit raise @ir.IrError {
  if !signal_type.is_data() {
    raise TypeMismatch(operation~)
  }
  let width = signal_type.width().bits()
  if width < 64 && value >> width != 0UL {
    raise ConstantOutOfRange(width~, value~)
  }
}

///|
fn ModuleBuilder::canonical_register_controls(
  self : ModuleBuilder,
  signal_type : @ir.SignalType,
  domain : ClockDomain,
  reset : SynchronousReset?,
  enable : Signal?,
  initial : UInt64?,
) -> (@ir.ClockDomain, @ir.ResetSpec?, @ir.NodeId?, UInt64?) raise {
  self.require_open()
  if !physical_equal(self.owner, domain.owner) {
    raise ForeignClockDomain
  }
  self.require_signal(domain.clock)
  let canonical_reset = match reset {
    None => None
    Some(reset) => {
      if !physical_equal(self.owner, reset.owner) {
        raise ForeignReset
      }
      self.require_signal(reset.signal)
      require_raw_value_fits("register_reset", signal_type, reset.value())
      Some(reset.canonical)
    }
  }
  let canonical_enable = match enable {
    None => None
    Some(enable) => {
      self.require_signal(enable)
      if !enable.signal_type.is_data() || enable.signal_type.width().bits() != 1 {
        raise @ir.IrError::ExpectedEnable(node=enable.id.ordinal())
      }
      Some(enable.id)
    }
  }
  if initial is Some(value) {
    require_raw_value_fits("register_initial", signal_type, value)
  }
  (domain.canonical, canonical_reset, canonical_enable, initial)
}

///|
fn ModuleBuilder::register_with_controls(
  self : ModuleBuilder,
  domain : ClockDomain,
  next : Signal,
  reset : SynchronousReset?,
  enable : Signal?,
  initial : UInt64?,
) -> Signal raise {
  self.require_signal(next)
  if !next.signal_type.is_data() {
    raise @ir.IrError::TypeMismatch(operation="register")
  }
  let (canonical_domain, canonical_reset, canonical_enable, canonical_initial) = self.canonical_register_controls(
    next.signal_type,
    domain,
    reset,
    enable,
    initial,
  )
  let spec = @ir.RegisterSpec::new(
    canonical_domain,
    next.id,
    reset?=canonical_reset,
    enable?=canonical_enable,
    initial?=canonical_initial,
  )
  self.append(next.signal_type, Register(spec))
}

///|
/// Add a register in an explicit clock domain. On its rising edge, synchronous
/// reset has priority over enable; a deasserted enable holds the old value.
pub fn ModuleBuilder::register_in(
  self : ModuleBuilder,
  domain : ClockDomain,
  next : Signal,
  reset? : SynchronousReset,
  enable? : Signal,
  initial? : UInt64,
) -> Signal raise {
  self.register_with_controls(domain, next, reset, enable, initial)
}

///|
/// Compatibility convenience for a rising-edge register without controls.
/// The clock remains explicit and no default domain is installed.
pub fn ModuleBuilder::register(
  self : ModuleBuilder,
  clock : Signal,
  next : Signal,
  initial? : UInt64,
) -> Signal raise {
  let domain = self.rising_edge(clock)
  self.register_with_controls(domain, next, None, None, initial)
}

///|
/// Declare state before constructing its next-state logic.
///
/// Call `connect_next` exactly once before finishing. The returned handle's
/// value can be used immediately, including by its own next-state expression.
fn ModuleBuilder::register_state_with_controls(
  self : ModuleBuilder,
  domain : ClockDomain,
  signal_type : @ir.SignalType,
  reset : SynchronousReset?,
  enable : Signal?,
  initial : UInt64?,
) -> RegisterHandle raise {
  if !signal_type.is_data() {
    raise @ir.IrError::TypeMismatch(operation="register")
  }
  let (canonical_domain, canonical_reset, canonical_enable, canonical_initial) = self.canonical_register_controls(
    signal_type, domain, reset, enable, initial,
  )
  let id = @ir.NodeId::new(self.nodes.length())
  let value : Signal = { owner: self.owner, id, signal_type }
  let index = self.registers.length()
  let handle : RegisterHandle = {
    owner: self.owner,
    index,
    value,
    domain: canonical_domain,
    reset: canonical_reset,
    enable: canonical_enable,
    initial: canonical_initial,
  }
  // This temporary hold-state node is replaced by `connect_next`.
  let placeholder = @ir.RegisterSpec::new(
    canonical_domain,
    id,
    reset?=canonical_reset,
    enable?=canonical_enable,
    initial?=canonical_initial,
  )
  self.nodes.push(@ir.Node::new(id, signal_type, Register(placeholder)))
  self.registers.push(handle)
  self.next_drivers.push(None)
  handle
}

///|
/// Declare controlled state in an explicit domain before its next logic.
pub fn ModuleBuilder::register_state_in(
  self : ModuleBuilder,
  domain : ClockDomain,
  signal_type : @ir.SignalType,
  reset? : SynchronousReset,
  enable? : Signal,
  initial? : UInt64,
) -> RegisterHandle raise {
  self.register_state_with_controls(domain, signal_type, reset, enable, initial)
}

///|
/// Compatibility convenience for rising-edge state without controls.
pub fn ModuleBuilder::register_state(
  self : ModuleBuilder,
  clock : Signal,
  signal_type : @ir.SignalType,
  initial? : UInt64,
) -> RegisterHandle raise {
  let domain = self.rising_edge(clock)
  self.register_state_with_controls(domain, signal_type, None, None, initial)
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
  let spec = @ir.RegisterSpec::new(
    register.domain,
    next.id,
    reset?=register.reset,
    enable?=register.enable,
    initial?=register.initial,
  )
  self.nodes[node_index] = @ir.Node::new(
    register.value.id,
    register.value.signal_type,
    Register(spec),
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
  let memories : Array[@ir.MemorySpec] = []
  for declaration in self.memories {
    memories.push(
      @ir.MemorySpec::new(
        declaration.id,
        declaration.name,
        declaration.element_type,
        declaration.depth,
        declaration.domain.canonical,
        declaration.read_ports,
        declaration.write_ports,
        declaration.read_write_policy,
        declaration.multi_write_policy,
        declaration.bounds_policy,
      ),
    )
  }
  let hardware_module = @ir.Module::checked_with_memories(
    self.name,
    self.nodes,
    memories,
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
