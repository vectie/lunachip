///|
// A complete four-row request has 128 reserved words. A balanced mux avoids
// extending the legacy priority chain to 128 entries. Invalid indices retain
// table()'s exact fallback to word zero.
fn read_ahead_word(
  b : @wire.ModuleBuilder,
  index : @wire.Signal,
  words : ArrayView[@wire.Signal],
) -> @wire.Signal raise {
  assert_true([128, 256, 512].contains(words.length()))
  let levels = if words.length() == 512 {
    9
  } else if words.length() == 256 {
    8
  } else {
    7
  }
  assert_eq(index.signal_type().width().bits(), levels + 1)
  fn select(first : Int32, level : Int32) -> @wire.Signal raise {
    if level == 0 {
      words[first]
    } else {
      let half = 1 << (level - 1)
      let low = select(first, level - 1)
      let high = select(first + half, level - 1)
      b.mux(b.slice(index, level - 1, level - 1), high, low)
    }
  }
  let selected = select(0, levels)
  b.mux(b.slice(index, levels, levels), words[0], selected)
}

///|
// MIG addresses count 16-bit words. The header's byte stride is therefore
// explicitly divided by two. The accepted command, rather than app_en alone,
// advances the row offset, so command backpressure cannot skip a row.
fn read_ahead_offset(
  b : @wire.ModuleBuilder,
  fast : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  request : @wire.Signal,
  accept : @wire.Signal,
  command_fire : @wire.Signal,
  issued : @wire.Signal,
) -> @wire.Signal raise {
  let offset = b.register_state_in(fast, @wire.uint(27), reset~)
  let next_row = both(b, [
    command_fire,
    eq(b, b.slice(request, 63, 60), 14UL),
    b.slice(request, 31, 31),
    eq(b, b.slice(issued, 2, 0), 7UL),
  ])
  increment(b, offset, accept, next_row, u(b, b.slice(request, 27, 1)))
  offset.value()
}
