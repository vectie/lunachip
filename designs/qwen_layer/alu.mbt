///|
/// One-edge observation vehicle for the exact FP32 adder/multiplier used by
/// the layer machine. Operation 0 multiplies; operation 1 adds. Not an FMA.
pub fn arithmetic_pipeline() -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("qwen_fp32_arithmetic")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  b.input_timing(rs, SampledIn(d.id()))
  let a = b.input("a", @wire.uint(32))
  let c = b.input("b", @wire.uint(32))
  let op = b.input("operation", @wire.bits(1))
  for x in [a, c, op] {
    b.input_timing(x, SampledIn(d.id()))
  }
  let result = b.register_in(
    d,
    b.mux(op, add(b, a, c), multiply(b, a, c)),
    reset=b.synchronous_reset(rs, 0UL),
  )
  let output = b.output("result", @wire.uint(32))
  b.output_timing(output, ProducedIn(d.id()))
  b.connect(output, result)
  b.finish()
}
