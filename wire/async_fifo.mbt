///|
fn fifo_pointer_width(depth : Int) -> Int {
  let mut value = depth
  let mut address_width = 0
  while value > 1 {
    value = value >> 1
    address_width += 1
  }
  address_width + 1
}

///|
fn ModuleBuilder::require_fifo_reset(
  self : ModuleBuilder,
  reset : SynchronousReset,
  role : String,
) -> Unit raise {
  if !physical_equal(self.owner, reset.owner) {
    raise ForeignReset
  }
  self.require_signal(reset.signal)
  if reset.value() != 0UL ||
    reset.mode() != Synchronous ||
    reset.polarity() != ActiveHigh {
    raise @ir.IrError::AsyncFifoResetMismatch(
      primitive=self.cdc_primitives.length(),
      role~,
      node=reset.signal().id().ordinal(),
    )
  }
}

///|
fn ModuleBuilder::require_fifo_name(
  self : ModuleBuilder,
  name : String,
) -> Unit raise @ir.IrError {
  if name.is_empty() {
    raise EmptyName(kind="CDC primitive")
  }
  for primitive in self.cdc_primitives {
    if primitive.name() == name {
      raise DuplicateCdcPrimitiveName(name)
    }
  }
}

///|
fn ModuleBuilder::require_fifo_reset_timing(
  self : ModuleBuilder,
  reset : SynchronousReset,
  domain : ClockDomain,
  role : String,
) -> Unit raise @ir.IrError {
  for binding in self.input_timings {
    if binding.input() == reset.signal().id() &&
      binding.timing() != SampledIn(domain.id()) {
      raise AsyncFifoResetMismatch(
        primitive=self.cdc_primitives.length(),
        role~,
        node=reset.signal().id().ordinal(),
      )
    }
  }
}

///|
fn ModuleBuilder::fifo_gray_next(
  self : ModuleBuilder,
  binary_next : Signal,
  one : Signal,
) -> Signal raise {
  self.bit_xor(binary_next, self.logical_shift_right(binary_next, one))
}

///|
fn ModuleBuilder::fifo_address(
  self : ModuleBuilder,
  pointer : Signal,
  address_width : Int,
) -> Signal raise {
  self.reinterpret(
    self.slice(pointer, address_width - 1, 0),
    uint(address_width),
  )
}

