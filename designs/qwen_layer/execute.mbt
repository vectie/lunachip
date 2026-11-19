///|
fn machine_execute(
  m : Machine,
  inputs : Map[String, @wire.Signal],
  av : @wire.Signal,
  bv : @wire.Signal,
  matrix : @wire.Signal,
  reduction : @wire.Signal,
  load : @wire.Signal,
  store : @wire.Signal,
  external_matrix : @wire.Signal,
  lanes~ : Map[String, @wire.Signal]? = None,
  batch~ : Bool = false,
  load_line~ : @wire.Signal? = None,
  store_bursts~ : Bool = false,
  scratch_word~ : @wire.Signal,
) -> Unit raise {
  let b = m.b
  let zero = u(b, 32, 0UL)
  let one = u(b, 32, 1UL)
  let execute = if m.fast_arithmetic {
    b.bit_and(
      m.is_state(5UL),
      b.equal(
        m.v("exec_phase"),
        u(
          b,
          3,
          if m.registered_multiply_inputs {
            6UL
          } else if m.staged_multiply_product {
            5UL
          } else {
            4UL
          },
        ),
      ),
    )
  } else {
    m.is_state(5UL)
  }
  let unary = either(b, [m.is_op(9UL), m.is_op(10UL), m.is_op(11UL)])
  let product_op = either(b, [matrix, m.is_op(7UL)])
  let raw_multiply_b = b.mux(
    m.is_op(7UL),
    av,
    b.mux(m.is_op(13UL), b.mux(bit(b, av, 31), bv, u(b, 32, 0x3f800000UL)), bv),
  )
  let accumulated = if m.fast_arithmetic {
    // The second synchronous read commits operand_a on leaving state16.
    // Capture on the following edge,not simultaneously with that commit.
    let capture = b.bit_and(
      m.is_state(5UL),
      b.equal(m.v("exec_phase"), u(b, 3, 0UL)),
    )
    m.put("exec_a", capture, av)
    m.put("exec_b", capture, bv)
    m.put("exec_multiply_b", capture, raw_multiply_b)
    m.put("exec_add_a", capture, b.mux(m.is_op(6UL), m.v("sum"), av))
    let active = either(b, [m.is_state(5UL), m.is_state(6UL)])
    let accumulated = b.bit_and(
      m.is_state(6UL),
      b.equal(
        m.v("exec_phase"),
        u(b, 3, if m.deep_fp32_add { 3UL } else { 1UL }),
      ),
    )
    m.put(
      "exec_phase",
      active,
      b.mux(
        b.bit_or(execute, accumulated),
        u(b, 3, 0UL),
        b.add(m.v("exec_phase"), u(b, 3, 1UL)),
      ),
    )
    m.set("exec_phase", b.bit_not(active), 0UL)
    Some(accumulated)
  } else {
    None
  }
  let av = if m.fast_arithmetic { m.v("exec_a") } else { av }
  let bv = if m.fast_arithmetic { m.v("exec_b") } else { bv }
  let multiply_b = if m.fast_arithmetic {
    m.v("exec_multiply_b")
  } else {
    raw_multiply_b
  }
  let product = if m.fast_arithmetic {
    fp32_multiply_pipeline3(
      b,
      m.d,
      m.reset,
      av,
      multiply_b,
      fast=true,
      compact_pack=m.compact_multiply_pack,
      staged_product=m.staged_multiply_product,
      registered_inputs=m.registered_multiply_inputs,
    )
  } else {
    multiply(b, av, multiply_b)
  }
  let pipeline = if m.fast_arithmetic { Some((m.d, m.reset)) } else { None }
  let added = add(
    b,
    if m.fast_arithmetic {
      m.v("exec_add_a")
    } else {
      b.mux(m.is_op(6UL), m.v("sum"), av)
    },
    bv,
    fast=m.fast_arithmetic,
    bounded=m.bounded_add,
    stage_aligned=m.staged_scalar_alignment,
    stage_normalized=m.staged_scalar_add,
    pipeline~,
  )
  let sum_value = add(
    b,
    m.v("sum"),
    m.v("product"),
    fast=m.fast_arithmetic,
    bounded=m.bounded_add,
    stage_aligned=m.deep_fp32_add,
    stage_normalized=m.deep_fp32_add,
    pipeline~,
  )
  let max_value = b.mux(fp_less(b, m.v("sum"), av), av, m.v("sum"))
  let total = add(
    b,
    m.v("sum"),
    av,
    fast=m.fast_arithmetic,
    bounded=m.bounded_add,
    stage_aligned=m.staged_scalar_alignment,
    stage_normalized=m.staged_scalar_add,
    pipeline~,
  )
  let value = b.mux(
    m.is_op(2UL),
    added,
    b.mux(
      either(b, [m.is_op(3UL), m.is_op(13UL)]),
      product,
      b.mux(m.is_op(12UL), b.bit_or(av, u(b, 32, 0x80000000UL)), av),
    ),
  )
  m.jump(m.is_state(4UL), 16UL)
  m.jump(m.is_state(16UL), 5UL)
  m.put("out", execute, value)
  m.put(
    "state",
    execute,
    b.mux(
      store,
      u(b, 5, 9UL),
      b.mux(
        unary,
        u(b, 5, 11UL),
        b.mux(
          product_op,
          u(b, 5, 6UL),
          b.mux(reduction, u(b, 5, 7UL), u(b, 5, 8UL)),
        ),
      ),
    ),
  )
  m.put("product", b.bit_and(execute, product_op), product)
  increment(
    m,
    "products",
    all(b, [execute, either(b, [product_op, m.is_op(3UL), m.is_op(13UL)])]),
    1UL,
  )
  m.put(
    "sum",
    all(b, [execute, reduction, b.bit_not(product_op)]),
    b.mux(m.is_op(8UL), max_value, total),
  )
  m.put(
    "sum",
    if accumulated is Some(v) {
      v
    } else {
      m.is_state(6UL)
    },
    sum_value,
  )
  m.jump(if accumulated is Some(v) { v } else { m.is_state(6UL) }, 7UL)
  let advance = m.is_state(7UL)
  let limit = b.mux(matrix, m.v("k"), m.v("n"))
  let last = b.equal(b.add(m.v("i"), one), limit)
  m.put("out", b.bit_and(advance, last), m.v("sum"))
  m.jump(b.bit_and(advance, last), 8UL)
  let inner = all(b, [advance, b.bit_not(last)])
  increment(m, "i", inner, 1UL)
  increment(m, "ai", inner, 1UL)
  m.put("bi", inner, b.add(m.v("bi"), m.v("bs")))
  m.put(
    "state",
    inner,
    b.mux(
      b.bit_and(
        external_matrix,
        b.equal(field(b, m.v("i"), 5, 0), u(b, 6, 63UL)),
      ),
      u(b, 5, 9UL),
      u(b, 5, 4UL),
    ),
  )
  let write = m.is_state(8UL)
  let end_row = b.equal(b.add(m.v("row"), one), m.v("n"))
  let next_row = all(b, [write, matrix, b.bit_not(end_row)])
  increment(m, "row", next_row, 1UL)
  increment(m, "di", next_row, 1UL)
  m.set("i", next_row, 0UL)
  m.set("sum", next_row, 0UL)
  m.put("ai", next_row, m.v("a"))
  let row_b = b.add(m.v("brow"), m.v("br"))
  m.put("brow", next_row, row_b)
  m.put("bi", next_row, row_b)
  m.put("state", next_row, b.mux(external_matrix, u(b, 5, 9UL), u(b, 5, 4UL)))
  m.jump(all(b, [write, b.bit_or(reduction, b.bit_and(matrix, end_row))]), 13UL)
  let vector = all(b, [write, b.bit_not(b.bit_or(matrix, reduction))])
  let vector_last = b.equal(b.add(m.v("i"), one), m.v("n"))
  m.jump(b.bit_and(vector, vector_last), 13UL)
  let next_vector = all(b, [vector, b.bit_not(vector_last)])
  for name in ["i", "ai", "di"] {
    increment(m, name, next_vector, 1UL)
  }
  m.put(
    "bi",
    next_vector,
    b.add(m.v("bi"), b.mux(b.equal(m.v("flags"), zero), one, zero)),
  )
  increment(m, "ext", all(b, [next_vector, b.bit_or(load, store)]), 4UL)
  m.put("state", next_vector, b.mux(load, u(b, 5, 9UL), u(b, 5, 4UL)))
  let unit = if m.interleaved {
    interleaved_unary_path(m, scratch_word)
  } else {
    unary_logic(
      b,
      m.d,
      m.reset,
      m.is_state(11UL),
      b.truncate(b.sub(m.v("op"), u(b, 32, 8UL)), 2),
      m.v("out"),
      fast=m.fast_arithmetic,
      short=m.short_unary,
    )
  }
  m.jump(m.is_state(11UL), 12UL)
  let unary_done = all(b, [m.is_state(12UL), unit.done, b.bit_not(unit.busy)])
  m.put("out", unary_done, unit.result)
  m.jump(unary_done, 8UL)
  let unary_error = b.bit_and(unary_done, unit.error)
  m.jump(unary_error, 15UL)
  m.set("error", unary_error, 3UL)
  let request = m.is_state(9UL)
  let accepted = b.bit_and(request, inputs["ddr_request_ready"])
  m.jump(accepted, 10UL)
  m.set("fill", accepted, 0UL)
  increment(m, "ext", b.bit_and(accepted, external_matrix), 128UL)
  let response = all(b, [m.is_state(10UL), inputs["ddr_response_valid"]])
  let last_response = b.mux(
    external_matrix,
    b.equal(m.v("fill"), u(b, 5, 31UL)),
    b.constant(@wire.bits(1), 1UL),
  )
  increment(m, "fill", b.bit_and(response, external_matrix), 1UL)
  let complete = b.bit_and(response, last_response)
  m.put("out", b.bit_and(response, load), inputs["ddr_response_data"])
  m.put("state", complete, b.mux(external_matrix, u(b, 5, 4UL), u(b, 5, 8UL)))
  let bad = all(b, [
    response,
    either(b, [
      b.not_equal(inputs["ddr_response_fault"], u(b, 2, 0UL)),
      b.bit_xor(last_response, inputs["ddr_response_last"]),
    ]),
  ])
  m.jump(bad, 15UL)
  m.set("error", bad, 4UL)
  increment(m, "ddr_beats", response, 1UL)
  let line_read = if load_line is Some(line) {
    if m.indirect_bf16 {
      let indirect = indirect_load(m)
      receive_load_line(
        m,
        inputs,
        line,
        accepted,
        response,
        b.bit_and(load, b.bit_not(indirect)),
      )
      indirect_bf16_load(m, inputs, indirect, response, bad)
    } else {
      receive_load_line(m, inputs, line, accepted, response, load)
    }
    b.bit_or(external_matrix, line)
  } else {
    external_matrix
  }
  let line_request = if store_bursts {
    store_burst_path(
      m,
      scratch_word,
      store,
      response,
      bad,
      inputs["memory_healthy"],
    )
    b.bit_or(line_read, b.bit_and(store, m.v("store_group")))
  } else {
    line_read
  }
  let outputs = [
    ("ddr_request_valid", request),
    ("ddr_request_line", line_request),
    ("ddr_request_burst", line_request),
    ("ddr_request_write", store),
    ("ddr_request_address", m.memory_address(m.v("ext"))),
    (
      "ddr_request_data",
      if load_line is Some(line) {
        b.mux(line, zero, m.v("out"))
      } else {
        m.v("out")
      },
    ),
  ]
  for (name, value) in outputs {
    let x = match lanes {
      Some(p) =>
        if name == "ddr_request_valid" {
          b.bit_or(value, p["request_valid"])
        } else {
          b.mux(
            p["request_valid"],
            if name == "ddr_request_address" {
              p["request_address"]
            } else if name == "ddr_request_line" || name == "ddr_request_burst" {
              b.constant(@wire.bits(1), 1UL)
            } else if name == "ddr_request_write" {
              b.constant(@wire.bits(1), 0UL)
            } else if batch && name == "ddr_request_data" {
              // Bit 31 marks a row batch. In the long-prefetch target bit 30
              // selects 512-byte rows. The remaining bits hold the byte stride.
              let header = b.bit_or(
                if m.prefetch256 {
                  b.mux(
                    p["long_stripe"],
                    u(b, 32, 0xc0000000UL),
                    u(b, 32, 0x80000000UL),
                  )
                } else {
                  u(b, 32, 0x80000000UL)
                },
                if m.full_rows {
                  b.mux(
                    p["full_row"],
                    if m.strided_rows {
                      b.mux(
                        b.equal(m.v("k"), u(b, 32, 1024UL)),
                        u(b, 32, 0x20000200UL),
                        b.bit_or(
                          u(b, 32, 0x20000000UL),
                          b.shift_left(m.v("k"), u(b, 1, 1UL)),
                        ),
                      )
                    } else {
                      u(b, 32, if m.deep_batch { 0x20000200UL } else { 512UL })
                    },
                    b.mux(
                      b.equal(m.v("flags"), u(b, 32, 1UL)),
                      u(b, 32, 128UL),
                      b.shift_left(m.v("k"), u(b, 1, 1UL)),
                    ),
                  )
                } else if m.packed_weights {
                  b.mux(
                    b.equal(m.v("flags"), u(b, 32, 1UL)),
                    u(b, 32, 128UL),
                    b.shift_left(m.v("k"), u(b, 1, 1UL)),
                  )
                } else {
                  b.shift_left(m.v("k"), u(b, 1, 1UL))
                },
              )
              if m.group64_rows {
                b.mux(
                  p["group64_rows"],
                  b.bit_or(
                    if m.stripe512 {
                      b.mux(
                        p["stripe512"],
                        if m.prefetch_row_blocks {
                          b.mux(
                            p["prefetch_row_blocks"],
                            u(b, 32, 0xfc000000UL),
                            u(b, 32, 0xf8000000UL),
                          )
                        } else {
                          u(b, 32, 0xf8000000UL)
                        },
                        u(b, 32, 0xf0000000UL),
                      )
                    } else {
                      u(b, 32, 0xf0000000UL)
                    },
                    b.shift_left(m.v("k"), u(b, 1, 1UL)),
                  ),
                  header,
                )
              } else {
                header
              }
            } else {
              u(b, 32, 0UL)
            },
            value,
          )
        }
      None => value
    }
    let p = b.output(name, x.signal_type())
    b.output_timing(p, ProducedIn(m.d.id()))
    b.connect(p, x)
  }
}
