///|
fn queued_concurrent_dependencies_connect(
  builder : @wire.ModuleBuilder,
  registers : QueuedConcurrentState,
  descriptor : QueuedConcurrentDescriptor,
  dispatch : QueuedConcurrentDispatch,
  engine : ConcurrentEngineSignals,
  reject : @wire.Signal,
) -> Unit raise {
  let syntax_ok = builder.equal(
    descriptor.command.syntax_fault,
    execute_constant(builder, 4, 0),
  )
  let publish = execute_and(builder, [
    dispatch.reserve,
    descriptor.writer,
    syntax_ok,
    builder.bit_not(engine.halted),
  ])
  // Snapshot old source generations before this head publishes its intended
  // writer. Strict dispatch forbids younger replacement while this head waits.
  for index in 0..<2 {
    portable_hold(
      builder,
      registers.dependency_status[index],
      dispatch.reserve,
      queued_concurrent_select(
        builder,
        descriptor.dependency_index[index],
        registers.writers.map(writer => writer.status.value()),
      ),
    )
    portable_hold(
      builder,
      registers.dependency_ticket[index],
      dispatch.reserve,
      queued_concurrent_select(
        builder,
        descriptor.dependency_index[index],
        registers.writers.map(writer => writer.ticket.value()),
      ),
    )
  }
  for index in 0..<6 {
    let writer = registers.writers[index]
    let load_class = index < 4
    let completion_valid = if load_class {
      engine.load.completion_valid
    } else {
      engine.compute.completion_valid
    }
    let completion_ticket = if load_class {
      engine.load.completion_id
    } else {
      engine.compute.completion_id
    }
    let completion_fault = if load_class {
      engine.load.completion_fault
    } else {
      engine.compute.completion_fault
    }
    let pending = builder.equal(
      writer.status.value(),
      execute_constant(builder, 2, 1),
    )
    let collect = execute_and(builder, [
      pending,
      completion_valid,
      builder.equal(writer.ticket.value(), completion_ticket),
    ])
    let local_failure = execute_and(builder, [
      pending,
      reject,
      descriptor.writer,
      syntax_ok,
      builder.equal(
        descriptor.writer_index,
        execute_constant(builder, 3, index),
      ),
      builder.equal(writer.ticket.value(), registers.head_ticket.value()),
    ])
    let intent = builder.bit_and(
      publish,
      builder.equal(
        descriptor.writer_index,
        execute_constant(builder, 3, index),
      ),
    )
    let collected_status = builder.mux(
      builder.equal(completion_fault, execute_constant(builder, 4, 0)),
      execute_constant(builder, 2, 2),
      execute_constant(builder, 2, 3),
    )
    // New intent wins an older producer's simultaneous terminal update.
    builder.connect_next(
      writer.status,
      builder.mux(
        intent,
        execute_constant(builder, 2, 1),
        builder.mux(
          local_failure,
          execute_constant(builder, 2, 3),
          builder.mux(collect, collected_status, writer.status.value()),
        ),
      ),
    )
    portable_hold(builder, writer.ticket, intent, registers.next_ticket.value())
  }
}
