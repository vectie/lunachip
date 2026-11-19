///|
priv struct Job {
  busy : @wire.Signal
  done : @wire.Signal
  fault : @wire.Signal
  error : @wire.Signal
  request_valid : @wire.Signal
  request_write : @wire.Signal
  request_address : @wire.Signal
  request_data : Array[@wire.Signal]
  request_burst : @wire.Signal
  registers : Array[(UInt64, @wire.Signal)]
}

///|
fn worker(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  rs : @wire.Signal,
  c : Map[String, @wire.Signal],
  bases : Array[@wire.Signal],
  length : @wire.Signal,
  jobs : @wire.Signal,
  vectors : @wire.Signal,
  start : @wire.Signal,
  invalidate : @wire.Signal,
  healthy : @wire.Signal,
  protocol_fault : @wire.Signal,
  ready : @wire.Signal,
  response : @wire.Signal,
  response_data : @wire.Signal,
  response_fault : @wire.Signal,
  response_last : @wire.Signal,
  watchdog : UInt64,
) -> Job raise {
  let state = b.register_state_in(d, @wire.uint(4), reset~)
  let error = b.register_state_in(d, @wire.uint(3), reset~)
  let cached = b.register_state_in(d, @wire.bits(1), reset~)
  let block = b.register_state_in(d, @wire.uint(7), reset~)
  let beat = b.register_state_in(d, @wire.uint(5), reset~)
  let index = b.register_state_in(d, @wire.uint(6), reset~)
  let vector = b.register_state_in(d, @wire.uint(2), reset~)
  let completed = b.register_state_in(d, @wire.uint(6), reset~)
  let result_line = b.register_state_in(d, @wire.bits(1), reset~)
  let packing = b.register_state_in(d, @wire.uint(11), reset~)
  let total = b.register_state_in(d, @wire.uint(32), reset~)
  let ddr_cycles = b.register_state_in(d, @wire.uint(32), reset~)
  let pack_cycles = b.register_state_in(d, @wire.uint(32), reset~)
  let core_wait = b.register_state_in(d, @wire.uint(32), reset~)
  let core_cycles = b.register_state_in(d, @wire.uint(32), reset~)
  let reads = b.register_state_in(d, @wire.uint(32), reset~)
  let writes = b.register_state_in(d, @wire.uint(32), reset~)
  let staged = b.register_state_in(d, @wire.uint(32), reset~)
  let core_words = b.register_state_in(d, @wire.uint(32), reset~)
  fn at(i : UInt64) -> @wire.Signal raise {
    eq(b, state.value(), i)
  }
  let idle = any(b, [at(0UL), at(10UL)])
  let fault = at(11UL)
  let busy = b.bit_not(b.bit_or(idle, fault))
  let weight_request = at(1UL)
  let weight_receive = at(2UL)
  let activation_request = at(3UL)
  let activation_receive = at(4UL)
  let pack = at(5UL)
  let launch = at(6UL)
  let compute = at(7UL)
  let result_request = at(8UL)
  let result_receive = at(9UL)
  let request = any(b, [weight_request, activation_request, result_request])
  let accepted = b.bit_and(request, ready)
  let receive = b.bit_and(
    response,
    any(b, [weight_receive, activation_receive, result_receive]),
  )
  let read_end = eq(b, beat.value(), 31UL)
  let last_expected = b.bit_or(result_receive, read_end)
  let bad_last = b.bit_and(receive, b.bit_xor(response_last, last_expected))
  let data_error = b.bit_and(receive, b.bit_not(eq(b, response_fault, 0UL)))
  let finished_core = both(b, [compute, c["done"], b.bit_not(c["busy"])])
  let bad_core = both(b, [
    busy,
    any(b, [
      c["error"],
      both(b, [c["busy"], b.bit_not(any(b, [compute, launch]))]),
      both(b, [
        finished_core,
        b.not_equal(
          c["cycles"],
          b.add(
            b.add(
              b.shift_left(b.zero_extend(length, 32), n(b, 2, 2UL)),
              b.zero_extend(length, 32),
            ),
            n(b, 32, 4UL),
          ),
        ),
      ]),
    ]),
  ])
  let timeout = both(b, [
    busy,
    b.greater_equal(total.value(), n(b, 32, watchdog)),
  ])
  let fatal = any(b, [
    protocol_fault,
    both(b, [busy, b.bit_not(healthy)]),
    bad_last,
    data_error,
    bad_core,
    timeout,
  ])
  let safe = both(b, [
    b.bit_not(fatal),
    b.bit_not(fault),
    healthy,
    b.bit_not(b.reset_asserted(rs)),
  ])
  let good = b.bit_and(receive, safe)
  let weight_word = b.bit_and(good, weight_receive)
  let activation_word = b.bit_and(good, activation_receive)
  let weight_done = both(b, [weight_word, read_end, eq(b, block.value(), 127UL)])
  let activation_done = both(b, [
    activation_word,
    read_end,
    eq(b, block.value(), 15UL),
  ])
  let line_done = b.bit_and(good, result_receive)
  let job_done = b.bit_and(line_done, result_line.value())
  let final_job = b.equal(b.add(index.value(), n(b, 6, 1UL)), jobs)
  let pack_done = b.bit_and(pack, eq(b, packing.value(), 1024UL))
  let next_vector = b.add(vector.value(), n(b, 2, 1UL))
  let next_vector = b.mux(
    b.equal(next_vector, vectors),
    n(b, 2, 0UL),
    next_vector,
  )
  let next_state = b.mux(
    start,
    b.mux(cached.value(), n(b, 4, 3UL), n(b, 4, 1UL)),
    b.mux(
      b.bit_and(accepted, weight_request),
      n(b, 4, 2UL),
      b.mux(
        b.bit_and(weight_word, read_end),
        b.mux(weight_done, n(b, 4, 3UL), n(b, 4, 1UL)),
        b.mux(
          b.bit_and(accepted, activation_request),
          n(b, 4, 4UL),
          b.mux(
            b.bit_and(activation_word, read_end),
            b.mux(activation_done, n(b, 4, 5UL), n(b, 4, 3UL)),
            b.mux(
              pack_done,
              n(b, 4, 6UL),
              b.mux(
                launch,
                n(b, 4, 7UL),
                b.mux(
                  finished_core,
                  n(b, 4, 8UL),
                  b.mux(
                    b.bit_and(accepted, result_request),
                    n(b, 4, 9UL),
                    b.mux(
                      line_done,
                      b.mux(
                        result_line.value(),
                        b.mux(final_job, n(b, 4, 10UL), n(b, 4, 3UL)),
                        n(b, 4, 8UL),
                      ),
                      state.value(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  )
  b.connect_next(state, b.mux(fatal, n(b, 4, 11UL), next_state))
  let error_code = b.mux(
    protocol_fault,
    n(b, 3, 4UL),
    b.mux(
      b.bit_not(healthy),
      n(b, 3, 2UL),
      b.mux(
        bad_last,
        n(b, 3, 4UL),
        b.mux(
          data_error,
          n(b, 3, 3UL),
          b.mux(bad_core, n(b, 3, 5UL), n(b, 3, 6UL)),
        ),
      ),
    ),
  )
  update(b, error, b.bit_and(fatal, b.bit_not(fault)), error_code)
  b.connect_next(
    cached,
    b.mux(
      any(b, [invalidate, fatal, b.bit_not(healthy)]),
      n(b, 1, 0UL),
      b.mux(weight_done, n(b, 1, 1UL), cached.value()),
    ),
  )
  b.connect_next(
    block,
    b.mux(
      any(b, [start, weight_done, activation_done, job_done]),
      n(b, 7, 0UL),
      b.mux(
        both(b, [good, b.bit_not(result_receive), read_end]),
        b.add(block.value(), n(b, 7, 1UL)),
        block.value(),
      ),
    ),
  )
  b.connect_next(
    beat,
    b.mux(
      b.bit_or(start, accepted),
      n(b, 5, 0UL),
      b.mux(good, b.add(beat.value(), n(b, 5, 1UL)), beat.value()),
    ),
  )
  b.connect_next(
    index,
    b.mux(
      start,
      n(b, 6, 0UL),
      b.mux(
        b.bit_and(job_done, b.bit_not(final_job)),
        b.add(index.value(), n(b, 6, 1UL)),
        index.value(),
      ),
    ),
  )
  b.connect_next(
    vector,
    b.mux(
      start,
      n(b, 2, 0UL),
      b.mux(
        b.bit_and(job_done, b.bit_not(final_job)),
        next_vector,
        vector.value(),
      ),
    ),
  )
  b.connect_next(
    completed,
    b.mux(
      start,
      n(b, 6, 0UL),
      b.mux(job_done, b.add(completed.value(), n(b, 6, 1UL)), completed.value()),
    ),
  )
  b.connect_next(
    result_line,
    b.mux(
      b.bit_or(start, finished_core),
      n(b, 1, 0UL),
      b.mux(line_done, b.bit_not(result_line.value()), result_line.value()),
    ),
  )
  b.connect_next(
    packing,
    b.mux(
      b.bit_or(start, activation_done),
      n(b, 11, 0UL),
      b.mux(pack, b.add(packing.value(), n(b, 11, 1UL)), packing.value()),
    ),
  )
  let load = pack_operands(
    b,
    d,
    reset,
    rs,
    state.value(),
    packing.value(),
    block.value(),
    beat.value(),
    weight_word,
    activation_word,
    response_data,
    safe,
  )
  for
    (r, enable, amount) in [
      (total, busy, n(b, 32, 1UL)),
      (
        ddr_cycles,
        any(b, [request, weight_receive, activation_receive, result_receive]),
        n(b, 32, 1UL),
      ),
      (pack_cycles, pack, n(b, 32, 1UL)),
      (core_wait, compute, n(b, 32, 1UL)),
      (core_cycles, finished_core, c["cycles"]),
      (reads, both(b, [accepted, b.bit_not(result_request)]), n(b, 32, 1UL)),
      (writes, b.bit_and(accepted, result_request), n(b, 32, 1UL)),
      (staged, b.bit_or(weight_word, activation_word), n(b, 32, 1UL)),
      (core_words, load, n(b, 32, 8UL)),
    ] {
    b.connect_next(
      r,
      b.mux(
        start,
        n(b, 32, 0UL),
        b.mux(b.bit_and(enable, safe), b.add(r.value(), amount), r.value()),
      ),
    )
  }
  out(b, "core_reset", any(b, [b.reset_asserted(rs), fault, fatal]))
  out(b, "start", b.bit_and(launch, safe))
  out(b, "length", length)
  let request_address = b.mux(
    weight_request,
    b.add(
      bases[0],
      b.shift_left(b.zero_extend(block.value(), 28), n(b, 3, 7UL)),
    ),
    b.mux(
      activation_request,
      b.add(
        b.add(
          bases[1],
          b.shift_left(b.zero_extend(vector.value(), 28), n(b, 4, 11UL)),
        ),
        b.shift_left(b.zero_extend(block.value(), 28), n(b, 3, 7UL)),
      ),
      b.add(
        b.add(
          bases[2],
          b.shift_left(b.zero_extend(index.value(), 28), n(b, 3, 5UL)),
        ),
        b.shift_left(b.zero_extend(u(b, result_line.value()), 28), n(b, 3, 4UL)),
      ),
    ),
  )
  let data = Array::makei(4, i => {
    b.mux(
      result_line.value(),
      c["result_" + (i + 4).to_string()],
      c["result_" + i.to_string()],
    )
  })
  let registers = [
    (0x30UL, index.value()),
    (0x34UL, completed.value()),
    (0x38UL, total.value()),
    (0x3cUL, ddr_cycles.value()),
    (0x40UL, pack_cycles.value()),
    (0x44UL, core_wait.value()),
    (0x48UL, core_cycles.value()),
    (0x4cUL, reads.value()),
    (0x50UL, writes.value()),
    (0x54UL, staged.value()),
    (0x58UL, core_words.value()),
    (0x5cUL, state.value()),
    (0x60UL, vector.value()),
    (0x64UL, n(b, 32, 50000000UL)),
    (0x68UL, n(b, 32, 100000000UL)),
    (0x6cUL, cached.value()),
  ]
  for i in 0..<8 {
    registers.push((0x80UL + i.to_uint64() * 4UL, c["result_" + i.to_string()]))
  }
  for
    (name, x) in [
      ("state", state.value()),
      ("busy", busy),
      ("done", at(10UL)),
      ("fault", fault),
      ("start", start),
      ("cycles", total.value()),
      ("completed", completed.value()),
      ("cache", cached.value()),
      ("pack", pack),
      ("load", load),
      ("core_words", core_words.value()),
    ] {
    out(b, "observe_" + name, x)
  }
  {
    busy,
    done: at(10UL),
    fault,
    error: error.value(),
    request_valid: b.bit_and(request, safe),
    request_write: result_request,
    request_address,
    request_data: data,
    request_burst: b.bit_not(result_request),
    registers,
  }
}
