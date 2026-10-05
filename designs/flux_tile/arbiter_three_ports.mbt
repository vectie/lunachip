///|
priv struct ArbiterThreeRegisters {
  state : @wire.RegisterHandle
  owner : @wire.RegisterHandle
  preference : @wire.RegisterHandle
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
priv struct ArbiterThreeRoutes {
  request_valid : @wire.Signal
  request_write : @wire.Signal
  address : @wire.Signal
  request_bytes : @wire.Signal
  request_mask : @wire.Signal
  request_data : @wire.Signal
  request_tag : @wire.Signal
  clients : Array[ArbiterClientRoute]
  poisoned : @wire.Signal
}

///|
fn arbiter_three_registers(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
) -> ArbiterThreeRegisters raise {
  {
    state: builder.register_state_in(domain, @wire.uint(2), reset~),
    owner: builder.register_state_in(domain, @wire.uint(2), reset~),
    preference: builder.register_state_in(domain, @wire.uint(2), reset~),
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
