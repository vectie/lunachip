///|
priv struct StoredInputs {
  execute : ExecuteInputs
  read_valid : @wire.Signal
  read_row : @wire.Signal
  read_column : @wire.Signal
  read_id : @wire.Signal
  response_ready : @wire.Signal
}

///|
priv struct StoredSignals {
  execute : ExecuteSignals
  capture_cycles : @wire.Signal
  read_ready : @wire.Signal
  response_valid : @wire.Signal
  response_id : @wire.Signal
  response_fault : @wire.Signal
  response_data : @wire.Signal
}

///|
fn stored_inputs(builder : @wire.ModuleBuilder) -> StoredInputs raise {
  let execute = execute_inputs(builder)
  let read_valid = builder.input("result_read_valid", @wire.bits(1))
  let read_row = builder.input("result_read_row", @wire.uint(4))
  let read_column = builder.input("result_read_column", @wire.uint(4))
  let read_id = builder.input("result_read_id", @wire.uint(32))
  let response_ready = builder.input("result_response_ready", @wire.bits(1))
  { execute, read_valid, read_row, read_column, read_id, response_ready, }
}

///|
fn stored_outputs(
  builder : @wire.ModuleBuilder,
  signals : StoredSignals,
  rows : Int32,
  columns : Int32,
) -> Unit raise {
  execute_accumulator_outputs(builder, signals.execute, rows, columns)
  execute_status_outputs(builder, signals.execute)
  execute_output(builder, "capture_cycles", signals.capture_cycles)
  execute_output(builder, "result_read_ready", signals.read_ready)
  execute_output(builder, "result_response_valid", signals.response_valid)
  execute_output(builder, "result_response_id", signals.response_id)
  execute_output(builder, "result_response_fault", signals.response_fault)
  execute_output(builder, "result_response_data", signals.response_data)
}

///|
/// Construct FluxTile execute with a persistent INT32 result SRAM.
/// Successful completion follows all active-cell capture writes. Result reads
/// accept in Idle or held Done and return a held, one-edge response. Reset
/// invalidates the stored result and pending response, not SRAM contents.
/// See PHASE6_RESULT.md for timing and provisional port semantics.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @flux_tile.stored_execute_tile(rows=1, columns=1, max_reduction=4)
///     .memories()
///     .length(),
///     3,
///   )
/// }
/// ```
pub fn stored_execute_tile(
  rows~ : Int32,
  columns~ : Int32,
  max_reduction~ : Int32,
) -> @ir.Module raise {
  let builder = execute_builder(
    "FluxTileStoredExecute", rows, columns, max_reduction,
  )
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let reset_inactive = builder.bit_not(builder.reset_asserted(reset_signal))
  let inputs = stored_inputs(builder)
  let signals = build_stored_graph(
    builder, domain, reset, reset_inactive, inputs, rows, columns, max_reduction,
  )
  stored_outputs(builder, signals, rows, columns)
  builder.finish()
}
