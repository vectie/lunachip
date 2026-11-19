///|
// BF16 operands, FP32 result. This is floating point, not scaled integer math.
fn multiply(
  b : @wire.ModuleBuilder,
  a : @wire.Signal,
  w : @wire.Signal,
) -> @wire.Signal raise {
  let ae = field(b, a, 14, 7)
  let we = field(b, w, 14, 7)
  let af = field(b, a, 6, 0)
  let wf = field(b, w, 6, 0)
  let an = b.not_equal(ae, u(b, 8, 0UL))
  let wn = b.not_equal(we, u(b, 8, 0UL))
  let am = cat(b, b.reinterpret(an, @wire.uint(1)), af)
  let wm = cat(b, b.reinterpret(wn, @wire.uint(1)), wf)
  let raw = b.mul_full(am, wm)
  let biased = b.sub(
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
  )
  // raw bit15 is the tentative leading one; bit14 corresponds to exponent-1.
  let (sig, exponent) = normalize(
    b,
    b.shift_left(b.zero_extend(raw, 27), u(b, 4, 11UL)),
    biased,
  )
  let sign = b.bit_xor(bit(b, a, 15), bit(b, w, 15))
  let zero = b.equal(raw, u(b, 16, 0UL))
  let result = b.mux(
    zero,
    cat(b, sign, u(b, 31, 0UL)),
    pack(b, sign, exponent, sig),
  )
  let ai = b.equal(ae, u(b, 8, 255UL))
  let wi = b.equal(we, u(b, 8, 255UL))
  let az = b.equal(field(b, a, 14, 0), u(b, 15, 0UL))
  let wz = b.equal(field(b, w, 14, 0), u(b, 15, 0UL))
  let invalid = b.bit_or(
    b.bit_or(
      b.bit_and(ai, b.not_equal(af, u(b, 7, 0UL))),
      b.bit_and(wi, b.not_equal(wf, u(b, 7, 0UL))),
    ),
    b.bit_or(b.bit_and(ai, wz), b.bit_and(wi, az)),
  )
  b.mux(
    invalid,
    u(b, 32, 0x7fc00000UL),
    b.mux(b.bit_or(ai, wi), cat(b, sign, u(b, 31, 0x7f800000UL)), result),
  )
}

///|
/// Experimental RNE BF16 multiplication producing FP32, including gradual
/// underflow and canonical quiet NaNs. No exception status flags are exported.
pub fn bf16_multiplier() -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("bf16_multiplier")
  let a = b.input("a", @wire.uint(16))
  let w = b.input("b", @wire.uint(16))
  let result = multiply(b, a, w)
  b.connect(b.output("result", @wire.uint(32)), result)
  b.finish()
}
