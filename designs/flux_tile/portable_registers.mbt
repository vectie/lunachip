///|
priv struct PortableRegisters {
  state : @wire.RegisterHandle
  row : @wire.RegisterHandle
  column : @wire.RegisterHandle
  tag : @wire.RegisterHandle
  expected_tag : @wire.RegisterHandle
  load_byte : @wire.RegisterHandle
  bytes_completed : @wire.RegisterHandle
  fault : @wire.RegisterHandle
  fault_address : @wire.RegisterHandle
  locked : @wire.RegisterHandle
  a_valid : @wire.RegisterHandle
  a_rows : @wire.RegisterHandle
  a_columns : @wire.RegisterHandle
  b_valid : @wire.RegisterHandle
  b_rows : @wire.RegisterHandle
  b_columns : @wire.RegisterHandle
  c_valid : @wire.RegisterHandle
  c_rows : @wire.RegisterHandle
  c_columns : @wire.RegisterHandle
}

///|
fn portable_registers(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
) -> PortableRegisters raise {
  {
    state: builder.register_state_in(domain, @wire.uint(4), reset~),
    row: builder.register_state_in(domain, @wire.uint(13), reset~),
    column: builder.register_state_in(domain, @wire.uint(13), reset~),
    tag: builder.register_state_in(domain, @wire.uint(32), reset~),
    expected_tag: builder.register_state_in(domain, @wire.uint(32), reset~),
    load_byte: builder.register_state_in(domain, @wire.bits(32), reset~),
    bytes_completed: builder.register_state_in(domain, @wire.uint(32), reset~),
    fault: builder.register_state_in(domain, @wire.uint(4), reset~),
    fault_address: builder.register_state_in(domain, @wire.uint(32), reset~),
    locked: builder.register_state_in(domain, @wire.bits(1), reset~),
    a_valid: builder.register_state_in(domain, @wire.bits(1), reset~),
    a_rows: builder.register_state_in(domain, @wire.uint(13), reset~),
    a_columns: builder.register_state_in(domain, @wire.uint(13), reset~),
    b_valid: builder.register_state_in(domain, @wire.bits(1), reset~),
    b_rows: builder.register_state_in(domain, @wire.uint(13), reset~),
    b_columns: builder.register_state_in(domain, @wire.uint(13), reset~),
    c_valid: builder.register_state_in(domain, @wire.bits(1), reset~),
    c_rows: builder.register_state_in(domain, @wire.uint(13), reset~),
    c_columns: builder.register_state_in(domain, @wire.uint(13), reset~),
  }
}

///|
fn portable_hold(
  builder : @wire.ModuleBuilder,
  handle : @wire.RegisterHandle,
  update : @wire.Signal,
  value : @wire.Signal,
) -> Unit raise {
  builder.connect_next(handle, builder.mux(update, value, handle.value()))
}

///|
fn portable_slot(
  builder : @wire.ModuleBuilder,
  valid : @wire.RegisterHandle,
  rows : @wire.RegisterHandle,
  columns : @wire.RegisterHandle,
  invalidate : @wire.Signal,
  finish : @wire.Signal,
  command : PortableCommand,
) -> Unit raise {
  builder.connect_next(
    valid,
    builder.mux(
      invalidate,
      builder.constant(@wire.bits(1), 0UL),
      builder.mux(finish, builder.constant(@wire.bits(1), 1UL), valid.value()),
    ),
  )
  portable_hold(builder, rows, finish, command.rows)
  portable_hold(builder, columns, finish, command.columns)
}
