///|
/// A packed resident span contains full 2048-descriptor segments followed by
/// one 1..2048-descriptor segment. The loader still writes the same program RAM.
priv struct TokenChain {
  accept : @wire.Signal
  configure : @wire.Signal
  advance : @wire.Signal
  count : @wire.Signal
  registers : Array[(UInt64, @wire.Signal)]
}

///|
fn token_chain(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  a : Axi,
  writable : @wire.Signal,
  healthy : @wire.Signal,
  protocol : @wire.Signal,
  active : @wire.RegisterHandle,
  loader : ResidentLoader,
  c : Map[String, @wire.Signal],
) -> TokenChain raise {
  let total = b.register_state_in(d, @wire.uint(16), reset~)
  let remaining = b.register_state_in(d, @wire.uint(16), reset~)
  let running = b.register_state_in(d, @wire.bits(1), reset~)
  let configure = both(b, [
    writable,
    eq(b, a.address, 0x98UL),
    b.greater_equal(a.data, n(b, 32, 1UL)),
    b.less_equal(a.data, n(b, 32, 65535UL)),
  ])
  update(b, total, configure, b.truncate(a.data, 16))
  let end_address = b.add(
    b.zero_extend(loader.base.value(), 33),
    b.shift_left(b.zero_extend(total.value(), 33), n(b, 33, 6UL)),
  )
  let accept = both(b, [
    writable,
    healthy,
    eq(b, a.address, 0x10UL),
    eq(b, a.data, 2UL),
    b.bit_not(eq(b, total.value(), 0UL)),
    b.bit_not(eq(b, loader.base.value(), 0UL)),
    b.less_equal(end_address, n(b, 33, 0x80000000UL)),
  ])
  // DONE is sticky until the next core launch. Arm completion only after
  // the loader has pulsed START and the core has left the preceding HALT.
  let end_segment = both(b, [
    running.value(),
    c["done"],
    b.bit_not(c["busy"]),
    b.bit_not(c["fault"]),
    b.bit_not(protocol),
    healthy,
  ])
  let more = b.greater_than(remaining.value(), n(b, 16, 2048UL))
  let advance = b.bit_and(end_segment, more)
  let stop = any(b, [
    b.bit_and(end_segment, b.bit_not(more)),
    protocol,
    c["fault"],
    b.bit_not(healthy),
  ])
  b.connect_next(
    active,
    b.mux(stop, n(b, 1, 0UL), b.bit_or(active.value(), accept)),
  )
  b.connect_next(
    running,
    b.mux(
      b.bit_or(end_segment, stop),
      n(b, 1, 0UL),
      b.bit_or(running.value(), b.bit_and(active.value(), loader.launch)),
    ),
  )
  update(
    b,
    remaining,
    b.bit_or(accept, advance),
    b.mux(accept, total.value(), b.sub(remaining.value(), n(b, 16, 2048UL))),
  )
  let registers = [(0x98UL, total.value()), (0x9cUL, n(b, 32, 0x43484e31UL))]
  let cycles = b.register_state_in(d, @wire.uint(64), reset~)
  let segment_cycles = u(b, b.concat(c["cycles_high"], c["cycles_low"]))
  let latch = b.bit_or(accept, end_segment)
  update(
    b,
    cycles,
    latch,
    b.mux(accept, n(b, 64, 0UL), b.add(cycles.value(), segment_cycles)),
  )
  registers.push((0x21cUL, b.slice(cycles.value(), 31, 0)))
  registers.push((0x220UL, b.slice(cycles.value(), 63, 32)))
  for
    (offset, delta) in [
      (0x224UL, c["instructions"]),
      (0x228UL, c["products"]),
      (0x22cUL, c["ddr_beats"]),
      (0x230UL, loader.cycles.value()),
      (0x238UL, n(b, 32, 1UL)),
    ] {
    let sum = b.register_state_in(d, @wire.uint(32), reset~)
    update(
      b,
      sum,
      latch,
      b.mux(accept, n(b, 32, 0UL), b.add(sum.value(), delta)),
    )
    registers.push((offset, sum.value()))
  }
  let elapsed = b.register_state_in(d, @wire.uint(32), reset~)
  update(
    b,
    elapsed,
    b.bit_or(accept, active.value()),
    b.mux(accept, n(b, 32, 0UL), b.add(elapsed.value(), n(b, 32, 1UL))),
  )
  registers.push((0x23cUL, elapsed.value()))
  {
    accept,
    configure,
    advance,
    registers,
    count: b.mux(more, n(b, 12, 2048UL), b.truncate(remaining.value(), 12)),
  }
}
