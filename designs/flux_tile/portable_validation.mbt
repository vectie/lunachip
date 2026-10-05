///|
fn portable_positive(
  builder : @wire.ModuleBuilder,
  signal : @wire.Signal,
  maximum : Int,
) -> @wire.Signal raise {
  builder.bit_and(
    builder.greater_than(signal, execute_constant(builder, 13, 0)),
    builder.less_equal(signal, execute_constant(builder, 13, maximum)),
  )
}

///|
fn portable_preflight(
  builder : @wire.ModuleBuilder,
  command : PortableCommand,
  op : Array[@wire.Signal],
  registers : PortableRegisters,
  rows : Int,
  columns : Int,
  capacity : Int,
  host_bytes : UInt64,
) -> @wire.Signal raise {
  let zero13 = execute_constant(builder, 13, 0)
  let zero32 = execute_constant(builder, 32, 0)
  let load = builder.bit_or(op[0], op[1])
  let transfer = builder.bit_or(load, op[3])
  let no_address = builder.bit_and(
    builder.equal(command.base, zero32),
    builder.equal(command.stride, zero32),
  )
  let unused_valid = builder.mux(
    op[4],
    execute_and(builder, [
      no_address,
      builder.equal(command.rows, zero13),
      builder.equal(command.columns, zero13),
      builder.equal(command.reduction, zero13),
    ]),
    builder.mux(op[2], no_address, builder.equal(command.reduction, zero13)),
  )
  let a_dimensions = builder.bit_and(
    portable_positive(builder, command.rows, rows),
    portable_positive(builder, command.columns, capacity),
  )
  let b_dimensions = builder.bit_and(
    portable_positive(builder, command.rows, capacity),
    portable_positive(builder, command.columns, columns),
  )
  let result_dimensions = builder.bit_and(
    portable_positive(builder, command.rows, rows),
    portable_positive(builder, command.columns, columns),
  )
  let dimensions_valid = builder.mux(
    op[0],
    a_dimensions,
    builder.mux(
      op[1],
      b_dimensions,
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
  let operands = execute_and(builder, [
    registers.a_valid.value(),
    registers.b_valid.value(),
    builder.equal(registers.a_rows.value(), command.rows),
    builder.equal(registers.a_columns.value(), command.reduction),
    builder.equal(registers.b_rows.value(), command.reduction),
    builder.equal(registers.b_columns.value(), command.columns),
  ])
  let result = execute_and(builder, [
    registers.c_valid.value(),
    builder.equal(registers.c_rows.value(), command.rows),
    builder.equal(registers.c_columns.value(), command.columns),
  ])
  let available = builder.mux(
    op[2],
    operands,
    builder.mux(op[3], result, builder.constant(@wire.bits(1), 1UL)),
  )
  let byte_bounds = portable_transfer_bounds(
    builder,
    command.base,
    command.stride,
    command.rows,
    command.columns,
    1,
    host_bytes,
  )
  let word_bounds = portable_transfer_bounds(
    builder,
    command.base,
    command.stride,
    command.rows,
    command.columns,
    4,
    host_bytes,
  )
  let stride_valid = builder.mux(
    op[3],
    word_bounds.stride_valid,
    byte_bounds.stride_valid,
  )
  let aligned = builder.mux(op[3], word_bounds.aligned, byte_bounds.aligned)
  let in_aperture = builder.mux(
    op[3],
    word_bounds.in_aperture,
    byte_bounds.in_aperture,
  )
  let mut fault = execute_constant(builder, 4, 0)
  for
    (valid, code) in [
      (builder.bit_or(builder.bit_not(transfer), in_aperture), 8),
      (builder.bit_or(builder.bit_not(transfer), aligned), 7),
      (builder.bit_or(builder.bit_not(transfer), stride_valid), 6),
      (available, -1),
      (dimensions_valid, 3),
      (unused_valid, 2),
      (builder.less_equal(command.opcode, execute_constant(builder, 3, 4)), 1),
    ] {
    let rejected = if code == -1 {
      builder.mux(
        op[2],
        execute_constant(builder, 4, 4),
        execute_constant(builder, 4, 5),
      )
    } else {
      execute_constant(builder, 4, code)
    }
    fault = builder.mux(valid, fault, rejected)
  }
  fault
}
