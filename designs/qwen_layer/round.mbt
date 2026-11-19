///|
fn u(
  b : @wire.ModuleBuilder,
  width : Int32,
  value : UInt64,
) -> @wire.Signal raise {
  b.constant(@wire.uint(width), value)
}

///|
fn bit(
  b : @wire.ModuleBuilder,
  x : @wire.Signal,
  index : Int32,
) -> @wire.Signal raise {
  b.slice(x, index, index)
}

///|
fn field(
  b : @wire.ModuleBuilder,
  x : @wire.Signal,
  high : Int32,
  low : Int32,
) -> @wire.Signal raise {
  b.reinterpret(b.slice(x, high, low), @wire.uint(high - low + 1))
}

///|
fn cat(
  b : @wire.ModuleBuilder,
  x : @wire.Signal,
  y : @wire.Signal,
) -> @wire.Signal raise {
  b.reinterpret(
    b.concat(x, y),
    @wire.uint(x.signal_type().width().bits() + y.signal_type().width().bits()),
  )
}

///|
fn signed_constant(b : @wire.ModuleBuilder, n : Int32) -> @wire.Signal raise {
  b.constant(@wire.sint(11), (n.to_int64() & 2047L).reinterpret_as_uint64())
}

///|
// Logical right shift with all discarded bits folded into bit zero.
fn jam(
  b : @wire.ModuleBuilder,
  x : @wire.Signal,
  amount : @wire.Signal,
) -> @wire.Signal raise {
  let width = x.signal_type().width().bits()
  let shifted = b.logical_shift_right(x, amount)
  let lost = b.not_equal(x, b.shift_left(shifted, amount))
  b.bit_or(shifted, b.zero_extend(b.reinterpret(lost, @wire.uint(1)), width))
}

///|
// sig has its leading one at bit26; exponent is the signed biased exponent.
// Three low bits are guard/round/sticky. Underflow is gradual, RNE throughout.
fn pack(
  b : @wire.ModuleBuilder,
  sign : @wire.Signal,
  exponent : @wire.Signal,
  sig : @wire.Signal,
  compact_shift~ : Bool = false,
) -> @wire.Signal raise {
  let tiny = b.less_than(exponent, signed_constant(b, 1))
  let distance = b.reinterpret(
    b.sub(signed_constant(b, 1), exponent),
    @wire.uint(11),
  )
  let adjusted = b.mux(
    tiny,
    if compact_shift {
      compact_jam27(b, sig, distance)
    } else {
      jam(b, sig, distance)
    },
    sig,
  )
  let base = field(b, adjusted, 26, 3)
  let round_up = b.bit_and(
    bit(b, adjusted, 2),
    b.bit_or(
      b.not_equal(field(b, adjusted, 1, 0), u(b, 2, 0UL)),
      bit(b, adjusted, 3),
    ),
  )
  let rounded = b.add(
    b.zero_extend(base, 25),
    b.zero_extend(b.reinterpret(round_up, @wire.uint(1)), 25),
  )
  let carry = bit(b, rounded, 24)
  let normal_exp = b.add(
    exponent,
    b.reinterpret(b.zero_extend(carry, 11), @wire.sint(11)),
  )
  let overflow = b.greater_equal(normal_exp, signed_constant(b, 255))
  let exp_bits = b.mux(
    tiny,
    b.reinterpret(b.zero_extend(bit(b, rounded, 23), 8), @wire.uint(8)),
    field(b, normal_exp, 7, 0),
  )
  let fraction = b.mux(
    carry,
    field(b, rounded, 23, 1),
    field(b, rounded, 22, 0),
  )
  let finite = cat(b, sign, cat(b, exp_bits, fraction))
  let infinity = cat(b, sign, u(b, 31, 0x7f800000UL))
  b.mux(b.bit_and(b.bit_not(tiny), overflow), infinity, finite)
}

///|
// Normalize a nonzero unsigned magnitude to bit26 using a logarithmic shifter.
fn normalize(
  b : @wire.ModuleBuilder,
  sig : @wire.Signal,
  exponent : @wire.Signal,
) -> (@wire.Signal, @wire.Signal) raise {
  let mut value = sig
  let mut exp = exponent
  for distance in [16, 8, 4, 2, 1] {
    let empty = b.equal(field(b, value, 26, 27 - distance), u(b, distance, 0UL))
    value = b.mux(
      empty,
      b.shift_left(value, u(b, 5, distance.to_uint64())),
      value,
    )
    exp = b.mux(empty, b.sub(exp, signed_constant(b, distance)), exp)
  }
  (value, exp)
}
