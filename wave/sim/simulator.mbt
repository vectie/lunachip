///|
fn initial_node_value(node : @ir.Node) -> @wave.LogicValue raise {
  let width = node.signal_type().width().bits()
  match node.kind() {
    Constant(value) => @wave.LogicValue::from_uint64(width~, value~)
    Register(spec) =>
      match spec.initial() {
        Some(value) => @wave.LogicValue::from_uint64(width~, value~)
        None => @wave.LogicValue::unknown(width~)
      }
    _ => @wave.LogicValue::unknown(width~)
  }
}

///|
/// Select a register's simultaneous next state using four-state controls.
///
/// A known asserted synchronous reset wins over enable. Unknown controls use
/// the same bitwise merge as a hardware mux, retaining every bit that is equal
/// on both possible paths instead of pessimistically turning the whole word X.
fn Simulator::register_update(
  self : Simulator,
  node : @ir.Node,
  spec : @ir.RegisterSpec,
) -> @wave.LogicValue raise {
  let current = self.read_slot(node.id())
  let next = self.read_slot(spec.next())
  let enabled = match spec.enable() {
    None => next
    Some(enable) => self.read_slot(enable).mux(next, current)
  }
  match spec.reset() {
    None => enabled
    Some(reset) => {
      let reset_value = @wave.LogicValue::from_uint64(
        width=node.signal_type().width().bits(),
        value=reset.value(),
      )
      self.read_slot(reset.signal()).mux(reset_value, enabled)
    }
  }
}

///|
fn Simulator::read_slot(
  self : Simulator,
  id : @ir.NodeId,
) -> @wave.LogicValue raise SimulatorError {
  match self.values.get(id.ordinal()) {
    Some(value) => value
    None => raise UnknownNode(id.ordinal())
  }
}

///|
fn Simulator::operand_is_signed(
  self : Simulator,
  id : @ir.NodeId,
) -> Bool raise SimulatorError {
  match self.hardware_module.node(id) {
    Some(node) => node.signal_type() is SInt(_)
    None => raise UnknownNode(id.ordinal())
  }
}

///|
fn Simulator::less_than(
  self : Simulator,
  left : @ir.NodeId,
  right : @ir.NodeId,
) -> @wave.LogicValue raise {
  let lhs = self.read_slot(left)
  let rhs = self.read_slot(right)
  if self.operand_is_signed(left) {
    lhs.less_than_signed(rhs)
  } else {
    lhs.less_than_unsigned(rhs)
  }
}

///|
fn Simulator::evaluate_node(
  self : Simulator,
  node : @ir.Node,
) -> @wave.LogicValue raise {
  match node.kind() {
    Input(_) | Register(_) => self.read_slot(node.id())
    Constant(value) =>
      @wave.LogicValue::from_uint64(
        width=node.signal_type().width().bits(),
        value~,
      )
    Add(left, right) => self.read_slot(left).add(self.read_slot(right))
    Sub(left, right) => self.read_slot(left).sub(self.read_slot(right))
    MulLow(left, right) => self.read_slot(left).mul_low(self.read_slot(right))
    MulFull(left, right) =>
      if self.operand_is_signed(left) {
        self.read_slot(left).mul_full_signed(self.read_slot(right))
      } else {
        self.read_slot(left).mul_full(self.read_slot(right))
      }
    BitAnd(left, right) => self.read_slot(left).bit_and(self.read_slot(right))
    BitOr(left, right) => self.read_slot(left).bit_or(self.read_slot(right))
    BitXor(left, right) => self.read_slot(left).bit_xor(self.read_slot(right))
    BitNot(operand) => self.read_slot(operand).bit_not()
    Equal(left, right) =>
      self.read_slot(left).equal_value(self.read_slot(right))
    LessThan(left, right) => self.less_than(left, right)
    LessEqual(left, right) => self.less_than(right, left).bit_not()
    ShiftLeft(value~, amount~) =>
      self.read_slot(value).shift_left(self.read_slot(amount))
    LogicalShiftRight(value~, amount~) =>
      self.read_slot(value).logical_shift_right(self.read_slot(amount))
    ArithmeticShiftRight(value~, amount~) =>
      self.read_slot(value).arithmetic_shift_right(self.read_slot(amount))
    Slice(value~, msb~, lsb~) => self.read_slot(value).slice(msb~, lsb~)
    Concat(most_significant~, least_significant~) =>
      self.read_slot(most_significant).concat(self.read_slot(least_significant))
    ZeroExtend(value) =>
      self.read_slot(value).zero_extend(node.signal_type().width().bits())
    SignExtend(value) =>
      self.read_slot(value).sign_extend(node.signal_type().width().bits())
    Truncate(value) =>
      self.read_slot(value).truncate(node.signal_type().width().bits())
    Reinterpret(value) => self.read_slot(value)
    Mux(select~, when_true~, when_false~) =>
      self
      .read_slot(select)
      .mux(self.read_slot(when_true), self.read_slot(when_false))
  }
}