///|
/// Construct the first checked, coordinated-idle-reset asynchronous FIFO.
///
/// The FIFO is first-word-fall-through: when destination valid is known zero,
/// every visible payload leaf is the exact zero value. The private storage is
/// not represented as a generic dual-clock memory.
pub fn ModuleBuilder::asynchronous_fifo(
  self : ModuleBuilder,
  name : String,
  source_domain : ClockDomain,
  destination_domain : ClockDomain,
  source : ReadyValidForward,
  destination_ready : ReadyValidBackward,
  source_reset : SynchronousReset,
  destination_reset : SynchronousReset,
  depth : Int,
  synchronizer_stages? : Int = 2,
) -> AsyncFifo raise {
  self.require_open()
  self.require_fifo_name(name)
  self.require_clock_domain(source_domain)
  self.require_clock_domain(destination_domain)
  let primitive_ordinal = self.cdc_primitives.length()
  if source_domain.id() == destination_domain.id() {
    raise @ir.IrError::EqualAsyncFifoDomains(
      primitive=primitive_ordinal,
      domain=source_domain.id().ordinal(),
    )
  }
  if !physical_equal(self.owner, source.owner) ||
    !physical_equal(self.owner, destination_ready.owner) {
    raise ForeignSignal
  }
  self.require_ready_valid_control(source.valid())
  self.validate_ready_valid_payload(source.payload())
  self.require_ready_valid_control(destination_ready.ready())
  self.require_fifo_reset(source_reset, "source_reset")
  self.require_fifo_reset(destination_reset, "destination_reset")
  self.require_fifo_reset_timing(
    source_reset, source_domain, "source_reset_timing",
  )
  self.require_fifo_reset_timing(
    destination_reset, destination_domain, "destination_reset_timing",
  )
  if depth < 4 || depth > 1048576 || (depth & (depth - 1)) != 0 {
    raise @ir.IrError::InvalidAsyncFifoDepth(
      primitive=primitive_ordinal,
      actual=depth,
    )
  }
  if synchronizer_stages < 2 || synchronizer_stages > 4 {
    raise @ir.IrError::InvalidAsyncFifoStageCount(
      primitive=primitive_ordinal,
      actual=synchronizer_stages,
    )
  }
  let payload_shape = signal_aggregate_shape(source.payload())
  let source_leaves = source.payload().flatten()
  let mut total_width = 0
  for leaf in source_leaves {
    let leaf_width = leaf.value().signal_type().width().bits()
    if leaf_width > 64 - total_width {
      raise @ir.IrError::AsyncFifoPayloadWidth(
        primitive=primitive_ordinal,
        actual=65,
      )
    }
    total_width += leaf_width
  }
  if total_width < 1 || total_width > 64 {
    raise @ir.IrError::AsyncFifoPayloadWidth(
      primitive=primitive_ordinal,
      actual=total_width,
    )
  }
  let pointer_width = fifo_pointer_width(depth)
  let address_width = pointer_width - 1
  let pointer_type = uint(pointer_width)
  let bit_type = bits(1)
  let write_binary = self.register_state_in(
    source_domain,
    pointer_type,
    reset=source_reset,
  )
  let write_gray = self.register_state_in(
    source_domain,
    pointer_type,
    reset=source_reset,
  )
  let full = self.register_state_in(source_domain, bit_type, reset=source_reset)
  let read_binary = self.register_state_in(
    destination_domain,
    pointer_type,
    reset=destination_reset,
  )
  let read_gray = self.register_state_in(
    destination_domain,
    pointer_type,
    reset=destination_reset,
  )
  let nonempty = self.register_state_in(
    destination_domain,
    bit_type,
    reset=destination_reset,
  )
  let source_ready = self.bit_not(full.value())
  let source_transfer = self.bit_and(source.valid(), source_ready)
  let destination_transfer = self.bit_and(
    nonempty.value(),
    destination_ready.ready(),
  )
  let one = self.constant(pointer_type, 1UL)
  let write_advance = self.add(write_binary.value(), one)
  let write_binary_next = self.mux(
    source_transfer,
    write_advance,
    write_binary.value(),
  )
  self.connect_next(write_binary, write_binary_next)
  let write_gray_next = self.fifo_gray_next(write_binary_next, one)
  self.connect_next(write_gray, write_gray_next)
  let read_advance = self.add(read_binary.value(), one)
  let read_binary_next = self.mux(
    destination_transfer,
    read_advance,
    read_binary.value(),
  )
  self.connect_next(read_binary, read_binary_next)
  let read_gray_next = self.fifo_gray_next(read_binary_next, one)
  self.connect_next(read_gray, read_gray_next)
  let read_gray_stage_signals : Array[Signal] = []
  let mut read_gray_sample = read_gray.value()
  for _ in 0..<synchronizer_stages {
    read_gray_sample = self.register_in(
      source_domain,
      read_gray_sample,
      reset=source_reset,
    )
    read_gray_stage_signals.push(read_gray_sample)
  }
  let write_gray_stage_signals : Array[Signal] = []
  let mut write_gray_sample = write_gray.value()
  for _ in 0..<synchronizer_stages {
    write_gray_sample = self.register_in(
      destination_domain,
      write_gray_sample,
      reset=destination_reset,
    )
    write_gray_stage_signals.push(write_gray_sample)
  }
  let full_mask = self.constant(pointer_type, 3UL << (pointer_width - 2))
  let adjusted_read_gray = self.bit_xor(read_gray_sample, full_mask)
  let full_next = self.equal(write_gray_next, adjusted_read_gray)
  self.connect_next(full, full_next)
  let empty_next = self.equal(read_gray_next, write_gray_sample)
  let nonempty_next = self.bit_not(empty_next)
  self.connect_next(nonempty, nonempty_next)
  let write_address = self.fifo_address(write_binary.value(), address_width)
  let read_address = self.fifo_address(read_binary.value(), address_width)
  let primitive_id = @ir.CdcPrimitiveId::new(primitive_ordinal)
  let raw_reads : Array[Signal] = []
  let visible_payload : Array[Signal] = []
  for leaf, source_leaf in source_leaves {
    let raw = self.append(
      source_leaf.value().signal_type(),
      AsyncFifoRead(primitive=primitive_id, leaf~),
    )
    let zero = self.constant(source_leaf.value().signal_type(), 0UL)
    raw_reads.push(raw)
    visible_payload.push(self.mux(nonempty.value(), raw, zero))
  }
  let destination_payload = source.payload().reconstruct_like(visible_payload)
  let primitive = @ir.AsyncFifoPrimitive::checked(
    primitive_id,
    name,
    source_domain.id(),
    destination_domain.id(),
    depth,
    pointer_width,
    synchronizer_stages,
    CoordinatedIdle,
    source_reset.canonical,
    destination_reset.canonical,
    payload_shape,
    source.valid().id(),
    source_ready.id(),
    source_transfer.id(),
    source_leaves.map(leaf => leaf.value().id()),
    destination_ready.ready().id(),
    nonempty.value().id(),
    destination_transfer.id(),
    raw_reads.map(signal => signal.id()),
    visible_payload.map(signal => signal.id()),
    write_binary.value().id(),
    write_binary_next.id(),
    read_binary.value().id(),
    read_binary_next.id(),
    write_gray.value().id(),
    write_gray_next.id(),
    read_gray.value().id(),
    read_gray_next.id(),
    read_gray_stage_signals.map(stage => stage.id()),
    write_gray_stage_signals.map(stage => stage.id()),
    full.value().id(),
    full_next.id(),
    nonempty.value().id(),
    nonempty_next.id(),
    write_address.id(),
    read_address.id(),
  )
  self.cdc_primitives.push(AsyncFifo(primitive))
  {
    source: { owner: self.owner, ready: source_ready, },
    destination: {
      owner: self.owner,
      valid: nonempty.value(),
      payload: destination_payload,
    },
  }
}
