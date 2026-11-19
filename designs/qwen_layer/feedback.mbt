///|
// Addition of two binary32 values cannot produce a nonzero magnitude below
// the least subnormal. Bound cancellation normalization at exponent one so
// the result needs no second variable underflow shifter before rounding.
fn addition_normalize(
  b : @wire.ModuleBuilder,
  sig : @wire.Signal,
  exponent : @wire.Signal,
) -> (@wire.Signal, @wire.Signal) raise {
  let mut probe = sig
  let decisions : Array[@wire.Signal] = []
  for distance in [16, 8, 4, 2, 1] {
    let empty = b.equal(field(b, probe, 26, 27 - distance), u(b, distance, 0UL))
    probe = b.mux(
      empty,
      b.shift_left(probe, u(b, 5, distance.to_uint64())),
      probe,
    )
    decisions.push(b.reinterpret(empty, @wire.uint(1)))
  }
  let mut leading = decisions[0]
  for part in decisions[1:] {
    leading = cat(b, leading, part)
  }
  let limit = b.sub(exponent, u(b, 9, 1UL))
  let subnormal = b.less_than(limit, b.zero_extend(leading, 9))
  // The normal path already contains its shifted value. Calculate the
  // subnormal shift in parallel instead of shifting again after leading-zero
  // detection. The five-bit limit is used only when limit < leading <= 31.
  (
    b.mux(subnormal, b.shift_left(sig, b.truncate(limit, 5)), probe),
    b.mux(subnormal, u(b, 9, 1UL), b.sub(exponent, b.zero_extend(leading, 9))),
  )
}

///|
// The biased exponent is >=1. An absent hidden bit denotes a subnormal;
// rounding may promote it to the smallest normal. This is still binary32 RNE.
fn addition_pack(
  b : @wire.ModuleBuilder,
  sign : @wire.Signal,
  exponent : @wire.Signal,
  sig : @wire.Signal,
) -> @wire.Signal raise {
  let up = b.bit_and(
    bit(b, sig, 2),
    either(b, [bit(b, sig, 3), b.not_equal(field(b, sig, 1, 0), u(b, 2, 0UL))]),
  )
  let rounded = b.add(
    b.zero_extend(field(b, sig, 26, 3), 25),
    b.zero_extend(b.reinterpret(up, @wire.uint(1)), 25),
  )
  let carry = bit(b, rounded, 24)
  let exp = b.add(
    exponent,
    b.zero_extend(b.reinterpret(carry, @wire.uint(1)), 9),
  )
  let normal = b.bit_or(carry, bit(b, rounded, 23))
  let encoded_exp = b.mux(normal, field(b, exp, 7, 0), u(b, 8, 0UL))
  let fraction = b.mux(
    carry,
    field(b, rounded, 23, 1),
    field(b, rounded, 22, 0),
  )
  b.mux(
    b.greater_equal(exp, u(b, 9, 255UL)),
    cat(b, sign, u(b, 31, 0x7f800000UL)),
    cat(b, sign, cat(b, encoded_exp, fraction)),
  )
}

