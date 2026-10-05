///|
priv struct RingRegisters {
  state : @wire.RegisterHandle
  base : @wire.RegisterHandle
  origin : @wire.RegisterHandle
  producer : @wire.RegisterHandle
  consumer : @wire.RegisterHandle
  configured : @wire.RegisterHandle
  cursor : @wire.RegisterHandle
  tag : @wire.RegisterHandle
  expected_tag : @wire.RegisterHandle
  fault : @wire.RegisterHandle
  fault_address : @wire.RegisterHandle
  lanes : Array[@wire.RegisterHandle]
}

///|
fn ring_registers(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
) -> RingRegisters raise {
  let state = builder.register_state_in(domain, @wire.uint(3), reset~)
  let base = builder.register_state_in(domain, @wire.uint(32), reset~)
  let origin = builder.register_state_in(domain, @wire.uint(32), reset~)
  let producer = builder.register_state_in(domain, @wire.uint(32), reset~)
  let consumer = builder.register_state_in(domain, @wire.uint(32), reset~)
  let configured = builder.register_state_in(domain, @wire.bits(1), reset~)
  let cursor = builder.register_state_in(domain, @wire.uint(5), reset~)
  let tag = builder.register_state_in(domain, @wire.uint(32), reset~)
  let expected_tag = builder.register_state_in(domain, @wire.uint(32), reset~)
  let fault = builder.register_state_in(domain, @wire.uint(3), reset~)
  let fault_address = builder.register_state_in(domain, @wire.uint(32), reset~)
  let lanes : Array[@wire.RegisterHandle] = []
  for _ in 0..<4 {
    lanes.push(builder.register_state_in(domain, @wire.bits(64), reset~))
  }
  {
    state,
    base,
    origin,
    producer,
    consumer,
    configured,
    cursor,
    tag,
    expected_tag,
    fault,
    fault_address,
    lanes,
  }
}
