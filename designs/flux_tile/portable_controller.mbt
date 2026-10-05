///|
fn portable_controller(
  builder : @wire.ModuleBuilder,
  registers : PortableRegisters,
  ports : PortablePorts,
  states : Array[@wire.Signal],
  op : Array[@wire.Signal],
  accept : @wire.Signal,
  preflight : @wire.Signal,
  core : StoredSignals,
  events : PortableEvents,
  address : @wire.Signal,
  storage : PortableStorageControl,
) -> Unit raise {
  let terminal_response = builder.bit_or(
    events.response_remote,
    events.response_protocol,
  )
  let finish_load = builder.bit_and(events.load_commit, events.last)
  let finish_store = execute_and(builder, [
    states[9],
    events.response_good,
    events.last,
  ])
  let finish_compute = builder.bit_and(
    events.compute_done,
    builder.bit_not(events.internal_fault),
  )
  let cursor_advance = builder.bit_or(
    events.load_commit,
    builder.bit_and(states[9], events.response_good),
  )
  builder.connect_next(
    registers.row,
    builder.mux(
      accept,
      execute_constant(builder, 13, 0),
      builder.mux(
        builder.bit_and(cursor_advance, events.last_column),
        builder.add(registers.row.value(), execute_constant(builder, 13, 1)),
        registers.row.value(),
      ),
    ),
  )
  builder.connect_next(
    registers.column,
    builder.mux(
      accept,
      execute_constant(builder, 13, 0),
      builder.mux(
        cursor_advance,
        builder.mux(
          events.last_column,
          execute_constant(builder, 13, 0),
          builder.add(
            registers.column.value(),
            execute_constant(builder, 13, 1),
          ),
        ),
        registers.column.value(),
      ),
    ),
  )
  portable_hold(
    builder,
    registers.tag,
    events.request_accept,
    builder.add(registers.tag.value(), execute_constant(builder, 32, 1)),
  )
  portable_hold(
    builder,
    registers.expected_tag,
    events.request_accept,
    registers.tag.value(),
  )
  portable_hold(
    builder,
    registers.load_byte,
    builder.bit_and(states[3], events.response_good),
    ports.response_data,
  )
  let progress = builder.bit_or(
    events.load_commit,
    builder.bit_and(states[9], events.response_good),
  )
  let increment = builder.mux(
    states[9],
    execute_constant(builder, 32, 4),
    execute_constant(builder, 32, 1),
  )
  builder.connect_next(
    registers.bytes_completed,
    builder.mux(
      accept,
      execute_constant(builder, 32, 0),
      builder.mux(
        progress,
        builder.add(registers.bytes_completed.value(), increment),
        registers.bytes_completed.value(),
      ),
    ),
  )
  let validation_fault = builder.bit_and(
    states[1],
    builder.bit_not(builder.equal(preflight, execute_constant(builder, 4, 0))),
  )
  let failed = builder.bit_or(terminal_response, events.internal_fault)
  let execution_fault = builder.mux(
    events.internal_fault,
    execute_constant(builder, 4, 11),
    builder.mux(
      events.response_protocol,
      execute_constant(builder, 4, 10),
      execute_constant(builder, 4, 9),
    ),
  )
  builder.connect_next(
    registers.fault,
    builder.mux(
      accept,
      execute_constant(builder, 4, 0),
      builder.mux(
        validation_fault,
        preflight,
        builder.mux(failed, execution_fault, registers.fault.value()),
      ),
    ),
  )
  builder.connect_next(
    registers.fault_address,
    builder.mux(
      accept,
      execute_constant(builder, 32, 0),
      builder.mux(terminal_response, address, registers.fault_address.value()),
    ),
  )
  builder.connect_next(
    registers.locked,
    builder.bit_or(registers.locked.value(), events.response_protocol),
  )
  (storage.finish)(events.validate_ok, finish_load, finish_compute)
  // Pre-edge state chooses exactly one transition. Done acknowledgement never
  // also accepts a command; a protocol-fault latch keeps Idle locked out.
  let done_value = execute_constant(builder, 4, 10)
  let hold = registers.state.value()
  let on_validate = builder.mux(
    validation_fault,
    done_value,
    builder.mux(
      op[4],
      done_value,
      builder.mux(
        builder.bit_or(op[0], op[1]),
        execute_constant(builder, 4, 2),
        builder.mux(
          op[2],
          execute_constant(builder, 4, 5),
          execute_constant(builder, 4, 7),
        ),
      ),
    ),
  )
  let transitions = [
    builder.mux(accept, execute_constant(builder, 4, 1), hold),
    on_validate,
    builder.mux(events.request_accept, execute_constant(builder, 4, 3), hold),
    builder.mux(
      terminal_response,
      done_value,
      builder.mux(events.response_good, execute_constant(builder, 4, 4), hold),
    ),
    builder.mux(
      events.load_commit,
      builder.mux(events.last, done_value, execute_constant(builder, 4, 2)),
      hold,
    ),
    builder.mux(
      core.execute.command_ready,
      execute_constant(builder, 4, 6),
      hold,
    ),
    builder.mux(events.compute_done, done_value, hold),
    builder.mux(core.read_ready, execute_constant(builder, 4, 8), hold),
    builder.mux(
      events.internal_fault,
      done_value,
      builder.mux(events.request_accept, execute_constant(builder, 4, 9), hold),
    ),
    builder.mux(
      terminal_response,
      done_value,
      builder.mux(
        events.response_good,
        builder.mux(finish_store, done_value, execute_constant(builder, 4, 7)),
        hold,
      ),
    ),
    builder.mux(ports.completion_ready, execute_constant(builder, 4, 0), hold),
  ]
  let mut next = hold
  for index in 0..<transitions.length() {
    next = builder.mux(states[index], transitions[index], next)
  }
  builder.connect_next(registers.state, next)
}