///|
// Close opposite-sign operands use a one-bit aligner and full cancellation
// normalization. The far path uses a full aligner but at most one left shift.
// Both paths preserve the original ordered, separately rounded FP32 sum.
fn feedback_add(
  b : @wire.ModuleBuilder,
  a : @wire.Signal,
  c : @wire.Signal,
) -> @wire.Signal raise {
  // Far-path alignment depends only on exponents. Equal-exponent operands
  // need magnitude ordering only for close subtraction; calculate both
  // subtraction directions below rather than delaying alignment on a full
  // 31-bit magnitude comparison.
  let ae = field(b, a, 30, 23)
  let ce = field(b, c, 30, 23)
  let swap = b.less_than(ae, ce)
  let x = b.mux(swap, c, a)
  let y = b.mux(swap, a, c)
  let xe = field(b, x, 30, 23)
  let ye = field(b, y, 30, 23)
  let xn = b.not_equal(xe, u(b, 8, 0UL))
  let yn = b.not_equal(ye, u(b, 8, 0UL))
  let ex = b.mux(xn, xe, u(b, 8, 1UL))
  let ey = b.mux(yn, ye, u(b, 8, 1UL))
  let distance = b.sub(ex, ey)
  let different = b.bit_xor(bit(b, x, 31), bit(b, y, 31))
  let xm = cat(
    b,
    cat(b, b.reinterpret(xn, @wire.uint(1)), field(b, x, 22, 0)),
    u(b, 3, 0UL),
  )
  let ym = cat(
    b,
    cat(b, b.reinterpret(yn, @wire.uint(1)), field(b, y, 22, 0)),
    u(b, 3, 0UL),
  )
  let near = b.bit_and(different, b.less_equal(distance, u(b, 8, 1UL)))
  let near_y = b.mux(
    b.equal(distance, u(b, 8, 0UL)),
    ym,
    b.logical_shift_right(ym, u(b, 1, 1UL)),
  )
  let forward = b.sub(b.zero_extend(xm, 28), b.zero_extend(near_y, 28))
  let reverse = b.sub(near_y, xm)
  let negative = bit(b, forward, 27)
  let near_raw = b.mux(negative, reverse, field(b, forward, 26, 0))
  let (near_sig, near_exp) = addition_normalize(
    b,
    near_raw,
    b.zero_extend(ex, 9),
  )
  let near_zero = b.equal(near_raw, u(b, 27, 0UL))
  let near_result = b.mux(
    near_zero,
    u(b, 32, 0UL),
    addition_pack(b, b.bit_xor(bit(b, x, 31), negative), near_exp, near_sig),
  )

  let far_y = b.zero_extend(jam(b, ym, distance), 28)
  let far_x = b.zero_extend(xm, 28)
  let raw = b.mux(different, b.sub(far_x, far_y), b.add(far_x, far_y))
  let carry = bit(b, raw, 27)
  let right = field(b, jam(b, raw, u(b, 1, 1UL)), 26, 0)
  let left = all(b, [
    different,
    b.bit_not(bit(b, raw, 26)),
    b.greater_than(ex, u(b, 8, 1UL)),
  ])
  let low = field(b, raw, 26, 0)
  let sig = b.mux(
    carry,
    right,
    b.mux(left, b.shift_left(low, u(b, 1, 1UL)), low),
  )
  let exp = b.sub(
    b.add(
      b.zero_extend(ex, 9),
      b.zero_extend(b.reinterpret(carry, @wire.uint(1)), 9),
    ),
    b.zero_extend(b.reinterpret(left, @wire.uint(1)), 9),
  )
  let zero = b.equal(raw, u(b, 28, 0UL))
  let sign = b.mux(zero, b.bit_and(bit(b, x, 31), bit(b, y, 31)), bit(b, x, 31))
  let far_result = b.mux(
    zero,
    cat(b, sign, u(b, 31, 0UL)),
    addition_pack(b, sign, exp, sig),
  )
  let xi = b.equal(xe, u(b, 8, 255UL))
  let yi = b.equal(ye, u(b, 8, 255UL))
  let invalid = either(b, [
    b.bit_and(xi, b.not_equal(field(b, x, 22, 0), u(b, 23, 0UL))),
    b.bit_and(yi, b.not_equal(field(b, y, 22, 0), u(b, 23, 0UL))),
    all(b, [xi, yi, different]),
  ])
  b.mux(
    invalid,
    u(b, 32, 0x7fc00000UL),
    b.mux(xi, x, b.mux(near, near_result, far_result)),
  )
}

///|
/// Experimental close/far FP32 RNE adder for ordered accumulator feedback.
/// Example: `let hardware = @qwen_layer.feedback_adder()`.
pub fn feedback_adder() -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("qwen_fp32_feedback_adder")
  let a = b.input("a", @wire.uint(32))
  let c = b.input("b", @wire.uint(32))
  b.connect(b.output("result", @wire.uint(32)), feedback_add(b, a, c))
  b.finish()
}

///|
/// Ordered FP32 accumulator accepting a new value on every enabled edge.
/// Reset clears the sum to positive zero; disabled edges preserve every bit.
pub fn feedback_accumulator() -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("qwen_fp32_feedback_accumulator")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  b.input_timing(rs, SampledIn(d.id()))
  let valid = b.input("valid", @wire.bits(1))
  let value = b.input("value", @wire.uint(32))
  for x in [valid, value] {
    b.input_timing(x, SampledIn(d.id()))
  }
  let sum = b.register_state_in(
    d,
    @wire.uint(32),
    reset=b.synchronous_reset(rs, 0UL),
  )
  b.connect_next(
    sum,
    b.mux(valid, feedback_add(b, sum.value(), value), sum.value()),
  )
  let output = b.output("sum", @wire.uint(32))
  b.output_timing(output, ProducedIn(d.id()))
  b.connect(output, sum.value())
  b.finish()
}
