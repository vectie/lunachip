///|
/// Ordered BF16/FP32 matrices with four interleaved nonlinear contexts.
/// The 256-bit target issues 16 row-major products per edge. The 512-bit
/// target supports 32 or 64 products, with optional banked storage at 64.
/// Packed weights keep the 16-row layout. Aliasing vectors execute serially.
/// `deep_fp32_add` splits all scalar/vector nonlinear adders and lengthens
/// dependent issue spacing. It requires ordered_array, pipelined_vectors,
/// staged_add_inputs, staged_unary_inputs and staged_scalar_alignment.
/// `compact_multiply_pack` requires deep_fp32_add; `staged_multiply_product`
/// additionally requires compact packing and adds one multiplier edge with
/// explicit scalar/reduction/nonlinear scheduling adjustments.
/// `incremental_row_address` requires ordered_array and staged_decode; it
/// advances row-group addresses by a descriptor-derived byte stride.
/// `eager_weight_reads` requires the ordered banked array. Read-only weight
/// ports run throughout matrix state20; credit still gates valid MAC issues.
/// `state_scratch_mux` requires eager_weight_reads and selects scratch write
/// addresses/data by exclusive execution ownership; write permits stay exact.
/// Example: `let hardware = @qwen_layer.interleaved_layer_machine()`.
pub fn interleaved_layer_machine(
  memory~ : MemoryAperture = MiB256,
  pipelined_vectors~ : Bool = false,
  wide512~ : Bool = false,
  rows64~ : Bool = false,
  banked64~ : Bool = false,
  prefetch256~ : Bool = false,
  scalar_lines~ : Bool = false,
  store_bursts~ : Bool = false,
  stream_unary~ : Bool = false,
  staged_decode~ : Bool = false,
  stream_reductions~ : Bool = false,
  paired_rows~ : Bool = false,
  full_rows~ : Bool = false,
  dual_read~ : Bool = false,
  indirect_bf16~ : Bool = false,
  bounded_add~ : Bool = false,
  deep_batch~ : Bool = false,
  strided_rows~ : Bool = false,
  ordered_array~ : Bool = false,
  staged_add_inputs~ : Bool = false,
  group64_rows~ : Bool = false,
  stripe512~ : Bool = false,
  prefetch_row_blocks~ : Bool = false,
  staged_unary_inputs~ : Bool = false,
  staged_reduction_term~ : Bool = false,
  staged_scalar_add~ : Bool = false,
  staged_scalar_alignment~ : Bool = false,
  deep_fp32_add~ : Bool = false,
  compact_multiply_pack~ : Bool = false,
  staged_multiply_product~ : Bool = false,
  incremental_row_address~ : Bool = false,
  registered_multiply_inputs~ : Bool = false,
  eager_weight_reads~ : Bool = false,
  state_scratch_mux~ : Bool = false,
  direct_reduction_writeback~ : Bool = false,
) -> @ir.Module raise {
  make_layer_machine(
    true,
    overlap=true,
    wide=true,
    batch=true,
    throughput=true,
    compute=wide512,
    wide512~,
    rows64~,
    banked64~,
    prefetch256~,
    scalar_lines~,
    store_bursts~,
    stream_unary~,
    staged_decode~,
    stream_reductions~,
    paired_rows~,
    full_rows~,
    dual_read~,
    indirect_bf16~,
    bounded_add~,
    deep_batch~,
    strided_rows~,
    ordered_array~,
    staged_add_inputs~,
    group64_rows~,
    stripe512~,
    prefetch_row_blocks~,
    staged_unary_inputs~,
    staged_reduction_term~,
    staged_scalar_add~,
    staged_scalar_alignment~,
    deep_fp32_add~,
    compact_multiply_pack~,
    staged_multiply_product~,
    incremental_row_address~,
    registered_multiply_inputs~,
    eager_weight_reads~,
    state_scratch_mux~,
    direct_reduction_writeback~,
    eight_row=true,
    short_unary=true,
    sixteen_row=true,
    packed_weights=true,
    feedback=true,
    delivery=true,
    interleaved=true,
    pipelined_vectors~,
    memory~,
  )
}

