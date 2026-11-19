///|
priv struct Receiver {
  valid : @wire.Signal
  data : @wire.Signal
  error : @wire.Signal
}

///|
fn uart_receiver(
  b : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset_signal : @wire.Signal,
  reset : @wire.SynchronousReset,
  pin : @wire.Signal,
  divisor : Int32,
) -> Receiver raise {
  let idle_reset = b.synchronous_reset(reset_signal, 1UL)
  let rx = b.bit_synchronizer("uart_rx", pin, domain, 2, reset=idle_reset)
  let state = b.register_state_in(domain, @wire.uint(2), reset~)
  let timer = b.register_state_in(domain, @wire.uint(16), reset~)
  let bit_index = b.register_state_in(domain, @wire.uint(3), reset~)
  let data = b.register_state_in(domain, @wire.uint(8), reset~)
  let running = b.bit_not(same(b, state.value(), 0UL))
  let expired = same(b, timer.value(), 0UL)
  let low = same(b, rx, 0UL)
  let start = all(b, [same(b, state.value(), 0UL), low])
  let check_start = all(b, [same(b, state.value(), 1UL), expired])
  let sample = all(b, [same(b, state.value(), 2UL), expired])
  let stop = all(b, [same(b, state.value(), 3UL), expired])
  b.connect_next(
    state,
    b.mux(
      start,
      number(b, 2, 1UL),
      b.mux(
        check_start,
        b.mux(low, number(b, 2, 2UL), number(b, 2, 0UL)),
        b.mux(
          all(b, [sample, same(b, bit_index.value(), 7UL)]),
          number(b, 2, 3UL),
          b.mux(stop, number(b, 2, 0UL), state.value()),
        ),
      ),
    ),
  )
  b.connect_next(
    timer,
    b.mux(
      start,
      number(b, 16, (divisor / 2 - 1).to_uint64()),
      b.mux(
        expired,
        number(b, 16, (divisor - 1).to_uint64()),
        b.mux(running, b.sub(timer.value(), number(b, 16, 1UL)), timer.value()),
      ),
    ),
  )
  b.connect_next(
    bit_index,
    b.mux(
      check_start,
      number(b, 3, 0UL),
      b.mux(
        sample,
        b.add(bit_index.value(), number(b, 3, 1UL)),
        bit_index.value(),
      ),
    ),
  )
  let shifted = as_uint(b, b.concat(rx, b.slice(data.value(), 7, 1)))
  b.connect_next(data, b.mux(sample, shifted, data.value()))
  {
    valid: b.register_in(domain, b.bit_and(stop, rx), reset~),
    data: data.value(),
    error: b.register_in(domain, b.bit_and(stop, low), reset~),
  }
}

///|
priv struct Transmitter {
  state : @wire.RegisterHandle
  timer : @wire.RegisterHandle
  bits : @wire.RegisterHandle
  ready : @wire.Signal
}

///|
fn transmitter(
  b : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
) -> Transmitter raise {
  let state = b.register_state_in(domain, @wire.uint(4), reset~)
  {
    state,
    timer: b.register_state_in(domain, @wire.uint(16), reset~),
    bits: b.register_state_in(domain, @wire.uint(10), reset~),
    ready: same(b, state.value(), 0UL),
  }
}

///|
fn finish_transmitter(
  b : @wire.ModuleBuilder,
  tx : Transmitter,
  valid : @wire.Signal,
  byte : @wire.Signal,
  divisor : Int32,
) -> @wire.Signal raise {
  let accept = b.bit_and(valid, tx.ready)
  let tick = same(b, tx.timer.value(), 0UL)
  let advance = all(b, [b.bit_not(tx.ready), tick])
  b.connect_next(
    tx.state,
    b.mux(
      accept,
      number(b, 4, 10UL),
      b.mux(
        advance,
        b.sub(tx.state.value(), number(b, 4, 1UL)),
        tx.state.value(),
      ),
    ),
  )
  b.connect_next(
    tx.timer,
    b.mux(
      either(b, [accept, advance]),
      number(b, 16, (divisor - 1).to_uint64()),
      b.mux(
        b.bit_not(tx.ready),
        b.sub(tx.timer.value(), number(b, 16, 1UL)),
        tx.timer.value(),
      ),
    ),
  )
  let frame = as_uint(
    b,
    b.concat(b.concat(number(b, 1, 1UL), byte), number(b, 1, 0UL)),
  )
  let shift = as_uint(
    b,
    b.concat(number(b, 1, 1UL), b.slice(tx.bits.value(), 9, 1)),
  )
  b.connect_next(
    tx.bits,
    b.mux(accept, frame, b.mux(advance, shift, tx.bits.value())),
  )
  b.mux(
    tx.ready,
    b.constant(@wire.bits(1), 1UL),
    b.slice(tx.bits.value(), 0, 0),
  )
}