///|
fn Simulator::clock_id(
  self : Simulator,
  name : String,
) -> @ir.NodeId raise SimulatorError {
  for node in self.hardware_module.nodes() {
    match node.kind() {
      Input(input_name) if input_name == name => {
        if !node.signal_type().is_clock() {
          raise ExpectedClockInput(name)
        }
        return node.id()
      }
      _ => ()
    }
  }
  raise UnknownClock(name)
}

///|
/// Prepare deterministic execution state for a validated canonical module.
///
/// Inputs begin unknown, constants begin known, and registers begin at their
/// explicit canonical initial value. Uninitialized registers begin unknown.
/// The initial combinational state is settled before the simulator is returned.
pub fn Simulator::prepare(hardware_module : @ir.Module) -> Simulator raise {
  let values : Array[@wave.LogicValue] = []
  let pending_registers : Array[@wave.LogicValue?] = []
  for node in hardware_module.nodes() {
    let width = node.signal_type().width().bits()
    if width > 64 {
      raise UnsupportedWidth(node=node.id().ordinal(), width~)
    }
    values.push(initial_node_value(node))
    pending_registers.push(None)
  }
  let simulator = {
    hardware_module,
    values,
    pending_registers,
    cycle: @wave.CycleCounter::zero(),
  }
  simulator.settle()
  simulator
}

///|
/// Drive a named canonical input without advancing simulated time.
///
/// Call `settle` before observing combinational outputs, or call `rising_edge`,
/// which performs both the pre-edge and post-commit settlements.
pub fn Simulator::set_input(
  self : Simulator,
  name : String,
  value : @wave.LogicValue,
) -> Unit raise SimulatorError {
  for node in self.hardware_module.nodes() {
    match node.kind() {
      Input(input_name) if input_name == name => {
        let expected = node.signal_type().width().bits()
        if value.width() != expected {
          raise InputWidthMismatch(name~, expected~, actual=value.width())
        }
        self.values[node.id().ordinal()] = value
        return
      }
      _ => ()
    }
  }
  raise UnknownInput(name)
}

///|
/// Settle all combinational nodes in canonical order.
///
/// Validated combinational operands precede their users. Registers are state
/// cut-points: their old committed values remain visible throughout settlement,
/// even when their next-state expressions occur later in canonical order.
pub fn Simulator::settle(self : Simulator) -> Unit raise {
  for node in self.hardware_module.nodes() {
    match node.kind() {
      Input(_) | Register(_) => ()
      _ => self.values[node.id().ordinal()] = self.evaluate_node(node)
    }
  }
}

///|
/// Apply one named rising-edge event and advance one deterministic cycle.
///
/// The simulator first settles old state, collects every register update in
/// the selected clock domain, commits all collected values simultaneously,
/// settles the new state, and only then advances the cycle counter.
pub fn Simulator::rising_edge(
  self : Simulator,
  clock_name : String,
) -> Unit raise {
  let clock = self.clock_id(clock_name)
  self.settle()
  for node in self.hardware_module.nodes() {
    match node.kind() {
      Register(spec) if spec.domain().clock() == clock =>
        self.pending_registers[node.id().ordinal()] = Some(
          self.register_update(node, spec),
        )
      _ => ()
    }
  }
  for node in self.hardware_module.nodes() {
    match node.kind() {
      Register(spec) if spec.domain().clock() == clock => {
        let ordinal = node.id().ordinal()
        match self.pending_registers[ordinal] {
          Some(value) => {
            self.values[ordinal] = value
            self.pending_registers[ordinal] = None
          }
          None => raise MissingRegisterUpdate(ordinal)
        }
      }
      _ => ()
    }
  }
  self.settle()
  self.cycle = self.cycle.next()
}

///|
/// Return the most recently settled value of a canonical node.
pub fn Simulator::value(
  self : Simulator,
  id : @ir.NodeId,
) -> @wave.LogicValue raise SimulatorError {
  self.read_slot(id)
}

///|
/// Return the most recently settled value of a named output.
pub fn Simulator::output(
  self : Simulator,
  name : String,
) -> @wave.LogicValue raise SimulatorError {
  for output in self.hardware_module.outputs() {
    if output.name() == name {
      return self.read_slot(output.driver())
    }
  }
  raise UnknownOutput(name)
}

///|
/// Return the number of rising-edge events committed by this simulator.
pub fn Simulator::cycle(self : Simulator) -> @wave.CycleCounter {
  self.cycle
}

///|
/// Capture all inputs, state, and settled combinational slots without sharing
/// mutable storage with the running simulator.
pub fn Simulator::snapshot(self : Simulator) -> SimulatorSnapshot {
  {
    hardware_module: self.hardware_module,
    values: ReadOnlyArray::from_array(self.values.copy()),
    cycle: self.cycle,
  }
}

///|
/// Restore a snapshot made from the exact same validated module.
pub fn Simulator::restore(
  self : Simulator,
  snapshot : SimulatorSnapshot,
) -> Unit raise SimulatorError {
  if self.hardware_module != snapshot.hardware_module {
    raise SnapshotDesignMismatch
  }
  for index, value in snapshot.values {
    self.values[index] = value
    self.pending_registers[index] = None
  }
  self.cycle = snapshot.cycle
}
