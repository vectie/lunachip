///|
fn stored_result_memory(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  name : String,
  rows : Int32,
  columns : Int32,
  capture : @wire.Signal,
  capture_row : @wire.Signal,
  capture_column : @wire.Signal,
  accumulators : Array[@wire.Signal],
  read_accept : @wire.Signal,
  valid : @wire.Signal,
  in_bounds : @wire.Signal,
  read_row : @wire.Signal,
  read_column : @wire.Signal,
) -> @wire.Signal raise {
  let memory = builder.synchronous_memory(
    name,
    @wire.sint(32),
    rows * columns,
    domain,
    read_write_policy=ReadOld,
    multi_write_policy=Reject,
    bounds_policy=Fault,
  )
  let width = @ir.MemoryDepth::new(rows * columns).address_width().bits()
  let write_address = stored_address(
    builder, capture_row, capture_column, columns, width,
  )
  let write_data = stored_accumulator(
    builder, accumulators, capture_row, capture_column, rows, columns,
  )
  builder.memory_write(
    memory,
    "capture",
    write_address,
    write_data,
    enable=capture,
  )
  let read_enable = execute_and(builder, [read_accept, valid, in_bounds])
  // Validate full-width coordinates before address truncation. Invalid reads
  // never touch SRAM; a pending response holds the last successful read.
  let safe_row = builder.mux(
    read_enable,
    read_row,
    execute_constant(builder, 4, 0),
  )
  let safe_column = builder.mux(
    read_enable,
    read_column,
    execute_constant(builder, 4, 0),
  )
  let read_data = builder.memory_read(
    memory,
    "result",
    stored_address(builder, safe_row, safe_column, columns, width),
    enable=read_enable,
    enable_behavior=HoldLast,
  )
  read_data
}
