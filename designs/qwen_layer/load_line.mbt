///|
// A full aligned line can be read with the existing single-row, non-batched
// wide request. Scalar reads peel the unaligned prefix and handle the tail.
fn load_line_request(m : Machine, load : @wire.Signal) -> @wire.Signal raise {
  let b = m.b
  let aligned = all(b, [
    m.is_state(9UL),
    load,
    b.equal(field(b, m.v("ext"), 6, 0), u(b, 7, 0UL)),
    b.greater_equal(b.sub(m.v("n"), m.v("i")), u(b, 32, 32UL)),
  ])
  if m.indirect_bf16 {
    b.bit_and(aligned, b.bit_not(m.v("bf16_pointer")))
  } else {
    aligned
  }
}

///|
// State 10 owns the response until it arrives. State 8 commits each FP32
// word in sequence through the existing single scratch write port. No line
// survives the descriptor or supplies a subsequent request.
fn receive_load_line(
  m : Machine,
  inputs : Map[String, @wire.Signal],
  line : @wire.Signal,
  accepted : @wire.Signal,
  response : @wire.Signal,
  load : @wire.Signal,
) -> Unit raise {
  let b = m.b
  let wide = b.register_state_in(m.d, @wire.bits(1), reset=m.reset)
  b.connect_next(wide, b.mux(accepted, line, wide.value()))
  let receive = all(b, [
    response,
    load,
    wide.value(),
    inputs["ddr_response_last"],
    b.equal(inputs["ddr_response_fault"], u(b, 2, 0UL)),
  ])
  let advance = all(b, [
    m.is_state(8UL),
    load,
    wide.value(),
    b.not_equal(m.v("fill"), u(b, 5, 31UL)),
  ])
  let words = Array::makei(31, _ => {
    b.register_state_in(m.d, @wire.uint(32), reset=m.reset)
  })
  for i, reg in words {
    let hold = if i + 1 < words.length() {
      b.mux(advance, words[i + 1].value(), reg.value())
    } else {
      reg.value()
    }
    b.connect_next(
      reg,
      b.mux(receive, inputs["ddr_response_data" + (i + 1).to_string()], hold),
    )
  }
  m.put("out", advance, words[0].value())
  m.jump(advance, 8UL)
  increment(m, "fill", advance, 1UL)
  increment(m, "ddr_beats", receive, 32UL)
}
