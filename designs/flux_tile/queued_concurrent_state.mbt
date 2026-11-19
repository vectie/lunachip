///|
priv struct QueuedConcurrentEntry {
  valid : @wire.RegisterHandle
  terminal : @wire.RegisterHandle
  ticket : @wire.RegisterHandle
  id : @wire.RegisterHandle
  fault : @wire.RegisterHandle
  progress : @wire.RegisterHandle
  address : @wire.RegisterHandle
}

///|
priv struct QueuedConcurrentWriter {
  status : @wire.RegisterHandle
  ticket : @wire.RegisterHandle
}

///|
priv struct QueuedConcurrentState {
  head_state : @wire.RegisterHandle
  lanes : Array[@wire.RegisterHandle]
  head_ticket : @wire.RegisterHandle
  head_entry : @wire.RegisterHandle
  next_ticket : @wire.RegisterHandle
  read_pointer : @wire.RegisterHandle
  write_pointer : @wire.RegisterHandle
  occupancy : @wire.RegisterHandle
  entries : Array[QueuedConcurrentEntry]
  writers : Array[QueuedConcurrentWriter]
  dependency_status : Array[@wire.RegisterHandle]
  dependency_ticket : Array[@wire.RegisterHandle]
}

///|
fn queued_concurrent_state(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  depth : Int32,
) -> QueuedConcurrentState raise {
  {
    head_state: builder.register_state_in(domain, @wire.uint(2), reset~),
    lanes: Array::makei(4, _ => {
      builder.register_state_in(domain, @wire.bits(64), reset~)
    }),
    head_ticket: builder.register_state_in(domain, @wire.uint(32), reset~),
    head_entry: builder.register_state_in(domain, @wire.uint(5), reset~),
    next_ticket: builder.register_state_in(domain, @wire.uint(32), reset~),
    read_pointer: builder.register_state_in(domain, @wire.uint(5), reset~),
    write_pointer: builder.register_state_in(domain, @wire.uint(5), reset~),
    occupancy: builder.register_state_in(domain, @wire.uint(5), reset~),
    entries: Array::makei(depth, _ => {
      valid: builder.register_state_in(domain, @wire.bits(1), reset~),
      terminal: builder.register_state_in(domain, @wire.bits(1), reset~),
      ticket: builder.register_state_in(domain, @wire.uint(32), reset~),
      id: builder.register_state_in(domain, @wire.uint(32), reset~),
      fault: builder.register_state_in(domain, @wire.uint(4), reset~),
      progress: builder.register_state_in(domain, @wire.uint(32), reset~),
      address: builder.register_state_in(domain, @wire.uint(32), reset~),
    }),
    writers: Array::makei(6, _ => {
      status: builder.register_state_in(domain, @wire.uint(2), reset~),
      ticket: builder.register_state_in(domain, @wire.uint(32), reset~),
    }),
    dependency_status: Array::makei(2, _ => {
      builder.register_state_in(domain, @wire.uint(2), reset~)
    }),
    dependency_ticket: Array::makei(2, _ => {
      builder.register_state_in(domain, @wire.uint(32), reset~)
    }),
  }
}

///|
fn queued_concurrent_select(
  builder : @wire.ModuleBuilder,
  index : @wire.Signal,
  values : Array[@wire.Signal],
) -> @wire.Signal raise {
  let mut selected = values[0]
  for ordinal in 1..<values.length() {
    selected = builder.mux(
      builder.equal(
        index,
        builder.constant(index.signal_type(), ordinal.to_uint64()),
      ),
      values[ordinal],
      selected,
    )
  }
  selected
}

///|
fn queued_concurrent_pointer(
  builder : @wire.ModuleBuilder,
  pointer : @wire.RegisterHandle,
  advance : @wire.Signal,
  depth : Int32,
) -> Unit raise {
  portable_hold(
    builder,
    pointer,
    advance,
    builder.mux(
      builder.equal(pointer.value(), execute_constant(builder, 5, depth - 1)),
      execute_constant(builder, 5, 0),
      builder.add(pointer.value(), execute_constant(builder, 5, 1)),
    ),
  )
}
