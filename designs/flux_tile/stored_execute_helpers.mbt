///|
fn stored_capture_final(
  builder : @wire.ModuleBuilder,
  capture : @wire.Signal,
  row : @wire.Signal,
  column : @wire.Signal,
  rows : @wire.Signal,
  columns : @wire.Signal,
) -> @wire.Signal raise {
  execute_and(builder, [
    capture,
    builder.equal(builder.add(row, execute_constant(builder, 4, 1)), rows),
    builder.equal(builder.add(column, execute_constant(builder, 4, 1)), columns),
  ])
}

///|
fn stored_address(
  builder : @wire.ModuleBuilder,
  row : @wire.Signal,
  column : @wire.Signal,
  columns : Int32,
  width : Int32,
) -> @wire.Signal raise {
  let address = builder.add(
    builder.mul_low(
      builder.zero_extend(row, 8),
      execute_constant(builder, 8, columns),
    ),
    builder.zero_extend(column, 8),
  )
  builder.truncate(address, width)
}

///|
fn stored_accumulator(
  builder : @wire.ModuleBuilder,
  accumulators : Array[@wire.Signal],
  row : @wire.Signal,
  column : @wire.Signal,
  rows : Int32,
  columns : Int32,
) -> @wire.Signal raise {
  let mut selected = builder.constant(@wire.sint(32), 0UL)
  for i in 0..<rows {
    for j in 0..<columns {
      let at_cell = builder.bit_and(
        builder.equal(row, execute_constant(builder, 4, i)),
        builder.equal(column, execute_constant(builder, 4, j)),
      )
      selected = builder.mux(at_cell, accumulators[i * columns + j], selected)
    }
  }
  selected
}
