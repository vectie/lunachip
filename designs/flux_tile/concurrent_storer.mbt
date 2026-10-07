///|
priv struct ConcurrentStorerView {
  states : Array[@wire.Signal]
  active : @wire.Signal
  read_valid : @wire.Signal
  read_row : @wire.Signal
  read_column : @wire.Signal
  read_id : @wire.Signal
  read_slot : @wire.Signal
  response_ready : @wire.Signal
  core_response_ready : @wire.Signal
}

///|
fn concurrent_storer_state(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
) -> ConcurrentTransferState raise {
  concurrent_transfer_state(builder, domain, reset)
}

///|
fn concurrent_storer_view(
  builder : @wire.ModuleBuilder,
  registers : ConcurrentTransferState,
  reset_inactive : @wire.Signal,
  poison : @wire.Signal,
) -> ConcurrentStorerView raise {
  // Idle, indexed C Read, held write Request, acknowledged Wait, held Done.
  let states = concurrent_transfer_states(builder, registers, reset_inactive)
  {
    states,
    // Whole-rectangle ownership remains visible on the cancellation edge.
    // Poison stops new work, not the pre-edge reservation itself.
    active: builder.bit_or(states[1], builder.bit_or(states[2], states[3])),
    read_valid: builder.bit_and(states[1], builder.bit_not(poison)),
    read_row: builder.truncate(registers.row.value(), 4),
    read_column: builder.truncate(registers.column.value(), 4),
    read_id: registers.id.value(),
    read_slot: registers.slot.value(),
    response_ready: states[3],
    core_response_ready: builder.bit_or(states[3], states[4]),
  }
}

///|
fn concurrent_storer_connect(
  builder : @wire.ModuleBuilder,
  registers : ConcurrentTransferState,
  ports : ConcurrentTransferPorts,
  view : ConcurrentStorerView,
  route : ArbiterClientRoute,
  core : StoredSignals,
  accept : @wire.Signal,
  preflight : @wire.Signal,
  poison : @wire.Signal,
  store_observations? : Array[StorePreservationObservation],
) -> ArbiterRequest raise {
  concurrent_transfer_latch(builder, registers, ports, accept)
  let identity_ok = builder.equal(core.response_id, registers.id.value())
  let status_ok = builder.equal(
    core.response_fault,
    execute_constant(builder, 2, 0),
  )
  let payload_ok = execute_and(builder, [
    core.response_valid,
    identity_ok,
    status_ok,
  ])
  let internal_fault = execute_and(builder, [
    view.states[2],
    core.response_valid,
    builder.bit_not(builder.bit_and(identity_ok, status_ok)),
  ])
  let request_valid = execute_and(builder, [
    view.states[2],
    builder.bit_not(poison),
    payload_ok,
  ])
  let request_accept = builder.bit_and(request_valid, route.request_ready)
  let response = transfer_response(
    builder,
    route,
    registers.expected_tag.value(),
    view.response_ready,
  )
  let advance = response.good
  match store_observations {
    Some(observations) =>
      store_preservation_events(observations, [
        (StoreAccept, accept),
        (StoreActive, view.active),
        (StoreReadValid, view.read_valid),
        (StoreRequestValid, request_valid),
        (StoreRequestAccept, request_accept),
        (StoreResponseGood, response.good),
        (StoreResponseRemote, response.remote),
        (StoreResponseProtocol, response.protocol),
        (StoreInternalFault, internal_fault),
      ])
    None => ()
  }
  let (_, last) = concurrent_cursor(builder, registers, accept, advance)
  let address = portable_transfer_address(
    builder,
    registers.base.value(),
    registers.stride.value(),
    registers.row.value(),
    registers.column.value(),
    4,
  )
  portable_hold(
    builder,
    registers.tag,
    request_accept,
    builder.add(registers.tag.value(), execute_constant(builder, 32, 1)),
  )
  portable_hold(
    builder,
    registers.expected_tag,
    request_accept,
    registers.tag.value(),
  )
  builder.connect_next(
    registers.progress,
    builder.mux(
      accept,
      execute_constant(builder, 32, 0),
      builder.mux(
        advance,
        builder.add(
          registers.progress.value(),
          execute_constant(builder, 32, 4),
        ),
        registers.progress.value(),
      ),
    ),
  )
  concurrent_storer_controller(
    builder,
    registers,
    ports,
    view,
    core,
    accept,
    preflight,
    poison,
    request_accept,
    response,
    internal_fault,
    last,
    address,
    store_observations?,
  )
  {
    valid: request_valid,
    write: builder.constant(@wire.bits(1), 1UL),
    address,
    bytes: execute_constant(builder, 3, 4),
    mask: builder.constant(@wire.bits(4), 15UL),
    data: builder.reinterpret(core.response_data, @wire.bits(32)),
    tag: registers.tag.value(),
  }
}
