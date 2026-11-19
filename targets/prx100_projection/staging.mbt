///|
priv struct Stage {
  word : @wire.Signal
  accepted : @wire.Signal
}

///|
fn aligned_word(
  b : @wire.ModuleBuilder,
  address : @wire.Signal,
) -> @wire.Signal raise {
  both(b, [
    b.less_equal(address, n(b, 32, 4092UL)),
    eq(b, b.slice(address, 1, 0), 0UL),
  ])
}

///|
fn staging(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  ports : Map[String, @wire.Signal],
  active : @wire.Signal,
  clear : @wire.Signal,
  host_write : @wire.Signal,
  host_address : @wire.Signal,
  host_data : @wire.Signal,
  host_read : @wire.Signal,
  host_read_address : @wire.Signal,
) -> Stage raise {
  let host_write = b.bit_and(host_write, b.bit_not(clear))
  let host_read = b.bit_and(host_read, b.bit_not(clear))
  let pending = b.register_state_in(d, @wire.bits(1), reset~)
  let tag = b.register_state_in(d, @wire.uint(32), reset~)
  let fault = b.register_state_in(d, @wire.uint(2), reset~)
  let offset = b.register_state_in(d, @wire.uint(2), reset~)
  let reading = b.register_state_in(d, @wire.uint(2), reset~)
  let ready = both(b, [
    active,
    b.bit_not(clear),
    b.bit_not(pending.value()),
    b.bit_not(b.bit_and(host_write, ports["memory_request_write"])),
  ])
  let accept = b.bit_and(ready, ports["memory_request_valid"])
  let write = ports["memory_request_write"]
  let address = ports["memory_request_address"]
  let byte_shape = both(b, [
    eq(b, ports["memory_request_bytes"], 1UL),
    eq(b, ports["memory_request_mask"], 1UL),
    eq(b, ports["memory_request_data"], 0UL),
  ])
  let word_read = both(b, [
    eq(b, ports["memory_request_bytes"], 4UL),
    eq(b, ports["memory_request_mask"], 15UL),
    eq(b, ports["memory_request_data"], 0UL),
    eq(b, b.slice(address, 1, 0), 0UL),
  ])
  let read_shape = b.bit_or(byte_shape, word_read)
  let write_shape = both(b, [
    eq(b, ports["memory_request_bytes"], 4UL),
    eq(b, ports["memory_request_mask"], 15UL),
    eq(b, b.slice(address, 1, 0), 0UL),
  ])
  let shape = b.mux(write, write_shape, read_shape)
  let bounds = b.mux(
    write,
    both(b, [
      aligned_word(b, address),
      any(b, [
        both(b, [
          b.greater_equal(address, n(b, 32, 1024UL)),
          b.less_equal(address, n(b, 32, 1052UL)),
        ]),
        both(b, [
          b.greater_equal(address, n(b, 32, 3072UL)),
          b.less_equal(address, n(b, 32, 3100UL)),
        ]),
      ]),
    ]),
    b.mux(
      word_read,
      aligned_word(b, address),
      b.less_equal(address, n(b, 32, 4095UL)),
    ),
  )
  let legal = b.bit_and(shape, bounds)
  let memory = b.synchronous_memory(
    "projection_staging",
    @wire.uint(32),
    1024,
    d,
    read_write_policy=ReadOld,
    multi_write_policy=Reject,
    bounds_policy=Fault,
  )
  let word = b.memory_read(
    memory,
    "core_read",
    u(b, b.slice(address, 11, 2)),
    enable=both(b, [accept, legal, b.bit_not(write)]),
    enable_behavior=HoldLast,
  )
  // Collection cannot change the registered core read output while its
  // tagged response is held. A separate port also leaves core acceptance open.
  let host_word = b.memory_read(
    memory,
    "collection_read",
    u(b, b.slice(host_read_address, 11, 2)),
    enable=host_read,
    enable_behavior=HoldLast,
  )
  let write_address = b.mux(host_write, host_address, address)
  b.memory_write(
    memory,
    "write",
    u(b, b.slice(write_address, 11, 2)),
    b.mux(host_write, host_data, u(b, ports["memory_request_data"])),
    enable=any(b, [host_write, both(b, [accept, legal, write])]),
  )
  b.connect_next(
    pending,
    b.mux(
      clear,
      n(b, 1, 0UL),
      b.mux(
        accept,
        n(b, 1, 1UL),
        b.mux(ports["memory_response_ready"], n(b, 1, 0UL), pending.value()),
      ),
    ),
  )
  update(b, tag, accept, ports["memory_request_tag"])
  update(b, offset, accept, u(b, b.slice(address, 1, 0)))
  update(
    b,
    reading,
    accept,
    b.mux(write, n(b, 2, 0UL), b.mux(word_read, n(b, 2, 2UL), n(b, 2, 1UL))),
  )
  update(
    b,
    fault,
    accept,
    b.mux(
      b.bit_not(shape),
      n(b, 2, 2UL),
      b.mux(bounds, n(b, 2, 0UL), n(b, 2, 1UL)),
    ),
  )
  let shift = u(b, b.concat(offset.value(), n(b, 3, 0UL)))
  let byte = b.zero_extend(
    b.truncate(b.logical_shift_right(word, shift), 8),
    32,
  )
  out(b, "memory_request_ready", ready)
  out(
    b,
    "memory_response_valid",
    both(b, [active, b.bit_not(clear), pending.value()]),
  )
  out(b, "memory_response_tag", tag.value())
  out(b, "memory_response_fault", fault.value())
  out(
    b,
    "memory_response_data",
    b.reinterpret(
      b.mux(
        both(b, [
          pending.value(),
          b.bit_not(eq(b, reading.value(), 0UL)),
          eq(b, fault.value(), 0UL),
        ]),
        b.mux(eq(b, reading.value(), 2UL), word, byte),
        n(b, 32, 0UL),
      ),
      @wire.bits(32),
    ),
  )
  { word: host_word, accepted: accept, }
}
