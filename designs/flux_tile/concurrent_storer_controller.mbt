///|
fn concurrent_storer_controller(
  builder : @wire.ModuleBuilder,
  registers : ConcurrentTransferState,
  ports : ConcurrentTransferPorts,
  view : ConcurrentStorerView,
  core : StoredSignals,
  accept : @wire.Signal,
  preflight : @wire.Signal,
  poison : @wire.Signal,
  request_accept : @wire.Signal,
  response : TransferResponse,
  internal_fault : @wire.Signal,
  last : @wire.Signal,
  address : @wire.Signal,
  store_observations? : Array[StorePreservationObservation],
) -> Unit raise {
  let response_fault = builder.bit_or(response.protocol, response.remote)
  let cancelled = builder.bit_and(view.active, poison)
  let terminal = builder.bit_or(
    response_fault,
    builder.bit_or(internal_fault, cancelled),
  )
  match store_observations {
    Some(observations) =>
      store_preservation_events(observations, [
        (StoreCancelled, cancelled),
        (StoreTerminal, terminal),
      ])
    None => ()
  }
  let terminal_code = builder.mux(
    response.protocol,
    execute_constant(builder, 4, 10),
    builder.mux(
      response.remote,
      execute_constant(builder, 4, 9),
      builder.mux(
        internal_fault,
        execute_constant(builder, 4, 11),
        execute_constant(builder, 4, 15),
      ),
    ),
  )
  // Only active engines can change terminal records. Done is immutable even
  // when an unrelated engine discovers transport poison during backpressure.
  builder.connect_next(
    registers.fault,
    builder.mux(
      accept,
      preflight,
      builder.mux(terminal, terminal_code, registers.fault.value()),
    ),
  )
  builder.connect_next(
    registers.fault_address,
    builder.mux(
      accept,
      execute_constant(builder, 32, 0),
      builder.mux(
        terminal,
        builder.mux(response_fault, address, execute_constant(builder, 32, 0)),
        registers.fault_address.value(),
      ),
    ),
  )
  let hold = registers.state.value()
  let read_state = execute_constant(builder, 3, 1)
  let request_state = execute_constant(builder, 3, 2)
  let wait_state = execute_constant(builder, 3, 3)
  let done_state = execute_constant(builder, 3, 4)
  let transitions = [
    builder.mux(
      accept,
      builder.mux(
        builder.equal(preflight, execute_constant(builder, 4, 0)),
        read_state,
        done_state,
      ),
      hold,
    ),
    builder.mux(
      builder.bit_and(view.read_valid, core.read_ready),
      request_state,
      hold,
    ),
    builder.mux(request_accept, wait_state, hold),
    builder.mux(response.good, builder.mux(last, done_state, read_state), hold),
    builder.mux(ports.completion_ready, execute_constant(builder, 3, 0), hold),
  ]
  let mut next = hold
  for index in 0..<5 {
    next = builder.mux(view.states[index], transitions[index], next)
  }
  builder.connect_next(registers.state, builder.mux(terminal, done_state, next))
}
