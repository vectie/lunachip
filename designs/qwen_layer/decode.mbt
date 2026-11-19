///|
fn machine_decode(
  m : Machine,
  matrix : @wire.Signal,
  reduction : @wire.Signal,
  load : @wire.Signal,
  external_matrix : @wire.Signal,
  parallel~ : Bool = false,
  overlap~ : Bool = false,
) -> Unit raise {
  let b = m.b
  let decode = m.is_state(3UL)
  let halt = m.is_op(0UL)
  let one = u(b, 32, 1UL)
  let zero = u(b, 32, 0UL)
  let count = b.mux(matrix, m.v("k"), m.v("n"))
  let dest_count = b.mux(reduction, one, m.v("n"))
  let b_count = b.mux(b.equal(m.v("flags"), one), one, m.v("n"))
  // The 16 descriptor words are fetched serially. In the high-clock profile
  // their shape, strides and base are stable well before the reserved tail.
  // Pipeline this address arithmetic during fetch, before it fans out to all
  // 64 accumulator clears. All operations retain the existing widths.
  fn stage(x : @wire.Signal) -> @wire.Signal raise {
    if m.staged_decode {
      b.register_in(m.d, x, reset=m.reset)
    } else {
      x
    }
  }
  let last_b = stage(
    b.add(
      m.v("b"),
      b.add(
        stage(b.mul_low(stage(b.sub(m.v("n"), one)), m.v("br"))),
        stage(b.mul_low(stage(b.sub(m.v("k"), one)), m.v("bs"))),
      ),
    ),
  )
  let memory_size = b.mux(
    external_matrix,
    b.mul_low(stage(b.mul_low(m.v("n"), m.v("k"))), u(b, 32, 2UL)),
    if m.indirect_bf16 {
      b.mux(indirect_load(m), u(b, 32, 4UL), b.mul_low(m.v("n"), u(b, 32, 4UL)))
    } else {
      b.mul_low(m.v("n"), u(b, 32, 4UL))
    },
  )
  // Shape checks below bound memory_size to 32 MiB. Widen the address/end
  // addition in the 2 GiB profile so a UInt32 wrap cannot pass the aperture.
  // Preserve the original PRX100 graph and overflow guard in its default.
  let (memory_base, memory_extent, extent_width) = match m.memory {
    MiB256 => (m.v("ddr"), b.add(m.v("ddr"), memory_size), 32)
    GiB2 => {
      let base = b.zero_extend(m.v("ddr"), 33)
      (base, b.add(base, b.zero_extend(memory_size, 33)), 33)
    }
  }
  let valid : Array[@wire.Signal] = [
    b.less_equal(m.v("op"), u(b, 32, 15UL)),
    b.greater_equal(m.v("n"), one),
    b.less_equal(m.v("n"), u(b, 32, 4096UL)),
    b.less_than(m.v("dst"), u(b, 32, 32768UL)),
    b.less_than(m.v("a"), u(b, 32, 32768UL)),
    b.less_than(m.v("b"), u(b, 32, 32768UL)),
    b.less_equal(b.add(m.v("dst"), dest_count), u(b, 32, 32768UL)),
    b.less_equal(b.add(m.v("a"), count), u(b, 32, 32768UL)),
    b.less_equal(m.v("flags"), u(b, 32, 2UL)),
    b.mux(
      matrix,
      all(b, [
        b.greater_equal(m.v("k"), one),
        b.less_equal(m.v("k"), u(b, 32, 4096UL)),
        b.less_equal(m.v("bs"), u(b, 32, 32768UL)),
        b.less_equal(m.v("br"), u(b, 32, 32768UL)),
        b.mux(
          external_matrix,
          b.equal(field(b, m.v("k"), 5, 0), u(b, 6, 0UL)),
          b.less_than(last_b, u(b, 32, 32768UL)),
        ),
      ]),
      b.less_equal(b.add(m.v("b"), b_count), u(b, 32, 32768UL)),
    ),
    b.mux(
      either(b, [external_matrix, load, m.is_op(15UL)]),
      all(b, [
        match m.memory {
          MiB256 => b.equal(field(b, m.v("ddr"), 31, 28), u(b, 4, 0UL))
          GiB2 => b.less_than(m.v("ddr"), u(b, 32, m.memory.capacity_bytes()))
        },
        b.equal(field(b, m.v("ddr"), 1, 0), u(b, 2, 0UL)),
        b.less_equal(
          memory_extent,
          u(b, extent_width, m.memory.capacity_bytes()),
        ),
        b.greater_equal(memory_extent, memory_base),
        b.mux(
          external_matrix,
          b.equal(field(b, m.v("ddr"), 6, 0), u(b, 7, 0UL)),
          b.constant(@wire.bits(1), 1UL),
        ),
      ]),
      b.constant(@wire.bits(1), 1UL),
    ),
  ]
  if m.indirect_bf16 {
    let indirect = indirect_load(m)
    valid.push(
      b.bit_or(
        b.bit_not(indirect),
        b.equal(field(b, m.v("n"), 5, 0), u(b, 6, 0UL)),
      ),
    )
    m.put("bf16_pointer", decode, indirect)
  }
  for
    name in [
      "reserved11", "reserved12", "reserved13", "reserved14", "reserved15",
    ] {
    if !m.staged_decode {
      valid.push(b.equal(m.v(name), zero))
    }
  }
  if m.packed_weights {
    valid.push(
      b.mux(
        external_matrix,
        either(b, [
          b.equal(m.v("flags"), zero),
          all(b, [
            b.equal(m.v("flags"), one),
            b.equal(field(b, m.v("n"), 3, 0), u(b, 4, 0UL)),
            either(b, [
              b.less_equal(b.add(m.v("dst"), m.v("n")), m.v("a")),
              b.less_equal(b.add(m.v("a"), m.v("k")), m.v("dst")),
            ]),
          ]),
        ]),
        b.constant(@wire.bits(1), 1UL),
      ),
    )
  }
  let (accepted, rejected) = if m.staged_decode {
    let checks = [stage(all(b, valid))]
    for
      name in [
        "reserved11", "reserved12", "reserved13", "reserved14", "reserved15",
      ] {
      checks.push(b.equal(m.v(name), zero))
    }
    let checked = all(b, checks)
    (
      all(b, [decode, b.bit_not(halt), checked]),
      all(b, [decode, b.bit_not(halt), b.bit_not(checked)]),
    )
  } else {
    (
      all(b, [decode, b.bit_not(halt), all(b, valid)]),
      all(b, [decode, b.bit_not(halt), b.bit_not(all(b, valid))]),
    )
  }
  m.jump(rejected, 15UL)
  m.set("error", rejected, 1UL)
  m.jump(b.bit_and(decode, halt), 14UL)
  for
    (dst, src) in [
      ("ai", "a"),
      ("bi", "b"),
      ("brow", "b"),
      ("di", "dst"),
      ("ext", "ddr"),
    ] {
    m.put(dst, accepted, m.v(src))
  }
  for name in ["i", "row", "fill", "product", "out"] {
    m.set(name, accepted, 0UL)
  }
  m.put("sum", accepted, b.mux(m.is_op(8UL), u(b, 32, 0xff800000UL), zero))
  m.put(
    "state",
    accepted,
    b.mux(b.bit_or(external_matrix, load), u(b, 5, 9UL), u(b, 5, 4UL)),
  )
  if parallel {
    let alignment_bits = if m.wide512 { 4 } else { m.lane_width }
    let fast = all(b, [
      accepted,
      external_matrix,
      b.equal(
        field(b, m.v("n"), alignment_bits - 1, 0),
        u(b, alignment_bits, 0UL),
      ),
      either(b, [
        b.less_equal(b.add(m.v("dst"), m.v("n")), m.v("a")),
        b.less_equal(b.add(m.v("a"), m.v("k")), m.v("dst")),
      ]),
    ])
    m.jump(fast, 18UL)
    m.put("p_address", fast, m.v("ddr"))
    if m.incremental_row_address {
      m.put("p_group_base", fast, m.v("ddr"))
    }
    if overlap {
      m.set("o_state", fast, 1UL)
      m.set("o_bank", fast, 0UL)
      m.set("o_active", fast, 0UL)
    }
    for name in ["p_row", "p_chunk", "p_index", "p_lane", "p_write"] {
      m.set(name, fast, 0UL)
    }
    for lane in 0..<(if m.ordered_array { 0 } else { m.accumulator_count() }) {
      m.set("p_sum" + lane.to_string(), fast, 0UL)
    }
  }
  if m.interleaved {
    let unary = either(b, [m.is_op(9UL), m.is_op(10UL), m.is_op(11UL)])
    let safe_alias = either(b, [
      b.equal(m.v("dst"), m.v("a")),
      b.less_equal(b.add(m.v("dst"), m.v("n")), m.v("a")),
      b.less_equal(b.add(m.v("a"), m.v("n")), m.v("dst")),
    ])
    let fast = all(b, [accepted, unary, safe_alias])
    if m.stream_unary {
      let legacy = b.input("unary_legacy", @wire.bits(1))
      b.input_timing(legacy, SampledIn(m.d.id()))
      m.put(
        "u_stream",
        accepted,
        all(b, [
          fast,
          b.bit_not(legacy),
          b.bit_or(m.is_op(9UL), m.is_op(11UL)),
          b.greater_equal(m.v("n"), u(b, 32, 64UL)),
        ]),
      )
    }
    m.jump(fast, 24UL)
    m.set("u_lane", fast, 0UL)
    m.put(
      "u_count",
      fast,
      b.truncate(
        b.mux(b.less_than(m.v("n"), u(b, 32, 4UL)), m.v("n"), u(b, 32, 4UL)),
        3,
      ),
    )
  }
  if m.pipelined_vectors {
    m.jump(b.bit_and(accepted, vector_pipeline_eligible(m)), 29UL)
  }
  if m.stream_reductions {
    m.jump(b.bit_and(accepted, reduction_stream_eligible(m)), 29UL)
  }
  let next = m.is_state(13UL)
  let more = b.less_than(
    b.add(b.zero_extend(m.v("pc"), 12), u(b, 12, 1UL)),
    m.v("limit"),
  )
  increment(m, "instructions", next, 1UL)
  increment(m, "pc", next, 1UL)
  m.set("fetch", next, 0UL)
  m.put("state", next, b.mux(more, u(b, 5, 1UL), u(b, 5, 15UL)))
  m.set("error", b.bit_and(next, b.bit_not(more)), 2UL)
}
