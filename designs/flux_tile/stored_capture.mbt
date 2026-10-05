///|
fn stored_capture_updates(
  builder : @wire.ModuleBuilder,
  state : @wire.RegisterHandle,
  capture_row : @wire.RegisterHandle,
  capture_column : @wire.RegisterHandle,
  accept : @wire.Signal,
  capture : @wire.Signal,
  final_capture : @wire.Signal,
  active_columns : @wire.Signal,
  done : @wire.Signal,
  completion_ready : @wire.Signal,
  legal : @wire.Signal,
) -> Unit raise {
  let last_column = builder.equal(
    builder.add(capture_column.value(), execute_constant(builder, 4, 1)),
    active_columns,
  )
  builder.connect_next(
    capture_row,
    builder.mux(
      accept,
      execute_constant(builder, 4, 0),
      builder.mux(
        builder.bit_and(capture, last_column),
        builder.add(capture_row.value(), execute_constant(builder, 4, 1)),
        capture_row.value(),
      ),
    ),
  )
  builder.connect_next(
    capture_column,
    builder.mux(
      accept,
      execute_constant(builder, 4, 0),
      builder.mux(
        capture,
        builder.mux(
          last_column,
          execute_constant(builder, 4, 0),
          builder.add(capture_column.value(), execute_constant(builder, 4, 1)),
        ),
        capture_column.value(),
      ),
    ),
  )
  let idle_value = execute_constant(builder, 2, 0)
  let compute_value = execute_constant(builder, 2, 1)
  let capture_value = execute_constant(builder, 2, 2)
  let done_value = execute_constant(builder, 2, 3)
  builder.connect_next(
    state,
    builder.mux(
      accept,
      builder.mux(legal, compute_value, done_value),
      builder.mux(
        capture,
        builder.mux(final_capture, done_value, capture_value),
        builder.mux(
          done,
          builder.mux(completion_ready, idle_value, done_value),
          state.value(),
        ),
      ),
    ),
  )
}
