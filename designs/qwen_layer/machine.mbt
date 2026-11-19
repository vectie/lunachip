///|
fn make_layer_machine(
  parallel : Bool,
  overlap~ : Bool = false,
  wide~ : Bool = false,
  batch~ : Bool = false,
  throughput~ : Bool = false,
  compute~ : Bool = false,
  eight_row~ : Bool = false,
  short_unary~ : Bool = false,
  sixteen_row~ : Bool = false,
  packed_weights~ : Bool = false,
  feedback~ : Bool = false,
  delivery~ : Bool = false,
  wide512~ : Bool = false,
  rows64~ : Bool = false,
  banked64~ : Bool = false,
  prefetch256~ : Bool = false,
  scalar_lines~ : Bool = false,
  store_bursts~ : Bool = false,
  interleaved~ : Bool = false,
  pipelined_vectors~ : Bool = false,
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
  memory~ : MemoryAperture = MiB256,
) -> @ir.Module raise {
  assert_true(!wide512 || (compute && interleaved && delivery))
  assert_true(!rows64 || wide512)
  assert_true(!banked64 || rows64)
  assert_true(!prefetch256 || banked64)
  assert_true(!scalar_lines || prefetch256)
  assert_true(!store_bursts || scalar_lines)
  assert_true(!stream_unary || (interleaved && store_bursts))
  assert_true(!staged_decode || stream_unary)
  assert_true(!stream_reductions || staged_decode)
  assert_true(!paired_rows || (stream_reductions && prefetch256))
  assert_true(!full_rows || paired_rows)
  assert_true(!dual_read || full_rows)
  assert_true(!strided_rows || deep_batch)
  assert_true(!ordered_array || strided_rows)
  assert_true(!deep_batch || bounded_add)
  assert_true(!bounded_add || indirect_bf16)
  assert_true(!indirect_bf16 || dual_read)
  assert_true(!interleaved || delivery)
  assert_true(!delivery || feedback)
  assert_true(!group64_rows || ordered_array)
  assert_true(!stripe512 || group64_rows)
  assert_true(!prefetch_row_blocks || stripe512)
  assert_true(!staged_reduction_term || (stream_reductions && bounded_add))
  assert_true(!direct_reduction_writeback || (stream_reductions && bounded_add))
  assert_true(!staged_scalar_add || (throughput && bounded_add))
  assert_true(!staged_scalar_alignment || staged_scalar_add)
  assert_true(!compact_multiply_pack || deep_fp32_add)
  assert_true(!staged_multiply_product || compact_multiply_pack)
  assert_true(!incremental_row_address || (ordered_array && staged_decode))
  assert_true(!registered_multiply_inputs || staged_multiply_product)
  assert_true(!eager_weight_reads || (ordered_array && banked64))
  assert_true(!state_scratch_mux || (ordered_array && eager_weight_reads))
  assert_true(
    !deep_fp32_add ||
    (
      ordered_array &&
      pipelined_vectors &&
      staged_add_inputs &&
      staged_unary_inputs &&
      staged_scalar_alignment
    ),
  )
  assert_true(!feedback || packed_weights)
  assert_true(!packed_weights || sixteen_row)
  assert_true(!sixteen_row || (eight_row && throughput && short_unary))
  let b = @wire.ModuleBuilder::new("qwen_layer_machine")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  b.input_timing(rs, SampledIn(d.id()))
  let m : Machine = {
    b,
    d,
    rs,
    reset: b.synchronous_reset(rs, 0UL),
    regs: Map([]),
    next: Map([]),
    order: [],
    row_lanes: if rows64 {
      64
    } else if compute {
      32
    } else if throughput {
      16
    } else {
      4
    },
    lane_width: if ordered_array {
      9
    } else if paired_rows {
      7
    } else if rows64 {
      6
    } else if compute {
      5
    } else if throughput {
      4
    } else {
      2
    },
    fast_arithmetic: throughput,
    short_unary,
    bf16_weights: compute || feedback,
    packed_weights,
    feedback,
    delivery,
    wide512,
    banked64,
    prefetch256,
    interleaved,
    pipelined_vectors,
    stream_unary,
    staged_decode,
    stream_reductions,
    paired_rows,
    full_rows,
    dual_read,
    indirect_bf16,
    bounded_add,
    deep_batch,
    strided_rows,
    ordered_array,
    group64_rows,
    stripe512,
    prefetch_row_blocks,
    staged_unary_inputs,
    staged_reduction_term,
    staged_scalar_add,
    staged_scalar_alignment,
    deep_fp32_add,
    compact_multiply_pack,
    staged_multiply_product,
    incremental_row_address,
    registered_multiply_inputs,
    eager_weight_reads,
    memory,
  }
  let inputs : Map[String, @wire.Signal] = Map([])
  for
    (name, width) in [
      ("start", 1),
      ("program_count", 12),
      ("program_write", 1),
      ("program_address", 15),
      ("program_data", 32),
      ("program_read", 1),
      ("program_read_address", 15),
      ("scratch_write", 1),
      ("scratch_address", 15),
      ("scratch_data", 32),
      ("scratch_read", 1),
      ("scratch_read_address", 15),
      ("memory_healthy", 1),
      ("ddr_request_ready", 1),
      ("ddr_response_valid", 1),
      ("ddr_response_data", 32),
      ("ddr_response_fault", 2),
      ("ddr_response_last", 1),
    ] {
    let x = b.input(
      name,
      if width == 1 {
        @wire.bits(1)
      } else {
        @wire.uint(width)
      },
    )
    b.input_timing(x, SampledIn(d.id()))
    inputs[name] = x
  }
  if wide {
    for
      i in 1..<(if prefetch256 {
        32
      } else if wide512 {
        16
      } else if delivery {
        8
      } else {
        4
      }) {
      let name = "ddr_response_data" + i.to_string()
      let x = b.input(name, @wire.uint(32))
      b.input_timing(x, SampledIn(d.id()))
      inputs[name] = x
    }
  }
  for
    (name, width) in [
      ("state", 5),
      ("pc", 11),
      ("limit", 12),
      ("fetch", 4),
      ("i", 32),
      ("row", 32),
      ("ai", 32),
      ("bi", 32),
      ("di", 32),
      ("brow", 32),
      ("ext", 32),
      ("sum", 32),
      ("product", 32),
      ("operand_a", 32),
      ("out", 32),
      ("fill", 5),
      ("error", 32),
      ("cycles", 64),
      ("instructions", 32),
      ("products", 32),
      ("ddr_beats", 32),
    ] {
    ignore(m.reg(name, width))
  }
  let fields = [
    "op", "dst", "a", "b", "n", "k", "bs", "br", "ddr", "imm", "flags", "reserved11",
    "reserved12", "reserved13", "reserved14", "reserved15",
  ]
  for name in fields {
    ignore(m.reg(name, 32))
  }
  if staged_decode {
    for opcode in 1..<=15 {
      ignore(m.reg("opcode_" + opcode.to_string(), 1))
    }
  }
  if parallel {
    if incremental_row_address {
      ignore(m.reg("p_group_base", 32))
    }
    for
      (name, width) in [
        ("p_row", 32),
        ("p_chunk", 32),
        ("p_index", if full_rows { 10 } else if prefetch256 { 8 } else { 6 }),
        ("p_lane", m.lane_width),
        ("p_write", m.lane_width),
        ("p_address", 32),
      ] {
      ignore(m.reg(name, width))
    }
    for lane in 0..<(if ordered_array { 0 } else { m.accumulator_count() }) {
      ignore(m.reg("p_sum" + lane.to_string(), 32))
    }
  }
  if prefetch256 {
    if indirect_bf16 {
      ignore(m.reg("bf16_pointer", 1))
    }
    ignore(m.reg("packet_in_row", if full_rows { 4 } else { 2 }))
  }
  if overlap {
    for (name, width) in [("o_state", 2), ("o_bank", 1), ("o_active", 1)] {
      ignore(m.reg(name, width))
    }
  }
  if throughput {
    for name in ["exec_a", "exec_b", "exec_multiply_b", "exec_add_a"] {
      ignore(m.reg(name, 32))
    }
    ignore(m.reg("exec_phase", 3))
    if ordered_array {
      ignore(m.reg("ordered_slot", 3))
    } else if !feedback || paired_rows {
      ignore(m.reg("p_issue_gap", 1))
    }
  }
  if stream_unary {
    ignore(m.reg("u_stream", 1))
  }
  if interleaved {
    ignore(m.reg("u_lane", 2))
    ignore(m.reg("u_count", 3))
    for i in 0..<4 {
      ignore(m.reg("u_value" + i.to_string(), 32))
      ignore(m.reg("u_result" + i.to_string(), 32))
      ignore(m.reg("u_error" + i.to_string(), 1))
    }
  }
  let idle = either(b, [m.is_state(0UL), m.is_state(14UL)])
  let active = b.bit_not(either(b, [idle, m.is_state(15UL)]))
  let safe = b.bit_not(b.reset_asserted(m.rs))
  let begin = all(b, [
    idle,
    inputs["start"],
    inputs["memory_healthy"],
    b.greater_equal(inputs["program_count"], u(b, 12, 1UL)),
    b.less_equal(inputs["program_count"], u(b, 12, 2048UL)),
  ])
  let host = all(b, [idle, safe])
  let program = m.word_ram("program")
  b.memory_write(
    program,
    "host",
    inputs["program_address"],
    inputs["program_data"],
    enable=b.bit_and(host, inputs["program_write"]),
  )
  let program_read = b.bit_and(host, inputs["program_read"])
  let instruction = b.memory_read(
    program,
    "fetch",
    b.mux(
      program_read,
      inputs["program_read_address"],
      cat(b, m.v("pc"), m.v("fetch")),
    ),
    enable=either(b, [program_read, b.bit_and(m.is_state(1UL), safe)]),
    enable_behavior=HoldLast,
  )
  let program_valid = b.register_in(d, program_read, reset=m.reset)
  for
    (name, x) in [
      ("program_read_valid", program_valid),
      ("program_read_data", instruction),
    ] {
    let o = b.output(name, x.signal_type())
    b.output_timing(o, ProducedIn(d.id()))
    b.connect(o, x)
  }
  m.jump(m.is_state(1UL), 2UL)
  if staged_decode {
    // Word zero arrives before the remaining fifteen words. Capture the full
    // 32-bit predicates here so execution sees a registered select.
    let first = b.bit_and(m.is_state(2UL), b.equal(m.v("fetch"), u(b, 4, 0UL)))
    for opcode in 1..<=15 {
      m.put(
        "opcode_" + opcode.to_string(),
        first,
        b.equal(instruction, u(b, 32, opcode.to_uint64())),
      )
    }
  }
  for i, name in fields {
    m.put(
      name,
      all(b, [m.is_state(2UL), b.equal(m.v("fetch"), u(b, 4, i.to_uint64()))]),
      instruction,
    )
  }
  increment(m, "fetch", m.is_state(2UL), 1UL)
  m.put(
    "state",
    m.is_state(2UL),
    b.mux(b.equal(m.v("fetch"), u(b, 4, 15UL)), u(b, 5, 3UL), u(b, 5, 1UL)),
  )
  let matrix = either(b, [m.is_op(4UL), m.is_op(5UL)])
  let reduction = either(b, [m.is_op(6UL), m.is_op(7UL), m.is_op(8UL)])
  let load = m.is_op(14UL)
  let store = m.is_op(15UL)
  let external_matrix = m.is_op(4UL)
  let read = m.is_state(4UL)
  let second_read = m.is_state(16UL)
  let host_read = b.bit_and(host, inputs["scratch_read"])
  let parallel_read = if parallel { m.is_state(20UL) } else { read }
  let engine_read_address = if parallel {
    b.mux(
      parallel_read,
      b.add(m.v("a"), b.add(m.v("p_chunk"), b.zero_extend(m.v("p_index"), 32))),
      b.mux(second_read, m.v("bi"), m.v("ai")),
    )
  } else {
    b.mux(second_read, m.v("bi"), m.v("ai"))
  }
  let engine_read_address = if interleaved {
    b.mux(
      m.is_state(24UL),
      b.add(m.v("a"), b.add(m.v("i"), b.zero_extend(m.v("u_lane"), 32))),
      engine_read_address,
    )
  } else {
    engine_read_address
  }
  let engine_read_address = if pipelined_vectors {
    b.mux(m.is_state(30UL), m.v("bi"), engine_read_address)
  } else {
    engine_read_address
  }
  let engine_read_address = if store_bursts {
    ignore(m.reg("store_lane", 6))
    ignore(m.reg("store_group", 1))
    ignore(m.reg("store_committed", 1))
    let cursor = m.reg("store_cursor", 15)
    b.mux(m.is_state(17UL), b.zero_extend(cursor, 32), engine_read_address)
  } else {
    engine_read_address
  }
  let scratch = m.word_ram("scratch")
  // One synchronous read port, explicitly scheduled over two cycles. This
  // avoids synthesis merging replicated 2R1W arrays into an unsupported RAM.
  let scratch_word = b.memory_read(
    scratch,
    "a",
    b.mux(
      host_read,
      inputs["scratch_read_address"],
      b.truncate(engine_read_address, 15),
    ),
    enable=if store_bursts {
      either(b, [
        host_read,
        all(b, [
          safe,
          either(b, [
            read,
            second_read,
            parallel_read,
            m.is_state(24UL),
            m.is_state(29UL),
            m.is_state(30UL),
            all(b, [
              m.is_state(17UL),
              b.not_equal(m.v("store_lane"), u(b, 6, 63UL)),
            ]),
          ]),
        ]),
      ])
    } else if interleaved {
      b.bit_or(
        either(b, [
          host_read,
          b.bit_and(either(b, [read, second_read, parallel_read]), safe),
        ]),
        b.bit_and(
          if pipelined_vectors {
            either(b, [m.is_state(24UL), m.is_state(29UL), m.is_state(30UL)])
          } else {
            m.is_state(24UL)
          },
          safe,
        ),
      )
    } else {
      either(b, [
        host_read,
        b.bit_and(either(b, [read, second_read, parallel_read]), safe),
      ])
    },
    enable_behavior=HoldLast,
  )
  m.put("operand_a", second_read, scratch_word)
  let av = m.v("operand_a")
  let bv = scratch_word
  let cache = b.synchronous_memory(
    "weight_line",
    @wire.uint(32),
    32,
    d,
    read_write_policy=ReadOld,
    multi_write_policy=Reject,
  )
  let response = inputs["ddr_response_valid"]
  let fill = all(b, [m.is_state(10UL), external_matrix, response, safe])
  b.memory_write(
    cache,
    "ddr",
    m.v("fill"),
    inputs["ddr_response_data"],
    enable=fill,
  )
  let packed = b.memory_read(
    cache,
    "weight",
    field(b, m.v("i"), 5, 1),
    enable=b.bit_and(read, safe),
    enable_behavior=HoldLast,
  )
  let weight = cat(
    b,
    b.mux(
      bit(b, m.v("i"), 0),
      field(b, packed, 31, 16),
      field(b, packed, 15, 0),
    ),
    u(b, 16, 0UL),
  )
  let operand = b.mux(
    external_matrix,
    weight,
    b.mux(b.equal(m.v("flags"), u(b, 32, 2UL)), m.v("imm"), bv),
  )
  machine_decode(
    m,
    matrix,
    reduction,
    load,
    external_matrix,
    parallel~,
    overlap~,
  )
  let lanes = if overlap {
    Some(
      overlapped_path(
        m,
        inputs,
        scratch_word,
        wide~,
        batch~,
        eight_row~,
        sixteen_row~,
      ),
    )
  } else if parallel {
    Some(parallel_path(m, inputs, scratch_word))
  } else {
    None
  }
  let load_line = if scalar_lines {
    Some(load_line_request(m, load))
  } else {
    None
  }
  machine_execute(
    m,
    inputs,
    av,
    operand,
    matrix,
    reduction,
    load,
    store,
    external_matrix,
    lanes~,
    batch~,
    load_line~,
    store_bursts~,
    scratch_word~,
  )
  if wide {
    let x = all(b, [
      safe,
      either(b, [
        m.is_state(18UL),
        m.is_state(20UL),
        m.is_state(21UL),
        m.is_state(22UL),
        m.is_state(23UL),
      ]),
    ])
    let o = b.output("ddr_request_wide", @wire.bits(1))
    b.output_timing(o, ProducedIn(d.id()))
    b.connect(o, if load_line is Some(line) { b.bit_or(x, line) } else { x })
  }
  let parallel_write = if parallel {
    m.is_state(23UL)
  } else {
    b.constant(@wire.bits(1), 0UL)
  }
  let engine_write = all(b, [
    b.bit_or(m.is_state(8UL), parallel_write),
    b.bit_not(store),
    safe,
  ])
  let host_write = b.bit_and(host, inputs["scratch_write"])
  let (write_address, write_data) = match lanes {
    Some(p) =>
      (
        b.mux(parallel_write, p["write_address"], b.truncate(m.v("di"), 15)),
        b.mux(parallel_write, p["write_data"], m.v("out")),
      )
    None => (b.truncate(m.v("di"), 15), m.v("out"))
  }
  let (engine_write, write_address, write_data) = if interleaved {
    let error = interleaved_select(m, "u_error")
    let owner = m.is_state(28UL)
    let write = all(b, [owner, b.bit_not(error), safe, inputs["memory_healthy"]])
    (
      b.bit_or(engine_write, write),
      b.mux(
        if state_scratch_mux {
          owner
        } else {
          write
        },
        b.truncate(
          b.add(m.v("dst"), b.add(m.v("i"), b.zero_extend(m.v("u_lane"), 32))),
          15,
        ),
        write_address,
      ),
      b.mux(
        if state_scratch_mux {
          owner
        } else {
          write
        },
        interleaved_select(m, "u_result"),
        write_data,
      ),
    )
  } else {
    (engine_write, write_address, write_data)
  }
  let mirror = scratch_mirror(m)
  let second = mirror.map(s => s.word)
  let (engine_write, write_address, write_data) = if pipelined_vectors {
    let write_data = if stream_reductions {
      let final_sum = ordered_reduction_pipeline(
        m,
        scratch_word,
        inputs["memory_healthy"],
        second~,
        direct_writeback=direct_reduction_writeback,
      )
      match final_sum {
        Some((ready, sum)) => b.mux(ready, sum, write_data)
        None => write_data
      }
    } else {
      write_data
    }
    let (write, address, value, owner) = vector_pipeline(
      m,
      staged_add_inputs~,
      scratch_word,
      inputs["memory_healthy"],
      second~,
    )
    (
      b.bit_or(engine_write, write),
      b.mux(
        if state_scratch_mux {
          owner
        } else {
          write
        },
        address,
        write_address,
      ),
      b.mux(if state_scratch_mux { owner } else { write }, value, write_data),
    )
  } else {
    (engine_write, write_address, write_data)
  }
  let (engine_write, write_address, write_data) = if stream_unary {
    let (write, address, value, owner) = stream_unary_path(
      m,
      scratch_word,
      inputs["memory_healthy"],
    )
    (
      b.bit_or(engine_write, write),
      b.mux(
        if state_scratch_mux {
          owner
        } else {
          write
        },
        address,
        write_address,
      ),
      b.mux(if state_scratch_mux { owner } else { write }, value, write_data),
    )
  } else {
    (engine_write, write_address, write_data)
  }
  write_scratch(
    m,
    scratch,
    mirror,
    // Address/data ownership excludes all other writers. Keep permission on
    // the memory write enable, not on the high-fanout address/data selectors.
    b.mux(
      if state_scratch_mux {
        host
      } else {
        host_write
      },
      inputs["scratch_address"],
      write_address,
    ),
    b.mux(
      if state_scratch_mux {
        host
      } else {
        host_write
      },
      inputs["scratch_data"],
      write_data,
    ),
    b.bit_or(host_write, engine_write),
  )
  let read_valid = b.register_in(d, host_read, reset=m.reset)
  for
    (name, x) in [
      ("busy", active),
      ("done", m.is_state(14UL)),
      ("fault", m.is_state(15UL)),
      ("scratch_read_valid", read_valid),
      ("scratch_read_data", scratch_word),
      ("error", m.v("error")),
      ("pc", m.v("pc")),
      ("state", m.v("state")),
      ("opcode", m.v("op")),
      ("cycles_low", field(b, m.v("cycles"), 31, 0)),
      ("cycles_high", field(b, m.v("cycles"), 63, 32)),
      ("instructions", m.v("instructions")),
      ("products", m.v("products")),
      ("ddr_beats", m.v("ddr_beats")),
    ] {
    let o = b.output(name, x.signal_type())
    b.output_timing(o, ProducedIn(d.id()))
    b.connect(o, x)
  }
  increment(m, "cycles", active, 1UL)
  let abort = all(b, [
    active,
    either(b, [
      b.bit_not(inputs["memory_healthy"]),
      b.greater_equal(m.v("cycles"), u(b, 64, 15000000000UL)),
    ]),
  ])
  m.jump(abort, 15UL)
  m.set("error", abort, 8UL)
  m.jump(begin, 1UL)
  m.put("limit", begin, inputs["program_count"])
  for
    name in [
      "pc", "fetch", "error", "cycles", "instructions", "products", "ddr_beats",
    ] {
    m.set(name, begin, 0UL)
  }
  m.commit()
  b.finish()
}
