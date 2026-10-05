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
  rows~ : Int,
  columns~ : Int,
  max_reduction~ : Int,
) -> @ir.Module raise {
  let builder = execute_builder(
    "FluxTileStoredExecute", rows, columns, max_reduction,
  )
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let reset_inactive = builder.bit_not(builder.reset_asserted(reset_signal))
  let inputs = execute_inputs(builder)
  let read_valid = builder.input("result_read_valid", @wire.bits(1))
  let read_row = builder.input("result_read_row", @wire.uint(4))
  let read_column = builder.input("result_read_column", @wire.uint(4))
  let read_id = builder.input("result_read_id", @wire.uint(32))
  let response_ready = builder.input("result_response_ready", @wire.bits(1))
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
  let last_column = builder.equal(
    builder.add(capture_column.value(), execute_constant(builder, 4, 1)),
    core.active_columns,
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
      builder.mux(core.legal, compute_value, done_value),
      builder.mux(
        capture,
        builder.mux(final_capture, done_value, capture_value),
        builder.mux(
          done,
          builder.mux(inputs.completion_ready, idle_value, done_value),
          state.value(),
        ),
      ),
    ),
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
  let memory = builder.synchronous_memory(
    "c_result",
    @wire.sint(32),
    rows * columns,
    domain,
    read_write_policy=ReadOld,
    multi_write_policy=Reject,
    bounds_policy=Fault,
  )
  let width = @ir.MemoryDepth::new(rows * columns).address_width().bits()
  let write_address = stored_address(
    builder,
    capture_row.value(),
    capture_column.value(),
    columns,
    width,
  )
  let write_data = stored_accumulator(
    builder,
    core.accumulators,
    capture_row.value(),
    capture_column.value(),
    rows,
    columns,
  )
  builder.memory_write(
    memory,
    "capture",
    write_address,
    write_data,
    enable=capture,
  )
  let read_enable = execute_and(builder, [read_accept, valid.value(), in_bounds])
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
  execute_accumulator_outputs(builder, core, rows, columns)
  execute_status_outputs(builder, {
    ..core,
    load_a_ready: builder.bit_and(idle, core.load_a_ready),
    load_b_ready: builder.bit_and(idle, core.load_b_ready),
    command_ready,
    completion_valid: done,
  })
  execute_output(builder, "capture_cycles", capture_cycles)
  execute_output(builder, "result_read_ready", read_ready)
  execute_output(builder, "result_response_valid", response_valid)
  execute_output(builder, "result_response_id", response_id)
  execute_output(builder, "result_response_fault", response_fault)
  execute_output(builder, "result_response_data", response_data)
  builder.finish()
}
