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
// Prepared-minus-retired bounds the two physical operand banks. A feeder,
// an FP executor and one held result share a single DDR transaction owner.
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
  fn reg(width : Int32) -> @wire.RegisterHandle raise {
    b.register_state_in(
      d,
      if width == 1 {
        @wire.bits(1)
      } else {
        @wire.uint(width)
      },
      reset~,
    )
  }
  let running = reg(1)
  let done = reg(1)
  let fault = reg(1)
  let error = reg(3)
  let cached = reg(1)
  let feeder = reg(3)
  let bus = reg(2)
  let block = reg(7)
  let beat = reg(5)
  let packing = reg(11)
  let vector = reg(2)
  let prepared = reg(6)
  let started = reg(6)
  let retired = reg(6)
  let published = reg(6)
  let executing = reg(1)
  let pending = reg(1)
  let line = reg(1)
  let results = Array::makei(8, _ => reg(32))
  let total = reg(32)
  fn f(i : UInt64) -> @wire.Signal raise {
    eq(b, feeder.value(), i)
  }
  let bus_idle = eq(b, bus.value(), 0UL)
  let bus_weight = eq(b, bus.value(), 1UL)
  let bus_activation = eq(b, bus.value(), 2UL)
  let bus_store = eq(b, bus.value(), 3UL)
  let receive = both(b, [response, b.bit_not(bus_idle)])
  let read_receive = both(b, [receive, b.bit_not(bus_store)])
  let read_end = eq(b, beat.value(), 31UL)
  let bad_last = both(b, [
    receive,
    b.bit_xor(response_last, b.bit_or(bus_store, read_end)),
  ])
  let data_error = both(b, [receive, b.bit_not(eq(b, response_fault, 0UL))])
  let core_finished = both(b, [
    executing.value(),
    c["done"],
    b.bit_not(c["busy"]),
  ])
  let expected_cycles = b.add(
    b.shift_left(b.zero_extend(length, 32), n(b, 2, 2UL)),
    n(b, 32, 4UL),
  )
  let bad_core = both(b, [
    running.value(),
    any(b, [
      c["error"],
      both(b, [c["busy"], b.bit_not(executing.value())]),
      both(b, [core_finished, b.not_equal(c["cycles"], expected_cycles)]),
    ]),
  ])
  let timeout = both(b, [
    running.value(),
    b.greater_equal(total.value(), n(b, 32, watchdog)),
  ])
  let fatal = any(b, [
    protocol_fault,
    both(b, [response, bus_idle]),
    both(b, [running.value(), b.bit_not(healthy)]),
    bad_last,
    data_error,
    bad_core,
    timeout,
  ])
  let safe = both(b, [
    b.bit_not(fatal),
    b.bit_not(fault.value()),
    healthy,
    b.bit_not(b.reset_asserted(rs)),
  ])
  let good = both(b, [receive, safe])
  let weight_word = both(b, [good, bus_weight])
  let activation_word = both(b, [good, bus_activation])
  let weight_done = both(b, [weight_word, read_end, eq(b, block.value(), 127UL)])
  let activation_done = both(b, [
    activation_word,
    read_end,
    eq(b, block.value(), 15UL),
  ])
  let store_ack = both(b, [good, bus_store])
  let stored = both(b, [store_ack, line.value()])
  let complete = both(b, [
    stored,
    b.equal(b.add(published.value(), n(b, 6, 1UL)), jobs),
  ])
  let pack_done = both(b, [f(5UL), eq(b, packing.value(), 1024UL), safe])
  let bank_free = b.less_than(
    b.zero_extend(prepared.value(), 7),
    b.add(b.zero_extend(retired.value(), 7), n(b, 7, 2UL)),
  )
  let launch = both(b, [
    running.value(),
    b.bit_not(executing.value()),
    b.less_than(started.value(), prepared.value()),
    safe,
  ])
  let finish = both(b, [core_finished, b.bit_not(pending.value()), safe])
  let request = both(b, [
    running.value(),
    bus_idle,
    any(b, [pending.value(), f(1UL), f(3UL)]),
    safe,
  ])
  let accepted = both(b, [request, ready])
  let write = pending.value()
  let selected_bus = b.mux(
    write,
    n(b, 2, 3UL),
    b.mux(f(1UL), n(b, 2, 1UL), n(b, 2, 2UL)),
  )
  let busy = both(b, [running.value(), b.bit_not(fault.value())])
  b.connect_next(
    running,
    b.mux(
      fatal,
      n(b, 1, 0UL),
      b.mux(start, n(b, 1, 1UL), b.mux(complete, n(b, 1, 0UL), running.value())),
    ),
  )
  b.connect_next(
    done,
    b.mux(
      fatal,
      n(b, 1, 0UL),
      b.mux(start, n(b, 1, 0UL), b.mux(complete, n(b, 1, 1UL), done.value())),
    ),
  )
  update(b, fault, fatal, n(b, 1, 1UL))
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
  update(b, error, both(b, [fatal, b.bit_not(fault.value())]), error_code)
  b.connect_next(
    cached,
    b.mux(
      any(b, [invalidate, fatal, b.bit_not(healthy)]),
      n(b, 1, 0UL),
      b.mux(weight_done, n(b, 1, 1UL), cached.value()),
    ),
  )
  b.connect_next(
    bus,
    b.mux(
      start,
      n(b, 2, 0UL),
      b.mux(
        accepted,
        selected_bus,
        b.mux(
          both(b, [receive, b.bit_or(bus_store, read_end)]),
          n(b, 2, 0UL),
          bus.value(),
        ),
      ),
    ),
  )
  let feed_next = b.mux(
    start,
    b.mux(cached.value(), n(b, 3, 3UL), n(b, 3, 1UL)),
    b.mux(
      both(b, [accepted, b.bit_not(write), f(1UL)]),
      n(b, 3, 2UL),
      b.mux(
        both(b, [weight_word, read_end]),
        b.mux(weight_done, n(b, 3, 3UL), n(b, 3, 1UL)),
        b.mux(
          both(b, [accepted, b.bit_not(write), f(3UL)]),
          n(b, 3, 4UL),
          b.mux(
            both(b, [activation_word, read_end]),
            b.mux(activation_done, n(b, 3, 6UL), n(b, 3, 3UL)),
            b.mux(
              both(b, [f(6UL), bank_free, safe]),
              n(b, 3, 5UL),
              b.mux(
                pack_done,
                b.mux(
                  b.equal(b.add(prepared.value(), n(b, 6, 1UL)), jobs),
                  n(b, 3, 0UL),
                  n(b, 3, 3UL),
                ),
                feeder.value(),
              ),
            ),
          ),
        ),
      ),
    ),
  )
  b.connect_next(feeder, feed_next)
  b.connect_next(
    block,
    b.mux(
      any(b, [start, weight_done, activation_done]),
      n(b, 7, 0UL),
      b.mux(
        both(b, [read_receive, read_end, safe]),
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
      b.mux(read_receive, b.add(beat.value(), n(b, 5, 1UL)), beat.value()),
    ),
  )
  b.connect_next(
    packing,
    b.mux(
      b.bit_or(start, activation_done),
      n(b, 11, 0UL),
      b.mux(
        both(b, [f(5UL), safe]),
        b.add(packing.value(), n(b, 11, 1UL)),
        packing.value(),
      ),
    ),
  )
  let next_vector = b.add(vector.value(), n(b, 2, 1UL))
  b.connect_next(
    vector,
    b.mux(
      start,
      n(b, 2, 0UL),
      b.mux(
        pack_done,
        b.mux(b.equal(next_vector, vectors), n(b, 2, 0UL), next_vector),
        vector.value(),
      ),
    ),
  )
  for
    (r, pulse) in [
      (prepared, pack_done),
      (started, launch),
      (retired, finish),
      (published, stored),
    ] {
    b.connect_next(
      r,
      b.mux(
        start,
        n(b, 6, 0UL),
        b.mux(pulse, b.add(r.value(), n(b, 6, 1UL)), r.value()),
      ),
    )
  }
  b.connect_next(
    executing,
    b.mux(
      start,
      n(b, 1, 0UL),
      b.mux(
        launch,
        n(b, 1, 1UL),
        b.mux(finish, n(b, 1, 0UL), executing.value()),
      ),
    ),
  )
  b.connect_next(
    pending,
    b.mux(
      start,
      n(b, 1, 0UL),
      b.mux(finish, n(b, 1, 1UL), b.mux(stored, n(b, 1, 0UL), pending.value())),
    ),
  )
  b.connect_next(
    line,
    b.mux(
      b.bit_or(start, finish),
      n(b, 1, 0UL),
      b.mux(store_ack, b.bit_not(line.value()), line.value()),
    ),
  )
  for lane, r in results {
    update(b, r, finish, c["result_" + lane.to_string()])
  }
  b.connect_next(
    total,
    b.mux(
      start,
      n(b, 32, 0UL),
      b.mux(
        both(b, [busy, safe]),
        b.add(total.value(), n(b, 32, 1UL)),
        total.value(),
      ),
    ),
  )
  let load = pack_operands(
    b,
    d,
    reset,
    rs,
    b.zero_extend(feeder.value(), 4),
    packing.value(),
    block.value(),
    beat.value(),
    weight_word,
    activation_word,
    response_data,
    safe,
  )
  out(b, "write_bank", u(b, b.slice(prepared.value(), 0, 0)))
  out(b, "start_bank", u(b, b.slice(started.value(), 0, 0)))
  out(b, "start", launch)
  out(b, "length", length)
  out(b, "core_reset", any(b, [b.reset_asserted(rs), fault.value(), fatal]))
  let ddr = both(b, [running.value(), any(b, [b.bit_not(bus_idle), request])])
  let pack = both(b, [running.value(), f(5UL)])
  let registers = account_overlap(
    b,
    d,
    reset,
    start,
    busy,
    safe,
    ddr,
    pack,
    executing.value(),
    finish,
    c["cycles"],
    accepted,
    write,
    weight_word,
    activation_word,
    load,
  )
  let state = b.mux(
    fault.value(),
    n(b, 4, 11UL),
    b.mux(
      done.value(),
      n(b, 4, 10UL),
      b.mux(running.value(), n(b, 4, 7UL), n(b, 4, 0UL)),
    ),
  )
  let published_vector = publication_vector(
    b, d, reset, start, stored, complete, vectors,
  )
  for
    pair in [
      (
        0x30UL,
        b.mux(
          done.value(),
          b.sub(published.value(), n(b, 6, 1UL)),
          published.value(),
        ),
      ),
      (0x34UL, published.value()),
      (0x38UL, total.value()),
      (0x5cUL, state),
      (0x60UL, published_vector),
      (0x64UL, n(b, 32, 50000000UL)),
      (0x68UL, n(b, 32, 100000000UL)),
      (0x6cUL, cached.value()),
      (0xa4UL, feeder.value()),
      (0xa8UL, prepared.value()),
      (0xacUL, started.value()),
      (0xb0UL, retired.value()),
      (0xb4UL, pending.value()),
    ] {
    registers.push(pair)
  }
  for lane, r in results {
    registers.push((0x80UL + lane.to_uint64() * 4UL, r.value()))
  }
  for
    (name, x) in [
      ("state", state),
      ("busy", busy),
      ("done", done.value()),
      ("fault", fault.value()),
      ("start", start),
      ("cycles", total.value()),
      ("completed", published.value()),
      ("cache", cached.value()),
      ("pack", pack),
      ("load", load),
      ("prepared", prepared.value()),
      ("started", started.value()),
      ("retired", retired.value()),
      ("executing", executing.value()),
      ("pending", pending.value()),
      ("feeder", feeder.value()),
      ("bus", bus.value()),
      ("core_bank", c["active_bank"]),
    ] {
    out(b, "observe_" + name, x)
  }
  let address = b.mux(
    write,
    b.add(
      b.add(
        bases[2],
        b.shift_left(b.zero_extend(published.value(), 28), n(b, 3, 5UL)),
      ),
      b.shift_left(b.zero_extend(u(b, line.value()), 28), n(b, 3, 4UL)),
    ),
    b.mux(
      f(1UL),
      b.add(
        bases[0],
        b.shift_left(b.zero_extend(block.value(), 28), n(b, 3, 7UL)),
      ),
      b.add(
        b.add(
          bases[1],
          b.shift_left(b.zero_extend(vector.value(), 28), n(b, 4, 11UL)),
        ),
        b.shift_left(b.zero_extend(block.value(), 28), n(b, 3, 7UL)),
      ),
    ),
  )
  {
    busy,
    done: done.value(),
    fault: fault.value(),
    error: error.value(),
    request_valid: request,
    request_write: write,
    request_address: address,
    request_data: Array::makei(4, i => {
      b.mux(line.value(), results[i + 4].value(), results[i].value())
    }),
    request_burst: b.bit_not(write),
    registers,
  }
}
