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
    MemoryRead(..) => @wave.LogicValue::unknown(width~)
    _ => @wave.LogicValue::unknown(width~)
  }
}

///|
/// Select a register's simultaneous next state using four-state controls.
///
/// A known asserted synchronous reset wins over enable. Unknown controls use
/// the same bitwise merge as a hardware mux, retaining every bit that is equal
/// on both possible paths instead of pessimistically turning the whole word X.
fn Simulator::normalized_reset_control(
  self : Simulator,
  reset : @ir.ResetSpec,
) -> @wave.LogicValue raise {
  let control = self.read_slot(reset.signal())
  match reset.polarity() {
    ActiveHigh => control
    ActiveLow => control.bit_not()
  }
}

///|
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
      self.normalized_reset_control(reset).mux(reset_value, enabled)
    }
  }
}

///|
/// Compute and commit every level-sensitive asynchronous reset from one shared
/// pre-reset state. Unknown controls merge reset and retained values bitwise.
fn Simulator::apply_asynchronous_resets(self : Simulator) -> Bool raise {
  let mut changed = false
  for node in self.hardware_module.nodes() {
    match node.kind() {
      Register(spec) =>
        match spec.reset() {
          Some(reset) if reset.mode() is Asynchronous => {
            let current = self.read_slot(node.id())
            let reset_value = @wave.LogicValue::from_uint64(
              width=node.signal_type().width().bits(),
              value=reset.value(),
            )
            let candidate = self
              .normalized_reset_control(reset)
              .mux(reset_value, current)
            self.pending_state[node.id().ordinal()] = Some(candidate)
            if candidate != current {
              changed = true
            }
          }
          _ => ()
        }
      _ => ()
    }
  }
  for node in self.hardware_module.nodes() {
    match node.kind() {
      Register(spec) =>
        match spec.reset() {
          Some(reset) if reset.mode() is Asynchronous => {
            let ordinal = node.id().ordinal()
            match self.pending_state[ordinal] {
              Some(value) => self.values[ordinal] = value
              None => raise MissingRegisterUpdate(ordinal)
            }
          }
          _ => ()
        }
      _ => ()
    }
  }
  self.clear_pending_updates()
  changed
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
    Input(_) | Register(_) | MemoryRead(..) => self.read_slot(node.id())
    AsyncFifoRead(..) => self.async_fifo_read(node.id())
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
fn Simulator::domain_index(
  self : Simulator,
  id : @ir.ClockDomainId,
) -> Int32 raise SimulatorError {
  for index, domain in self.hardware_module.domains() {
    if domain.id() == id {
      return index
    }
  }
  raise UnknownClockDomainId(id.ordinal())
}

///|
fn Simulator::domain_is_active(
  self : Simulator,
  domains : ArrayView[@ir.ClockDomainId],
  requested : @ir.ClockDomainId,
) -> Bool {
  ignore(self)
  for domain in domains {
    if domain == requested {
      return true
    }
  }
  false
}

///|
fn Simulator::validate_input_drive(
  self : Simulator,
  drive : InputDrive,
) -> Unit raise SimulatorError {
  for node in self.hardware_module.nodes() {
    match node.kind() {
      Input(name) if name == drive.name() => {
        let expected = node.signal_type().width().bits()
        if drive.value().width() != expected {
          raise InputWidthMismatch(
            name~,
            expected~,
            actual=drive.value().width(),
          )
        }
        return
      }
      _ => ()
    }
  }
  raise UnknownInput(drive.name())
}

///|
fn Simulator::clear_pending_updates(self : Simulator) -> Unit {
  for index in 0..<self.pending_state.length() {
    self.pending_state[index] = None
  }
  for index in 0..<self.pending_memories.length() {
    self.pending_memories[index] = None
  }
  for index in 0..<self.pending_async_fifos.length() {
    self.pending_async_fifos[index] = None
  }
}

///|
fn maximum_prepared_memory_depth() -> Int32 {
  1048576
}

///|
/// Prepare deterministic execution state for a validated canonical module.
///
/// Inputs begin unknown, constants begin known, and registers begin at their
/// explicit canonical initial value. Uninitialized registers begin unknown.
/// The initial combinational state is settled before the simulator is returned.
pub fn Simulator::prepare(hardware_module : @ir.Module) -> Simulator raise {
  @cdc.validate_module(hardware_module) catch {
    error => raise CdcRejected(error)
  }
  prepare_kernel(hardware_module)
}

///|
/// Package-private execution kernel. White-box semantic tests may exercise
/// simultaneous-event behavior over deliberately unsafe fixtures, but no
/// public caller can bypass the canonical CDC boundary.
fn prepare_kernel(hardware_module : @ir.Module) -> Simulator raise {
  let values : Array[@wave.LogicValue] = []
  let pending_state : Array[@wave.LogicValue?] = []
  for node in hardware_module.nodes() {
    let width = node.signal_type().width().bits()
    if width > 64 {
      raise UnsupportedWidth(node=node.id().ordinal(), width~)
    }
    values.push(initial_node_value(node))
    pending_state.push(None)
  }
  let memory_cells : Array[Array[@wave.LogicValue]] = []
  let pending_memories : Array[Array[PendingMemoryWrite]?] = []
  let maximum_memory_cells = maximum_prepared_memory_depth()
  validate_prepared_state_budget(hardware_module, maximum_memory_cells)
  for memory in hardware_module.memories() {
    if memory.element_type().width().bits() > 64 {
      raise UnsupportedWidth(
        node=memory.id().ordinal(),
        width=memory.element_type().width().bits(),
      )
    }
    memory_cells.push(
      Array::make(
        memory.depth().elements(),
        @wave.LogicValue::unknown(width=memory.element_type().width().bits()),
      ),
    )
    pending_memories.push(None)
  }
  let (async_fifos, async_fifo_reads, pending_async_fifos) = prepare_async_fifo_storage(
    hardware_module,
  )
  let simulator = {
    hardware_module,
    values,
    pending_state,
    memory_cells,
    pending_memories,
    async_fifos,
    async_fifo_reads,
    pending_async_fifos,
    cycle: @wave.CycleCounter::zero(),
    time: SimulationTime::zero(),
    event_ordinal: 0UL,
    domain_edge_counts: Array::make(hardware_module.domains().length(), 0UL),
  }
  simulator.settle()
  simulator
}

///|
/// Stage a named canonical input without advancing simulated time or changing
/// sequential state. `settle` updates combinational values only; it does not
/// apply asynchronous reset. Use `apply_event` with `TimestampEvent::drives_only`
/// to commit a drive-only timestamp atomically, or `rising_edge` to commit a
/// staged value together with one edge.
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
/// Settle all combinational nodes in canonical order. This operation never
/// commits asynchronous-reset or edge-triggered state.
///
/// Validated combinational operands precede their users. Registers are state
/// cut-points: their old committed values remain visible throughout settlement,
/// even when their next-state expressions occur later in canonical order.
pub fn Simulator::settle(self : Simulator) -> Unit raise {
  for node in self.hardware_module.nodes() {
    match node.kind() {
      Input(_) | Register(_) | MemoryRead(..) => ()
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
  let domain = @ir.ClockDomain::rising(clock).id()
  match self.hardware_module.domain(domain) {
    Some(_) =>
      self.apply_event(TimestampEvent::checked(self.time.next(), [], [domain]))
    None => {
      // Schema-1/2 replay historically allowed an edge on a Clock input even
      // when the design had no sequential element and therefore no canonical
      // domain-table entry. Retain that state-less compatibility behavior;
      // public timestamp events still reject unknown domain IDs.
      if self.event_ordinal == 18446744073709551615UL {
        raise EventOrdinalOverflow
      }
      let next_time = self.time.next()
      let next_cycle = self.cycle.next()
      self.settle()
      self.time = next_time
      self.event_ordinal = self.event_ordinal + 1UL
      self.cycle = next_cycle
    }
  }
}

///|
/// Apply one atomic timestamp event.
///
/// Every failure that can be detected without evaluating design behavior is
/// checked before inputs or state are changed. Drives are applied and settled;
/// every asynchronous-reset effect is computed from one shared pre-state and
/// committed together. Active-domain register and memory candidates are then
/// computed from one shared post-reset state and committed globally.
fn Simulator::apply_event_mutating(
  self : Simulator,
  event : TimestampEvent,
  memory_undo : Array[MemoryUndoEntry],
  async_fifo_undo : Array[AsyncFifoUndoEntry],
) -> Unit raise {
  let previous_time = self.time.value()
  let actual_time = event.time().value()
  if self.event_ordinal > 0UL && actual_time <= previous_time {
    raise NonMonotonicTimestamp(previous=previous_time, actual=actual_time)
  }
  if self.event_ordinal == 18446744073709551615UL {
    raise EventOrdinalOverflow
  }
  for drive in event.drives() {
    self.validate_input_drive(drive)
  }
  let domain_indices : Array[Int32] = []
  for domain in event.active_domains() {
    let index = self.domain_index(domain)
    if self.domain_edge_counts[index] == 18446744073709551615UL {
      raise DomainEdgeCountOverflow(domain.ordinal())
    }
    domain_indices.push(index)
  }
  let next_cycle = if event.active_domains().is_empty() {
    self.cycle
  } else {
    self.cycle.next()
  }

  self.clear_pending_updates()
  for drive in event.drives() {
    self.set_input(drive.name(), drive.value())
  }
  self.settle()

  if self.apply_asynchronous_resets() {
    self.settle()
  }
  for domain in event.active_domains() {
    for node in self.hardware_module.nodes() {
      match node.kind() {
        Register(spec) if spec.domain().id() == domain =>
          self.pending_state[node.id().ordinal()] = Some(
            self.register_update(node, spec),
          )
        _ => ()
      }
    }
    for memory in self.hardware_module.memories() {
      if memory.domain().id() == domain {
        self.prepare_memory_update(memory)
      }
    }
    for fifo in self.async_fifos {
      if fifo.primitive.source_domain() == domain {
        self.prepare_async_fifo_update(fifo)
      }
    }
  }

  for node in self.hardware_module.nodes() {
    match node.kind() {
      Register(spec) if self.domain_is_active(
          event.active_domains(),
          spec.domain().id(),
        ) => {
        let ordinal = node.id().ordinal()
        match self.pending_state[ordinal] {
          Some(value) => self.values[ordinal] = value
          None => raise MissingRegisterUpdate(ordinal)
        }
      }
      MemoryRead(memory~, port~) => {
        let memory_spec = self.hardware_module.memories()[memory.ordinal()]
        if self.domain_is_active(
            event.active_domains(),
            memory_spec.domain().id(),
          ) {
          let ordinal = node.id().ordinal()
          match self.pending_state[ordinal] {
            Some(value) => self.values[ordinal] = value
            None => raise MissingMemoryReadUpdate(node=ordinal)
          }
        }
        ignore(port)
      }
      _ => ()
    }
  }
  for memory in self.hardware_module.memories() {
    if self.domain_is_active(event.active_domains(), memory.domain().id()) {
      let ordinal = memory.id().ordinal()
      match self.pending_memories[ordinal] {
        Some(updates) =>
          for update in updates {
            memory_undo.push({
              memory: ordinal,
              address: update.address,
              value: self.memory_cells[ordinal][update.address],
            })
            self.memory_cells[ordinal][update.address] = update.value
          }
        None => raise MissingMemoryUpdate(memory=ordinal)
      }
    }
  }
  for fifo in self.async_fifos {
    if self.domain_is_active(
        event.active_domains(),
        fifo.primitive.source_domain(),
      ) {
      let fifo_index = fifo.index
      match self.pending_async_fifos[fifo_index] {
        Some(update) =>
          for leaf, value in update.values {
            async_fifo_undo.push({
              fifo: fifo_index,
              leaf,
              address: update.address,
              value: self.async_fifos[fifo_index].lanes[leaf][update.address],
            })
            self.async_fifos[fifo_index].lanes[leaf][update.address] = value
          }
        None => ()
      }
    }
  }
  self.clear_pending_updates()
  self.settle()
  for index in domain_indices {
    self.domain_edge_counts[index] = self.domain_edge_counts[index] + 1UL
  }
  self.time = event.time()
  self.event_ordinal = self.event_ordinal + 1UL
  self.cycle = next_cycle
}

///|
/// Apply one atomic timestamp event transactionally.
///
/// Design-semantic checks such as memory bounds and collision policies happen
/// while candidates are evaluated. If any such check fails, every mutable
/// input, state, memory, counter, and pending slot is restored exactly. The
/// transaction retains one node-value checkpoint and an undo entry only for
/// each written memory address; it never copies whole memories per event.
pub fn Simulator::apply_event(
  self : Simulator,
  event : TimestampEvent,
) -> Unit raise {
  let values_before = self.values.copy()
  let cycle_before = self.cycle
  let time_before = self.time
  let ordinal_before = self.event_ordinal
  let edge_counts_before = self.domain_edge_counts.copy()
  let memory_undo : Array[MemoryUndoEntry] = []
  let async_fifo_undo : Array[AsyncFifoUndoEntry] = []
  errdefer {
    for index, value in values_before {
      self.values[index] = value
    }
    for entry in memory_undo {
      self.memory_cells[entry.memory][entry.address] = entry.value
    }
    for entry in async_fifo_undo {
      self.async_fifos[entry.fifo].lanes[entry.leaf][entry.address] = entry.value
    }
    self.cycle = cycle_before
    self.time = time_before
    self.event_ordinal = ordinal_before
    for index, count in edge_counts_before {
      self.domain_edge_counts[index] = count
    }
    self.clear_pending_updates()
  }
  self.apply_event_mutating(event, memory_undo, async_fifo_undo)
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
/// Return the timestamp of the last committed atomic event.
pub fn Simulator::time(self : Simulator) -> SimulationTime {
  self.time
}

///|
/// Return the number of committed atomic events, including drive-only events.
pub fn Simulator::event_ordinal(self : Simulator) -> UInt64 {
  self.event_ordinal
}

///|
/// Return the committed rising-edge count for one canonical clock domain.
pub fn Simulator::domain_edge_count(
  self : Simulator,
  domain : @ir.ClockDomainId,
) -> UInt64 raise SimulatorError {
  self.domain_edge_counts[self.domain_index(domain)]
}
