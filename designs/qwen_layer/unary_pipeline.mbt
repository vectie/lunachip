///|
// One outstanding nonlinear micro-op: capture operands/metadata, then allow
// the existing three-edge multiplier (or equally delayed sum) to settle.
// The legacy schedule commits on the fifth edge. The short schedule issues
// directly into stage one, then commits sums on edge two and products on four.
// Destination/operation metadata is captured once. FP32 operations stay ordered.
fn unary_pipeline(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  issue : @wire.Signal,
  commit : @wire.Signal,
  lhs : @wire.Signal,
  rhs : @wire.Signal,
  use_add : @wire.Signal,
  writes : Array[@wire.Signal],
  last : @wire.Signal,
  short~ : Bool = false,
) -> (@wire.Signal, Array[@wire.Signal], @wire.Signal) raise {
  fn capture(x : @wire.Signal) -> @wire.Signal raise {
    let r = b.register_state_in(d, x.signal_type(), reset~)
    b.connect_next(r, b.mux(issue, x, r.value()))
    r.value()
  }
  let a = if short { lhs } else { capture(lhs) }
  let c = if short { rhs } else { capture(rhs) }
  let selected = capture(use_add)
  let destinations = writes.map(x => b.bit_and(commit, capture(x)))
  let finished = b.bit_and(commit, capture(last))
  let product = fp32_multiply_pipeline3(b, d, reset, a, c, fast=true)
  let mut sum = add(b, a, c, fast=true, pipeline=Some((d, reset)))
  if !short {
    for _ in 0..<2 {
      sum = b.register_in(d, sum, reset~)
    }
  }
  (b.mux(selected, sum, product), destinations, finished)
}
