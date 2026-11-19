///|
fn indirect_load(m : Machine) -> @wire.Signal raise {
  m.b.bit_and(m.is_op(14UL), m.b.equal(m.v("flags"), u(m.b, 32, 1UL)))
}

///|
// LOAD flag 1 reads a 32-bit byte address, then expands complete 128-byte
// lines into scratch. The upper 16 bits of every FP32 word are the raw BF16
// operand. Validate the pointed-to span before issuing its first read.
fn indirect_bf16_load(
  m : Machine,
  inputs : Map[String, @wire.Signal],
  indirect : @wire.Signal,
  response : @wire.Signal,
  bad : @wire.Signal,
) -> Unit raise {
  let b = m.b
  let ok = all(b, [response, indirect, b.bit_not(bad)])
  let pointer = b.bit_and(ok, m.v("bf16_pointer"))
  let word = inputs["ddr_response_data"]
  let end = b.add(
    b.zero_extend(word, 33),
    b.shift_left(b.zero_extend(m.v("n"), 33), u(b, 1, 1UL)),
  )
  let valid = all(b, [
    b.equal(field(b, word, 6, 0), u(b, 7, 0UL)),
    b.less_equal(end, u(b, 33, m.memory.capacity_bytes())),
  ])
  m.put("ext", pointer, word)
  m.set("bf16_pointer", pointer, 0UL)
  m.jump(b.bit_and(pointer, valid), 9UL)
  let invalid = b.bit_and(pointer, b.bit_not(valid))
  m.jump(invalid, 15UL)
  m.set("error", invalid, 1UL)
  let receive = b.bit_and(ok, b.bit_not(m.v("bf16_pointer")))
  let writing = b.bit_and(indirect, m.is_state(8UL))
  let advance = b.bit_and(
    writing,
    b.not_equal(field(b, m.v("i"), 5, 0), u(b, 6, 63UL)),
  )
  m.put("ext", writing, m.v("ext"))
  increment(m, "ext", receive, 128UL)
  increment(m, "ddr_beats", receive, 32UL)
  m.put("out", receive, cat(b, field(b, word, 15, 0), u(b, 16, 0UL)))
  let rest = Array::makei(63, _ => {
    b.register_state_in(m.d, @wire.uint(16), reset=m.reset)
  })
  for i, r in rest {
    let j = i + 1
    let packed = if j == 1 {
      word
    } else {
      inputs["ddr_response_data" + (j / 2).to_string()]
    }
    let lo = j % 2 * 16
    let hold = if i + 1 < rest.length() {
      b.mux(advance, rest[i + 1].value(), r.value())
    } else {
      r.value()
    }
    b.connect_next(r, b.mux(receive, field(b, packed, lo + 15, lo), hold))
  }
  m.put("out", advance, cat(b, rest[0].value(), u(b, 16, 0UL)))
  m.jump(advance, 8UL)
}
