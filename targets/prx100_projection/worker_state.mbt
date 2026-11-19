///|
priv struct WorkerState {
  state : @wire.RegisterHandle
  tile : @wire.RegisterHandle
  fill : @wire.RegisterHandle
  prefetch : @wire.RegisterHandle
  // 0 joins operand fill/consumer release, 1 patches packets, 2 publishes,
  // 3 holds the next tile's lease until current result collection completes.
  ahead : @wire.RegisterHandle
  descriptor : @wire.RegisterHandle
  channel : @wire.RegisterHandle
  ordinal : @wire.RegisterHandle
  retired : @wire.RegisterHandle
  completed : @wire.RegisterHandle
  partials : @wire.RegisterHandle
  partial : Array[@wire.RegisterHandle]
  sums : Array[@wire.RegisterHandle]
  error : @wire.RegisterHandle
  cycles : @wire.RegisterHandle
  ddr_wait : @wire.RegisterHandle
  core_wait : @wire.RegisterHandle
  staging_cycles : @wire.RegisterHandle
  compute : @wire.RegisterHandle
  staged : @wire.RegisterHandle
  reads : @wire.RegisterHandle
  writes : @wire.RegisterHandle
}

///|
fn worker_state(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
) -> WorkerState raise {
  fn reg(width : Int32) -> @wire.RegisterHandle raise {
    b.register_state_in(d, @wire.uint(width), reset~)
  }
  {
    state: reg(5),
    tile: reg(6),
    fill: reg(6),
    prefetch: reg(2),
    ahead: reg(2),
    descriptor: reg(5),
    channel: reg(3),
    ordinal: reg(3),
    retired: reg(32),
    completed: reg(7),
    partials: reg(32),
    partial: Array::makei(4, _ => reg(32)),
    sums: Array::makei(8, _ => reg(32)),
    error: reg(8),
    cycles: reg(64),
    ddr_wait: reg(64),
    core_wait: reg(64),
    staging_cycles: reg(64),
    compute: reg(64),
    staged: reg(32),
    reads: reg(32),
    writes: reg(32),
  }
}

///|
fn increment(
  b : @wire.ModuleBuilder,
  r : @wire.RegisterHandle,
  clear : @wire.Signal,
  enable : @wire.Signal,
  amount : @wire.Signal,
) -> Unit raise {
  b.connect_next(
    r,
    b.mux(
      clear,
      b.constant(r.value().signal_type(), 0UL),
      b.mux(enable, b.add(r.value(), amount), r.value()),
    ),
  )
}

///|
fn table(
  b : @wire.ModuleBuilder,
  index : @wire.Signal,
  values : ArrayView[@wire.Signal],
) -> @wire.Signal raise {
  let mut value = values[0]
  for i, x in values {
    value = b.mux(eq(b, index, i.to_uint64()), x, value)
  }
  value
}

///|
priv struct Worker {
  request_valid : @wire.Signal
  request_write : @wire.Signal
  request_burst : @wire.Signal
  request_address : @wire.Signal
  request_data : @wire.Signal
  request_more : Array[@wire.Signal]
  busy : @wire.Signal
  idle : @wire.Signal
  registers : Array[(UInt64, @wire.Signal)]
  prefetch_write : @wire.Signal
}
