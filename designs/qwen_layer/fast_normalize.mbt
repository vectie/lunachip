///|
// The shift decisions are the same as normalize(). Assemble their binary
// distance in parallel instead of subtracting through five dependent adders.
fn fast_normalize(
  b : @wire.ModuleBuilder,
  sig : @wire.Signal,
  exponent : @wire.Signal,
) -> (@wire.Signal, @wire.Signal) raise {
  let mut value = sig
  let shifts : Array[@wire.Signal] = []
  for distance in [16, 8, 4, 2, 1] {
    let empty = b.equal(field(b, value, 26, 27 - distance), u(b, distance, 0UL))
    value = b.mux(
      empty,
      b.shift_left(value, u(b, 5, distance.to_uint64())),
      value,
    )
    shifts.push(b.reinterpret(empty, @wire.uint(1)))
  }
  let mut count = shifts[0]
  for shift in shifts[1:] {
    count = cat(b, count, shift)
  }
  (
    value,
    b.sub(exponent, b.reinterpret(b.zero_extend(count, 11), @wire.sint(11))),
  )
}

///|
/// Bit-exact RNE FP32 adder with parallel normalization distance calculation.
pub fn throughput_adder() -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("qwen_fp32_throughput_adder")
  let a = b.input("a", @wire.uint(32))
  let c = b.input("b", @wire.uint(32))
  b.connect(b.output("result", @wire.uint(32)), add(b, a, c, fast=true))
  b.finish()
}

///|
// Full 48-bit product normalization, retaining every low bit before RNE pack.
fn fast_normalize_product(
  b : @wire.ModuleBuilder,
  sig : @wire.Signal,
  exponent : @wire.Signal,
) -> (@wire.Signal, @wire.Signal) raise {
  let mut value = sig
  let shifts : Array[@wire.Signal] = []
  for distance in [32, 16, 8, 4, 2, 1] {
    let empty = b.equal(field(b, value, 47, 48 - distance), u(b, distance, 0UL))
    value = b.mux(
      empty,
      b.shift_left(value, u(b, 6, distance.to_uint64())),
      value,
    )
    shifts.push(b.reinterpret(empty, @wire.uint(1)))
  }
  let mut count = shifts[0]
  for shift in shifts[1:] {
    count = cat(b, count, shift)
  }
  (
    value,
    b.sub(exponent, b.reinterpret(b.zero_extend(count, 11), @wire.sint(11))),
  )
}
