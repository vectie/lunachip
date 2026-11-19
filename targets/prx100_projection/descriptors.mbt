///|
// Four existing descriptor0.2 packets, generated into staging before publish.
fn descriptor_word(
  b : @wire.ModuleBuilder,
  index : @wire.Signal,
  tile : @wire.Signal,
) -> @wire.Signal raise {
  let op = u(b, b.slice(index, 4, 3))
  let word = u(b, b.slice(index, 2, 0))
  let tile32 = b.zero_extend(tile, 32)
  let id = b.add(
    b.add(b.shift_left(tile32, n(b, 3, 2UL)), b.zero_extend(op, 32)),
    n(b, 32, 1UL),
  )
  let slot = b.zero_extend(u(b, b.slice(tile, 0, 0)), 32)
  let region = b.shift_left(slot, n(b, 4, 11UL))
  let slots = b.mux(
    eq(b, op, 0UL),
    slot,
    b.mux(
      eq(b, op, 1UL),
      b.shift_left(slot, n(b, 5, 8UL)),
      b.mux(
        eq(b, op, 2UL),
        b.mul_low(slot, n(b, 32, 0x00010101UL)),
        b.shift_left(slot, n(b, 5, 16UL)),
      ),
    ),
  )
  let header = b.bit_or(
    n(b, 32, 0x200UL),
    b.shift_left(b.zero_extend(op, 32), n(b, 5, 16UL)),
  )
  let dims = b.mux(
    eq(b, op, 0UL),
    n(b, 32, 0x00100001UL),
    b.mux(eq(b, op, 1UL), n(b, 32, 0x00080010UL), n(b, 32, 0x00080001UL)),
  )
  let reduction = b.mux(eq(b, op, 2UL), n(b, 32, 16UL), n(b, 32, 0UL))
  let base = b.mux(
    eq(b, op, 0UL),
    b.add(n(b, 32, 256UL), region),
    b.mux(
      eq(b, op, 1UL),
      b.add(n(b, 32, 512UL), region),
      b.mux(eq(b, op, 3UL), b.add(n(b, 32, 1024UL), region), n(b, 32, 0UL)),
    ),
  )
  let stride = b.mux(
    eq(b, op, 0UL),
    n(b, 32, 16UL),
    b.mux(
      eq(b, op, 1UL),
      n(b, 32, 8UL),
      b.mux(eq(b, op, 3UL), n(b, 32, 32UL), n(b, 32, 0UL)),
    ),
  )
  let values = [header, id, dims, reduction, base, stride, slots, n(b, 32, 0UL)]
  let mut selected = n(b, 32, 0UL)
  for i, value in values {
    selected = b.mux(eq(b, word, i.to_uint64()), value, selected)
  }
  selected
}
