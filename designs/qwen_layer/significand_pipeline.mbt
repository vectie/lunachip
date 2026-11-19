///|
/// Exact unsigned 24-by-8 significand product for a BF16 weight and FP32
/// activation. Accepts one operand pair per edge. The result for the first
/// pair appears on the thirteenth edge. Only payload bits cross this pipeline.
/// `full_product` selects an exact integer multiply with the same latency;
/// a backend may map it to a hardware multiplier. The default uses compressors.
pub fn significand_product_pipeline(
  full_product~ : Bool = false,
) -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("qwen_significand_product_pipeline")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let a = b.input("activation", @wire.uint(24))
  let w = b.input("weight", @wire.uint(8))
  b.input_timing(a, SampledIn(d.id()))
  b.input_timing(w, SampledIn(d.id()))
  let value = significand_product(b, d, a, w, full_product~)
  let result = b.output("result", @wire.uint(32))
  b.output_timing(result, ProducedIn(d.id()))
  b.connect(result, value)
  b.finish()
}

///|
fn significand_product(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  a : @wire.Signal,
  w : @wire.Signal,
  full_product~ : Bool = false,
) -> @wire.Signal raise {
  fn stage(x : @wire.Signal) -> @wire.Signal raise {
    b.register_in(d, x)
  }
  fn left(x : @wire.Signal, amount : Int32) -> @wire.Signal raise {
    b.shift_left(x, u(b, 5, amount.to_uint64()))
  }
  if full_product {
    // Keep the 13-edge interface. Two result registers leave a place for
    // the target's multiplier and output registers; operand delays precede
    // the multiplication so a long result SRL cannot absorb both registers.
    let mut a = a
    let mut w = w
    for _ in 0..<11 {
      a = stage(a)
      w = stage(w)
    }
    // mul_full takes equal-width operands. The upper 16 result bits are
    // mathematically zero for this zero-extended unsigned 24-by-8 product.
    return stage(stage(field(b, b.mul_full(a, b.zero_extend(w, 24)), 31, 0)))
  }
  let a = stage(a)
  let w = stage(w)
  let mut rows : Array[@wire.Signal] = []
  for i in 0..<8 {
    let part = b.mux(bit(b, w, i), a, u(b, 24, 0UL))
    rows.push(stage(left(b.zero_extend(part, 32), i)))
  }
  // Each compressor sends its carry to the next stage and bit position.
  while rows.length() > 2 {
    let next = []
    let mut i = 0
    while i + 2 < rows.length() {
      let x = rows[i]
      let y = rows[i + 1]
      let z = rows[i + 2]
      let xy = b.bit_xor(x, y)
      next.push(stage(b.bit_xor(xy, z)))
      next.push(stage(left(b.bit_or(b.bit_and(x, y), b.bit_and(xy, z)), 1)))
      i += 3
    }
    while i < rows.length() {
      next.push(stage(rows[i]))
      i += 1
    }
    rows = next
  }
  // Each prefix level doubles the span of the carry it resolves.
  let mut prop = stage(b.bit_xor(rows[0], rows[1]))
  let mut gen = stage(b.bit_and(rows[0], rows[1]))
  let mut low_sum = prop
  for distance in [1, 2, 4, 8, 16] {
    let next_gen = b.bit_or(gen, b.bit_and(prop, left(gen, distance)))
    if distance < 16 {
      prop = stage(b.bit_and(prop, left(prop, distance)))
    }
    gen = stage(next_gen)
    low_sum = stage(low_sum)
  }
  stage(b.bit_xor(low_sum, left(gen, 1)))
}
