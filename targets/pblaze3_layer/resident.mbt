///|
/// DDR-backed instruction staging. One request is outstanding at a time; the
/// shared controller owns request/response matching. Core arithmetic is idle
/// until the final instruction word has committed to the program RAM.
priv struct ResidentLoader {
  state : @wire.RegisterHandle
  base : @wire.RegisterHandle
  index : @wire.RegisterHandle
  cycles : @wire.RegisterHandle
  busy : @wire.Signal
  request : @wire.Signal
  launch : @wire.Signal
  address : @wire.Signal
}

///|
fn resident_loader(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
) -> ResidentLoader raise {
  let state = b.register_state_in(d, @wire.uint(3), reset~)
  let base = b.register_state_in(d, @wire.uint(32), reset~)
  let index = b.register_state_in(d, @wire.uint(15), reset~)
  let cycles = b.register_state_in(d, @wire.uint(32), reset~)
  {
    state,
    base,
    index,
    cycles,
    busy: b.bit_not(eq(b, state.value(), 0UL)),
    request: eq(b, state.value(), 1UL),
    launch: eq(b, state.value(), 3UL),
    address: b.add(
      base.value(),
      b.shift_left(b.zero_extend(index.value(), 32), n(b, 32, 2UL)),
    ),
  }
}

///|
fn ResidentLoader::commit(
  r : ResidentLoader,
  b : @wire.ModuleBuilder,
  accepted : @wire.Signal,
  take : @wire.Signal,
  result : @wire.Signal,
  fault : @wire.Signal,
  count : @wire.Signal,
  finish_request~ : @wire.Signal? = None,
) -> Unit raise {
  let begin = b.bit_and(accepted, b.bit_not(eq(b, r.base.value(), 0UL)))
  let last = b.equal(
    b.add(b.zero_extend(r.index.value(), 16), n(b, 16, 1UL)),
    b.shift_left(b.zero_extend(count, 16), n(b, 16, 4UL)),
  )
  let next = b.mux(
    finish_request.unwrap_or(result),
    b.mux(last, n(b, 3, 3UL), n(b, 3, 1UL)),
    b.mux(take, n(b, 3, 2UL), b.mux(r.launch, n(b, 3, 0UL), r.state.value())),
  )
  b.connect_next(
    r.state,
    b.mux(fault, n(b, 3, 4UL), b.mux(begin, n(b, 3, 1UL), next)),
  )
  b.connect_next(
    r.index,
    b.mux(
      begin,
      n(b, 15, 0UL),
      b.mux(result, b.add(r.index.value(), n(b, 15, 1UL)), r.index.value()),
    ),
  )
  b.connect_next(
    r.cycles,
    b.mux(
      accepted,
      n(b, 32, 0UL),
      b.mux(
        both(b, [r.busy, b.bit_not(eq(b, r.state.value(), 4UL))]),
        b.add(r.cycles.value(), n(b, 32, 1UL)),
        r.cycles.value(),
      ),
    ),
  )
}
