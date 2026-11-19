///|
// Loader ownership is independent of the compute FSM: 0=empty, 1=request,
// 2=receive, 3=full. Only a full stripe may become active. After the last read
// drains, the banks exchange roles; no bank is overwritten while being read.
fn overlapped_path(
  m : Machine,
  inputs : Map[String, @wire.Signal],
  activation : @wire.Signal,
  wide~ : Bool = false,
  batch~ : Bool = false,
  eight_row~ : Bool = false,
  sixteen_row~ : Bool = false,
) -> Map[String, @wire.Signal] raise {
  let b = m.b
  // Returned health includes the controller's combinational request checker.
  // Request publication must depend only on registered ownership/reset, never
  // on that feedback. Health still gates arithmetic; the machine aborts on
  // the next edge, as in the existing scalar/four-lane transport contract.
  let safe = b.bit_not(b.reset_asserted(m.rs))
  let live = all(b, [
    safe,
    either(b, [
      m.is_state(18UL),
      m.is_state(20UL),
      m.is_state(21UL),
      m.is_state(22UL),
      m.is_state(23UL),
    ]),
  ])
  fn loader(state : UInt64) -> @wire.Signal raise {
    b.equal(m.v("o_state"), u(b, 2, state))
  }
  let request = all(b, [live, loader(1UL)])
  let accepted = b.bit_and(request, inputs["ddr_request_ready"])
  m.set("o_state", accepted, 2UL)
  m.set("fill", accepted, 0UL)
  let response = all(b, [live, loader(2UL), inputs["ddr_response_valid"]])
  let long_stripe = if m.prefetch256 {
    Some(
      all(b, [
        b.equal(m.v("flags"), u(b, 32, 0UL)),
        b.equal(field(b, m.v("ddr"), 8, 0), u(b, 9, 0UL)),
        b.equal(field(b, m.v("k"), 7, 0), u(b, 8, 0UL)),
      ]),
    )
  } else {
    None
  }
  let words = if m.prefetch256 {
    32UL
  } else if m.wide512 {
    16UL
  } else if m.delivery {
    8UL
  } else if wide {
    4UL
  } else {
    1UL
  }
  // A 1024-column stripe fits in the same banks at all three Qwen widths.
  // Wider rows skip their remaining bytes after each four 512-byte bursts.
  let full = if m.ordered_array {
    Some(b.constant(@wire.bits(1), 0UL))
  } else if m.full_rows {
    let k = m.v("k")
    let fits = b.equal(k, u(b, 32, 1024UL))
    let fits = if m.strided_rows {
      either(b, [
        fits,
        b.equal(k, u(b, 32, 2048UL)),
        b.equal(k, u(b, 32, 3072UL)),
      ])
    } else {
      fits
    }
    Some(b.bit_and(long_stripe.unwrap(), fits))
  } else {
    None
  }
  let last = if full is Some(whole) {
    b.bit_or(
      b.bit_not(long_stripe.unwrap()),
      b.equal(m.v("packet_in_row"), b.mux(whole, u(b, 4, 15UL), u(b, 4, 3UL))),
    )
  } else if long_stripe is Some(long) {
    b.bit_or(b.bit_not(long), b.equal(m.v("packet_in_row"), u(b, 2, 3UL)))
  } else {
    b.equal(m.v("fill"), u(b, 5, 32UL - words))
  }
  let grouped = if m.group64_rows {
    Some(
      all(b, [
        long_stripe.unwrap(),
        b.equal(m.v("flags"), u(b, 32, 0UL)),
        b.equal(field(b, m.v("n"), 5, 0), u(b, 6, 0UL)),
        either(
          b,
          [1024UL, 2048UL, 3072UL].map(k => b.equal(m.v("k"), u(b, 32, k))),
        ),
      ]),
    )
  } else {
    None
  }
  // Wider aligned row slices use eight 128-byte packets per physical row.
  let stripe512 = if m.stripe512 {
    Some(
      b.bit_and(
        grouped.unwrap(),
        b.equal(field(b, m.v("ddr"), 9, 9), u(b, 1, 0UL)),
      ),
    )
  } else {
    None
  }
  let last = if stripe512 is Some(w) {
    b.mux(w, b.equal(m.v("packet_in_row"), u(b, 4, 7UL)), last)
  } else {
    last
  }
  // A full 512-row bank lets the AXI reader pre-issue the next 32-row
  // block while responses for the current block are still arriving.
  let prefetch = if m.prefetch_row_blocks {
    Some(
      b.bit_and(
        stripe512.unwrap(),
        b.equal(field(b, m.v("n"), 8, 0), u(b, 9, 0UL)),
      ),
    )
  } else {
    None
  }
  let batch_last_lane = if batch {
    Some(
      b.equal(
        if m.row_lanes == 4 {
          m.v("p_lane")
        } else {
          field(
            b,
            m.v("p_lane"),
            if sixteen_row {
              3
            } else if eight_row {
              2
            } else {
              1
            },
            0,
          )
        },
        u(
          b,
          if sixteen_row {
            4
          } else if eight_row {
            3
          } else {
            2
          },
          if sixteen_row {
            15UL
          } else if eight_row {
            7UL
          } else {
            3UL
          },
        ),
      ),
    )
  } else {
    None
  }
  let batch_last_lane = if m.deep_batch {
    batch_last_lane
  } else if full is Some(whole) {
    Some(
      b.mux(
        whole,
        b.equal(field(b, m.v("p_lane"), 1, 0), u(b, 2, 3UL)),
        batch_last_lane.unwrap(),
      ),
    )
  } else {
    batch_last_lane
  }
  let batch_last_lane = if grouped is Some(g) {
    Some(
      b.mux(
        g,
        if stripe512 is Some(w) {
          b.mux(
            w,
            b.equal(field(b, m.v("p_lane"), 4, 0), u(b, 5, 31UL)),
            b.equal(field(b, m.v("p_lane"), 5, 0), u(b, 6, 63UL)),
          )
        } else {
          b.equal(field(b, m.v("p_lane"), 5, 0), u(b, 6, 63UL))
        },
        batch_last_lane.unwrap(),
      ),
    )
  } else {
    batch_last_lane
  }
  let batch_last_lane = if prefetch is Some(w) {
    Some(
      b.mux(w, b.equal(m.v("p_lane"), u(b, 9, 511UL)), batch_last_lane.unwrap()),
    )
  } else {
    batch_last_lane
  }
  let expected_last = if batch {
    b.bit_and(last, batch_last_lane.unwrap())
  } else {
    last
  }
  let bad = all(b, [
    response,
    either(b, [
      b.not_equal(inputs["ddr_response_fault"], u(b, 2, 0UL)),
      b.bit_xor(expected_last, inputs["ddr_response_last"]),
    ]),
  ])
  let complete = all(b, [response, last, b.bit_not(bad)])
  if m.prefetch256 {
    increment(m, "packet_in_row", response, 1UL)
    m.set("packet_in_row", either(b, [accepted, complete]), 0UL)
  } else {
    increment(m, "fill", response, words)
  }
  // This counter remains logical 32-bit words, not physical response packets.
  increment(m, "ddr_beats", response, words)
  // Keep packed-16 addressing and support row counts divisible by 16.
  // Wide row-major groups consist of consecutive checked sixteen-row requests.
  let short_group = if m.wide512 {
    Some(b.bit_or(bit(b, m.v("n"), 4), b.equal(m.v("flags"), u(b, 32, 1UL))))
  } else {
    None
  }
  fn last_lane_index() -> @wire.Signal raise {
    match short_group {
      Some(short) if m.ordered_array => {
        let mut last = u(b, 9, 511UL)
        for width in [8, 7, 6, 5] {
          last = b.mux(
            bit(b, m.v("n"), width),
            u(b, 9, (1UL << width) - 1UL),
            last,
          )
        }
        b.mux(short, u(b, 9, 15UL), last)
      }
      Some(short) if m.paired_rows =>
        b.mux(
          short,
          u(b, 7, 15UL),
          b.mux(
            bit(b, m.v("n"), 5),
            u(b, 7, 31UL),
            b.mux(bit(b, m.v("n"), 6), u(b, 7, 63UL), u(b, 7, 127UL)),
          ),
        )
      Some(short) if m.row_lanes == 64 =>
        b.mux(
          short,
          u(b, 6, 15UL),
          b.mux(bit(b, m.v("n"), 5), u(b, 6, 31UL), u(b, 6, 63UL)),
        )
      Some(short) => b.mux(short, u(b, 5, 15UL), u(b, 5, 31UL))
      None => u(b, m.lane_width, (m.row_lanes - 1).to_uint64())
    }
  }
  fn group_rows() -> @wire.Signal raise {
    match short_group {
      Some(_) if m.paired_rows =>
        b.add(b.zero_extend(last_lane_index(), 32), u(b, 32, 1UL))
      Some(short) if m.row_lanes == 64 =>
        b.mux(
          short,
          u(b, 32, 16UL),
          b.mux(bit(b, m.v("n"), 5), u(b, 32, 32UL), u(b, 32, 64UL)),
        )
      Some(short) => b.mux(short, u(b, 32, 16UL), u(b, 32, 32UL))
      None => u(b, 32, m.row_lanes.to_uint64())
    }
  }
  let next_group_address = if m.incremental_row_address {
    Some(b.add(m.v("p_group_base"), staged_group_byte_stride(m, group_rows())))
  } else {
    None
  }
  let last_lane = if batch {
    if m.row_lanes == 4 {
      batch_last_lane.unwrap()
    } else {
      b.equal(m.v("p_lane"), last_lane_index())
    }
  } else {
    b.equal(m.v("p_lane"), u(b, 2, 3UL))
  }
  let next_lane = all(b, [complete, b.bit_not(last_lane)])
  increment(m, "p_lane", next_lane, 1UL)
  if batch && m.row_lanes > 4 {
    let next_batch = all(b, [next_lane, batch_last_lane.unwrap()])
    m.put(
      "p_address",
      next_batch,
      b.add(
        m.v("p_address"),
        b.shift_left(
          m.v("k"),
          if grouped is Some(g) {
            b.mux(
              g,
              if stripe512 is Some(w) {
                b.mux(w, u(b, 3, 6UL), u(b, 3, 7UL))
              } else {
                u(b, 3, 7UL)
              },
              u(b, 3, 5UL),
            )
          } else if m.deep_batch {
            u(b, 3, 5UL)
          } else if full is Some(whole) {
            b.mux(whole, u(b, 3, 3UL), u(b, 3, 5UL))
          } else {
            u(
              b,
              if sixteen_row {
                3
              } else if eight_row {
                3
              } else {
                2
              },
              if sixteen_row {
                5UL
              } else if eight_row {
                4UL
              } else {
                3UL
              },
            )
          },
        ),
      ),
    )
    m.set("o_state", next_batch, 1UL)
  }
  if !batch {
    m.put(
      "p_address",
      next_lane,
      b.add(m.v("p_address"), b.shift_left(m.v("k"), u(b, 1, 1UL))),
    )
    m.set("o_state", next_lane, 1UL)
  }
  m.set("o_state", b.bit_and(complete, last_lane), 3UL)

  let begin = all(b, [live, m.is_state(18UL), loader(3UL)])
  m.set("p_index", begin, 0UL)
  m.jump(begin, 20UL)
  let chunk = if full is Some(whole) {
    b.mux(
      whole,
      u(b, 32, 1024UL),
      b.mux(long_stripe.unwrap(), u(b, 32, 256UL), u(b, 32, 64UL)),
    )
  } else if long_stripe is Some(long) {
    b.mux(long, u(b, 32, 256UL), u(b, 32, 64UL))
  } else {
    u(b, 32, 64UL)
  }
  let chunk = if stripe512 is Some(w) {
    b.mux(w, u(b, 32, 512UL), chunk)
  } else {
    chunk
  }
  let next_chunk_value = b.add(m.v("p_chunk"), chunk)
  let more_chunks = b.less_than(next_chunk_value, m.v("k"))
  // Preload the next group's first stripe while the last stripe computes.
  // The extended loader can do this for either layout and retains ownership
  // through the result writes.
  let following_group = if m.packed_weights {
    let row = b.add(m.v("p_row"), group_rows())
    Some(
      (
        if m.prefetch256 {
          b.less_than(row, m.v("n"))
        } else {
          b.bit_and(
            b.equal(m.v("flags"), u(b, 32, 1UL)),
            b.less_than(row, m.v("n")),
          )
        },
        match next_group_address {
          Some(address) => address
          None =>
            b.add(
              m.v("ddr"),
              b.shift_left(b.mul_low(row, m.v("k")), u(b, 1, 1UL)),
            )
        },
      ),
    )
  } else {
    None
  }
  let future_stripe = match following_group {
    Some((more_rows, _)) => b.bit_or(more_chunks, more_rows)
    None => more_chunks
  }
  // Start the next stripe in the other bank at the edge that starts compute.
  m.put("o_state", begin, b.mux(future_stripe, u(b, 2, 1UL), u(b, 2, 0UL)))
  m.put("o_bank", begin, b.bit_not(m.v("o_active")))
  m.set("p_lane", begin, 0UL)
  m.put("p_address", begin, next_stripe_address(m, next_chunk_value))
  if following_group is Some((more_rows, address)) {
    m.put(
      "p_address",
      all(b, [begin, b.bit_not(more_chunks), more_rows]),
      address,
    )
  }

  let issue = all(b, [
    live,
    inputs["memory_healthy"],
    if m.ordered_array {
      all(b, [m.is_state(20UL), ordered_input(m, "mac_credit", 1)])
    } else if m.paired_rows {
      all(b, [
        m.is_state(20UL),
        b.bit_or(paired_group(m), b.bit_not(m.v("p_issue_gap"))),
      ])
    } else if m.fast_arithmetic && !m.feedback {
      b.bit_and(m.is_state(20UL), b.bit_not(m.v("p_issue_gap")))
    } else {
      m.is_state(20UL)
    },
    b.bit_not(bad),
  ])
  if !m.ordered_array && ((m.fast_arithmetic && !m.feedback) || m.paired_rows) {
    m.put("p_issue_gap", m.is_state(20UL), b.bit_not(m.v("p_issue_gap")))
    m.set("p_issue_gap", b.bit_not(m.is_state(20UL)), 0UL)
  }
  let final_issue = if full is Some(_) {
    b.equal(m.v("p_index"), b.truncate(b.sub(chunk, u(b, 32, 1UL)), 10))
  } else if long_stripe is Some(long) {
    b.equal(m.v("p_index"), b.mux(long, u(b, 8, 255UL), u(b, 8, 63UL)))
  } else {
    b.equal(m.v("p_index"), u(b, 6, 63UL))
  }
  let advance = if m.ordered_array {
    let end_slot = b.equal(
      m.v("ordered_slot"),
      field(b, last_lane_index(), 8, 6),
    )
    increment(m, "ordered_slot", issue, 1UL)
    m.set("ordered_slot", b.bit_or(begin, b.bit_and(issue, end_slot)), 0UL)
    b.bit_and(issue, end_slot)
  } else if m.paired_rows {
    all(b, [issue, b.bit_or(b.bit_not(paired_group(m)), m.v("p_issue_gap"))])
  } else {
    issue
  }
  increment(m, "p_index", advance, 1UL)
  m.jump(b.bit_and(advance, final_issue), 21UL)
  fn delay(x : @wire.Signal, n : Int32) -> @wire.Signal raise {
    let mut r = x
    for _ in 0..<n {
      r = b.register_in(m.d, r, reset=m.reset)
    }
    r
  }
  let select_high = delay(bit(b, m.v("p_index"), 0), 1)
  let ordered_data = if m.ordered_array {
    let weights = banked_weights(
      m,
      inputs,
      b.bit_and(response, b.bit_not(bad)),
      issue,
      select_high,
    )
    let (retired, data) = ordered_row_interface(
      m,
      weights,
      activation,
      issue,
      final_issue,
      last_lane_index(),
      long_stripe.unwrap(),
      stripe512,
      live,
      bad,
      inputs["memory_healthy"],
    )
    m.jump(retired, 22UL)
    Some(data)
  } else {
    let active_bank = if m.banked64 {
      m.v("o_active")
    } else {
      delay(m.v("o_active"), 1)
    }
    let latency = if (m.fast_arithmetic && !m.feedback) || m.paired_rows {
      5
    } else {
      4
    }
    let valid = delay(issue, latency)
    let final_product = delay(b.bit_and(advance, final_issue), latency)
    let halves = if m.paired_rows {
      let read_half = delay(m.v("p_issue_gap"), 4)
      Some((read_half, delay(read_half, 1)))
    } else {
      None
    }
    let commit = all(b, [
      valid,
      live,
      inputs["memory_healthy"],
      b.bit_not(bad),
      either(b, [m.is_state(20UL), m.is_state(21UL)]),
    ])
    let banked = if m.banked64 {
      Some(
        banked_weights(
          m,
          inputs,
          b.bit_and(response, b.bit_not(bad)),
          issue,
          select_high,
        ),
      )
    } else {
      None
    }
    for lane in 0..<m.row_lanes {
      let half = if banked is Some(weights) {
        weights[lane]
      } else {
        let banks : Array[@wire.Signal] = []
        for bank in 0..<2 {
          let selected = b.equal(
            m.v("o_active"),
            b.constant(@wire.bits(1), bank.to_uint64()),
          )
          if wide {
            banks.push(
              wide_weight_bank(
                m,
                inputs,
                lane,
                bank,
                response,
                b.bit_not(bad),
                issue,
                selected,
              ),
            )
          } else {
            let weights = b.synchronous_memory(
              "overlap_weight_" + lane.to_string() + "_" + bank.to_string(),
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
                b.bit_not(bad),
                b.equal(
                  m.v("o_bank"),
                  b.constant(@wire.bits(1), bank.to_uint64()),
                ),
                b.equal(m.v("p_lane"), u(b, 2, lane.to_uint64())),
              ]),
            )
            banks.push(
              b.memory_read(
                weights,
                "weight",
                field(b, m.v("p_index"), 5, 1),
                enable=b.bit_and(issue, selected),
                enable_behavior=HoldLast,
              ),
            )
          }
        }
        let packed = b.mux(active_bank, banks[1], banks[0])
        b.mux(select_high, field(b, packed, 31, 16), field(b, packed, 15, 0))
      }
      let weight = cat(b, half, u(b, 16, 0UL))
      let product = fp32_multiply_pipeline3(
        b,
        m.d,
        m.reset,
        activation,
        weight,
        fast=m.fast_arithmetic,
        bf16_weight=m.bf16_weights,
      )
      let name = "p_sum" + lane.to_string()
      if halves is Some((read_half, write_half)) {
        paired_accumulate(m, lane, product, read_half, write_half, commit)
      } else {
        m.put(
          name,
          commit,
          if m.feedback {
            feedback_add(b, m.v(name), product)
          } else {
            add(
              b,
              m.v(name),
              product,
              fast=m.fast_arithmetic,
              pipeline=if m.fast_arithmetic {
                Some((m.d, m.reset))
              } else {
                None
              },
            )
          },
        )
      }
    }
    if m.paired_rows {
      m.put(
        "products",
        commit,
        b.add(
          m.v("products"),
          b.mux(paired_group(m), u(b, 32, 64UL), group_rows()),
        ),
      )
    } else if m.wide512 {
      m.put("products", commit, b.add(m.v("products"), group_rows()))
    } else {
      increment(m, "products", commit, m.row_lanes.to_uint64())
    }
    m.jump(b.bit_and(commit, final_product), 22UL)
    None
  }
  let stripe_done = m.is_state(22UL)
  let next_chunk = all(b, [stripe_done, more_chunks])
  m.put("p_chunk", next_chunk, next_chunk_value)
  m.put("o_active", next_chunk, b.bit_not(m.v("o_active")))
  m.jump(next_chunk, 18UL)
  let rows_done = all(b, [stripe_done, b.bit_not(more_chunks)])
  m.set("p_write", rows_done, 0UL)
  m.jump(rows_done, 23UL)
  let write = m.is_state(23UL)
  let final_write = b.equal(m.v("p_write"), last_lane_index())
  increment(m, "p_write", write, 1UL)
  let next_row_value = b.add(m.v("p_row"), group_rows())
  let more_rows = b.less_than(next_row_value, m.v("n"))
  let next_row = all(b, [write, final_write, more_rows])
  m.put("p_row", next_row, next_row_value)
  if next_group_address is Some(address) {
    m.put("p_group_base", next_row, address)
  }
  let restart = if m.prefetch256 {
    m.set("p_chunk", next_row, 0UL)
    m.put("o_active", next_row, b.bit_not(m.v("o_active")))
    b.constant(@wire.bits(1), 0UL)
  } else if m.packed_weights {
    let packed = b.equal(m.v("flags"), u(b, 32, 1UL))
    m.set("p_chunk", next_row, 0UL)
    m.put("o_active", b.bit_and(next_row, packed), b.bit_not(m.v("o_active")))
    let restart = b.bit_and(next_row, b.bit_not(packed))
    for name in ["p_lane", "o_bank", "o_active"] {
      m.set(name, restart, 0UL)
    }
    restart
  } else {
    for name in ["p_chunk", "p_lane", "o_bank", "o_active"] {
      m.set(name, next_row, 0UL)
    }
    next_row
  }
  m.set("o_state", restart, 1UL)
  m.put(
    "p_address",
    restart,
    match next_group_address {
      Some(address) => address
      None =>
        b.add(
          m.v("ddr"),
          b.shift_left(b.mul_low(next_row_value, m.v("k")), u(b, 1, 1UL)),
        )
    },
  )
  for lane in 0..<(if m.ordered_array { 0 } else { m.accumulator_count() }) {
    m.set("p_sum" + lane.to_string(), next_row, 0UL)
  }
  m.jump(next_row, 18UL)
  m.jump(all(b, [write, final_write, b.bit_not(more_rows)]), 13UL)
  let data = if ordered_data is Some(value) {
    value
  } else if m.paired_rows {
    paired_write_data(m)
  } else {
    let mut data = m.v("p_sum0")
    for lane in 1..<m.row_lanes {
      data = b.mux(
        b.equal(m.v("p_write"), u(b, m.lane_width, lane.to_uint64())),
        m.v("p_sum" + lane.to_string()),
        data,
      )
    }
    data
  }
  // Fault dominates compute/drain/loader completion on the same edge.
  m.jump(bad, 15UL)
  m.set("error", bad, 4UL)
  let ports = Map([
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
  if grouped is Some(g) {
    ports["group64_rows"] = g
  }
  if stripe512 is Some(w) {
    ports["stripe512"] = w
  }
  if prefetch is Some(w) {
    ports["prefetch_row_blocks"] = w
  }
  if long_stripe is Some(long) {
    ports["long_stripe"] = long
  }
  if full is Some(whole) {
    ports["full_row"] = whole
  }
  ports
}
