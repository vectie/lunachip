///|
priv struct QueuedConcurrentDispatch {
  states : Array[@wire.Signal]
  reserve : @wire.Signal
  local_fault : @wire.Signal
  fence_ready : @wire.Signal
  inputs : ConcurrentCommandInputs
}

///|
fn queued_concurrent_dispatch(
  builder : @wire.ModuleBuilder,
  registers : QueuedConcurrentState,
  descriptor : QueuedConcurrentDescriptor,
  reset_inactive : @wire.Signal,
  depth : Int,
) -> QueuedConcurrentDispatch raise {
  let states = Array::makei(4, index => {
    execute_and(builder, [
      reset_inactive,
      builder.equal(
        registers.head_state.value(),
        execute_constant(builder, 2, index),
      ),
    ])
  })
  let reserve = builder.bit_and(
    states[2],
    builder.less_than(
      registers.occupancy.value(),
      execute_constant(builder, 5, depth),
    ),
  )
  let dependency_states = Array::makei(2, index => {
    let current_status = queued_concurrent_select(
      builder,
      descriptor.dependency_index[index],
      registers.writers.map(writer => writer.status.value()),
    )
    let current_ticket = queued_concurrent_select(
      builder,
      descriptor.dependency_index[index],
      registers.writers.map(writer => writer.ticket.value()),
    )
    let resolved = builder.mux(
      builder.equal(current_ticket, registers.dependency_ticket[index].value()),
      current_status,
      execute_constant(builder, 2, 3),
    )
    builder.mux(
      builder.equal(
        registers.dependency_status[index].value(),
        execute_constant(builder, 2, 1),
      ),
      resolved,
      registers.dependency_status[index].value(),
    )
  })
  let source0_good = builder.equal(
    dependency_states[0],
    execute_constant(builder, 2, 2),
  )
  let source1_good = builder.equal(
    dependency_states[1],
    execute_constant(builder, 2, 2),
  )
  let source0_pending = builder.equal(
    dependency_states[0],
    execute_constant(builder, 2, 1),
  )
  let source1_pending = builder.equal(
    dependency_states[1],
    execute_constant(builder, 2, 1),
  )
  let unavailable0 = builder.bit_not(
    builder.bit_or(source0_good, source0_pending),
  )
  let unavailable1 = builder.bit_not(
    builder.bit_or(source1_good, source1_pending),
  )
  let dependency_bad = builder.mux(
    descriptor.op[2],
    builder.bit_or(unavailable0, unavailable1),
    builder.bit_and(descriptor.op[3], unavailable0),
  )
  let dependencies_ready = builder.mux(
    descriptor.op[2],
    builder.bit_and(source0_good, source1_good),
    builder.mux(
      descriptor.op[3],
      source0_good,
      builder.constant(@wire.bits(1), 1UL),
    ),
  )
  let semantic_fault = builder.mux(
    descriptor.unused_valid,
    builder.mux(
      descriptor.dimensions_valid,
      builder.mux(
        dependency_bad,
        builder.mux(
          descriptor.op[2],
          execute_constant(builder, 4, 4),
          execute_constant(builder, 4, 5),
        ),
        execute_constant(builder, 4, 0),
      ),
      execute_constant(builder, 4, 3),
    ),
    execute_constant(builder, 4, 2),
  )
  let local_fault = builder.mux(
    builder.equal(
      descriptor.command.syntax_fault,
      execute_constant(builder, 4, 0),
    ),
    semantic_fault,
    descriptor.command.syntax_fault,
  )
  let issue = execute_and(builder, [
    states[3],
    dependencies_ready,
    builder.equal(local_fault, execute_constant(builder, 4, 0)),
  ])
  let older_terminal = registers.entries.map(entry => {
    builder.bit_or(
      builder.bit_not(entry.valid.value()),
      builder.bit_or(
        entry.terminal.value(),
        builder.equal(entry.ticket.value(), registers.head_ticket.value()),
      ),
    )
  })
  let command = descriptor.command
  let operand = builder.reinterpret(
    builder.slice(command.opcode, 0, 0),
    @wire.uint(1),
  )
  let transfer = (
    valid : @wire.Signal,
    operand : @wire.Signal,
    slot : @wire.Signal,
  ) => ConcurrentTransferPorts::{
    valid,
    operand,
    slot,
    id: registers.head_ticket.value(),
    rows: command.rows,
    columns: command.columns,
    base: command.base,
    stride: command.stride,
    completion_ready: reset_inactive,
  }
  {
    states,
    reserve,
    local_fault,
    fence_ready: execute_and(builder, older_terminal),
    inputs: {
      load: transfer(
        builder.bit_and(
          issue,
          builder.bit_or(descriptor.op[0], descriptor.op[1]),
        ),
        operand,
        builder.mux(descriptor.op[0], descriptor.a, descriptor.b),
      ),
      compute: {
        valid: builder.bit_and(issue, descriptor.op[2]),
        id: registers.head_ticket.value(),
        a: descriptor.a,
        b: descriptor.b,
        c: descriptor.c,
        rows: command.rows,
        columns: command.columns,
        reduction: command.reduction,
        completion_ready: reset_inactive,
      },
      store: transfer(
        builder.bit_and(issue, descriptor.op[3]),
        operand,
        descriptor.c,
      ),
    },
  }
}

///|
fn queued_concurrent_head_connect(
  builder : @wire.ModuleBuilder,
  registers : QueuedConcurrentState,
  dispatch : QueuedConcurrentDispatch,
  fifo : Array[@memory.FifoSignals],
  engine : ConcurrentEngineSignals,
  reject : @wire.Signal,
  fence : @wire.Signal,
) -> Unit raise {
  let pop = builder.bit_and(
    dispatch.states[0],
    execute_and(builder, fifo.map(lane => lane.pop_ready())),
  )
  let capture = builder.bit_and(
    dispatch.states[1],
    execute_and(builder, fifo.map(lane => lane.response_valid())),
  )
  for index in 0..<4 {
    portable_hold(
      builder,
      registers.lanes[index],
      capture,
      fifo[index].response_data(),
    )
  }
  let issue = builder.bit_or(
    builder.bit_and(dispatch.inputs.load.valid, engine.load.command_ready),
    builder.bit_or(
      builder.bit_and(
        dispatch.inputs.compute.valid,
        engine.compute.command_ready,
      ),
      builder.bit_and(dispatch.inputs.store.valid, engine.store.command_ready),
    ),
  )
  let finish = builder.bit_or(issue, builder.bit_or(reject, fence))
  let hold = registers.head_state.value()
  let transitions = [
    builder.mux(pop, execute_constant(builder, 2, 1), hold),
    builder.mux(capture, execute_constant(builder, 2, 2), hold),
    builder.mux(dispatch.reserve, execute_constant(builder, 2, 3), hold),
    builder.mux(finish, execute_constant(builder, 2, 0), hold),
  ]
  let mut next = hold
  for index in 0..<4 {
    next = builder.mux(dispatch.states[index], transitions[index], next)
  }
  builder.connect_next(registers.head_state, next)
  portable_hold(
    builder,
    registers.head_ticket,
    dispatch.reserve,
    registers.next_ticket.value(),
  )
  portable_hold(
    builder,
    registers.head_entry,
    dispatch.reserve,
    registers.write_pointer.value(),
  )
  portable_hold(
    builder,
    registers.next_ticket,
    dispatch.reserve,
    builder.add(registers.next_ticket.value(), execute_constant(builder, 32, 1)),
  )
}
