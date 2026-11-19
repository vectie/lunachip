///|
priv struct BurstWriter {
  complete : @wire.Signal
  active : @wire.Signal
  second : @wire.RegisterHandle
  words : Array[@wire.Signal]
}

///|
// The core fills one group while the bridge is idle. The address request
// consumes it once. Keep the payload stable until both W beats and B retire.
fn burst_writer(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  r : @wire.SynchronousReset,
  idle : @wire.Signal,
  healthy : @wire.Signal,
  accept : @wire.Signal,
  selected : @wire.Signal,
  staged_fill : Bool,
) -> BurstWriter raise {
  let valid = input(b, d, "request_fill_valid", 1)
  let index = input(b, d, "request_fill_index", 6)
  let data = input(b, d, "request_fill_data", 32)
  let fill = both(b, [idle, healthy, valid, b.bit_not(accept)])
  let count = b.register_state_in(d, @wire.uint(7), reset=r)
  let ordered = b.bit_or(
    eq(b, index, 0UL),
    b.equal(b.zero_extend(index, 7), count.value()),
  )
  let next = b.add(b.zero_extend(index, 7), n(b, 7, 1UL))
  b.connect_next(
    count,
    b.mux(
      accept,
      n(b, 7, 0UL),
      b.mux(fill, b.mux(ordered, next, n(b, 7, 0UL)), count.value()),
    ),
  )
  // Capture the scratch RAM output once per eight destination words. The
  // count still advances on the original fill edge. The final staged word
  // commits on the earliest command-accept edge, before either AXI W beat.
  let groups = if staged_fill {
    Array::makei(8, i => {
      let group = b.register_state_in(d, @wire.uint(32))
      update(
        b,
        group,
        b.bit_and(fill, eq(b, b.slice(index, 5, 3), i.to_uint64())),
        data,
      )
      group.value()
    })
  } else {
    []
  }
  let word_index = if staged_fill { b.register_in(d, index) } else { index }
  let word_fill = if staged_fill {
    b.register_in(d, fill, reset=r)
  } else {
    fill
  }
  let words = Array::makei(64, i => {
    let word = b.register_state_in(d, @wire.uint(32), reset=r)
    update(
      b,
      word,
      b.bit_and(word_fill, eq(b, word_index, i.to_uint64())),
      if staged_fill {
        groups[i / 8]
      } else {
        data
      },
    )
    word.value()
  })
  let active = b.register_state_in(d, @wire.bits(1), reset=r)
  update(b, active, accept, selected)
  {
    complete: eq(b, count.value(), 64UL),
    active: active.value(),
    second: b.register_state_in(d, @wire.bits(1), reset=r),
    words,
  }
}
