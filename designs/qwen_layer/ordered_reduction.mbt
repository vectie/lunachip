///|
fn reduction_stream_op(m : Machine) -> @wire.Signal raise {
  either(m.b, [m.is_op(5UL), m.is_op(6UL), m.is_op(7UL)])
}

///|
fn reduction_stream_eligible(m : Machine) -> @wire.Signal raise {
  let b = m.b
  let size = b.mux(m.is_op(5UL), m.v("k"), m.v("n"))
  all(b, [
    reduction_stream_op(m),
    b.equal(m.v("flags"), u(b, 32, 0UL)),
    b.greater_equal(size, u(b, 32, 4UL)),
  ])
}

///|
// Each term reads one scratch word for a sum and two for a dot product.
// A mirrored read port supplies both dot operands on the same edge. The
// pipelined adder spaces dependent terms by two edges. All variants retire
// in column order. State 8 writes the result before advancing to another row.
fn ordered_reduction_pipeline(
  m : Machine,
  scratch : @wire.Signal,
  healthy : @wire.Signal,
  second~ : @wire.Signal? = None,
  direct_writeback~ : Bool = false,
) -> (@wire.Signal, @wire.Signal)? raise {
  let b = m.b
  let op = reduction_stream_op(m)
  let dot = m.is_op(5UL)
  let left = b.bit_and(op, m.is_state(29UL))
  let right = if second is Some(_) {
    left
  } else {
    b.bit_and(op, m.is_state(30UL))
  }
  let live = b.bit_and(
    op,
    either(b, [m.is_state(29UL), m.is_state(30UL), m.is_state(31UL)]),
  )
  let issue = if second is Some(_) {
    left
  } else {
    b.bit_or(right, b.bit_and(left, b.bit_not(dot)))
  }
  let one = u(b, 32, 1UL)
  let last = b.equal(b.add(m.v("i"), one), b.mux(dot, m.v("k"), m.v("n")))
  if second is None {
    m.jump(b.bit_and(left, dot), 30UL)
  }
  if m.bounded_add {
    // The returning sum is ready two edges after the operand pair enters
    // the adder. Leave one edge between successive terms of this same row.
    let waiting = b.bit_and(op, m.is_state(30UL))
    let next = if m.deep_fp32_add {
      let gap = b.register_state_in(m.d, @wire.uint(2), reset=m.reset)
      b.connect_next(
        gap,
        b.mux(waiting, b.add(gap.value(), u(b, 2, 1UL)), u(b, 2, 0UL)),
      )
      b.bit_and(waiting, b.equal(gap.value(), u(b, 2, 2UL)))
    } else {
      waiting
    }
    m.jump(next, 29UL)
  }
  m.put(
    "state",
    issue,
    b.mux(last, u(b, 5, 31UL), u(b, 5, if m.bounded_add { 30UL } else { 29UL })),
  )
  increment(m, "ai", issue, 1UL)
  increment(m, "i", issue, 1UL)
  m.put(
    "bi",
    if second is Some(_) {
      b.bit_and(dot, issue)
    } else {
      right
    },
    b.add(m.v("bi"), m.v("bs")),
  )
  let next_row = all(b, [
    m.is_state(8UL),
    dot,
    reduction_stream_eligible(m),
    b.less_than(b.add(m.v("row"), one), m.v("n")),
  ])
  m.jump(next_row, 29UL)

  fn delay(x : @wire.Signal, cycles : Int32) -> @wire.Signal raise {
    let mut result = x
    for _ in 0..<cycles {
      result = b.register_in(m.d, result, reset=m.reset)
    }
    result
  }
  let a = if second is Some(_) {
    scratch
  } else {
    b.mux(dot, delay(scratch, 1), scratch)
  }
  let operand = if second is Some(word) {
    b.mux(dot, word, scratch)
  } else {
    scratch
  }
  // SUM bypasses multiplication. Selecting its delayed operand before
  // the third product register leaves the adder a registered source and
  // preserves all valid edges, including consecutive reduction descriptors.
  let term = if m.staged_reduction_term {
    fp32_multiply_pipeline3(
      b,
      m.d,
      m.reset,
      a,
      operand,
      fast=true,
      final_bypass=Some(
        (
          m.is_op(6UL),
          delay(
            scratch,
            if m.registered_multiply_inputs {
              4
            } else if m.staged_multiply_product {
              3
            } else {
              2
            },
          ),
        ),
      ),
      compact_pack=m.compact_multiply_pack,
      staged_product=m.staged_multiply_product,
      registered_inputs=m.registered_multiply_inputs,
    )
  } else {
    let product = fp32_multiply_pipeline3(
      b,
      m.d,
      m.reset,
      a,
      operand,
      fast=true,
      compact_pack=m.compact_multiply_pack,
      staged_product=m.staged_multiply_product,
      registered_inputs=m.registered_multiply_inputs,
    )
    b.mux(
      m.is_op(6UL),
      delay(
        scratch,
        if m.registered_multiply_inputs {
          5
        } else if m.staged_multiply_product {
          4
        } else {
          3
        },
      ),
      product,
    )
  }
  let latency = if m.registered_multiply_inputs {
    9
  } else if m.staged_multiply_product {
    8
  } else if m.deep_fp32_add {
    7
  } else if m.bounded_add {
    5
  } else {
    4
  }
  let retire = all(b, [
    live,
    delay(issue, latency),
    healthy,
    b.bit_not(b.reset_asserted(m.rs)),
  ])
  let acc = b.register_state_in(m.d, @wire.uint(32), reset=m.reset)
  let sum = if m.bounded_add {
    add(
      b,
      acc.value(),
      term,
      fast=true,
      bounded=true,
      stage_aligned=m.deep_fp32_add,
      stage_normalized=m.deep_fp32_add,
      pipeline=Some((m.d, m.reset)),
    )
  } else {
    feedback_add(b, acc.value(), term)
  }
  b.connect_next(
    acc,
    b.mux(live, b.mux(retire, sum, acc.value()), u(b, 32, 0UL)),
  )
  increment(m, "products", b.bit_and(retire, b.bit_not(m.is_op(6UL))), 1UL)
  let done = b.bit_and(retire, delay(last, latency))
  let writeback = if direct_writeback {
    // The last retirement clocks the sum into acc and enters state 8.
    // Scratch can consume that register on the following write edge.
    let ready = delay(done, 1)
    m.put("out", ready, acc.value())
    Some((ready, acc.value()))
  } else {
    m.put("out", done, sum)
    None
  }
  m.jump(done, 8UL)
  writeback
}
