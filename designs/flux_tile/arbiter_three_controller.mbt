///|
fn arbiter_three_controller(
  builder : @wire.ModuleBuilder,
  registers : ArbiterThreeRegisters,
  reset_inactive : @wire.Signal,
  bus : ArbiterBusInputs,
  routes : ArbiterThreeRoutes,
  requests : Array[ArbiterRequest],
  response_readies : Array[@wire.Signal],
) -> @wire.Signal raise {
  let idle = arbiter_three_state(builder, registers, reset_inactive, 0)
  let wait = arbiter_three_state(builder, registers, reset_inactive, 2)
  let any_request = builder.bit_or(
    requests[0].valid,
    builder.bit_or(requests[1].valid, requests[2].valid),
  )
  // Each preference selects a genuine cyclic order, skipping absent peers.
  let owner = for preference = 0, selected = execute_constant(builder, 2, 0); preference <
                 3; {
    let second = (preference + 1) % 3
    let third = (preference + 2) % 3
    let candidate = builder.mux(
      requests[preference].valid,
      execute_constant(builder, 2, preference),
      builder.mux(
        requests[second].valid,
        execute_constant(builder, 2, second),
        execute_constant(builder, 2, third),
      ),
    )
    continue preference + 1,
      builder.mux(
        builder.equal(
          registers.preference.value(),
          execute_constant(builder, 2, preference),
        ),
        candidate,
        selected,
      )
  } nobreak {
    selected
  }
  let grant = builder.bit_and(idle, any_request)
  // Offer is visible only after all fields and the owner have been captured.
  for
    (handle, fields) in [
      (registers.write, requests.map(request => request.write)),
      (registers.address, requests.map(request => request.address)),
      (registers.bytes, requests.map(request => request.bytes)),
      (registers.mask, requests.map(request => request.mask)),
      (registers.data, requests.map(request => request.data)),
      (registers.local_tag, requests.map(request => request.tag)),
    ] {
    let selected = builder.mux(
      builder.equal(owner, execute_constant(builder, 2, 0)),
      fields[0],
      builder.mux(
        builder.equal(owner, execute_constant(builder, 2, 1)),
        fields[1],
        fields[2],
      ),
    )
    portable_hold(builder, handle, grant, selected)
  }
  portable_hold(builder, registers.owner, grant, owner)
  let request_accept = builder.bit_and(routes.request_valid, bus.request_ready)
  portable_hold(
    builder,
    registers.expected_tag,
    request_accept,
    registers.next_tag.value(),
  )
  portable_hold(
    builder,
    registers.next_tag,
    request_accept,
    builder.add(registers.next_tag.value(), execute_constant(builder, 32, 1)),
  )
  let successor = builder.mux(
    builder.equal(registers.owner.value(), execute_constant(builder, 2, 2)),
    execute_constant(builder, 2, 0),
    builder.add(registers.owner.value(), execute_constant(builder, 2, 1)),
  )
  portable_hold(builder, registers.preference, request_accept, successor)
  let client_ready = [
    for owner in 0..<3 => {
      builder.bit_and(
        builder.equal(
          registers.owner.value(),
          execute_constant(builder, 2, owner),
        ),
        response_readies[owner],
      )
    }
  ]
  let selected_ready = builder.bit_or(
    client_ready[0],
    builder.bit_or(client_ready[1], client_ready[2]),
  )
  let response_ready = builder.bit_and(wait, selected_ready)
  let response_accept = builder.bit_and(response_ready, bus.response_valid)
  let response_state = builder.mux(
    arbiter_three_malformed(builder, registers, bus),
    execute_constant(builder, 2, 3),
    execute_constant(builder, 2, 0),
  )
  builder.connect_next(
    registers.state,
    builder.mux(
      response_accept,
      response_state,
      builder.mux(
        request_accept,
        execute_constant(builder, 2, 2),
        builder.mux(
          grant,
          execute_constant(builder, 2, 1),
          registers.state.value(),
        ),
      ),
    ),
  )
  response_ready
}
