///|
fn build_execute_graph(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  reset_inactive : @wire.Signal,
  inputs : ExecuteInputs,
  rows : Int,
  columns : Int,
  max_reduction : Int,
  completion_control : (@wire.Signal, @wire.Signal, @wire.Signal, @wire.Signal) -> @wire.Signal raise,
) -> ExecuteSignals raise {
  let load_a_valid = inputs.load_a_valid
  let load_a_row = inputs.load_a_row
  let load_a_index = inputs.load_a_index
  let load_a_data = inputs.load_a_data
  let load_b_valid = inputs.load_b_valid
  let load_b_column = inputs.load_b_column
  let load_b_index = inputs.load_b_index
  let load_b_data = inputs.load_b_data
  let command_valid = inputs.command_valid
  let command_rows = inputs.command_rows
  let command_columns = inputs.command_columns
  let command_reduction = inputs.command_reduction
  let command_id = inputs.command_id
  let step_ready = inputs.step_ready
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
  let completion_ready = completion_control(
    latched_rows, latched_columns, completion_fault, done,
  )
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
  {
    load_a_ready: a_banks.load_ready,
    load_b_ready: b_banks.load_ready,
    command_ready: idle,
    completion_valid: done,
    completion_id: latched_id,
    completion_fault,
    accepted_steps,
    elapsed_cycles,
    active_cycles,
    stall_cycles,
    accumulators,
    active_rows: latched_rows,
    active_columns: latched_columns,
    legal,
  }
}
