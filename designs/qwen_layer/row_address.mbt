///|
// Ordered row groups contain 16, 32, 64, 128, 256 or 512 BF16 rows.
// Descriptor fields are stable for at least ten fetch edges before decode;
// these two stages therefore settle before any accepted matrix request.
// Keep the full 32-bit shift/add semantics, including modular overflow.
fn staged_group_byte_stride(
  m : Machine,
  rows : @wire.Signal,
) -> @wire.Signal raise {
  let b = m.b
  let mut shift = u(b, 4, 5UL)
  for exponent in 5..<=9 {
    shift = b.mux(
      b.equal(rows, u(b, 32, 1UL << exponent)),
      u(b, 4, (exponent + 1).to_uint64()),
      shift,
    )
  }
  let shift = b.register_in(m.d, shift, reset=m.reset)
  b.register_in(m.d, b.shift_left(m.v("k"), shift), reset=m.reset)
}

///|
fn next_stripe_address(m : Machine, chunk : @wire.Signal) -> @wire.Signal raise {
  let b = m.b
  fn offset() -> @wire.Signal raise {
    if m.packed_weights {
      b.mux(
        b.equal(m.v("flags"), u(b, 32, 1UL)),
        b.shift_left(chunk, u(b, 3, 4UL)),
        chunk,
      )
    } else {
      chunk
    }
  }
  if m.incremental_row_address {
    b.add(m.v("p_group_base"), b.shift_left(offset(), u(b, 1, 1UL)))
  } else {
    b.add(
      m.v("ddr"),
      b.shift_left(
        b.add(b.mul_low(m.v("p_row"), m.v("k")), offset()),
        u(b, 1, 1UL),
      ),
    )
  }
}
