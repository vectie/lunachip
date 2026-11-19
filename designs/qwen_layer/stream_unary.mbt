///|
// One virtual microprogram register at successive pipeline edges. Extend on
// demand so that repeated reads of the same version share their delay line.
priv struct UnaryStageValue {
  edge : Int32
  taps : Array[@wire.Signal]
}

///|
fn UnaryStageValue::at(
  v : UnaryStageValue,
  m : Machine,
  edge : Int32,
) -> @wire.Signal raise {
  guard edge >= v.edge else { fail("unary pipeline dependency goes backwards") }
  while v.taps.length() <= edge - v.edge {
    v.taps.push(m.b.register_in(m.d, v.taps.last().unwrap(), reset=m.reset))
  }
  v.taps[edge - v.edge]
}

///|
fn stream_value(x : @wire.Signal, edge : Int32) -> UnaryStageValue {
  { edge, taps: [x], }
}

///|
// Elaborate the very same sequence of separately rounded adds/multiplies as
// the shared four-context engine. Independent elements enter every edge.
fn stream_unary_arithmetic(
  m : Machine,
  input : @wire.Signal,
  exponential : Bool,
) -> UnaryStageValue raise {
  let b = m.b
  let seed = if exponential {
    u(
      b,
      32,
      Float::from_double(1.0 / 40320.0).reinterpret_as_uint().to_uint64(),
    )
  } else {
    b.sub(u(b, 32, 0x7ef311c3UL), input)
  }
  let words = [
    stream_value(input, 0),
    stream_value(seed, 0),
    stream_value(input, 0),
    stream_value(input, 0),
  ]
  let program = unary_programs()[if exponential { 2 } else { 0 }]
  for op in program {
    let (dst, kind, left, right, imm_left, imm_right, negate) = op
    let left_edge = if left < 0 { 0 } else { words[left].edge }
    let right_edge = if right < 0 { 0 } else { words[right].edge }
    let edge = if left_edge > right_edge { left_edge } else { right_edge }
    let a = if left < 0 {
      u(b, 32, imm_left.to_uint64())
    } else {
      words[left].at(m, edge)
    }
    let c = if right < 0 {
      u(b, 32, imm_right.to_uint64())
    } else {
      words[right].at(m, edge)
    }
    let c = if negate { b.bit_xor(c, u(b, 32, 0x80000000UL)) } else { c }
    words[dst] = if kind == 1 {
      stream_value(
        b.register_in(
          m.d,
          add(
            b,
            a,
            c,
            fast=true,
            bounded=m.bounded_add,
            stage_aligned=m.deep_fp32_add,
            stage_normalized=m.deep_fp32_add,
            pipeline=Some((m.d, m.reset)),
          ),
          reset=m.reset,
        ),
        edge + (if m.deep_fp32_add { 4 } else { 2 }),
      )
    } else {
      stream_value(
        fp32_multiply_pipeline3(
          b,
          m.d,
          m.reset,
          a,
          c,
          fast=true,
          compact_pack=m.compact_multiply_pack,
          staged_product=m.staged_multiply_product,
          registered_inputs=m.registered_multiply_inputs,
        ),
        edge +
        (if m.registered_multiply_inputs {
          5
        } else if m.staged_multiply_product {
          4
        } else {
          3
        }),
      )
    }
  }
  words[1]
}

///|
// State 24 owns the scratch read port through drain. Reset, memory failure
// or the first invalid operand suppresses all later writes of that launch.
fn stream_unary_path(
  m : Machine,
  scratch : @wire.Signal,
  healthy : @wire.Signal,
) -> (@wire.Signal, @wire.Signal, @wire.Signal, @wire.Signal) raise {
  let b = m.b
  let owner = m.is_state(24UL)
  let live = all(b, [
    owner,
    m.v("u_stream"),
    healthy,
    b.bit_not(b.reset_asserted(m.rs)),
  ])
  let issue = b.bit_and(live, b.less_than(m.v("i"), m.v("n")))
  increment(m, "i", issue, 1UL)
  let exp = m.is_op(11UL)
  let rcp = stream_unary_arithmetic(m, scratch, false)
  let poly = stream_unary_arithmetic(m, scratch, true)
  let depth = if rcp.edge > poly.edge { rcp.edge } else { poly.edge }
  let magnitude = field(b, scratch, 30, 0)
  let domain = b.mux(
    exp,
    b.less_equal(magnitude, u(b, 31, 0x7f800000UL)),
    all(b, [
      b.bit_not(bit(b, scratch, 31)),
      b.greater_equal(magnitude, u(b, 31, 0x1f800000UL)),
      b.less_equal(magnitude, u(b, 31, 0x5f800000UL)),
    ]),
  )
  let clipped = b.greater_than(magnitude, u(b, 31, 0x42000000UL))
  let clip_value = b.mux(
    bit(b, scratch, 31),
    u(b, 32, 0UL),
    u(b, 32, 0x7f800000UL),
  )
  let exp_value = b.mux(
    stream_value(clipped, 0).at(m, depth),
    stream_value(clip_value, 0).at(m, depth),
    poly.at(m, depth),
  )
  let value = b.mux(exp, exp_value, rcp.at(m, depth))
  // One edge for the synchronous scratch read, followed by the arithmetic.
  let retire = b.bit_and(live, stream_value(issue, 0).at(m, depth + 1))
  let ok = stream_value(domain, 0).at(m, depth)
  let write = b.bit_and(retire, ok)
  let dest = b.truncate(m.v("di"), 15)
  let final_word = b.equal(
    b.add(m.v("di"), u(b, 32, 1UL)),
    b.add(m.v("dst"), m.v("n")),
  )
  increment(m, "di", write, 1UL)
  m.jump(b.bit_and(write, final_word), 13UL)
  let fault = b.bit_and(retire, b.bit_not(ok))
  m.jump(fault, 15UL)
  m.set("error", fault, 3UL)
  (write, dest, value, owner)
}
