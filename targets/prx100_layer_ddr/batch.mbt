///|
// A marked wide read uses data31 as four-row mode and data27:0 as byte stride.
// Validate the entire extent in 30/31 bits before truncation to the 256 MiB ABI.
// The opt-in eight-row form works in 128-byte units: all accepted addresses
// and strides have seven zero low bits, already checked by the full header
// predicate. A21+7*S21 fits24bits. Raw malformed headers still fail the original
// alignment/shape checks. Prove equivalence of the full predicate, not this
// extent fragment alone. boundary_negative is used only by the formal miter.
fn invalid_batch_address(
  b : @wire.ModuleBuilder,
  header : @wire.Signal,
  eight_row~ : Bool = false,
  sixteen_row~ : Bool = false,
  aligned_extent~ : Bool = false,
  boundary_negative~ : Bool = false,
) -> @wire.Signal raise {
  assert_true(!aligned_extent || eight_row)
  assert_true(!boundary_negative || aligned_extent)
  assert_true(!sixteen_row || eight_row)
  let extent_bits = if sixteen_row && aligned_extent {
    25
  } else if sixteen_row {
    32
  } else if aligned_extent {
    24
  } else if eight_row {
    31
  } else {
    30
  }
  let stride = b.zero_extend(
    u(b, b.slice(header, 27, if aligned_extent { 7 } else { 0 })),
    extent_bits,
  )
  let extent = b.add(
    b.add(
      b.zero_extend(
        u(b, b.slice(header, 59, if aligned_extent { 39 } else { 32 })),
        extent_bits,
      ),
      b.mul_low(
        stride,
        n(
          b,
          extent_bits,
          if sixteen_row {
            15UL
          } else if eight_row {
            7UL
          } else {
            3UL
          },
        ),
      ),
    ),
    n(b, extent_bits, if aligned_extent { 0UL } else { 127UL }),
  )
  both(b, [
    b.slice(header, 63, 63),
    b.slice(header, 31, 31),
    any(b, [
      b.bit_not(eq(b, b.slice(header, 30, 28), 0UL)),
      b.bit_not(eq(b, b.slice(header, 6, 0), 0UL)),
      eq(b, stride, 0UL),
      if boundary_negative {
        b.greater_equal(extent, n(b, extent_bits, 0x1fffffUL))
      } else {
        b.greater_than(
          extent,
          n(
            b,
            extent_bits,
            if aligned_extent {
              0x1fffffUL
            } else {
              0xfffffffUL
            },
          ),
        )
      },
    ]),
  ])
}

///|
fn batch_native_offset(
  b : @wire.ModuleBuilder,
  header : @wire.Signal,
  row : @wire.Signal,
) -> @wire.Signal raise {
  let marked = both(b, [
    b.slice(header, 63, 63),
    b.slice(header, 62, 62),
    b.slice(header, 61, 61),
    b.bit_not(b.slice(header, 60, 60)),
    b.slice(header, 31, 31),
  ])
  b.mux(
    marked,
    b.mul_low(b.zero_extend(row, 27), u(b, b.slice(header, 27, 1))),
    n(b, 27, 0UL),
  )
}

///|
fn observe_batch(
  observations : Array[Observation],
  row : @wire.RegisterHandle?,
  advance : @wire.Signal?,
) -> Unit {
  if row is Some(r) {
    observations.push({ name: "batch_row", node: r.value().id(), })
    observations.push({ name: "advance_row", node: advance.unwrap().id(), })
  }
}
