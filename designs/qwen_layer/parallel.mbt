///|
// Four independent row accumulators preserve scalar k-order. A stripe loads
// four 128-byte weight lines, then issues one product per lane per cycle.
// Scratch A is read once and broadcast. Drain the full pipeline before moving
// to another chunk or writing a row. Single-ported BRAM writes stay serialized.
fn parallel_path(
  m : Machine,
  inputs : Map[String, @wire.Signal],
  activation : @wire.Signal,
) -> Map[String, @wire.Signal] raise {
  let b = m.b
  let safe = b.bit_not(b.reset_asserted(m.rs))
  let request = m.is_state(18UL)
  let accepted = b.bit_and(request, inputs["ddr_request_ready"])
  m.jump(accepted, 19UL)
  m.set("fill", accepted, 0UL)
  let response = all(b, [m.is_state(19UL), inputs["ddr_response_valid"]])
  let last = b.equal(m.v("fill"), u(b, 5, 31UL))
  let complete = b.bit_and(response, last)
  let bad = all(b, [
    response,
    either(b, [
      b.not_equal(inputs["ddr_response_fault"], u(b, 2, 0UL)),
      b.bit_xor(last, inputs["ddr_response_last"]),
    ]),
  ])
  increment(m, "fill", response, 1UL)
  increment(m, "ddr_beats", response, 1UL)
  let last_lane = b.equal(m.v("p_lane"), u(b, 2, 3UL))
  let next_lane = all(b, [complete, b.bit_not(last_lane)])
  increment(m, "p_lane", next_lane, 1UL)
  m.put(
    "p_address",
    next_lane,
    b.add(m.v("p_address"), b.shift_left(m.v("k"), u(b, 1, 1UL))),
  )
  m.jump(next_lane, 18UL)
  let begin = all(b, [complete, last_lane])
  m.set("p_index", begin, 0UL)
  m.jump(begin, 20UL)
  let issue = all(b, [m.is_state(20UL), safe])
  let final_issue = b.equal(m.v("p_index"), u(b, 6, 63UL))
  increment(m, "p_index", issue, 1UL)
  m.jump(b.bit_and(issue, final_issue), 21UL)
  fn delay(x : @wire.Signal, n : Int32) -> @wire.Signal raise {
    let mut r = x
    for _ in 0..<n {
      r = b.register_in(m.d, r, reset=m.reset)
    }
    r
  }
  let select_high = delay(bit(b, m.v("p_index"), 0), 1)
  let valid = delay(issue, 4)
  let final_product = delay(b.bit_and(issue, final_issue), 4)
  // A delayed token must never resurrect a terminal fault or commit after
  // loss of DDR health. Fault/reset can interrupt any pipeline drain edge.
  let commit = all(b, [
    valid,
    safe,
    inputs["memory_healthy"],
    either(b, [m.is_state(20UL), m.is_state(21UL)]),
  ])
  for lane in 0..<4 {
    let weights = b.synchronous_memory(
      "parallel_weight_" + lane.to_string(),
      @wire.uint(32),
      32,
      m.d,
      read_write_policy=ReadOld,
      multi_write_policy=Reject,
    )
    b.memory_write(
      weights,
      "ddr",
      m.v("fill"),
      inputs["ddr_response_data"],
      enable=all(b, [
        response,
        safe,
        b.equal(m.v("p_lane"), u(b, 2, lane.to_uint64())),
      ]),
    )
    let packed = b.memory_read(
      weights,
      "weight",
      field(b, m.v("p_index"), 5, 1),
      enable=issue,
      enable_behavior=HoldLast,
    )
    let weight = cat(
      b,
      b.mux(select_high, field(b, packed, 31, 16), field(b, packed, 15, 0)),
      u(b, 16, 0UL),
    )
    let product = fp32_multiply_pipeline3(b, m.d, m.reset, activation, weight)
    let name = "p_sum" + lane.to_string()
    m.put(name, commit, add(b, m.v(name), product))
  }
  increment(m, "products", commit, 4UL)
  m.jump(b.bit_and(commit, final_product), 22UL)
  let stripe_done = m.is_state(22UL)
  let next_chunk_value = b.add(m.v("p_chunk"), u(b, 32, 64UL))
  let next_chunk = all(b, [stripe_done, b.less_than(next_chunk_value, m.v("k"))])
  m.put("p_chunk", next_chunk, next_chunk_value)
  m.set("p_lane", next_chunk, 0UL)
  m.put(
    "p_address",
    next_chunk,
    b.add(
      m.v("ddr"),
      b.shift_left(
        b.add(b.mul_low(m.v("p_row"), m.v("k")), next_chunk_value),
        u(b, 1, 1UL),
      ),
    ),
  )
  m.jump(next_chunk, 18UL)
  let rows_done = all(b, [stripe_done, b.bit_not(next_chunk)])
  m.set("p_write", rows_done, 0UL)
  m.jump(rows_done, 23UL)
  let write = m.is_state(23UL)
  let final_write = b.equal(m.v("p_write"), u(b, 2, 3UL))
  increment(m, "p_write", write, 1UL)
  let next_row_value = b.add(m.v("p_row"), u(b, 32, 4UL))
  let more_rows = b.less_than(next_row_value, m.v("n"))
  let next_row = all(b, [write, final_write, more_rows])
  m.put("p_row", next_row, next_row_value)
  m.set("p_chunk", next_row, 0UL)
  m.set("p_lane", next_row, 0UL)
  m.put(
    "p_address",
    next_row,
    b.add(
      m.v("ddr"),
      b.shift_left(b.mul_low(next_row_value, m.v("k")), u(b, 1, 1UL)),
    ),
  )
  for lane in 0..<4 {
    m.set("p_sum" + lane.to_string(), next_row, 0UL)
  }
  m.jump(next_row, 18UL)
  m.jump(all(b, [write, final_write, b.bit_not(more_rows)]), 13UL)
  let mut data = m.v("p_sum0")
  for lane in 1..<4 {
    data = b.mux(
      b.equal(m.v("p_write"), u(b, 2, lane.to_uint64())),
      m.v("p_sum" + lane.to_string()),
      data,
    )
  }
  // Fault dominates all normal DDR transitions in this helper.
  m.jump(bad, 15UL)
  m.set("error", bad, 4UL)
  Map([
    ("request_valid", request),
    ("request_address", m.memory_address(m.v("p_address"))),
    (
      "write_address",
      b.truncate(
        b.add(
          m.v("dst"),
          b.add(m.v("p_row"), b.zero_extend(m.v("p_write"), 32)),
        ),
        15,
      ),
    ),
    ("write_data", data),
  ])
}