///|
fn interleaved_select(m : Machine, prefix : String) -> @wire.Signal raise {
  let b = m.b
  let mut value = m.v(prefix + "0")
  for i in 1..<4 {
    value = b.mux(
      b.equal(m.v("u_lane"), u(b, 2, i.to_uint64())),
      m.v(prefix + i.to_string()),
      value,
    )
  }
  value
}

///|
// All scratch reads finish before the batch starts. Results retire in address
// order, stopping before the first invalid element to preserve scalar faults.
fn interleaved_unary_path(
  m : Machine,
  scratch_word : @wire.Signal,
) -> UnaryPorts raise {
  let b = m.b
  let scalar_start = m.is_state(11UL)
  let p = interleaved_unary_logic(
    b,
    m.d,
    m.reset,
    b.bit_or(scalar_start, m.is_state(26UL)),
    b.truncate(b.sub(m.v("op"), u(b, 32, 8UL)), 2),
    Array::makei(4, i => {
      b.mux(scalar_start, m.v("out"), m.v("u_value" + i.to_string()))
    }),
    bounded=m.bounded_add,
    staged_add_inputs=m.staged_unary_inputs,
    deep_add=m.deep_fp32_add,
    compact_pack=m.compact_multiply_pack,
    staged_product=m.staged_multiply_product,
    registered_inputs=m.registered_multiply_inputs,
  )
  let gather = m.is_state(24UL)
  m.jump(
    if m.stream_unary {
      b.bit_and(gather, b.bit_not(m.v("u_stream")))
    } else {
      gather
    },
    25UL,
  )
  let capture = m.is_state(25UL)
  for i in 0..<4 {
    m.put(
      "u_value" + i.to_string(),
      all(b, [capture, b.equal(m.v("u_lane"), u(b, 2, i.to_uint64()))]),
      scratch_word,
    )
  }
  let next_lane = b.add(b.zero_extend(m.v("u_lane"), 3), u(b, 3, 1UL))
  let last = b.equal(next_lane, m.v("u_count"))
  m.jump(b.bit_and(capture, last), 26UL)
  let more = b.bit_and(capture, b.bit_not(last))
  increment(m, "u_lane", more, 1UL)
  m.jump(more, 24UL)
  m.jump(m.is_state(26UL), 27UL)
  let finished = all(b, [m.is_state(27UL), p.done, b.bit_not(p.busy)])
  for i in 0..<4 {
    m.put("u_result" + i.to_string(), finished, p.results[i])
    m.put("u_error" + i.to_string(), finished, p.errors[i])
  }
  m.set("u_lane", finished, 0UL)
  m.jump(finished, 28UL)
  let error = interleaved_select(m, "u_error")
  let write = b.bit_and(m.is_state(28UL), b.bit_not(error))
  let end = b.bit_and(write, last)
  let next_i = b.add(m.v("i"), b.zero_extend(m.v("u_count"), 32))
  let last_element = b.equal(next_i, m.v("n"))
  let next = b.bit_and(end, b.bit_not(last_element))
  increment(m, "u_lane", b.bit_and(write, b.bit_not(last)), 1UL)
  m.set("u_lane", next, 0UL)
  m.put("i", next, next_i)
  let remaining = b.sub(m.v("n"), next_i)
  m.put(
    "u_count",
    next,
    b.truncate(
      b.mux(b.less_than(remaining, u(b, 32, 4UL)), remaining, u(b, 32, 4UL)),
      3,
    ),
  )
  m.jump(next, 24UL)
  m.jump(b.bit_and(end, last_element), 13UL)
  let bad = b.bit_and(m.is_state(28UL), error)
  m.jump(bad, 15UL)
  m.set("error", bad, 3UL)
  { busy: p.busy, done: p.done, error: p.errors[0], result: p.results[0], }
}
