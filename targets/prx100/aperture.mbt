///|
priv struct Aperture {
  pending : @wire.RegisterHandle
  tag : @wire.RegisterHandle
  fault : @wire.RegisterHandle
  offset : @wire.RegisterHandle
  reading : @wire.RegisterHandle
}

///|
fn aperture_registers(
  b : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
) -> Aperture raise {
  {
    pending: b.register_state_in(domain, @wire.bits(1), reset~),
    tag: b.register_state_in(domain, @wire.uint(32), reset~),
    fault: b.register_state_in(domain, @wire.uint(2), reset~),
    offset: b.register_state_in(domain, @wire.uint(2), reset~),
    reading: b.register_state_in(domain, @wire.bits(1), reset~),
  }
}

///|
fn word_address_valid(
  b : @wire.ModuleBuilder,
  address : @wire.Signal,
) -> @wire.Signal raise {
  all(b, [
    b.less_equal(address, number(b, 32, 4092UL)),
    same(b, b.slice(address, 1, 0), 0UL),
  ])
}

///|
fn finish_aperture(
  b : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  ports : Map[String, @wire.Signal],
  bus : Aperture,
  active : @wire.Signal,
  clear : @wire.Signal,
  host_read : @wire.Signal,
  host_write : @wire.Signal,
  address : @wire.Signal,
  data : @wire.Signal,
) -> @wire.Signal raise {
  let occupied = either(b, [bus.pending.value(), host_read, host_write])
  let ready = all(b, [active, b.bit_not(clear), b.bit_not(occupied)])
  let accept = all(b, [ready, ports["memory_request_valid"]])
  let write = ports["memory_request_write"]
  let dma_address = ports["memory_request_address"]
  let read_shape = all(b, [
    same(b, ports["memory_request_bytes"], 1UL),
    same(b, ports["memory_request_mask"], 1UL),
    same(b, ports["memory_request_data"], 0UL),
  ])
  let write_shape = all(b, [
    same(b, ports["memory_request_bytes"], 4UL),
    same(b, ports["memory_request_mask"], 15UL),
    same(b, b.slice(dma_address, 1, 0), 0UL),
  ])
  let shape = b.mux(write, write_shape, read_shape)
  let bounds = b.mux(
    write,
    word_address_valid(b, dma_address),
    b.less_equal(dma_address, number(b, 32, 4095UL)),
  )
  let legal = b.bit_and(shape, bounds)
  let memory = b.synchronous_memory(
    "host_aperture",
    @wire.uint(32),
    1024,
    domain,
    read_write_policy=ReadOld,
    multi_write_policy=Reject,
    bounds_policy=Fault,
  )
  let read_address = b.mux(host_read, address, dma_address)
  let read_enable = either(b, [
    host_read,
    all(b, [accept, legal, b.bit_not(write)]),
  ])
  let word = b.memory_read(
    memory,
    "read",
    as_uint(b, b.slice(read_address, 11, 2)),
    enable=read_enable,
    enable_behavior=HoldLast,
  )
  let write_address = b.mux(host_write, address, dma_address)
  b.memory_write(
    memory,
    "write",
    as_uint(b, b.slice(write_address, 11, 2)),
    b.mux(host_write, data, as_uint(b, ports["memory_request_data"])),
    enable=either(b, [host_write, all(b, [accept, legal, write])]),
  )
  b.connect_next(
    bus.pending,
    b.mux(
      clear,
      b.constant(@wire.bits(1), 0UL),
      b.mux(
        accept,
        b.constant(@wire.bits(1), 1UL),
        b.mux(
          ports["memory_response_ready"],
          b.constant(@wire.bits(1), 0UL),
          bus.pending.value(),
        ),
      ),
    ),
  )
  b.connect_next(
    bus.tag,
    b.mux(accept, ports["memory_request_tag"], bus.tag.value()),
  )
  b.connect_next(
    bus.offset,
    b.mux(accept, as_uint(b, b.slice(dma_address, 1, 0)), bus.offset.value()),
  )
  b.connect_next(
    bus.reading,
    b.mux(accept, b.bit_not(write), bus.reading.value()),
  )
  b.connect_next(
    bus.fault,
    b.mux(
      accept,
      b.mux(
        b.bit_not(shape),
        number(b, 2, 2UL),
        b.mux(bounds, number(b, 2, 0UL), number(b, 2, 1UL)),
      ),
      bus.fault.value(),
    ),
  )
  let offset_bits = as_uint(b, b.concat(bus.offset.value(), number(b, 3, 0UL)))
  let byte = b.zero_extend(
    b.truncate(b.logical_shift_right(word, offset_bits), 8),
    32,
  )
  output(b, "memory_request_ready", ready)
  output(
    b,
    "memory_response_valid",
    all(b, [active, b.bit_not(clear), bus.pending.value()]),
  )
  output(b, "memory_response_tag", bus.tag.value())
  output(b, "memory_response_fault", bus.fault.value())
  let read_response = all(b, [
    bus.pending.value(),
    bus.reading.value(),
    same(b, bus.fault.value(), 0UL),
  ])
  output(
    b,
    "memory_response_data",
    b.reinterpret(
      b.mux(read_response, byte, number(b, 32, 0UL)),
      @wire.bits(32),
    ),
  )
  word
}
