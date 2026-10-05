///|
priv struct TransferResponse {
  good : @wire.Signal
  remote : @wire.Signal
  protocol : @wire.Signal
}

///|
fn transfer_response(
  builder : @wire.ModuleBuilder,
  route : ArbiterClientRoute,
  expected_tag : @wire.Signal,
  response_ready : @wire.Signal,
) -> TransferResponse raise {
  let accept = builder.bit_and(response_ready, route.response_valid)
  let malformed = builder.bit_or(
    builder.bit_not(builder.equal(route.response_tag, expected_tag)),
    builder.greater_equal(route.response_fault, execute_constant(builder, 2, 2)),
  )
  let protocol = builder.bit_and(accept, malformed)
  let matched = builder.bit_and(accept, builder.bit_not(malformed))
  let good = builder.bit_and(
    matched,
    builder.equal(route.response_fault, execute_constant(builder, 2, 0)),
  )
  let remote = builder.bit_and(
    matched,
    builder.equal(route.response_fault, execute_constant(builder, 2, 1)),
  )
  { good, remote, protocol, }
}

///|
fn transfer_cursor_limits(
  builder : @wire.ModuleBuilder,
  row : @wire.Signal,
  column : @wire.Signal,
  rows : @wire.Signal,
  columns : @wire.Signal,
) -> (@wire.Signal, @wire.Signal) raise {
  let last_column = builder.equal(
    builder.add(column, execute_constant(builder, 13, 1)),
    columns,
  )
  let last = builder.bit_and(
    last_column,
    builder.equal(builder.add(row, execute_constant(builder, 13, 1)), rows),
  )
  (last_column, last)
}

///|
fn transfer_cursor_update(
  builder : @wire.ModuleBuilder,
  row : @wire.RegisterHandle,
  column : @wire.RegisterHandle,
  accept : @wire.Signal,
  advance : @wire.Signal,
  last_column : @wire.Signal,
) -> Unit raise {
  builder.connect_next(
    row,
    builder.mux(
      accept,
      execute_constant(builder, 13, 0),
      builder.mux(
        builder.bit_and(advance, last_column),
        builder.add(row.value(), execute_constant(builder, 13, 1)),
        row.value(),
      ),
    ),
  )
  builder.connect_next(
    column,
    builder.mux(
      accept,
      execute_constant(builder, 13, 0),
      builder.mux(
        advance,
        builder.mux(
          last_column,
          execute_constant(builder, 13, 0),
          builder.add(column.value(), execute_constant(builder, 13, 1)),
        ),
        column.value(),
      ),
    ),
  )
}

///|
fn concurrent_cursor(
  builder : @wire.ModuleBuilder,
  registers : ConcurrentTransferState,
  accept : @wire.Signal,
  advance : @wire.Signal,
) -> (@wire.Signal, @wire.Signal) raise {
  let (last_column, last) = transfer_cursor_limits(
    builder,
    registers.row.value(),
    registers.column.value(),
    registers.rows.value(),
    registers.columns.value(),
  )
  transfer_cursor_update(
    builder,
    registers.row,
    registers.column,
    accept,
    advance,
    last_column,
  )
  (last_column, last)
}

///|
fn concurrent_transfer_fault(
  builder : @wire.ModuleBuilder,
  ports : ConcurrentTransferPorts,
  rows : Int,
  columns : Int,
  capacity : Int,
  host_bytes : UInt64,
  store : Bool,
  available : @wire.Signal,
) -> @wire.Signal raise {
  let dimensions = if store {
    builder.bit_and(
      portable_positive(builder, ports.rows, rows),
      portable_positive(builder, ports.columns, columns),
    )
  } else {
    builder.mux(
      builder.equal(ports.operand, execute_constant(builder, 1, 0)),
      builder.bit_and(
        portable_positive(builder, ports.rows, rows),
        portable_positive(builder, ports.columns, capacity),
      ),
      builder.bit_and(
        portable_positive(builder, ports.rows, capacity),
        portable_positive(builder, ports.columns, columns),
      ),
    )
  }
  let bounds = portable_transfer_bounds(
    builder,
    ports.base,
    ports.stride,
    ports.rows,
    ports.columns,
    if store {
      4
    } else {
      1
    },
    host_bytes,
  )
  let mut fault = execute_constant(builder, 4, 0)
  for
    (valid, code) in [
      (bounds.in_aperture, 8),
      (bounds.aligned, 7),
      (bounds.stride_valid, 6),
      (available, 5),
      (dimensions, 3),
    ] {
    fault = builder.mux(valid, fault, execute_constant(builder, 4, code))
  }
  fault
}
