///|
// A pair of synchronous scratch reads feeds each element. Exact in-place
// operands are safe since the element is read before its own result retires.
// A broadcast must stay stable for every element in the descriptor.
fn vector_pipeline_eligible(m : Machine) -> @wire.Signal raise {
  let b = m.b
  let dst = m.v("dst")
  let n = m.v("n")
  let end = b.add(dst, n)
  fn safe_span(src : @wire.Signal) -> @wire.Signal raise {
    either(b, [
      b.equal(src, dst),
      b.less_equal(end, src),
      b.less_equal(b.add(src, n), dst),
    ])
  }
  let unary = b.bit_or(m.is_op(1UL), m.is_op(12UL))
  let binary = either(b, [m.is_op(2UL), m.is_op(3UL), m.is_op(13UL)])
  let src = m.v("b")
  let broadcast = b.equal(m.v("flags"), u(b, 32, 1UL))
  let safe_b = either(b, [
    unary,
    b.equal(m.v("flags"), u(b, 32, 2UL)),
    b.mux(
      broadcast,
      b.bit_or(b.less_than(src, dst), b.less_equal(end, src)),
      safe_span(src),
    ),
  ])
  all(b, [
    b.bit_or(unary, binary),
    b.greater_equal(n, u(b, 32, 4UL)),
    safe_span(m.v("a")),
    safe_b,
  ])
}

///|
// With one read port, states 29 and 30 alternate the two operands. A second
// port supplies both in state 29 on the same edge. State 31 drains the final
// write before the next descriptor can read the result.
fn vector_pipeline(
  m : Machine,
  scratch : @wire.Signal,
  healthy : @wire.Signal,
  second~ : @wire.Signal? = None,
  staged_add_inputs~ : Bool = false,
) -> (@wire.Signal, @wire.Signal, @wire.Signal, @wire.Signal) raise {
  let b = m.b
  fn reg(x : @wire.Signal) -> @wire.Signal raise {
    b.register_in(m.d, x, reset=m.reset)
  }
  let latency = if m.deep_fp32_add { 5 } else { 3 }
  fn delay(x : @wire.Signal, count : Int32) -> @wire.Signal raise {
    let mut value = x
    for _ in 0..<count {
      value = reg(value)
    }
    value
  }
  fn vector_state(state : UInt64) -> @wire.Signal raise {
    let active = m.is_state(state)
    if m.stream_reductions {
      b.bit_and(active, b.bit_not(reduction_stream_op(m)))
    } else {
      active
    }
  }
  let left = vector_state(29UL)
  let right = vector_state(30UL)
  let live = either(b, [left, right, vector_state(31UL)])
  let last = b.equal(b.add(m.v("i"), u(b, 32, 1UL)), m.v("n"))
  let read = if second is Some(_) { left } else { right }
  if second is None {
    m.jump(left, 30UL)
  }
  m.put("state", read, b.mux(last, u(b, 5, 31UL), u(b, 5, 29UL)))
  for name in ["i", "ai", "di"] {
    increment(m, name, read, 1UL)
  }
  increment(m, "bi", b.bit_and(read, b.equal(m.v("flags"), u(b, 32, 0UL))), 1UL)
  let issue = reg(read)
  let a = if second is Some(_) { scratch } else { reg(scratch) }
  let operand = b.mux(
    b.equal(m.v("flags"), u(b, 32, 2UL)),
    m.v("imm"),
    second.unwrap_or(scratch),
  )
  let factor = b.mux(
    b.bit_and(m.is_op(13UL), b.bit_not(bit(b, a, 31))),
    u(b, 32, 0x3f800000UL),
    operand,
  )
  let product = fp32_multiply_pipeline3(
    b,
    m.d,
    m.reset,
    a,
    factor,
    fast=true,
    compact_pack=m.compact_multiply_pack,
    staged_product=m.staged_multiply_product,
    registered_inputs=m.registered_multiply_inputs,
  )
  let product = if m.deep_fp32_add {
    delay(
      product,
      if m.registered_multiply_inputs {
        0
      } else if m.staged_multiply_product {
        1
      } else {
        2
      },
    )
  } else {
    product
  }
  // This path has three add edges to match the multiply. Move one of
  // the output delays to the inputs to isolate the long scratch RAM route.
  let (add_a, add_b) = if staged_add_inputs {
    (reg(a), reg(operand))
  } else {
    (a, operand)
  }
  let sum = reg(
    add(
      b,
      add_a,
      add_b,
      fast=true,
      bounded=m.bounded_add,
      stage_aligned=m.deep_fp32_add,
      stage_normalized=m.deep_fp32_add,
      pipeline=Some((m.d, m.reset)),
    ),
  )
  let sum = if staged_add_inputs { sum } else { reg(sum) }
  let moved = delay(
    b.mux(m.is_op(12UL), b.bit_or(a, u(b, 32, 0x80000000UL)), a),
    latency,
  )
  let mul = b.bit_or(m.is_op(3UL), m.is_op(13UL))
  increment(m, "products", all(b, [live, issue, mul]), 1UL)
  let write = all(b, [
    live,
    delay(issue, latency),
    healthy,
    b.bit_not(b.reset_asserted(m.rs)),
  ])
  let dest = delay(reg(b.truncate(m.v("di"), 15)), latency)
  let final_element = delay(reg(last), latency)
  m.jump(b.bit_and(write, final_element), 13UL)
  (write, dest, b.mux(mul, product, b.mux(m.is_op(2UL), sum, moved)), live)
}
