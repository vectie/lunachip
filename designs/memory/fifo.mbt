///|
fn require_control_port(
  port : String,
  signal : @wire.Signal,
) -> Unit raise MemoryComponentError {
  match signal.signal_type() {
    Bits(width) if width.bits() == 1 => ()
    _ => raise ExpectedControlPort(port)
  }
}

///|
fn require_element_port(
  port : String,
  signal : @wire.Signal,
  expected : @ir.SignalType,
) -> Unit raise MemoryComponentError {
  if signal.signal_type() != expected {
    raise ExpectedElementPort(port)
  }
}

///|
fn advance_fifo_pointer(
  builder : @wire.ModuleBuilder,
  pointer : @wire.Signal,
  fire : @wire.Signal,
  depth : @ir.MemoryDepth,
) -> @wire.Signal raise {
  let pointer_type = pointer.signal_type()
  let one = builder.constant(pointer_type, 1UL)
  let zero = builder.constant(pointer_type, 0UL)
  let last = builder.constant(pointer_type, (depth.elements() - 1).to_uint64())
  let incremented = builder.add(pointer, one)
  let at_last = builder.equal(pointer, last)
  let wrapped = builder.mux(at_last, zero, incremented)
  builder.mux(fire, wrapped, pointer)
}

///|
/// Elaborate a request/response synchronous FIFO into an existing builder.
///
/// `pop_request && pop_ready` accepts one pop. Its data and
/// `response_valid=1` appear after the next active edge. The FIFO has no
/// fall-through path. Full FIFOs accept a simultaneous pop and push, and
/// `ReadOld` guarantees that the response observes the replaced entry.
pub fn synchronous_fifo(
  builder : @wire.ModuleBuilder,
  config : FifoConfig,
  domain : @wire.ClockDomain,
  reset_signal : @wire.Signal,
  push_valid : @wire.Signal,
  push_data : @wire.Signal,
  pop_request : @wire.Signal,
) -> FifoSignals raise {
  require_control_port("push_valid", push_valid)
  require_control_port("pop_request", pop_request)
  require_element_port("push_data", push_data, config.element_type())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let reset_inactive = builder.bit_not(builder.reset_asserted(reset_signal))
  let pointer_type = @ir.SignalType::UInt(config.depth().address_width())
  let occupancy_type = @ir.SignalType::UInt(config.occupancy_width())
  let read_pointer = builder.register_state_in(domain, pointer_type, reset~)
  let write_pointer = builder.register_state_in(domain, pointer_type, reset~)
  let occupancy = builder.register_state_in(domain, occupancy_type, reset~)
  let zero = builder.constant(occupancy_type, 0UL)
  let capacity = builder.constant(
    occupancy_type,
    config.depth().elements().to_uint64(),
  )
  let empty = builder.equal(occupancy.value(), zero)
  let full = builder.equal(occupancy.value(), capacity)
  let pop_ready = builder.bit_and(builder.bit_not(empty), reset_inactive)
  let pop_fire = builder.bit_and(pop_request, pop_ready)
  // Permitting a simultaneous pop prevents an avoidable bubble at full.
  let push_ready = builder.bit_and(
    builder.bit_or(builder.bit_not(full), pop_fire),
    reset_inactive,
  )
  let push_fire = builder.bit_and(push_valid, push_ready)
  let memory = builder.synchronous_memory(
    "\{config.name()}.storage",
    config.element_type(),
    config.depth().elements(),
    domain,
    read_write_policy=ReadOld,
    multi_write_policy=Reject,
    bounds_policy=Fault,
  )
  builder.memory_write(
    memory,
    "push",
    write_pointer.value(),
    push_data,
    enable=push_fire,
  )
  let response_data = builder.memory_read(
    memory,
    "pop",
    read_pointer.value(),
    enable=pop_fire,
    enable_behavior=HoldLast,
  )
  let response_valid = builder.register_in(domain, pop_fire, reset~)
  builder.connect_next(
    read_pointer,
    advance_fifo_pointer(
      builder,
      read_pointer.value(),
      pop_fire,
      config.depth(),
    ),
  )
  builder.connect_next(
    write_pointer,
    advance_fifo_pointer(
      builder,
      write_pointer.value(),
      push_fire,
      config.depth(),
    ),
  )
  let one = builder.constant(occupancy_type, 1UL)
  let incremented = builder.add(occupancy.value(), one)
  let decremented = builder.sub(occupancy.value(), one)
  let fires_match = builder.equal(push_fire, pop_fire)
  let changed = builder.mux(push_fire, incremented, decremented)
  builder.connect_next(
    occupancy,
    builder.mux(fires_match, occupancy.value(), changed),
  )
  {
    push_ready,
    pop_ready,
    response_valid,
    response_data,
    full,
    empty,
    occupancy: occupancy.value(),
  }
}

///|
/// Build a standalone FIFO module with a deterministic public interface.
pub fn synchronous_fifo_module(config : FifoConfig) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new(config.name())
  let clock = builder.input("clock", Clock)
  let reset = builder.input("reset", Reset)
  let push_valid = builder.input("push_valid", @wire.bits(1))
  let push_data = builder.input("push_data", config.element_type())
  let pop_request = builder.input("pop_request", @wire.bits(1))
  let signals = synchronous_fifo(
    builder,
    config,
    builder.rising_edge(clock),
    reset,
    push_valid,
    push_data,
    pop_request,
  )
  let push_ready = builder.output("push_ready", @wire.bits(1))
  let pop_ready = builder.output("pop_ready", @wire.bits(1))
  let response_valid = builder.output("response_valid", @wire.bits(1))
  let response_data = builder.output("response_data", config.element_type())
  let full = builder.output("full", @wire.bits(1))
  let empty = builder.output("empty", @wire.bits(1))
  let occupancy = builder.output("occupancy", UInt(config.occupancy_width()))
  builder.connect(push_ready, signals.push_ready())
  builder.connect(pop_ready, signals.pop_ready())
  builder.connect(response_valid, signals.response_valid())
  builder.connect(response_data, signals.response_data())
  builder.connect(full, signals.full())
  builder.connect(empty, signals.empty())
  builder.connect(occupancy, signals.occupancy())
  builder.finish()
}
