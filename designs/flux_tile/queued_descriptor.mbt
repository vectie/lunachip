///|
priv struct QueuedDescriptor {
  opcode : @wire.Signal
  id : @wire.Signal
  rows : @wire.Signal
  columns : @wire.Signal
  reduction : @wire.Signal
  base : @wire.Signal
  stride : @wire.Signal
  syntax_fault : @wire.Signal
}

///|
fn queued_uint_slice(
  builder : @wire.ModuleBuilder,
  lane : @wire.Signal,
  high : Int,
  low : Int,
) -> @wire.Signal raise {
  builder.reinterpret(
    builder.slice(lane, high, low),
    @wire.uint(high - low + 1),
  )
}

///|
fn queued_descriptor(
  builder : @wire.ModuleBuilder,
  lanes : Array[@wire.RegisterHandle],
) -> QueuedDescriptor raise {
  let first = lanes[0].value()
  let dimensions = lanes[1].value()
  let addresses = lanes[2].value()
  let major = queued_uint_slice(builder, first, 7, 0)
  let minor = queued_uint_slice(builder, first, 15, 8)
  let opcode = queued_uint_slice(builder, first, 23, 16)
  let id = queued_uint_slice(builder, first, 63, 32)
  let rows = queued_uint_slice(builder, dimensions, 15, 0)
  let columns = queued_uint_slice(builder, dimensions, 31, 16)
  let reduction = queued_uint_slice(builder, dimensions, 47, 32)
  let version_valid = builder.bit_and(
    builder.equal(major, execute_constant(builder, 8, 0)),
    builder.equal(minor, execute_constant(builder, 8, 1)),
  )
  let reserved_valid = execute_and(builder, [
    builder.equal(
      builder.slice(first, 31, 24),
      builder.constant(@wire.bits(8), 0UL),
    ),
    builder.equal(
      builder.slice(dimensions, 63, 48),
      builder.constant(@wire.bits(16), 0UL),
    ),
    builder.equal(lanes[3].value(), builder.constant(@wire.bits(64), 0UL)),
  ])
  let dimensions_fit = execute_and(builder, [
    builder.less_equal(rows, execute_constant(builder, 16, 8191)),
    builder.less_equal(columns, execute_constant(builder, 16, 8191)),
    builder.less_equal(reduction, execute_constant(builder, 16, 8191)),
  ])
  let syntax_fault = builder.mux(
    version_valid,
    builder.mux(
      reserved_valid,
      builder.mux(
        builder.less_equal(opcode, execute_constant(builder, 8, 4)),
        builder.mux(
          dimensions_fit,
          execute_constant(builder, 4, 0),
          execute_constant(builder, 4, 14),
        ),
        execute_constant(builder, 4, 1),
      ),
      execute_constant(builder, 4, 13),
    ),
    execute_constant(builder, 4, 12),
  )
  {
    opcode: builder.truncate(opcode, 3),
    id,
    rows: builder.truncate(rows, 13),
    columns: builder.truncate(columns, 13),
    reduction: builder.truncate(reduction, 13),
    base: queued_uint_slice(builder, addresses, 31, 0),
    stride: queued_uint_slice(builder, addresses, 63, 32),
    syntax_fault,
  }
}
