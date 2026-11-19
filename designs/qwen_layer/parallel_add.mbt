///|
// Capture the aligned sum before normalization and RNE packing. The caller's
// destination register is the second stage,so ordered feedback needs II=2.
fn registered_add_tail(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  x : @wire.Signal,
  y : @wire.Signal,
  xe : @wire.Signal,
  ye : @wire.Signal,
  different : @wire.Signal,
  raw : @wire.Signal,
  scaled : @wire.Signal,
  initial_exp : @wire.Signal,
  bounded~ : Bool = false,
  stage_normalized~ : Bool = false,
) -> @wire.Signal raise {
  fn reg(v : @wire.Signal) -> @wire.Signal raise {
    b.register_in(d, v, reset~)
  }
  let zero = b.equal(raw, u(b, 28, 0UL))
  let sign = reg(
    b.mux(zero, b.bit_and(bit(b, x, 31), bit(b, y, 31)), bit(b, x, 31)),
  )
  // Reset represents an empty add with result +0. The bounded
  // normalizer expects a positive biased exponent for a nonzero sum.
  let zero = if bounded { b.bit_not(reg(b.bit_not(zero))) } else { reg(zero) }
  let xi = b.equal(xe, u(b, 8, 255UL))
  let yi = b.equal(ye, u(b, 8, 255UL))
  let invalid = reg(
    either(b, [
      b.bit_and(xi, b.not_equal(field(b, x, 22, 0), u(b, 23, 0UL))),
      b.bit_and(yi, b.not_equal(field(b, y, 22, 0), u(b, 23, 0UL))),
      b.bit_and(b.bit_and(xi, yi), different),
    ]),
  )
  let infinity = reg(xi)
  let special = reg(x)
  let sig = reg(scaled)
  let exponent = reg(initial_exp)
  if bounded {
    // An exact sum of binary32 operands is an integer multiple of the
    // smallest subnormal. Limit cancellation shifts at biased exponent one.
    let exp9 = b.truncate(b.reinterpret(exponent, @wire.uint(11)), 9)
    let (magnitude, adjusted) = addition_normalize(b, sig, exp9)
    // Optional normalization edge, with exception, signed zero and ordinary
    // results at the same age. Callers explicitly account for this latency.
    let (magnitude, adjusted, sign, zero, invalid, infinity, special) = if stage_normalized {
      (
        reg(magnitude),
        reg(adjusted),
        reg(sign),
        b.bit_not(reg(b.bit_not(zero))),
        reg(invalid),
        reg(infinity),
        reg(special),
      )
    } else {
      (magnitude, adjusted, sign, zero, invalid, infinity, special)
    }
    let result = b.mux(
      zero,
      cat(b, sign, u(b, 31, 0UL)),
      addition_pack(b, sign, adjusted, magnitude),
    )
    return b.mux(
      invalid,
      u(b, 32, 0x7fc00000UL),
      b.mux(infinity, special, result),
    )
  }
  let (sig, exponent) = fast_normalize(b, sig, exponent)
  let result = b.mux(
    zero,
    cat(b, sign, u(b, 31, 0UL)),
    pack(b, sign, exponent, sig),
  )
  b.mux(invalid, u(b, 32, 0x7fc00000UL), b.mux(infinity, special, result))
}

///|
/// Ordered RNE FP32 addition,latency two edges,initiation interval one.
pub fn pipelined_adder(bounded~ : Bool = false) -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("qwen_fp32_add_pipe2")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  b.input_timing(rs, SampledIn(d.id()))
  let reset = b.synchronous_reset(rs, 0UL)
  let a = b.input("a", @wire.uint(32))
  let c = b.input("b", @wire.uint(32))
  for x in [a, c] {
    b.input_timing(x, SampledIn(d.id()))
  }
  let result = b.register_in(
    d,
    add(b, a, c, fast=true, bounded~, pipeline=Some((d, reset))),
    reset~,
  )
  let out = b.output("result", @wire.uint(32))
  b.output_timing(out, ProducedIn(d.id()))
  b.connect(out, result)
  b.finish()
}
