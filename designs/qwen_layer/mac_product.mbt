///|
priv struct MacPipe {
  b : @wire.ModuleBuilder
  d : @wire.ClockDomain
}

///|
fn MacPipe::delay(
  self : MacPipe,
  x : @wire.Signal,
  edges : Int32,
) -> @wire.Signal raise {
  let mut result = x
  for _ in 0..<edges {
    result = self.b.register_in(self.d, result)
  }
  result
}

///|
fn MacPipe::reg(self : MacPipe, x : @wire.Signal) -> @wire.Signal raise {
  self.b.register_in(self.d, x)
}

///|
fn effective_exponent(
  b : @wire.ModuleBuilder,
  e : @wire.Signal,
) -> @wire.Signal raise {
  b.mux(b.equal(e, u(b, 8, 0UL)), u(b, 8, 1UL), e)
}

///|
// One registered, constant-distance jam per level. Combining discarded bits
// into bit zero is associative across the five shifts.
fn MacPipe::align(
  self : MacPipe,
  x : @wire.Signal,
  shifts : @wire.Signal,
) -> @wire.Signal raise {
  let b = self.b
  let mut v = x
  for i, distance in [1, 2, 4, 8, 16] {
    let sticky = b.not_equal(field(b, v, distance, 0), u(b, distance + 1, 0UL))
    let shifted = cat(
      b,
      b.zero_extend(field(b, v, 26, distance + 1), 26),
      b.reinterpret(sticky, @wire.uint(1)),
    )
    v = self.reg(b.mux(self.delay(bit(b, shifts, i), i), shifted, v))
  }
  v
}

///|
// First edge rounds the 24-bit candidate; the caller registers the encoding
// on the following edge. An effective exponent of one also encodes subnormals.
fn MacPipe::round_bits(
  self : MacPipe,
  sig : @wire.Signal,
) -> @wire.Signal raise {
  let b = self.b
  let up = b.bit_and(
    bit(b, sig, 2),
    either(b, [bit(b, sig, 3), bit(b, sig, 1), bit(b, sig, 0)]),
  )
  self.reg(
    b.add(
      b.zero_extend(field(b, sig, 26, 3), 25),
      b.zero_extend(b.reinterpret(up, @wire.uint(1)), 25),
    ),
  )
}

///|
fn encode_rounded(
  b : @wire.ModuleBuilder,
  rounded : @wire.Signal,
  exponent : @wire.Signal,
  sign : @wire.Signal,
) -> @wire.Signal raise {
  let carry = bit(b, rounded, 24)
  let exp = b.add(
    exponent,
    b.zero_extend(b.reinterpret(carry, @wire.uint(1)), 9),
  )
  let normal = b.bit_or(carry, bit(b, rounded, 23))
  let finite = cat(
    b,
    b.mux(normal, field(b, exp, 7, 0), u(b, 8, 0UL)),
    field(b, rounded, 22, 0),
  )
  cat(
    b,
    sign,
    b.mux(b.greater_equal(exp, u(b, 9, 255UL)), u(b, 31, 0x7f800000UL), finite),
  )
}

///|
const MAC_PRODUCT_EDGES : Int32 = 28

///|
// The 32 significant product bits are normalized before any sticky compression.
fn MacPipe::product(
  self : MacPipe,
  activation : @wire.Signal,
  weight : @wire.Signal,
  full_product~ : Bool = false,
) -> @wire.Signal raise {
  let b = self.b
  let a = self.reg(activation)
  let w = self.reg(weight)
  let ae = field(b, a, 30, 23)
  let we = field(b, w, 14, 7)
  let af = field(b, a, 22, 0)
  let wf = field(b, w, 6, 0)
  let an = b.not_equal(ae, u(b, 8, 0UL))
  let wn = b.not_equal(we, u(b, 8, 0UL))
  let sign = b.bit_xor(bit(b, a, 31), bit(b, w, 15))
  let zero = b.bit_or(
    b.equal(field(b, a, 30, 0), u(b, 31, 0UL)),
    b.equal(field(b, w, 14, 0), u(b, 15, 0UL)),
  )
  let ai = b.equal(ae, u(b, 8, 255UL))
  let wi = b.equal(we, u(b, 8, 255UL))
  let inf = b.bit_or(ai, wi)
  let nan = either(b, [
    b.bit_and(ai, b.not_equal(af, u(b, 23, 0UL))),
    b.bit_and(wi, b.not_equal(wf, u(b, 7, 0UL))),
    b.bit_and(inf, zero),
  ])
  let e_sum = b.add(
    b.zero_extend(effective_exponent(b, ae), 11),
    b.zero_extend(effective_exponent(b, we), 11),
  )
  let biased = b.sub(
    b.reinterpret(e_sum, @wire.sint(11)),
    signed_constant(b, 126),
  )
  let mut raw = significand_product(
    b,
    self.d,
    cat(b, an, af),
    cat(b, wn, wf),
    full_product~,
  )
  let mut leading = u(b, 5, 0UL)
  for distance in [16, 8, 4, 2, 1] {
    let empty = b.equal(field(b, raw, 31, 32 - distance), u(b, distance, 0UL))
    leading = self.reg(
      b.bit_or(
        leading,
        b.mux(empty, u(b, 5, distance.to_uint64()), u(b, 5, 0UL)),
      ),
    )
    raw = self.reg(
      b.mux(empty, b.shift_left(raw, u(b, 5, distance.to_uint64())), raw),
    )
  }
  let e = self.reg(
    b.sub(
      self.delay(biased, 18),
      b.reinterpret(b.zero_extend(leading, 11), @wire.sint(11)),
    ),
  )
  let sig = self.reg(
    cat(b, field(b, raw, 31, 6), b.not_equal(field(b, raw, 5, 0), u(b, 6, 0UL))),
  )
  let tiny = b.less_than(e, signed_constant(b, 1))
  let distance = self.reg(
    b.mux(
      tiny,
      b.mux(
        b.less_equal(e, signed_constant(b, -30)),
        u(b, 5, 31UL),
        field(b, b.sub(signed_constant(b, 1), e), 4, 0),
      ),
      u(b, 5, 0UL),
    ),
  )
  let exp = self.reg(b.mux(tiny, u(b, 9, 1UL), field(b, e, 8, 0)))
  let rounded = self.round_bits(self.align(self.reg(sig), distance))
  let sign = self.delay(sign, 26)
  let finite = encode_rounded(b, rounded, self.delay(exp, 6), sign)
  self.reg(
    b.mux(
      self.delay(nan, 26),
      u(b, 32, 0x7fc00000UL),
      b.mux(
        self.delay(inf, 26),
        cat(b, sign, u(b, 31, 0x7f800000UL)),
        b.mux(self.delay(zero, 26), cat(b, sign, u(b, 31, 0UL)), finite),
      ),
    ),
  )
}
