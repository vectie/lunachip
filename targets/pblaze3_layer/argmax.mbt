///|
/// Observe successful scalar DDR writes within one armed, contiguous FP32
/// vector. The ordered store stream makes "first maximum" deterministic.
fn streaming_argmax(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  writable : @wire.Signal,
  a : Axi,
  committed : @wire.Signal,
  address : @wire.Signal,
  value : @wire.Signal,
) -> (@wire.Signal, Array[(UInt64, @wire.Signal)]) raise {
  let length = b.register_state_in(d, @wire.uint(18), reset~)
  let base = b.register_state_in(d, @wire.uint(32), reset~)
  let end_addr = b.register_state_in(d, @wire.uint(32), reset~)
  let next_addr = b.register_state_in(d, @wire.uint(32), reset~)
  let seen = b.register_state_in(d, @wire.uint(18), reset~)
  let best = b.register_state_in(d, @wire.uint(32), reset~)
  let index = b.register_state_in(d, @wire.uint(18), reset~)
  let invalid = b.register_state_in(d, @wire.bits(1), reset~)
  let set_length = both(b, [
    writable,
    eq(b, a.address, 0x44UL),
    b.less_equal(a.data, n(b, 32, 151936UL)),
  ])
  let limit = b.add(
    b.zero_extend(a.data, 33),
    b.shift_left(b.zero_extend(length.value(), 33), n(b, 33, 2UL)),
  )
  let arm = both(b, [
    writable,
    eq(b, a.address, 0x48UL),
    eq(b, b.slice(a.data, 1, 0), 0UL),
    b.bit_not(eq(b, length.value(), 0UL)),
    b.less_equal(limit, n(b, 33, 0x80000000UL)),
  ])
  update(b, length, set_length, b.truncate(a.data, 18))
  update(b, base, arm, a.data)
  let clear = b.bit_or(set_length, arm)
  update(b, end_addr, clear, b.mux(arm, b.truncate(limit, 32), n(b, 32, 0UL)))
  let hit = both(b, [
    committed,
    b.greater_equal(address, base.value()),
    b.less_than(address, end_addr.value()),
  ])
  let finite = b.bit_not(eq(b, b.slice(value, 30, 23), 255UL))
  let valid = both(b, [hit, finite, b.equal(address, next_addr.value())])
  let bad = b.bit_and(hit, b.bit_not(valid))
  b.connect_next(
    invalid,
    b.mux(clear, n(b, 1, 0UL), b.bit_or(invalid.value(), bad)),
  )
  b.connect_next(
    next_addr,
    b.mux(
      arm,
      a.data,
      b.mux(valid, b.add(next_addr.value(), n(b, 32, 4UL)), next_addr.value()),
    ),
  )
  b.connect_next(
    seen,
    b.mux(
      clear,
      n(b, 18, 0UL),
      b.mux(valid, b.add(seen.value(), n(b, 18, 1UL)), seen.value()),
    ),
  )
  // Both signed zeros have one ordering key. Negative floats sort in
  // reverse magnitude order, positive floats in forward magnitude order.
  let key = b.mux(
    eq(b, b.slice(value, 30, 0), 0UL),
    n(b, 32, 0x80000000UL),
    b.mux(
      b.slice(value, 31, 31),
      b.bit_not(value),
      b.bit_xor(value, n(b, 32, 0x80000000UL)),
    ),
  )
  let win = both(b, [
    valid,
    b.bit_or(eq(b, seen.value(), 0UL), b.less_than(best.value(), key)),
  ])
  update(b, best, win, key)
  update(b, index, win, seen.value())
  let complete = both(b, [
    b.equal(seen.value(), length.value()),
    b.bit_not(eq(b, seen.value(), 0UL)),
    b.bit_not(invalid.value()),
  ])
  (
    clear,
    [
      (0x44UL, b.zero_extend(length.value(), 32)),
      (0x48UL, base.value()),
      (
        0x4cUL,
        b.mux(
          complete,
          b.zero_extend(index.value(), 32),
          n(b, 32, 0xffffffffUL),
        ),
      ),
      (0x94UL, n(b, 32, 1UL)),
    ],
  )
}
