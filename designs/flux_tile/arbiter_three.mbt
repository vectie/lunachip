///|
// Clients are reader, loader and storer, in that order. Routes refer only to
// allocated registers and external inputs so the client graphs can follow.
fn arbiter_three_routes(
  builder : @wire.ModuleBuilder,
  registers : ArbiterThreeRegisters,
  reset_inactive : @wire.Signal,
  bus : ArbiterBusInputs,
) -> ArbiterThreeRoutes raise {
  let offer = arbiter_three_state(builder, registers, reset_inactive, 1)
  let wait = arbiter_three_state(builder, registers, reset_inactive, 2)
  // Check the external tag before replacing it with the owner's local tag.
  let fault = builder.mux(
    arbiter_three_malformed(builder, registers, bus),
    execute_constant(builder, 2, 2),
    bus.response_fault,
  )
  let clients = [
    for owner in 0..<3 => {
      let selected = builder.equal(
        registers.owner.value(),
        execute_constant(builder, 2, owner),
      )
      let route : ArbiterClientRoute = {
        request_ready: execute_and(builder, [offer, selected, bus.request_ready]),
        response_valid: execute_and(builder, [
          wait,
          selected,
          bus.response_valid,
        ]),
        response_tag: registers.local_tag.value(),
        response_fault: fault,
        response_data: bus.response_data,
      }
      route
    }
  ]
  {
    request_valid: offer,
    request_write: registers.write.value(),
    address: registers.address.value(),
    request_bytes: registers.bytes.value(),
    request_mask: registers.mask.value(),
    request_data: registers.data.value(),
    request_tag: registers.next_tag.value(),
    clients,
    poisoned: arbiter_three_state(builder, registers, reset_inactive, 3),
  }
}

///|
fn arbiter_three_state(
  builder : @wire.ModuleBuilder,
  registers : ArbiterThreeRegisters,
  reset_inactive : @wire.Signal,
  state : Int32,
) -> @wire.Signal raise {
  builder.bit_and(
    builder.equal(registers.state.value(), execute_constant(builder, 2, state)),
    reset_inactive,
  )
}

///|
fn arbiter_three_malformed(
  builder : @wire.ModuleBuilder,
  registers : ArbiterThreeRegisters,
  bus : ArbiterBusInputs,
) -> @wire.Signal raise {
  builder.bit_or(
    builder.bit_not(
      builder.equal(bus.response_tag, registers.expected_tag.value()),
    ),
    builder.greater_equal(bus.response_fault, execute_constant(builder, 2, 2)),
  )
}
