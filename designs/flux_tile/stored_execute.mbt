///|
fn build_stored_graph(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  reset_inactive : @wire.Signal,
  ports : StoredInputs,
  rows : Int32,
  columns : Int32,
  max_reduction : Int32,
) -> StoredSignals raise {
  let inputs = ports.execute
  let read_valid = ports.read_valid
  let read_row = ports.read_row
  let read_column = ports.read_column
  let read_id = ports.read_id
  let response_ready = ports.response_ready
  let state = builder.register_state_in(domain, @wire.uint(2), reset~)
  let capture_row = builder.register_state_in(domain, @wire.uint(4), reset~)
  let capture_column = builder.register_state_in(domain, @wire.uint(4), reset~)
  let pending = builder.register_state_in(domain, @wire.bits(1), reset~)
  let idle = builder.bit_and(
    builder.equal(state.value(), execute_constant(builder, 2, 0)),
    reset_inactive,
  )
  let computing = builder.bit_and(
    builder.equal(state.value(), execute_constant(builder, 2, 1)),
    reset_inactive,
  )
  let capturing = builder.bit_and(
    builder.equal(state.value(), execute_constant(builder, 2, 2)),
    reset_inactive,
  )
  let done = builder.bit_and(
    builder.equal(state.value(), execute_constant(builder, 2, 3)),
    reset_inactive,
  )
  let command_window = execute_and(builder, [
    idle,
    builder.bit_not(read_valid),
    builder.bit_not(pending.value()),
  ])
  let core_inputs = {
    ..inputs,
    load_a_valid: builder.bit_and(inputs.load_a_valid, idle),
    load_b_valid: builder.bit_and(inputs.load_b_valid, idle),
    command_valid: builder.bit_and(inputs.command_valid, command_window),
  }
  // The completion hook is built at the original core ack node position.
  // Standalone execute supplies its input unchanged, preserving its graph.
  let core = build_execute_graph(
    builder,
    domain,
    reset,
    reset_inactive,
    core_inputs,
    rows,
    columns,
    max_reduction,
    (active_rows, active_columns, fault, core_done) => {
      let success = builder.equal(fault, execute_constant(builder, 2, 0))
      let capture = builder.bit_or(
        capturing,
        execute_and(builder, [computing, core_done, success]),
      )
      let final_capture = stored_capture_final(
        builder,
        capture,
        capture_row.value(),
        capture_column.value(),
        active_rows,
        active_columns,
      )
      let fault_ack = execute_and(builder, [
        done,
        inputs.completion_ready,
        builder.bit_not(success),
      ])
      builder.bit_or(final_capture, fault_ack)
    },
  )
  let command_ready = builder.bit_and(command_window, core.command_ready)
  let accept = builder.bit_and(command_ready, inputs.command_valid)
  let success = builder.equal(
    core.completion_fault,
    execute_constant(builder, 2, 0),
  )
  let capture = builder.bit_or(
    capturing,
    execute_and(builder, [computing, core.completion_valid, success]),
  )
  // Core Done is already visible before this edge, so the first write needs
  // no entry bubble. Core completion remains held through the final write.
  let final_capture = stored_capture_final(
    builder,
    capture,
    capture_row.value(),
    capture_column.value(),
    core.active_rows,
    core.active_columns,
  )
  stored_capture_updates(
    builder,
    state,
    capture_row,
    capture_column,
    accept,
    capture,
    final_capture,
    core.active_columns,
    done,
    inputs.completion_ready,
    core.legal,
  )
  let valid = builder.register_state_in(domain, @wire.bits(1), reset~)
  // A rejected command cannot discard a prior successful stored result.
  let invalidate = builder.bit_and(accept, core.legal)
  builder.connect_next(
    valid,
    builder.mux(
      invalidate,
      builder.constant(@wire.bits(1), 0UL),
      builder.mux(
        final_capture,
        builder.constant(@wire.bits(1), 1UL),
        valid.value(),
      ),
    ),
  )
  let stored_rows = execute_latch(
    builder,
    domain,
    reset,
    final_capture,
    core.active_rows,
  )
  let stored_columns = execute_latch(
    builder,
    domain,
    reset,
    final_capture,
    core.active_columns,
  )
  let read_ready = execute_and(builder, [
    builder.bit_or(idle, done),
    builder.bit_not(pending.value()),
  ])
  let read_accept = builder.bit_and(read_ready, read_valid)
  let in_bounds = builder.bit_and(
    builder.less_than(read_row, stored_rows),
    builder.less_than(read_column, stored_columns),
  )
  let read_fault = builder.mux(
    valid.value(),
    builder.mux(
      in_bounds,
      execute_constant(builder, 2, 0),
      execute_constant(builder, 2, 1),
    ),
    execute_constant(builder, 2, 2),
  )
  let response_fault = execute_latch(
    builder, domain, reset, read_accept, read_fault,
  )
  let response_id = execute_latch(builder, domain, reset, read_accept, read_id)
  builder.connect_next(
    pending,
    builder.mux(
      read_accept,
      builder.constant(@wire.bits(1), 1UL),
      builder.bit_and(pending.value(), builder.bit_not(response_ready)),
    ),
  )
  let read_data = stored_result_memory(
    builder,
    domain,
    "c_result",
    rows,
    columns,
    capture,
    capture_row.value(),
    capture_column.value(),
    core.accumulators,
    read_accept,
    valid.value(),
    in_bounds,
    read_row,
    read_column,
  )
  let response_valid = builder.bit_and(pending.value(), reset_inactive)
  let response_data = builder.mux(
    builder.bit_and(
      response_valid,
      builder.equal(response_fault, execute_constant(builder, 2, 0)),
    ),
    read_data,
    builder.constant(@wire.sint(32), 0UL),
  )
  let capture_cycles = execute_counter(
    builder, domain, reset, 7, accept, capture,
  )
  let execute = {
    ..core,
    load_a_ready: builder.bit_and(idle, core.load_a_ready),
    load_b_ready: builder.bit_and(idle, core.load_b_ready),
    command_ready,
    completion_valid: done,
  }
  {
    execute,
    capture_cycles,
    read_ready,
    response_valid,
    response_id,
    response_fault,
    response_data,
  }
}
