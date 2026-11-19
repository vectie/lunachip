///|
// Three internal boundaries; caller commits stage four. Magnitude ordering
// and alignment share the first stage; FP32 RNE arithmetic order is unchanged.
fn fast_add_pipeline(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  a : @wire.Signal,
  c : @wire.Signal,
) -> @wire.Signal raise {
  fn reg(x : @wire.Signal) -> @wire.Signal raise {
    b.register_in(d, x, reset~)
  }
  // Stage 0: order magnitudes.
  let swap = b.less_than(field(b, a, 30, 0), field(b, c, 30, 0))
  let x = b.mux(swap, c, a)
  let y = b.mux(swap, a, c)
  let xe = field(b, x, 30, 23)
  let ye = field(b, y, 30, 23)
  let xn = b.not_equal(xe, u(b, 8, 0UL))
  let yn = b.not_equal(ye, u(b, 8, 0UL))
  let ex = b.mux(xn, xe, u(b, 8, 1UL))
  let ey = b.mux(yn, ye, u(b, 8, 1UL))
  let different = b.bit_xor(bit(b, x, 31), bit(b, y, 31))
  let xi = b.equal(xe, u(b, 8, 255UL))
  let yi = b.equal(ye, u(b, 8, 255UL))
  let invalid = b.bit_or(
    b.bit_or(
      b.bit_and(xi, b.not_equal(field(b, x, 22, 0), u(b, 23, 0UL))),
      b.bit_and(yi, b.not_equal(field(b, y, 22, 0), u(b, 23, 0UL))),
    ),
    b.bit_and(b.bit_and(xi, yi), different),
  )
  // Stage 1: align and jam the smaller mantissa.
  let xm = reg(
    cat(
      b,
      cat(b, b.reinterpret(xn, @wire.uint(1)), field(b, x, 22, 0)),
      u(b, 3, 0UL),
    ),
  )
  let ym = reg(
    jam(
      b,
      cat(
        b,
        cat(b, b.reinterpret(yn, @wire.uint(1)), field(b, y, 22, 0)),
        u(b, 3, 0UL),
      ),
      b.sub(ex, ey),
    ),
  )
  let ex = reg(ex)
  let different = reg(different)
  let xs = reg(bit(b, x, 31))
  let ys = reg(bit(b, y, 31))
  let special = reg(xi)
  let exceptional = reg(b.mux(invalid, u(b, 32, 0x7fc00000UL), x))
  let wide_x = b.zero_extend(xm, 28)
  let wide_y = b.zero_extend(ym, 28)
  let raw = b.mux(different, b.sub(wide_x, wide_y), b.add(wide_x, wide_y))
  let carry = bit(b, raw, 27)
  // Stage 2: add/subtract, handle the carry and cancellation sign.
  let scaled = reg(
    b.mux(
      carry,
      field(b, jam(b, raw, u(b, 1, 1UL)), 26, 0),
      field(b, raw, 26, 0),
    ),
  )
  let exp = reg(
    b.add(
      b.reinterpret(b.zero_extend(ex, 11), @wire.sint(11)),
      b.reinterpret(b.zero_extend(carry, 11), @wire.sint(11)),
    ),
  )
  let zero = reg(b.equal(raw, u(b, 28, 0UL)))
  let sign = reg(b.mux(b.equal(raw, u(b, 28, 0UL)), b.bit_and(xs, ys), xs))
  let special = reg(special)
  let exceptional = reg(exceptional)
  // Stage 3: normalize cancellation, including all subnormal cases.
  let (sig, exp) = normalize(b, scaled, exp)
  let sig = reg(sig)
  let exp = reg(exp)
  let zero = reg(zero)
  let sign = reg(sign)
  let special = reg(special)
  let exceptional = reg(exceptional)
  b.mux(
    special,
    exceptional,
    b.mux(zero, cat(b, sign, u(b, 31, 0UL)), pack(b, sign, exp, sig)),
  )
}
