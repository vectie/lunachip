///|
priv struct QueuedConcurrentDescriptor {
  command : QueuedDescriptor
  a : @wire.Signal
  b : @wire.Signal
  c : @wire.Signal
  op : Array[@wire.Signal]
  unused_valid : @wire.Signal
  dimensions_valid : @wire.Signal
  writer_index : @wire.Signal
  writer : @wire.Signal
  dependency_index : Array[@wire.Signal]
}

///|
fn queued_concurrent_descriptor(
  builder : @wire.ModuleBuilder,
  lanes : Array[@wire.RegisterHandle],
  rows : Int,
  columns : Int,
  capacity : Int,
) -> QueuedConcurrentDescriptor raise {
  let first = lanes[0].value()
  let dimensions = lanes[1].value()
  let addresses = lanes[2].value()
  let slots = lanes[3].value()
  let opcode = queued_uint_slice(builder, first, 23, 16)
  let raw_rows = queued_uint_slice(builder, dimensions, 15, 0)
  let raw_columns = queued_uint_slice(builder, dimensions, 31, 16)
  let raw_reduction = queued_uint_slice(builder, dimensions, 47, 32)
  let version = execute_and(builder, [
    builder.equal(
      queued_uint_slice(builder, first, 7, 0),
      execute_constant(builder, 8, 0),
    ),
    builder.equal(
      queued_uint_slice(builder, first, 15, 8),
      execute_constant(builder, 8, 2),
    ),
  ])
  let reserved = execute_and(builder, [
    builder.equal(
      builder.slice(first, 31, 24),
      builder.constant(@wire.bits(8), 0UL),
    ),
    builder.equal(
      builder.slice(dimensions, 63, 48),
      builder.constant(@wire.bits(16), 0UL),
    ),
    builder.equal(
      builder.slice(slots, 7, 1),
      builder.constant(@wire.bits(7), 0UL),
    ),
    builder.equal(
      builder.slice(slots, 15, 9),
      builder.constant(@wire.bits(7), 0UL),
    ),
    builder.equal(
      builder.slice(slots, 23, 17),
      builder.constant(@wire.bits(7), 0UL),
    ),
    builder.equal(
      builder.slice(slots, 63, 24),
      builder.constant(@wire.bits(40), 0UL),
    ),
  ])
  let fits = execute_and(builder, [
    builder.less_equal(raw_rows, execute_constant(builder, 16, 8191)),
    builder.less_equal(raw_columns, execute_constant(builder, 16, 8191)),
    builder.less_equal(raw_reduction, execute_constant(builder, 16, 8191)),
  ])
  let syntax_fault = builder.mux(
    version,
    builder.mux(
      reserved,
      builder.mux(
        builder.less_equal(opcode, execute_constant(builder, 8, 4)),
        builder.mux(
          fits,
          execute_constant(builder, 4, 0),
          execute_constant(builder, 4, 14),
        ),
        execute_constant(builder, 4, 1),
      ),
      execute_constant(builder, 4, 13),
    ),
    execute_constant(builder, 4, 12),
  )
  let command : QueuedDescriptor = {
    opcode: builder.truncate(opcode, 3),
    id: queued_uint_slice(builder, first, 63, 32),
    rows: builder.truncate(raw_rows, 13),
    columns: builder.truncate(raw_columns, 13),
    reduction: builder.truncate(raw_reduction, 13),
    base: queued_uint_slice(builder, addresses, 31, 0),
    stride: queued_uint_slice(builder, addresses, 63, 32),
    syntax_fault,
  }
  let a = queued_uint_slice(builder, slots, 0, 0)
  let b = queued_uint_slice(builder, slots, 8, 8)
  let c = queued_uint_slice(builder, slots, 16, 16)
  let op = Array::makei(5, index => {
    builder.equal(command.opcode, execute_constant(builder, 3, index))
  })
  let az = builder.equal(a, execute_constant(builder, 1, 0))
  let bz = builder.equal(b, execute_constant(builder, 1, 0))
  let cz = builder.equal(c, execute_constant(builder, 1, 0))
  let no_address = builder.bit_and(
    builder.equal(command.base, execute_constant(builder, 32, 0)),
    builder.equal(command.stride, execute_constant(builder, 32, 0)),
  )
  let no_reduction = builder.equal(
    command.reduction,
    execute_constant(builder, 13, 0),
  )
  let unused_valid = builder.mux(
    op[0],
    execute_and(builder, [no_reduction, bz, cz]),
    builder.mux(
      op[1],
      execute_and(builder, [no_reduction, az, cz]),
      builder.mux(
        op[2],
        no_address,
        builder.mux(
          op[3],
          execute_and(builder, [no_reduction, az, bz]),
          execute_and(builder, [
            az,
            bz,
            cz,
            no_address,
            no_reduction,
            builder.equal(command.rows, execute_constant(builder, 13, 0)),
            builder.equal(command.columns, execute_constant(builder, 13, 0)),
          ]),
        ),
      ),
    ),
  )
  let result_dimensions = builder.bit_and(
    portable_positive(builder, command.rows, rows),
    portable_positive(builder, command.columns, columns),
  )
  let dimensions_valid = builder.mux(
    op[0],
    builder.bit_and(
      portable_positive(builder, command.rows, rows),
      portable_positive(builder, command.columns, capacity),
    ),
    builder.mux(
      op[1],
      builder.bit_and(
        portable_positive(builder, command.rows, capacity),
        portable_positive(builder, command.columns, columns),
      ),
      builder.mux(
        op[2],
        builder.bit_and(
          result_dimensions,
          portable_positive(builder, command.reduction, capacity),
        ),
        builder.mux(
          op[3],
          result_dimensions,
          builder.constant(@wire.bits(1), 1UL),
        ),
      ),
    ),
  )
  let writer_index = builder.mux(
    op[0],
    builder.zero_extend(a, 3),
    builder.mux(
      op[1],
      builder.add(builder.zero_extend(b, 3), execute_constant(builder, 3, 2)),
      builder.add(builder.zero_extend(c, 3), execute_constant(builder, 3, 4)),
    ),
  )
  {
    command,
    a,
    b,
    c,
    op,
    unused_valid,
    dimensions_valid,
    writer_index,
    writer: builder.bit_or(builder.bit_or(op[0], op[1]), op[2]),
    dependency_index: [
      builder.mux(
        op[3],
        builder.add(builder.zero_extend(c, 3), execute_constant(builder, 3, 4)),
        builder.zero_extend(a, 3),
      ),
      builder.add(builder.zero_extend(b, 3), execute_constant(builder, 3, 2)),
    ],
  }
}
