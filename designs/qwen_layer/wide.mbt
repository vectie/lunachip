///|
// Each 32-bit word of a 128-, 256- or 512-bit response has a separate bank.
// Reads retain one-cycle ReadOld/HoldLast semantics; the subword selector is
// delayed alongside that read before the unchanged multiplier pipeline.
fn wide_weight_bank(
  m : Machine,
  inputs : Map[String, @wire.Signal],
  lane : Int32,
  bank : Int32,
  response : @wire.Signal,
  good : @wire.Signal,
  issue : @wire.Signal,
  selected : @wire.Signal,
) -> @wire.Signal raise {
  let b = m.b
  let read_words : Array[@wire.Signal] = []
  let word_bits = if m.wide512 { 4 } else if m.delivery { 3 } else { 2 }
  let word_count = 1 << word_bits
  for word in 0..<word_count {
    let weights = b.synchronous_memory(
      "wide_weight_" +
      lane.to_string() +
      "_" +
      bank.to_string() +
      "_" +
      word.to_string(),
      @wire.uint(32),
      32,
      m.d,
      read_write_policy=ReadOld,
      multi_write_policy=Reject,
    )
    b.memory_write(
      weights,
      "ddr",
      b.zero_extend(field(b, m.v("fill"), 4, word_bits), 5),
      inputs[if word == 0 {
        "ddr_response_data"
      } else {
        "ddr_response_data" + word.to_string()
      }],
      enable=all(b, [
        response,
        good,
        b.equal(m.v("o_bank"), b.constant(@wire.bits(1), bank.to_uint64())),
        b.equal(m.v("p_lane"), u(b, m.lane_width, lane.to_uint64())),
      ]),
    )
    read_words.push(
      b.memory_read(
        weights,
        "weight",
        b.zero_extend(field(b, m.v("p_index"), 5, word_bits + 1), 5),
        enable=b.bit_and(issue, selected),
        enable_behavior=HoldLast,
      ),
    )
  }
  let select = b.register_in(
    m.d,
    field(b, m.v("p_index"), word_bits, 1),
    reset=m.reset,
  )
  let mut result = read_words[0]
  for word in 1..<word_count {
    result = b.mux(
      b.equal(select, u(b, word_bits, word.to_uint64())),
      read_words[word],
      result,
    )
  }
  result
}
