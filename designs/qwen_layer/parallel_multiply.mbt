///|
// Three edges: exact 24x24 product; full-width normalization; RNE pack.
// Sideband exceptions, signed zero and exponent travel with the product.
// staged_product adds a fourth edge: two independent 24x12 products, then
// their exact 48-bit sum. No partial product is rounded.
fn fp32_multiply_pipeline3(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  a : @wire.Signal,
  c : @wire.Signal,
  fast~ : Bool = false,
  bf16_weight~ : Bool = false,
  final_bypass~ : (@wire.Signal, @wire.Signal)? = None,
  compact_pack~ : Bool = false,
  staged_product~ : Bool = false,
  registered_inputs~ : Bool = false,
) -> @wire.Signal raise {
  assert_true(!staged_product || !bf16_weight)
  assert_true(!registered_inputs || staged_product)
  fn reg(x : @wire.Signal) -> @wire.Signal raise {
    b.register_in(d, x, reset~)
  }
  fn product_sideband(x : @wire.Signal) -> @wire.Signal raise {
    let first = reg(x)
    if staged_product {
      reg(first)
    } else {
      first
    }
  }
  let a = if registered_inputs { reg(a) } else { a }
  let c = if registered_inputs { reg(c) } else { c }
  let ae = field(b, a, 30, 23)
  let ce = field(b, c, 30, 23)
  let af = field(b, a, 22, 0)
  let cf = field(b, c, 22, 0)
  let an = b.not_equal(ae, u(b, 8, 0UL))
  let cn = b.not_equal(ce, u(b, 8, 0UL))
  let raw = reg(
    if staged_product {
      let ma = cat(b, b.reinterpret(an, @wire.uint(1)), af)
      let mc = cat(b, b.reinterpret(cn, @wire.uint(1)), cf)
      let low = reg(
        field(b, b.mul_full(ma, b.zero_extend(field(b, mc, 11, 0), 24)), 35, 0),
      )
      let high = reg(
        field(b, b.mul_full(ma, b.zero_extend(field(b, mc, 23, 12), 24)), 35, 0),
      )
      b.add(b.zero_extend(low, 48), cat(b, high, u(b, 12, 0UL)))
    } else if bf16_weight {
      cat(
        b,
        field(
          b,
          b.mul_full(
            cat(b, b.reinterpret(an, @wire.uint(1)), af),
            b.zero_extend(
              cat(b, b.reinterpret(cn, @wire.uint(1)), field(b, c, 22, 16)),
              24,
            ),
          ),
          31,
          0,
        ),
        u(b, 16, 0UL),
      )
    } else {
      b.mul_full(
        cat(b, b.reinterpret(an, @wire.uint(1)), af),
        cat(b, b.reinterpret(cn, @wire.uint(1)), cf),
      )
    },
  )
  let mut exponent = product_sideband(
    b.sub(
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
    ),
  )
  let sign = product_sideband(b.bit_xor(bit(b, a, 31), bit(b, c, 31)))
  let ai = b.equal(ae, u(b, 8, 255UL))
  let ci = b.equal(ce, u(b, 8, 255UL))
  let invalid = product_sideband(
    either(b, [
      b.bit_and(ai, b.not_equal(af, u(b, 23, 0UL))),
      b.bit_and(ci, b.not_equal(cf, u(b, 23, 0UL))),
      b.bit_and(ai, b.equal(field(b, c, 30, 0), u(b, 31, 0UL))),
      b.bit_and(ci, b.equal(field(b, a, 30, 0), u(b, 31, 0UL))),
    ]),
  )
  let infinity = product_sideband(b.bit_or(ai, ci))
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
  let normalized = reg(normalized)
  let exponent = reg(exponent)
  let zero = reg(b.equal(raw, u(b, 48, 0UL)))
  let sign = reg(sign)
  let invalid = reg(invalid)
  let infinity = reg(infinity)
  let sig = field(b, jam(b, normalized, u(b, 5, 21UL)), 26, 0)
  let product = b.mux(
    invalid,
    u(b, 32, 0x7fc00000UL),
    b.mux(
      infinity,
      cat(b, sign, u(b, 31, 0x7f800000UL)),
      b.mux(
        zero,
        cat(b, sign, u(b, 31, 0UL)),
        pack(b, sign, exponent, sig, compact_shift=compact_pack),
      ),
    ),
  )
  reg(
    match final_bypass {
      Some((select, word)) => b.mux(select, word, product)
      None => product
    },
  )
}

///|
/// Exact BF16-weight times FP32 activation; three edges, II one, FP32 RNE.
/// The weight is promoted by appending sixteen zero bits, including subnormals.
/// Example: `let hardware = @qwen_layer.bf16_weight_multiplier()`.
pub fn bf16_weight_multiplier() -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("qwen_bf16_weight_multiply_pipe3")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  b.input_timing(rs, SampledIn(d.id()))
  let a = b.input("a", @wire.uint(32))
  let c = b.input("b", @wire.uint(16))
  for x in [a, c] {
    b.input_timing(x, SampledIn(d.id()))
  }
  let result = fp32_multiply_pipeline3(
    b,
    d,
    b.synchronous_reset(rs, 0UL),
    a,
    cat(b, c, u(b, 16, 0UL)),
    fast=true,
    bf16_weight=true,
  )
  let out = b.output("result", @wire.uint(32))
  b.output_timing(out, ProducedIn(d.id()))
  b.connect(out, result)
  b.finish()
}

///|
/// Fully pipelined FP32 multiply, latency three edges (four with
/// `staged_product`, five with `registered_inputs`), initiation interval one.
/// Compact packing preserves latency.
/// Uses the identical generator as each complete-layer output-row lane.
pub fn pipelined_multiplier(
  fast~ : Bool = false,
  compact_pack~ : Bool = false,
  staged_product~ : Bool = false,
  registered_inputs~ : Bool = false,
) -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new(
    if fast {
      "qwen_fp32_multiply_fast_pipe3"
    } else {
      "qwen_fp32_multiply_pipe3"
    },
  )
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  b.input_timing(rs, SampledIn(d.id()))
  let a = b.input("a", @wire.uint(32))
  let c = b.input("b", @wire.uint(32))
  for x in [a, c] {
    b.input_timing(x, SampledIn(d.id()))
  }
  let result = fp32_multiply_pipeline3(
    b,
    d,
    b.synchronous_reset(rs, 0UL),
    a,
    c,
    fast~,
    compact_pack~,
    staged_product~,
    registered_inputs~,
  )
  let output = b.output("result", @wire.uint(32))
  b.output_timing(output, ProducedIn(d.id()))
  b.connect(output, result)
  b.finish()
}
