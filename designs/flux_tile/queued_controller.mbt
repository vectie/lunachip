///|
fn queued_controller(
  builder : @wire.ModuleBuilder,
  state : @wire.RegisterHandle,
  states : Array[@wire.Signal],
  head : Array[@wire.RegisterHandle],
  fifo : Array[@memory.FifoSignals],
  descriptor : QueuedDescriptor,
  core : PortableSignals,
  halted : @wire.Signal,
  completion_ready : @wire.Signal,
  completion : QueuedCompletion,
) -> Unit raise {
  let pop_fire = builder.bit_and(
    states[0],
    execute_and(builder, fifo.map(lane => lane.pop_ready())),
  )
  let capture_head = builder.bit_and(
    states[1],
    execute_and(builder, fifo.map(lane => lane.response_valid())),
  )
  for index in 0..<4 {
    portable_hold(
      builder,
      head[index],
      capture_head,
      fifo[index].response_data(),
    )
  }
  // Halt has priority over descriptor syntax: every already accepted entry
  // after a link fault receives one fault-15 completion with its raw identity.
  let local_fault = builder.mux(
    halted,
    execute_constant(builder, 4, 15),
    descriptor.syntax_fault,
  )
  let reject = builder.bit_and(
    states[2],
    builder.bit_not(builder.equal(local_fault, execute_constant(builder, 4, 0))),
  )
  let core_done = builder.bit_and(states[4], core.completion_valid)
  let publish = builder.bit_or(reject, core_done)
  portable_hold(
    builder,
    completion.id,
    publish,
    builder.mux(reject, descriptor.id, core.completion_id),
  )
  portable_hold(
    builder,
    completion.fault,
    publish,
    builder.mux(reject, local_fault, core.completion_fault),
  )
  portable_hold(
    builder,
    completion.bytes_completed,
    publish,
    builder.mux(reject, execute_constant(builder, 32, 0), core.bytes_completed),
  )
  portable_hold(
    builder,
    completion.fault_address,
    publish,
    builder.mux(reject, execute_constant(builder, 32, 0), core.fault_address),
  )
  let idle = execute_constant(builder, 3, 0)
  let fetch = execute_constant(builder, 3, 1)
  let decode = execute_constant(builder, 3, 2)
  let issue = execute_constant(builder, 3, 3)
  let active = execute_constant(builder, 3, 4)
  let done = execute_constant(builder, 3, 5)
  let hold = state.value()
  let transitions = [
    builder.mux(pop_fire, fetch, hold),
    builder.mux(capture_head, decode, hold),
    builder.mux(reject, done, issue),
    builder.mux(core.command_ready, active, hold),
    builder.mux(core_done, done, hold),
    builder.mux(completion_ready, idle, hold),
  ]
  let mut next = hold
  for index in 0..<transitions.length() {
    next = builder.mux(states[index], transitions[index], next)
  }
  builder.connect_next(state, next)
}
