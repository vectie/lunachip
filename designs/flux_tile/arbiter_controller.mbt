///|
// Connect state only after both clients' request and response-ready graphs
// exist. Return external response-ready without adding a second bus contract.
fn arbiter_controller(
  builder : @wire.ModuleBuilder,
  registers : ArbiterRegisters,
  reset_inactive : @wire.Signal,
  bus : ArbiterBusInputs,
  routes : ArbiterRoutes,
  reader_request : ArbiterRequest,
  reader_response_ready : @wire.Signal,
  engine_request : ArbiterRequest,
  engine_response_ready : @wire.Signal,
) -> @wire.Signal raise {
  let idle = arbiter_state(builder, registers, reset_inactive, 0)
  let wait = arbiter_state(builder, registers, reset_inactive, 2)
  let choose_engine = builder.bit_and(
    engine_request.valid,
    builder.bit_or(builder.bit_not(reader_request.valid), registers.prefer_engine.value()),
  )
  let grant = builder.bit_and(idle, builder.bit_or(reader_request.valid, engine_request.valid))
  // Snapshot the entire selected payload before exposing Offer. Contenders
  // cannot alter it, including while the external request is backpressured.
  for (handle, reader, engine) in [
    (registers.write, reader_request.write, engine_request.write),
    (registers.address, reader_request.address, engine_request.address),
    (registers.bytes, reader_request.bytes, engine_request.bytes),
    (registers.mask, reader_request.mask, engine_request.mask),
    (registers.data, reader_request.data, engine_request.data),
    (registers.local_tag, reader_request.tag, engine_request.tag),
  ] {
    portable_hold(builder, handle, grant, builder.mux(choose_engine, engine, reader))
  }
  portable_hold(builder, registers.owner, grant, choose_engine)
  let request_accept = builder.bit_and(routes.request_valid, bus.request_ready)
  portable_hold(builder, registers.expected_tag, request_accept, registers.next_tag.value())
  portable_hold(
    builder,
    registers.next_tag,
    request_accept,
    builder.add(registers.next_tag.value(), execute_constant(builder, 32, 1)),
  )
  // The next tie prefers the other client, but a sole requester never waits
  // for an absent peer. Preference changes only for a bus acceptance.
  portable_hold(builder, registers.prefer_engine, request_accept, builder.bit_not(registers.owner.value()))
  let response_ready = builder.bit_and(
    wait,
    builder.mux(registers.owner.value(), engine_response_ready, reader_response_ready),
  )
  let response_accept = builder.bit_and(response_ready, bus.response_valid)
  let response_state = builder.mux(
    arbiter_malformed(builder, registers, bus),
    execute_constant(builder, 2, 3),
    execute_constant(builder, 2, 0),
  )
  let next = builder.mux(
    response_accept,
    response_state,
    builder.mux(
      request_accept,
      execute_constant(builder, 2, 2),
      builder.mux(grant, execute_constant(builder, 2, 1), registers.state.value()),
    ),
  )
  builder.connect_next(registers.state, next)
  response_ready
}
