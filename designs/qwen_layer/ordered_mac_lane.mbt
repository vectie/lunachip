///|
/// Number of independent row slots per lane. Consecutive columns of a row
/// occupy the same slot on successive turns of this fixed pipeline.
pub const ORDERED_MAC_ROW_SLOTS : Int32 = 18

///|
fn MacPipe::add_next(
  self : MacPipe,
  base : @wire.Signal,
  term : @wire.Signal,
) -> @wire.Signal raise {
  let b = self.b
  let a = self.reg(base)
  let c = self.reg(term)
  let swap = self.reg(b.less_than(field(b, a, 30, 0), field(b, c, 30, 0)))
  // The ordering comparator and exponent work use the same input edge.
  // Register both differences while the significands are being exchanged.
  let ea = self.reg(effective_exponent(b, field(b, a, 30, 23)))
  let ec = self.reg(effective_exponent(b, field(b, c, 30, 23)))
  let gap_ac = self.reg(b.sub(ea, ec))
  let gap_ca = self.reg(b.sub(ec, ea))
  let gap = b.mux(self.reg(swap), gap_ca, gap_ac)
  let a = self.reg(a)
  let c = self.reg(c)
  let x = self.reg(b.mux(swap, c, a))
  let y = self.reg(b.mux(swap, a, c))
  let xe = field(b, x, 30, 23)
  let ye = field(b, y, 30, 23)
  let ex = effective_exponent(b, xe)
  let dist = self.reg(
    b.mux(
      b.greater_equal(gap, u(b, 8, 31UL)),
      u(b, 5, 31UL),
      field(b, gap, 4, 0),
    ),
  )
  fn mant(v : @wire.Signal, e : @wire.Signal) -> @wire.Signal raise {
    cat(
      b,
      cat(b, b.not_equal(e, u(b, 8, 0UL)), field(b, v, 22, 0)),
      u(b, 3, 0UL),
    )
  }
  let xm = self.delay(mant(x, xe), 6)
  let ym = self.align(self.reg(mant(y, ye)), dist)
  let different = b.bit_xor(bit(b, x, 31), bit(b, y, 31))
  let xw = b.zero_extend(xm, 28)
  let yw = b.zero_extend(ym, 28)
  let raw = self.reg(
    b.mux(self.delay(different, 6), b.sub(xw, yw), b.add(xw, yw)),
  )
  let carry = bit(b, raw, 27)
  let mut sig = self.reg(
    b.mux(
      carry,
      cat(
        b,
        field(b, raw, 27, 2),
        b.not_equal(field(b, raw, 1, 0), u(b, 2, 0UL)),
      ),
      field(b, raw, 26, 0),
    ),
  )
  let mut exp = self.reg(
    b.add(
      self.delay(b.zero_extend(ex, 9), 7),
      b.zero_extend(b.reinterpret(carry, @wire.uint(1)), 9),
    ),
  )
  // For finite sums stop shifting at biased exponent one. A subnormal then
  // has an unfilled hidden bit; rounding also handles promotion to normal.
  for step in [16, 8, 4, 2, 1] {
    let shift = b.bit_and(
      b.equal(field(b, sig, 26, 27 - step), u(b, step, 0UL)),
      b.greater_than(exp, u(b, 9, step.to_uint64())),
    )
    sig = self.reg(
      b.mux(shift, b.shift_left(sig, u(b, 5, step.to_uint64())), sig),
    )
    exp = self.reg(
      b.sub(exp, b.mux(shift, u(b, 9, step.to_uint64()), u(b, 9, 0UL))),
    )
  }
  let rounded = self.round_bits(sig)
  let zero = self.delay(b.equal(raw, u(b, 28, 0UL)), 7)
  let sx = self.delay(bit(b, x, 31), 14)
  let both_negative = self.delay(b.bit_and(bit(b, x, 31), bit(b, y, 31)), 14)
  let xi = b.equal(xe, u(b, 8, 255UL))
  let yi = b.equal(ye, u(b, 8, 255UL))
  let nan = either(b, [
    b.bit_and(xi, b.not_equal(field(b, x, 22, 0), u(b, 23, 0UL))),
    b.bit_and(yi, b.not_equal(field(b, y, 22, 0), u(b, 23, 0UL))),
    all(b, [xi, yi, different]),
  ])
  let finite = encode_rounded(b, rounded, self.reg(exp), sx)
  b.mux(
    self.delay(nan, 14),
    u(b, 32, 0x7fc00000UL),
    b.mux(
      self.delay(xi, 14),
      cat(b, sx, u(b, 31, 0x7f800000UL)),
      b.mux(zero, cat(b, both_negative, u(b, 31, 0UL)), finite),
    ),
  )
}

///|
/// Latency from the acceptance edge through the registered sum, inclusive.
pub const ORDERED_MAC_EDGES : Int32 = MAC_PRODUCT_EDGES + ORDERED_MAC_ROW_SLOTS

///|
/// Stream one FP32 activation and BF16 weight per edge. `first` initializes
/// this row slot to positive zero. Invalid edges preserve that slot's value.
/// Reset invalidates all slots and in-flight samples. A slot's columns arrive
/// in original order, spaced ORDERED_MAC_ROW_SLOTS edges apart.
/// `full_product` changes only the integer significand implementation, preserving
/// latency, FP32 rounding, exceptions, row order and the accumulation pipeline.
pub fn ordered_bf16_mac_lane(full_product~ : Bool = false) -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("qwen_ordered_bf16_mac_lane")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let p : MacPipe = { b, d, }
  let reset = b.input("reset", @wire.reset())
  b.input_timing(reset, SampledIn(d.id()))
  let reset = b.synchronous_reset(reset, 0UL)
  fn input(name : String, t : @ir.SignalType) -> @wire.Signal raise {
    let value = b.input(name, t)
    b.input_timing(value, SampledIn(d.id()))
    value
  }
  fn control(v : @wire.Signal, n : Int32) -> @wire.Signal raise {
    let mut x = v
    for _ in 0..<n {
      x = b.register_in(d, x, reset~)
    }
    x
  }
  let a = input("activation", @wire.uint(32))
  let w = input("weight", @wire.uint(16))
  let valid = control(input("valid", @wire.bits(1)), MAC_PRODUCT_EDGES)
  let first = p.delay(input("first", @wire.bits(1)), MAC_PRODUCT_EDGES)
  let product = p.product(a, w, full_product~)
  let sum = b.register_state_in(d, @wire.uint(32))
  let live = b.register_state_in(d, @wire.bits(1), reset~)
  let init = b.bit_or(b.bit_not(live.value()), b.bit_and(valid, first))
  let base = b.mux(init, u(b, 32, 0UL), sum.value())
  // -0 is the additive identity for both signs of zero under RNE.
  let term = b.mux(valid, product, u(b, 32, 0x80000000UL))
  b.connect_next(sum, p.add_next(base, term))
  b.connect_next(
    live,
    control(b.bit_or(live.value(), valid), ORDERED_MAC_ROW_SLOTS - 1),
  )
  for
    (name, signal) in [
      ("result", sum.value()),
      ("result_valid", control(valid, ORDERED_MAC_ROW_SLOTS)),
    ] {
    let out = b.output(name, signal.signal_type())
    b.output_timing(out, ProducedIn(d.id()))
    b.connect(out, signal)
  }
  b.finish()
}
