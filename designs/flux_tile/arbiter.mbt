///|
// Routes depend only on already allocated state and external inputs. Clients
// can therefore be constructed afterwards without combinational forward wires.
fn arbiter_routes(
  builder : @wire.ModuleBuilder,
  registers : ArbiterRegisters,
  reset_inactive : @wire.Signal,
  bus : ArbiterBusInputs,
) -> ArbiterRoutes raise {
  let offer = arbiter_state(builder, registers, reset_inactive, 1)
  let wait = arbiter_state(builder, registers, reset_inactive, 2)
  let malformed = arbiter_malformed(builder, registers, bus)
  let fault = builder.mux(malformed, execute_constant(builder, 2, 2), bus.response_fault)
  let reader_owner = builder.bit_not(registers.owner.value())
  let reader : ArbiterClientRoute = {
    request_ready: execute_and(builder, [offer, reader_owner, bus.request_ready]),
    response_valid: execute_and(builder, [wait, reader_owner, bus.response_valid]),
    response_tag: registers.local_tag.value(),
    response_fault: fault,
    response_data: bus.response_data,
  }
  let engine : ArbiterClientRoute = {
    request_ready: execute_and(builder, [offer, registers.owner.value(), bus.request_ready]),
    response_valid: execute_and(builder, [wait, registers.owner.value(), bus.response_valid]),
    response_tag: registers.local_tag.value(),
    response_fault: fault,
    response_data: bus.response_data,
  }
  {
    request_valid: offer,
    request_write: registers.write.value(),
    address: registers.address.value(),
    request_bytes: registers.bytes.value(),
    request_mask: registers.mask.value(),
    request_data: registers.data.value(),
    request_tag: registers.next_tag.value(),
    reader,
    engine,
    poisoned: arbiter_state(builder, registers, reset_inactive, 3),
  }
}

///|
fn arbiter_state(
  builder : @wire.ModuleBuilder,
  registers : ArbiterRegisters,
  reset_inactive : @wire.Signal,
  state : Int,
) -> @wire.Signal raise {
  builder.bit_and(
    builder.equal(registers.state.value(), execute_constant(builder, 2, state)),
    reset_inactive,
  )
}

///|
fn arbiter_malformed(
  builder : @wire.ModuleBuilder,
  registers : ArbiterRegisters,
  bus : ArbiterBusInputs,
) -> @wire.Signal raise {
  builder.bit_or(
    builder.bit_not(builder.equal(bus.response_tag, registers.expected_tag.value())),
    builder.greater_equal(bus.response_fault, execute_constant(builder, 2, 2)),
  )
}
