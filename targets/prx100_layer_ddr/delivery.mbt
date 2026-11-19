///|
// An eight-word response starts at a multiple of eight. Select each fixed
// word bank with the shared packet index instead of building eight independent
// 512-word selectors. The delivery harness proves the alignment invariant.
fn delivery_word(
  b : @wire.ModuleBuilder,
  index : @wire.Signal,
  words : ArrayView[@wire.Signal],
  lane : Int32,
) -> @wire.Signal raise {
  assert_eq(words.length(), 512)
  assert_eq(index.signal_type().width().bits(), 10)
  assert_true(lane >= 0 && lane < 8)
  fn select(first : Int32, level : Int32) -> @wire.Signal raise {
    if level == 0 {
      words[first * 8 + lane]
    } else {
      let half = 1 << (level - 1)
      let low = select(first, level - 1)
      let high = select(first + half, level - 1)
      b.mux(b.slice(index, level + 2, level + 2), high, low)
    }
  }
  b.mux(b.slice(index, 9, 9), words[0], select(0, 6))
}
