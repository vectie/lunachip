///|
// Inclusive stage counters and intersections retain an exact wall-cycle
// identity, including cycles where all three stages overlap.
fn account_overlap(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  start : @wire.Signal,
  busy : @wire.Signal,
  safe : @wire.Signal,
  ddr : @wire.Signal,
  pack : @wire.Signal,
  execute : @wire.Signal,
  finish : @wire.Signal,
  core_cycles : @wire.Signal,
  accepted : @wire.Signal,
  write : @wire.Signal,
  weight_word : @wire.Signal,
  activation_word : @wire.Signal,
  load : @wire.Signal,
) -> Array[(UInt64, @wire.Signal)] raise {
  let registers : Array[(UInt64, @wire.Signal)] = []
  for
    (address, enable, amount) in [
      (0x3cUL, ddr, n(b, 32, 1UL)),
      (0x40UL, pack, n(b, 32, 1UL)),
      (0x44UL, execute, n(b, 32, 1UL)),
      (0x48UL, finish, core_cycles),
      (0x4cUL, both(b, [accepted, b.bit_not(write)]), n(b, 32, 1UL)),
      (0x50UL, both(b, [accepted, write]), n(b, 32, 1UL)),
      (0x54UL, b.bit_or(weight_word, activation_word), n(b, 32, 1UL)),
      (0x58UL, load, n(b, 32, 8UL)),
      (0x70UL, b.bit_and(ddr, execute), n(b, 32, 1UL)),
      (0x74UL, b.bit_and(pack, execute), n(b, 32, 1UL)),
      (0x78UL, b.bit_and(ddr, pack), n(b, 32, 1UL)),
      (0x7cUL, both(b, [ddr, pack, execute]), n(b, 32, 1UL)),
      (
        0xa0UL,
        both(b, [busy, b.bit_not(any(b, [ddr, pack, execute]))]),
        n(b, 32, 1UL),
      ),
    ] {
    let r = b.register_state_in(d, @wire.uint(32), reset~)
    b.connect_next(
      r,
      b.mux(
        start,
        n(b, 32, 0UL),
        b.mux(
          both(b, [enable, busy, safe]),
          b.add(r.value(), amount),
          r.value(),
        ),
      ),
    )
    registers.push((address, r.value()))
    if address == 0x58UL {
      out(b, "observe_core_words", r.value())
    }
  }
  registers
}

///|
fn publication_vector(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  start : @wire.Signal,
  stored : @wire.Signal,
  complete : @wire.Signal,
  vectors : @wire.Signal,
) -> @wire.Signal raise {
  let r = b.register_state_in(d, @wire.uint(2), reset~)
  let next = b.add(r.value(), n(b, 2, 1UL))
  b.connect_next(
    r,
    b.mux(
      start,
      n(b, 2, 0UL),
      b.mux(
        both(b, [stored, b.bit_not(complete)]),
        b.mux(b.equal(next, vectors), n(b, 2, 0UL), next),
        r.value(),
      ),
    ),
  )
  r.value()
}
