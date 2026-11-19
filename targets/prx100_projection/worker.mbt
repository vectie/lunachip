///|
fn worker(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  c : Map[String, @wire.Signal],
  s : WorkerState,
  start : @wire.Signal,
  bases : ArrayView[@wire.Signal],
  count : @wire.Signal,
  healthy : @wire.Signal,
  ready : @wire.Signal,
  response : @wire.Signal,
  data : @wire.Signal,
  fault : @wire.Signal,
  last : @wire.Signal,
  foreign_response : @wire.Signal,
  watchdog : UInt64,
) -> Worker raise {
  let states : Map[Int32, @wire.Signal] = Map([])
  for i in 0..<18 {
    if i != 13 {
      states[i] = eq(b, s.state.value(), i.to_uint64())
    }
  }
  let busy = both(b, [
    b.greater_equal(s.state.value(), n(b, 5, 1UL)),
    b.less_equal(s.state.value(), n(b, 5, 15UL)),
  ])
  let idle = any(b, [states[0], states[16]])
  let core_reset = any(b, [
    b.reset_asserted(reset.signal()),
    states[1],
    states[17],
  ])
  let last_tile = b.equal(
    b.add(b.zero_extend(s.tile.value(), 7), n(b, 7, 1UL)),
    count,
  )
  let prefetch_active = both(b, [
    states[7],
    b.bit_not(last_tile),
    b.bit_not(eq(b, s.prefetch.value(), 2UL)),
  ])
  let prefetch_request = b.bit_and(
    prefetch_active,
    eq(b, s.prefetch.value(), 0UL),
  )
  let prefetch_wait = b.bit_and(prefetch_active, eq(b, s.prefetch.value(), 1UL))
  let read_request = b.bit_or(states[4], prefetch_request)
  let current_end = b.shift_left(
    b.add(b.zero_extend(s.tile.value(), 32), n(b, 32, 1UL)),
    n(b, 3, 2UL),
  )
  let ahead_write = both(b, [states[7], eq(b, s.ahead.value(), 1UL)])
  let ahead_publish = both(b, [
    states[7],
    eq(b, s.ahead.value(), 2UL),
    eq(b, s.prefetch.value(), 2UL),
  ])
  let begin_ahead = both(b, [
    states[7],
    b.bit_not(last_tile),
    eq(b, s.ahead.value(), 0UL),
    b.equal(c["consumer_count"], current_end),
  ])
  let request_valid = any(b, [read_request, states[11], states[14]])
  let request_fire = b.bit_and(request_valid, ready)
  let good_response = both(b, [
    response,
    eq(b, fault, 0UL),
    healthy,
    b.bit_not(foreign_response),
  ])
  let filled = b.bit_and(states[5], good_response)
  let prefetched = b.bit_and(prefetch_wait, good_response)
  let filled_word = b.bit_or(filled, prefetched)
  let partial_written = b.bit_and(states[12], good_response)
  let sum_written = b.bit_and(states[15], good_response)
  let tile28 = b.zero_extend(s.tile.value(), 28)
  let read_tile = b.add(
    tile28,
    b.mux(prefetch_active, n(b, 28, 1UL), n(b, 28, 0UL)),
  )
  let fill28 = b.zero_extend(s.fill.value(), 28)
  let weight_offset = b.add(
    b.shift_left(read_tile, n(b, 4, 7UL)),
    b.shift_left(b.sub(fill28, n(b, 28, 4UL)), n(b, 3, 2UL)),
  )
  let activation_offset = b.add(
    b.shift_left(read_tile, n(b, 3, 4UL)),
    b.shift_left(fill28, n(b, 3, 2UL)),
  )
  let address = b.mux(
    read_request,
    b.mux(
      b.less_than(s.fill.value(), n(b, 6, 4UL)),
      b.add(bases[1], activation_offset),
      b.add(bases[0], weight_offset),
    ),
    b.mux(
      states[11],
      b.add(
        bases[2],
        b.add(
          b.shift_left(tile28, n(b, 3, 5UL)),
          b.shift_left(
            b.zero_extend(u(b, b.slice(s.channel.value(), 2, 2)), 28),
            n(b, 3, 4UL),
          ),
        ),
      ),
      b.add(
        bases[3],
        b.shift_left(b.zero_extend(s.channel.value(), 28), n(b, 3, 2UL)),
      ),
    ),
  )
  let sum_words = s.sums.map(r => r.value())
  let result_words = Array::makei(4, i => {
    b.mux(
      states[14],
      b.mux(b.slice(s.channel.value(), 2, 2), sum_words[i + 4], sum_words[i]),
      s.partial[i].value(),
    )
  })
  let descriptor_index = b.mux(
    states[3],
    s.descriptor.value(),
    table(
      b,
      s.descriptor.value(),
      [1UL, 4UL, 6UL, 9UL, 12UL, 14UL, 17UL, 20UL, 22UL, 25UL, 28UL, 30UL].map(i => {
        n(b, 5, i)
      }),
    ),
  )
  let descriptor_data = descriptor_word(
    b,
    descriptor_index,
    b.add(s.tile.value(), b.mux(ahead_write, n(b, 6, 1UL), n(b, 6, 0UL))),
  )
  // DDR responses own the staging write port. Patch descriptors in the gaps
  // as soon as the reader releases the old ring image; publish only after all
  // operand words have landed in the alternate region.
  let descriptor_write = b.bit_or(
    states[3],
    b.bit_and(ahead_write, b.bit_not(filled_word)),
  )
  let fill_region = b.shift_left(
    b.zero_extend(u(b, b.slice(read_tile, 0, 0)), 32),
    n(b, 4, 11UL),
  )
  let fill_address = b.mux(
    b.less_than(s.fill.value(), n(b, 6, 4UL)),
    b.add(
      b.add(n(b, 32, 256UL), fill_region),
      b.shift_left(b.zero_extend(s.fill.value(), 32), n(b, 3, 2UL)),
    ),
    b.add(
      b.add(n(b, 32, 512UL), fill_region),
      b.shift_left(
        b.sub(b.zero_extend(s.fill.value(), 32), n(b, 32, 4UL)),
        n(b, 3, 2UL),
      ),
    ),
  )
  // The collection port issues C[n+1] while C[n] is captured. Its explicit
  // one-edge read latency permits consecutive captures without a wait bubble.
  let stage = staging(
    b,
    d,
    reset,
    c,
    both(b, [busy, b.greater_equal(s.state.value(), n(b, 5, 6UL))]),
    core_reset,
    any(b, [descriptor_write, filled_word]),
    b.mux(
      descriptor_write,
      b.shift_left(b.zero_extend(descriptor_index, 32), n(b, 3, 2UL)),
      fill_address,
    ),
    b.mux(descriptor_write, descriptor_data, data),
    any(b, [states[8], states[10], states[11], states[12]]),
    b.add(
      b.add(
        n(b, 32, 1024UL),
        b.shift_left(
          b.zero_extend(u(b, b.slice(s.tile.value(), 0, 0)), 32),
          n(b, 4, 11UL),
        ),
      ),
      b.shift_left(
        b.zero_extend(
          b.add(s.channel.value(), b.mux(states[8], n(b, 3, 0UL), n(b, 3, 1UL))),
          32,
        ),
        n(b, 3, 2UL),
      ),
    ),
  )
  out(b, "core_reset", core_reset)
  out(b, "config_valid", states[2])
  out_static(b, "config_base", 32, 0UL)
  out_static(b, "config_origin", 32, 0UL)
  out(b, "publish_valid", b.bit_or(states[6], ahead_publish))
  out(
    b,
    "publish_producer",
    b.add(current_end, b.mux(ahead_publish, n(b, 32, 4UL), n(b, 32, 0UL))),
  )
  let completion_ready = both(b, [
    states[7],
    b.less_than(s.ordinal.value(), n(b, 3, 4UL)),
  ])
  out(b, "completion_ready", completion_ready)
  let completed = b.bit_and(completion_ready, c["completion_valid"])
  let expected_id = b.add(
    b.add(
      b.shift_left(b.zero_extend(s.tile.value(), 32), n(b, 3, 2UL)),
      b.zero_extend(s.ordinal.value(), 32),
    ),
    n(b, 32, 1UL),
  )
  let expected_bytes = table(b, s.ordinal.value(), [
    n(b, 32, 16UL),
    n(b, 32, 128UL),
    n(b, 32, 0UL),
    n(b, 32, 32UL),
  ])
  let completion_ok = both(b, [
    b.equal(c["completion_id"], expected_id),
    eq(b, c["completion_fault"], 0UL),
    b.equal(c["completion_bytes_completed"], expected_bytes),
    eq(b, c["completion_fault_address"], 0UL),
  ])
  let bad_completion = b.bit_and(completed, b.bit_not(completion_ok))
  let core_fault = both(b, [
    busy,
    b.bit_not(states[1]),
    any(b, [c["halted"], c["transport_halted"], c["ring_fault_valid"]]),
  ])
  let bad_ddr = b.bit_and(response, b.bit_not(eq(b, fault, 0UL)))
  let timed_out = b.bit_and(
    busy,
    b.greater_equal(s.cycles.value(), n(b, 64, watchdog)),
  )
  let lost = b.bit_and(busy, b.bit_not(healthy))
  let failure = any(b, [
    bad_completion, core_fault, bad_ddr, timed_out, lost, foreign_response,
  ])
  let error = b.mux(
    lost,
    n(b, 8, 2UL),
    b.mux(
      bad_ddr,
      n(b, 8, 3UL),
      b.mux(
        bad_completion,
        n(b, 8, 4UL),
        b.mux(
          core_fault,
          n(b, 8, 5UL),
          b.mux(timed_out, n(b, 8, 6UL), n(b, 8, 7UL)),
        ),
      ),
    ),
  )
  update(b, s.error, both(b, [failure, b.bit_not(states[17])]), error)
  let drained = both(b, [states[8], b.equal(current_end, s.retired.value())])
  let last_channel = eq(b, s.channel.value(), 7UL)
  let group_end = eq(b, b.slice(s.channel.value(), 1, 0), 3UL)
  let last_sum = eq(b, s.channel.value(), 4UL)
  let prefetch_done = b.bit_or(last_tile, eq(b, s.prefetch.value(), 2UL))
  let ahead_done = b.bit_or(last_tile, eq(b, s.ahead.value(), 3UL))
  let transitions : Array[(@wire.Signal, UInt64)] = [
    (start, 1UL),
    (states[1], 2UL),
    (b.bit_and(states[2], c["config_ready"]), 3UL),
    (
      both(b, [states[3], eq(b, s.descriptor.value(), 31UL)]),
      0UL, // only the initial descriptor image precedes the first DDR fill
    ),
    (b.bit_and(states[4], request_fire), 5UL),
    (b.bit_and(filled, last), 0UL), // a line owns all four ordered fill beats
    (b.bit_and(states[6], c["publish_ready"]), 7UL),
    (
      both(b, [
        states[7],
        prefetch_done,
        ahead_done,
        any(b, [
          eq(b, s.ordinal.value(), 4UL),
          both(b, [completed, eq(b, s.ordinal.value(), 3UL)]),
        ]),
      ]),
      8UL,
    ),
    (drained, 10UL),
    (states[9], 10UL),
    (b.bit_and(states[10], b.bit_not(group_end)), 10UL),
    (b.bit_and(states[10], group_end), 11UL),
    (b.bit_and(states[11], request_fire), 12UL),
    (partial_written, 0UL),
    (b.bit_and(states[14], request_fire), 15UL),
    (sum_written, 0UL),
  ]
  let mut next = s.state.value()
  for (condition, destination) in transitions {
    let destination = if destination == 0UL {
      b.mux(
        states[3],
        n(b, 5, 4UL),
        b.mux(
          filled,
          b.mux(eq(b, s.fill.value(), 35UL), n(b, 5, 6UL), n(b, 5, 4UL)),
          b.mux(
            partial_written,
            b.mux(
              last_channel,
              b.mux(last_tile, n(b, 5, 14UL), n(b, 5, 7UL)),
              n(b, 5, 10UL),
            ),
            b.mux(last_sum, n(b, 5, 16UL), n(b, 5, 14UL)),
          ),
        ),
      )
    } else {
      n(b, 5, destination)
    }
    next = b.mux(condition, destination, next)
  }
  b.connect_next(s.state, b.mux(failure, n(b, 5, 17UL), next))
  let next_tile = both(b, [partial_written, last_channel, b.bit_not(last_tile)])
  let published = b.bit_and(states[6], c["publish_ready"])
  b.connect_next(
    s.ahead,
    b.mux(
      any(b, [start, next_tile]),
      n(b, 2, 0UL),
      b.mux(
        begin_ahead,
        n(b, 2, 1UL),
        b.mux(
          both(b, [
            ahead_write,
            descriptor_write,
            eq(b, s.descriptor.value(), 11UL),
          ]),
          n(b, 2, 2UL),
          b.mux(
            b.bit_and(ahead_publish, c["publish_ready"]),
            n(b, 2, 3UL),
            s.ahead.value(),
          ),
        ),
      ),
    ),
  )
  increment(b, s.tile, start, next_tile, n(b, 6, 1UL))
  increment(
    b,
    s.descriptor,
    any(b, [start, next_tile, published]),
    descriptor_write,
    n(b, 5, 1UL),
  )
  increment(
    b,
    s.fill,
    any(b, [start, next_tile, published]),
    filled_word,
    n(b, 6, 1UL),
  )
  b.connect_next(
    s.prefetch,
    b.mux(
      any(b, [start, published, next_tile]),
      n(b, 2, 0UL),
      b.mux(
        b.bit_and(prefetched, last),
        b.mux(eq(b, s.fill.value(), 35UL), n(b, 2, 2UL), n(b, 2, 0UL)),
        b.mux(
          b.bit_and(prefetch_request, request_fire),
          n(b, 2, 1UL),
          s.prefetch.value(),
        ),
      ),
    ),
  )
  increment(
    b,
    s.channel,
    any(b, [start, drained, both(b, [partial_written, last_channel])]),
    any(b, [
      both(b, [states[10], b.bit_not(group_end)]),
      partial_written,
      sum_written,
    ]),
    b.mux(sum_written, n(b, 3, 4UL), n(b, 3, 1UL)),
  )
  increment(
    b,
    s.ordinal,
    any(b, [start, published, next_tile]),
    completed,
    n(b, 3, 1UL),
  )
  increment(b, s.retired, start, completed, n(b, 32, 1UL))
  increment(
    b,
    s.completed,
    start,
    both(b, [partial_written, last_channel]),
    n(b, 7, 1UL),
  )
  increment(b, s.partials, start, partial_written, n(b, 32, 4UL))
  for i, r in s.partial {
    update(
      b,
      r,
      both(b, [
        states[10],
        eq(b, b.slice(s.channel.value(), 1, 0), i.to_uint64()),
      ]),
      stage.word,
    )
  }
  for i, sum in s.sums {
    increment(
      b,
      sum,
      start,
      both(b, [states[10], eq(b, s.channel.value(), i.to_uint64())]),
      stage.word,
    )
  }
  worker_counters(
    b, start, s, states, busy, descriptor_write, prefetch_active, completed, c, filled_word,
    read_request, request_fire,
  )
  let registers = worker_registers(b, d, reset, start, s, stage.accepted, c)
  {
    request_valid,
    request_write: b.bit_not(read_request),
    request_burst: both(b, [
      read_request,
      b.greater_equal(s.fill.value(), n(b, 6, 4UL)),
    ]),
    request_address: address,
    request_data: result_words[0],
    request_more: result_words[1:].to_owned(),
    busy,
    idle,
    registers,
    prefetch_write: prefetched,
  }
}
