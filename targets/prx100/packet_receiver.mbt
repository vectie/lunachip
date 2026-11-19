///|
priv struct Packet {
  complete : @wire.Signal
  valid : @wire.Signal
  opcode : @wire.Signal
  sequence : @wire.Signal
  argument : @wire.Signal
  data : @wire.Signal
}

///|
fn little_word(
  b : @wire.ModuleBuilder,
  bytes : ArrayView[@wire.Signal],
) -> @wire.Signal raise {
  let mut result = bytes[bytes.length() - 1]
  for offset in 1..<bytes.length() {
    result = b.concat(result, bytes[bytes.length() - offset - 1])
  }
  as_uint(b, result)
}

///|
fn packet_receiver(
  b : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  enabled : @wire.Signal,
  rx : Receiver,
  divisor : Int32,
) -> Packet raise {
  let index = b.register_state_in(domain, @wire.uint(4), reset~)
  let age = b.register_state_in(domain, @wire.uint(32), reset~)
  let crc = b.register_state_in(domain, @wire.uint(8), reset~)
  let saved_crc = b.register_state_in(domain, @wire.uint(8), reset~)
  let timeout = same(b, age.value(), (divisor * 1024).to_uint64())
  let abandon = either(b, [rx.error, timeout, b.bit_not(enabled)])
  let accepted = all(b, [rx.valid, enabled, b.bit_not(abandon)])
  let body = b.greater_equal(index.value(), number(b, 4, 2UL))
  let body_byte = all(b, [
    accepted,
    body,
    b.less_equal(index.value(), number(b, 4, 13UL)),
  ])
  let prefix = same(b, rx.data, 0xa5UL)
  let sync = all(b, [same(b, index.value(), 1UL), same(b, rx.data, 0x5aUL)])
  let last = same(b, index.value(), 15UL)
  let next_index = b.mux(
    body,
    b.mux(last, number(b, 4, 0UL), b.add(index.value(), number(b, 4, 1UL))),
    b.mux(
      sync,
      number(b, 4, 2UL),
      b.mux(prefix, number(b, 4, 1UL), number(b, 4, 0UL)),
    ),
  )
  b.connect_next(
    index,
    b.mux(
      abandon,
      number(b, 4, 0UL),
      b.mux(accepted, next_index, index.value()),
    ),
  )
  b.connect_next(
    age,
    b.mux(
      either(b, [accepted, abandon, same(b, index.value(), 0UL)]),
      number(b, 32, 0UL),
      b.add(age.value(), number(b, 32, 1UL)),
    ),
  )
  b.connect_next(
    crc,
    b.mux(
      b.bit_and(accepted, sync),
      number(b, 8, 0UL),
      b.mux(body_byte, crc_step(b, crc.value(), rx.data), crc.value()),
    ),
  )
  b.connect_next(
    saved_crc,
    b.mux(
      all(b, [accepted, same(b, index.value(), 14UL)]),
      rx.data,
      saved_crc.value(),
    ),
  )
  let bytes : Array[@wire.Signal] = []
  for offset in 0..<12 {
    bytes.push(
      b.register_in(
        domain,
        rx.data,
        reset~,
        enable=all(b, [
          body_byte,
          same(b, index.value(), (offset + 2).to_uint64()),
        ]),
      ),
    )
  }
  let complete = all(b, [accepted, last])
  {
    complete,
    valid: all(b, [
      complete,
      same(b, bytes[0], 1UL),
      same(b, rx.data, 0x0dUL),
      b.equal(crc.value(), saved_crc.value()),
    ]),
    opcode: bytes[1],
    sequence: little_word(b, bytes[2:4]),
    argument: little_word(b, bytes[4:8]),
    data: little_word(b, bytes[8:12]),
  }
}
