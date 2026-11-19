///|
fn add(
  b : @wire.ModuleBuilder,
  a : @wire.Signal,
  c : @wire.Signal,
  fast~ : Bool = false,
  bounded~ : Bool = false,
  stage_aligned~ : Bool = false,
  stage_normalized~ : Bool = false,
  pipeline~ : (@wire.ClockDomain, @wire.SynchronousReset)? = None,
) -> @wire.Signal raise {
  let swap = b.less_than(field(b, a, 30, 0), field(b, c, 30, 0))
  let x = b.mux(swap, c, a)
  let y = b.mux(swap, a, c)
  let xe = field(b, x, 30, 23)
  let ye = field(b, y, 30, 23)
  let xn = b.not_equal(xe, u(b, 8, 0UL))
  let yn = b.not_equal(ye, u(b, 8, 0UL))
  let ex = b.mux(xn, xe, u(b, 8, 1UL))
  let ey = b.mux(yn, ye, u(b, 8, 1UL))
  let xm = cat(
    b,
    cat(b, b.reinterpret(xn, @wire.uint(1)), field(b, x, 22, 0)),
    u(b, 3, 0UL),
  )
  let ym = jam(
    b,
    cat(
      b,
      cat(b, b.reinterpret(yn, @wire.uint(1)), field(b, y, 22, 0)),
      u(b, 3, 0UL),
    ),
    b.sub(ex, ey),
  )
  let different = b.bit_xor(bit(b, x, 31), bit(b, y, 31))
  // Optional alignment edge. Every caller opting in must also delay its
  // metadata and, for dependent accumulation, lengthen its issue interval.
  let (x, y, xe, ye, ex, xm, ym, different) = if stage_aligned {
    guard pipeline is Some((d, reset)) && bounded else {
      fail("aligned stage requires a bounded pipelined adder")
    }
    fn reg(v : @wire.Signal) -> @wire.Signal raise {
      b.register_in(d, v, reset~)
    }
    (
      reg(x),
      reg(y),
      reg(xe),
      reg(ye),
      reg(ex),
      reg(xm),
      reg(ym),
      reg(different),
    )
  } else {
    (x, y, xe, ye, ex, xm, ym, different)
  }
  let wide_x = b.zero_extend(xm, 28)
  let wide_y = b.zero_extend(ym, 28)
  let raw = b.mux(different, b.sub(wide_x, wide_y), b.add(wide_x, wide_y))
  let carry = bit(b, raw, 27)
  let scaled = b.mux(
    carry,
    field(b, jam(b, raw, u(b, 1, 1UL)), 26, 0),
    field(b, raw, 26, 0),
  )
  let initial_exp = b.add(
    b.reinterpret(b.zero_extend(ex, 11), @wire.sint(11)),
    b.reinterpret(b.zero_extend(carry, 11), @wire.sint(11)),
  )
  if pipeline is Some((d, reset)) {
    return registered_add_tail(
      b,
      d,
      reset,
      x,
      y,
      xe,
      ye,
      different,
      raw,
      scaled,
      initial_exp,
      bounded~,
      stage_normalized~,
    )
  }
  let (sig, exponent) = if fast {
    fast_normalize(b, scaled, initial_exp)
  } else {
    normalize(b, scaled, initial_exp)
  }
  // Exact cancellation is +0 under RNE; -0 + -0 remains -0.
  let sign = b.mux(
    b.equal(raw, u(b, 28, 0UL)),
    b.bit_and(bit(b, x, 31), bit(b, y, 31)),
    bit(b, x, 31),
  )
  let result = b.mux(
    b.equal(raw, u(b, 28, 0UL)),
    cat(b, sign, u(b, 31, 0UL)),
    pack(b, sign, exponent, sig),
  )
  let xi = b.equal(xe, u(b, 8, 255UL))
  let yi = b.equal(ye, u(b, 8, 255UL))
  let invalid = b.bit_or(
    b.bit_or(
      b.bit_and(xi, b.not_equal(field(b, x, 22, 0), u(b, 23, 0UL))),
      b.bit_and(yi, b.not_equal(field(b, y, 22, 0), u(b, 23, 0UL))),
    ),
    b.bit_and(b.bit_and(xi, yi), different),
  )
  b.mux(invalid, u(b, 32, 0x7fc00000UL), b.mux(xi, x, result))
}

///|
/// Experimental FP32 RNE adder with gradual underflow, signed zeros,
/// infinities and canonical quiet NaNs; no exception flags or other modes.
pub fn fp32_adder() -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("fp32_adder")
  let a = b.input("a", @wire.uint(32))
  let c = b.input("b", @wire.uint(32))
  let result = add(b, a, c)
  b.connect(b.output("result", @wire.uint(32)), result)
  b.finish()
}
