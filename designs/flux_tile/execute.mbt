///|
/// Construct a single-command FluxTile load/execute/completion core.
///
/// Each row of A and column of B has a synchronous INT8 memory bank. Loads
/// accept contiguous prefixes and overwrites while Idle. A command checks
/// dimensions and pre-edge loaded prefixes, then clears, prefetches, and
/// advances the systolic wavefront once per ready Run edge. Completion and
/// results remain stable until accepted. See PHASE6_EXECUTE.md for the
/// provisional signal contract; this is not the complete device ABI.
/// A load and command may both accept on one Idle edge. The command checks
/// prefixes before that edge; a simultaneous append cannot satisfy a missing
/// prefix. An overwrite of an initialized entry is visible to later reads.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @flux_tile.execute_tile(rows=1, columns=1, max_reduction=4)
///     .memories()
///     .length(),
///     2,
///   )
/// }
/// ```
pub fn execute_tile(
  rows~ : Int,
  columns~ : Int,
  max_reduction~ : Int,
) -> @ir.Module raise {
  for
    (name, value, maximum) in [
      ("rows", rows, 8),
      ("columns", columns, 8),
      ("max_reduction", max_reduction, 4096),
    ] {
    if value < 1 || value > maximum {
      raise ExecuteTileError::InvalidParameter(name~, value~, maximum~)
    }
  }
  let builder = @wire.ModuleBuilder::new("FluxTileExecute")
  builder.parameter("rows", Signed(rows.to_int64()))
  builder.parameter("columns", Signed(columns.to_int64()))
  builder.parameter("max_reduction", Signed(max_reduction.to_int64()))
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let reset_inactive = builder.bit_not(builder.reset_asserted(reset_signal))
  let bit_type = @wire.bits(1)
  let operand_type = @wire.sint(8)
  let load_a_valid = builder.input("load_a_valid", bit_type)
  let load_a_row = builder.input("load_a_row", @wire.uint(4))
  let load_a_index = builder.input("load_a_index", @wire.uint(13))
  let load_a_data = builder.input("load_a_data", operand_type)
  let load_b_valid = builder.input("load_b_valid", bit_type)
  let load_b_column = builder.input("load_b_column", @wire.uint(4))
  let load_b_index = builder.input("load_b_index", @wire.uint(13))
  let load_b_data = builder.input("load_b_data", operand_type)
  let command_valid = builder.input("command_valid", bit_type)
  let command_rows = builder.input("command_rows", @wire.uint(4))
  let command_columns = builder.input("command_columns", @wire.uint(4))
  let command_reduction = builder.input("command_reduction", @wire.uint(13))
  let command_id = builder.input("command_id", @wire.uint(32))
  let step_ready = builder.input("step_ready", bit_type)
  let completion_ready = builder.input("completion_ready", bit_type)
  let state = builder.register_state_in(domain, @wire.uint(2), reset~)
  let idle_value = execute_constant(builder, 2, 0)
  let clear_value = execute_constant(builder, 2, 1)
  let run_value = execute_constant(builder, 2, 2)
  let done_value = execute_constant(builder, 2, 3)
  let idle = builder.bit_and(
    builder.equal(state.value(), idle_value),
    reset_inactive,
  )
  let clearing = builder.bit_and(
    builder.equal(state.value(), clear_value),
    reset_inactive,
  )
  let running = builder.bit_and(
    builder.equal(state.value(), run_value),
    reset_inactive,
  )
  let done = builder.bit_and(
    builder.equal(state.value(), done_value),
    reset_inactive,
  )
  let accept = builder.bit_and(idle, command_valid)
  let advance = builder.bit_and(running, step_ready)
  let latched_rows = execute_latch(builder, domain, reset, accept, command_rows)
  let latched_columns = execute_latch(
    builder, domain, reset, accept, command_columns,
  )
  let latched_reduction = execute_latch(
    builder, domain, reset, accept, command_reduction,
  )
  let latched_id = execute_latch(builder, domain, reset, accept, command_id)
  let total_input = builder.sub(
    builder.add(
      builder.add(command_reduction, builder.zero_extend(command_rows, 13)),
      builder.zero_extend(command_columns, 13),
    ),
    execute_constant(builder, 13, 2),
  )
  let total_steps = execute_latch(builder, domain, reset, accept, total_input)
  let accepted_steps = execute_counter(
    builder, domain, reset, 13, accept, advance,
  )
  let next_step = builder.add(accepted_steps, execute_constant(builder, 13, 1))
  let final_step = builder.equal(next_step, total_steps)
  let prefetch_next = execute_and(builder, [
    advance,
    builder.bit_not(final_step),
  ])
  let read_launch = builder.bit_or(clearing, prefetch_next)
  let read_step = builder.mux(
    clearing,
    execute_constant(builder, 13, 0),
    next_step,
  )
  let a_banks = execute_operand_banks(
    builder, domain, reset, "a", rows, max_reduction, idle, load_a_valid, load_a_row,
    load_a_index, load_a_data, read_launch, read_step, latched_rows, latched_reduction,
  )
  let b_banks = execute_operand_banks(
    builder, domain, reset, "b", columns, max_reduction, idle, load_b_valid, load_b_column,
    load_b_index, load_b_data, read_launch, read_step, latched_columns, latched_reduction,
  )
  let dimensions_valid = execute_and(builder, [
    builder.greater_than(command_rows, execute_constant(builder, 4, 0)),
    builder.less_equal(command_rows, execute_constant(builder, 4, rows)),
    builder.greater_than(command_columns, execute_constant(builder, 4, 0)),
    builder.less_equal(command_columns, execute_constant(builder, 4, columns)),
    builder.greater_than(command_reduction, execute_constant(builder, 13, 0)),
    builder.less_equal(
      command_reduction,
      execute_constant(builder, 13, max_reduction),
    ),
  ])
  let initialized = builder.bit_and(
    execute_banks_loaded(
      builder,
      a_banks.prefixes,
      command_rows,
      command_reduction,
    ),
    execute_banks_loaded(
      builder,
      b_banks.prefixes,
      command_columns,
      command_reduction,
    ),
  )
  let fault_input = builder.mux(
    dimensions_valid,
    builder.mux(
      initialized,
      execute_constant(builder, 2, 0),
      execute_constant(builder, 2, 2),
    ),
    execute_constant(builder, 2, 1),
  )
  let completion_fault = execute_latch(
    builder, domain, reset, accept, fault_input,
  )
  let legal = builder.bit_and(dimensions_valid, initialized)
  let on_accept = builder.mux(legal, clear_value, done_value)
  let on_done = builder.mux(completion_ready, idle_value, done_value)
  let on_run = builder.mux(
    builder.bit_and(advance, final_step),
    done_value,
    run_value,
  )
  builder.connect_next(
    state,
    builder.mux(
      accept,
      on_accept,
      builder.mux(
        clearing,
        run_value,
        builder.mux(running, on_run, builder.mux(done, on_done, state.value())),
      ),
    ),
  )
  let accumulators = build_systolic_array(
    builder,
    domain,
    reset,
    clearing,
    advance,
    a_banks.data,
    b_banks.data,
    a_banks.valid,
    b_banks.valid,
  )
  for row in 0..<rows {
    for column in 0..<columns {
      execute_output(
        builder,
        "accumulator_\{row}_\{column}",
        accumulators[row * columns + column],
      )
    }
  }
  let elapsed_cycles = execute_counter(
    builder,
    domain,
    reset,
    64,
    accept,
    builder.bit_or(clearing, running),
  )
  let active_cycles = execute_counter(
    builder, domain, reset, 64, accept, advance,
  )
  let stalled = builder.bit_and(running, builder.bit_not(step_ready))
  let stall_cycles = execute_counter(
    builder, domain, reset, 64, accept, stalled,
  )
  execute_output(builder, "load_a_ready", a_banks.load_ready)
  execute_output(builder, "load_b_ready", b_banks.load_ready)
  execute_output(builder, "command_ready", idle)
  execute_output(builder, "completion_valid", done)
  execute_output(builder, "completion_id", latched_id)
  execute_output(builder, "completion_fault", completion_fault)
  execute_output(builder, "accepted_steps", accepted_steps)
  execute_output(builder, "elapsed_cycles", elapsed_cycles)
  execute_output(builder, "active_cycles", active_cycles)
  execute_output(builder, "stall_cycles", stall_cycles)
  builder.finish()
}
