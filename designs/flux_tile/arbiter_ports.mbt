///|
priv struct ArbiterBusInputs {
  request_ready : @wire.Signal
  response_valid : @wire.Signal
  response_tag : @wire.Signal
  response_fault : @wire.Signal
  response_data : @wire.Signal
}

///|
priv struct ArbiterRequest {
  valid : @wire.Signal
  write : @wire.Signal
  address : @wire.Signal
  bytes : @wire.Signal
  mask : @wire.Signal
  data : @wire.Signal
  tag : @wire.Signal
}

///|
priv struct ArbiterClientRoute {
  request_ready : @wire.Signal
  response_valid : @wire.Signal
  response_tag : @wire.Signal
  response_fault : @wire.Signal
  response_data : @wire.Signal
}

///|
priv struct ArbiterRoutes {
  request_valid : @wire.Signal
  request_write : @wire.Signal
  address : @wire.Signal
  request_bytes : @wire.Signal
  request_mask : @wire.Signal
  request_data : @wire.Signal
  request_tag : @wire.Signal
  reader : ArbiterClientRoute
  engine : ArbiterClientRoute
  poisoned : @wire.Signal
}

///|
priv struct ArbiterRegisters {
  state : @wire.RegisterHandle
  owner : @wire.RegisterHandle
  prefer_engine : @wire.RegisterHandle
  next_tag : @wire.RegisterHandle
  expected_tag : @wire.RegisterHandle
  local_tag : @wire.RegisterHandle
  write : @wire.RegisterHandle
  address : @wire.RegisterHandle
  bytes : @wire.RegisterHandle
  mask : @wire.RegisterHandle
  data : @wire.RegisterHandle
}

///|
fn arbiter_registers(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
) -> ArbiterRegisters raise {
  {
    state: builder.register_state_in(domain, @wire.uint(2), reset~),
    owner: builder.register_state_in(domain, @wire.bits(1), reset~),
    prefer_engine: builder.register_state_in(domain, @wire.bits(1), reset~),
    next_tag: builder.register_state_in(domain, @wire.uint(32), reset~),
    expected_tag: builder.register_state_in(domain, @wire.uint(32), reset~),
    local_tag: builder.register_state_in(domain, @wire.uint(32), reset~),
    write: builder.register_state_in(domain, @wire.bits(1), reset~),
    address: builder.register_state_in(domain, @wire.uint(32), reset~),
    bytes: builder.register_state_in(domain, @wire.uint(3), reset~),
    mask: builder.register_state_in(domain, @wire.bits(4), reset~),
    data: builder.register_state_in(domain, @wire.bits(32), reset~),
  }
}
