///|
// Three registered multiplier stages. Exception selection follows the same
// canonical-NaN and gradual-underflow contract as the scalar primitive.
fn multiply_pipeline(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  a : @wire.Signal,
  w : @wire.Signal,
) -> @wire.Signal raise {
  fn reg(x : @wire.Signal) -> @wire.Signal raise {
    b.register_in(d, x, reset~)
  }
  let ae = field(b, a, 14, 7)
  let we = field(b, w, 14, 7)
  let an = b.not_equal(ae, u(b, 8, 0UL))
  let wn = b.not_equal(we, u(b, 8, 0UL))
  let af = field(b, a, 6, 0)
  let wf = field(b, w, 6, 0)
  let raw = reg(
    b.mul_full(
      cat(b, b.reinterpret(an, @wire.uint(1)), af),
      cat(b, b.reinterpret(wn, @wire.uint(1)), wf),
    ),
  )
  let exp = reg(
    b.sub(
      b.add(
        b.reinterpret(
          b.zero_extend(b.mux(an, ae, u(b, 8, 1UL)), 11),
          @wire.sint(11),
        ),
        b.reinterpret(
          b.zero_extend(b.mux(wn, we, u(b, 8, 1UL)), 11),
          @wire.sint(11),
        ),
      ),
      signed_constant(b, 126),
    ),
  )
  let sign = b.bit_xor(bit(b, a, 15), bit(b, w, 15))
  let ai = b.equal(ae, u(b, 8, 255UL))
  let wi = b.equal(we, u(b, 8, 255UL))
  let invalid = b.bit_or(
    b.bit_or(
      b.bit_and(ai, b.not_equal(af, u(b, 7, 0UL))),
      b.bit_and(wi, b.not_equal(wf, u(b, 7, 0UL))),
    ),
    b.bit_or(
      b.bit_and(ai, b.equal(field(b, w, 14, 0), u(b, 15, 0UL))),
      b.bit_and(wi, b.equal(field(b, a, 14, 0), u(b, 15, 0UL))),
    ),
  )
  let special = reg(b.bit_or(ai, wi))
  let exceptional = reg(
    b.mux(invalid, u(b, 32, 0x7fc00000UL), cat(b, sign, u(b, 31, 0x7f800000UL))),
  )
  let sign = reg(sign)
  let (sig, exp) = normalize(
    b,
    b.shift_left(b.zero_extend(raw, 27), u(b, 4, 11UL)),
    exp,
  )
  let sig = reg(sig)
  let exp = reg(exp)
  let zero = reg(b.equal(raw, u(b, 16, 0UL)))
  let special = reg(special)
  let exceptional = reg(exceptional)
  let sign = reg(sign)
  reg(
    b.mux(
      special,
      exceptional,
      b.mux(zero, cat(b, sign, u(b, 31, 0UL)), pack(b, sign, exp, sig)),
    ),
  )
}

///|
// Four internal register boundaries; caller commits the fifth (round/pack)
// stage. Feedback is issued every five cycles, preserving scalar sum order.
fn add_pipeline(
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
  let x = reg(b.mux(swap, c, a))
  let y = reg(b.mux(swap, a, c))
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
