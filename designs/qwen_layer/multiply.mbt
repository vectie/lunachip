///|
// Full FP32 product. Normalize all 48 product bits before guard/round/sticky
// compression so subnormal inputs cannot lose significant bits prematurely.
fn multiply(
  b : @wire.ModuleBuilder,
  a : @wire.Signal,
  c : @wire.Signal,
  fast~ : Bool = false,
) -> @wire.Signal raise {
  let ae = field(b, a, 30, 23)
  let ce = field(b, c, 30, 23)
  let af = field(b, a, 22, 0)
  let cf = field(b, c, 22, 0)
  let an = b.not_equal(ae, u(b, 8, 0UL))
  let cn = b.not_equal(ce, u(b, 8, 0UL))
  let am = cat(b, b.reinterpret(an, @wire.uint(1)), af)
  let cm = cat(b, b.reinterpret(cn, @wire.uint(1)), cf)
  let raw = b.mul_full(am, cm)
  let mut exponent = b.sub(
    b.add(
      b.reinterpret(
        b.zero_extend(b.mux(an, ae, u(b, 8, 1UL)), 11),
        @wire.sint(11),
      ),
      b.reinterpret(
        b.zero_extend(b.mux(cn, ce, u(b, 8, 1UL)), 11),
        @wire.sint(11),
      ),
    ),
    signed_constant(b, 126),
  )
  let mut normalized = raw
  if fast {
    let (value, shifted_exp) = fast_normalize_product(b, raw, exponent)
    normalized = value
    exponent = shifted_exp
  } else {
    for distance in [32, 16, 8, 4, 2, 1] {
      let empty = b.equal(
        field(b, normalized, 47, 48 - distance),
        u(b, distance, 0UL),
      )
      normalized = b.mux(
        empty,
        b.shift_left(normalized, u(b, 6, distance.to_uint64())),
        normalized,
      )
      exponent = b.mux(
        empty,
        b.sub(exponent, signed_constant(b, distance)),
        exponent,
      )
    }
  }
  let sig = field(b, jam(b, normalized, u(b, 5, 21UL)), 26, 0)
  let sign = b.bit_xor(bit(b, a, 31), bit(b, c, 31))
  let zero = b.equal(raw, u(b, 48, 0UL))
  let result = b.mux(
    zero,
    cat(b, sign, u(b, 31, 0UL)),
    pack(b, sign, exponent, sig),
  )
  let ai = b.equal(ae, u(b, 8, 255UL))
  let ci = b.equal(ce, u(b, 8, 255UL))
  let invalid = b.bit_or(
    b.bit_or(
      b.bit_and(ai, b.not_equal(af, u(b, 23, 0UL))),
      b.bit_and(ci, b.not_equal(cf, u(b, 23, 0UL))),
    ),
    b.bit_or(
      b.bit_and(ai, b.equal(field(b, c, 30, 0), u(b, 31, 0UL))),
      b.bit_and(ci, b.equal(field(b, a, 30, 0), u(b, 31, 0UL))),
    ),
  )
  b.mux(
    invalid,
    u(b, 32, 0x7fc00000UL),
    b.mux(b.bit_or(ai, ci), cat(b, sign, u(b, 31, 0x7f800000UL)), result),
  )
}

///|
/// FP32 non-fused RNE multiplication with gradual underflow and canonical NaN.
pub fn fp32_multiplier(fast~ : Bool = false) -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new(
    if fast {
      "qwen_fp32_fast_multiplier"
    } else {
      "qwen_fp32_multiplier"
    },
  )
  let a = b.input("a", @wire.uint(32))
  let c = b.input("b", @wire.uint(32))
  b.connect(b.output("result", @wire.uint(32)), multiply(b, a, c, fast~))
  b.finish()
}
