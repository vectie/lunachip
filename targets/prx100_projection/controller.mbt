///|
/// Autonomous1x(K16*tiles) by(K16*tiles)x8 projection around the exact core.
/// Watchdog changes have distinct IR identities; the physical target uses1s.
pub fn controller(watchdog~ : UInt64 = 50000000UL) -> @ir.Module raise {
  build_controller(watchdog, [])
}

///|
fn build_controller(
  watchdog : UInt64,
  observations : Array[Observation],
) -> @ir.Module raise {
  guard watchdog > 0UL && watchdog <= 50000000UL else {
    fail("invalid watchdog")
  }
  let b = @wire.ModuleBuilder::new("Prx100DdrProjectionSequencer")
  b.parameter("job_watchdog_cycles", Signed(watchdog.reinterpret_as_int64()))
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  b.input_timing(rs, SampledIn(d.id()))
  let reset = b.synchronous_reset(rs, 0UL)
  let healthy = input(b, d, "memory_healthy", 1)
  let c : Map[String, @wire.Signal] = Map([])
  let needed = [
    "memory_request_valid", "memory_request_write", "memory_request_address", "memory_request_bytes",
    "memory_request_mask", "memory_request_data", "memory_request_tag", "memory_response_ready",
    "config_ready", "publish_ready", "completion_valid", "completion_id", "completion_fault",
    "completion_bytes_completed", "completion_fault_address", "producer_count", "consumer_count",
    "elapsed_cycles", "halted", "transport_halted", "ring_fault_valid",
  ]
  for port in core().outputs() {
    if needed.contains(port.name()) {
      let x = b.input("c_" + port.name(), port.signal_type())
      b.input_timing(x, SampledIn(d.id()))
      c[port.name()] = x
    }
  }
  let a = axi_begin(b, d, reset)
  let ready = input(b, d, "ddr_request_ready", 1)
  let response = input(b, d, "ddr_response_valid", 1)
  let response_data = input(b, d, "ddr_response_data", 32)
  let response_fault = input(b, d, "ddr_response_fault", 2)
  let response_last = input(b, d, "ddr_response_last", 1)
  let owner = b.register_state_in(d, @wire.uint(2), reset~)
  let issued = b.register_state_in(d, @wire.bits(1), reset~)
  let line_owned = b.register_state_in(d, @wire.bits(1), reset~)
  let burst_owned = b.register_state_in(d, @wire.bits(1), reset~)
  let beat = b.register_state_in(d, @wire.uint(5), reset~)
  let vacant = eq(b, owner.value(), 0UL)
  let job_owner = eq(b, owner.value(), 3UL)
  let write_owner = eq(b, owner.value(), 1UL)
  let read_owner = eq(b, owner.value(), 2UL)
  let aborted = both(b, [
    b.bit_not(healthy),
    b.bit_not(vacant),
    b.bit_not(issued.value()),
  ])
  let expected_last = b.bit_or(
    b.bit_not(line_owned.value()),
    b.equal(
      beat.value(),
      b.mux(burst_owned.value(), n(b, 5, 31UL), n(b, 5, 3UL)),
    ),
  )
  let bad_last = both(b, [
    response,
    issued.value(),
    b.bit_xor(response_last, expected_last),
  ])
  let terminated = b.bit_or(
    both(b, [response, b.bit_or(response_last, bad_last)]),
    aborted,
  )
  let s = worker_state(b, d, reset)
  let idle = any(b, [eq(b, s.state.value(), 0UL), eq(b, s.state.value(), 16UL)])
  let base_regs = Array::makei(4, _ => {
    b.register_state_in(d, @wire.uint(28), reset~)
  })
  let count = b.register_state_in(d, @wire.uint(7), reset~)
  let bases = base_regs.map(r => r.value())
  let portal_write = eq(b, b.slice(a.address, 31, 28), 1UL)
  let portal_read = eq(b, b.slice(a.ar_address, 31, 28), 1UL)
  let write_shape = eq(b, a.strobe, 15UL)
  let write_aligned = eq(b, b.slice(a.address, 1, 0), 0UL)
  let read_aligned = eq(b, b.slice(a.ar_address, 1, 0), 0UL)
  let configurable = both(b, [
    idle,
    vacant,
    b.bit_not(b.bit_and(a.read, portal_read)),
  ])
  let base_shape = both(b, [
    eq(b, b.slice(a.data, 31, 28), 0UL),
    eq(b, b.slice(a.data, 15, 0), 0UL),
  ])
  let count_shape = both(b, [
    b.greater_equal(a.data, n(b, 32, 1UL)),
    b.less_equal(a.data, n(b, 32, 64UL)),
  ])
  let valid_count = both(b, [
    b.greater_equal(count.value(), n(b, 7, 1UL)),
    b.less_equal(count.value(), n(b, 7, 64UL)),
  ])
  let distinct : Array[@wire.Signal] = [valid_count]
  for i in 0..<4 {
    for j in (i + 1)..<4 {
      distinct.push(b.bit_not(b.equal(bases[i], bases[j])))
    }
  }
  let valid_buffers = both(b, distinct)
  let start = both(b, [
    a.write,
    write_shape,
    eq(b, a.address, 16UL),
    eq(b, a.data, 1UL),
    configurable,
    healthy,
    valid_buffers,
  ])
  let writable : Array[@wire.Signal] = [start]
  for i, r in base_regs {
    let enable = both(b, [
      a.write,
      write_shape,
      configurable,
      eq(b, a.address, 20UL + i.to_uint64() * 4UL),
      base_shape,
    ])
    writable.push(enable)
    update(b, r, enable, b.truncate(a.data, 28))
  }
  let set_count = both(b, [
    a.write,
    write_shape,
    configurable,
    eq(b, a.address, 36UL),
    count_shape,
  ])
  writable.push(set_count)
  update(b, count, set_count, b.truncate(a.data, 7))
  let job_ready = both(b, [job_owner, b.bit_not(issued.value()), ready, healthy])
  let job = worker(
    b,
    d,
    reset,
    c,
    s,
    start,
    bases,
    count.value(),
    healthy,
    job_ready,
    both(b, [response, job_owner, issued.value()]),
    response_data,
    response_fault,
    response_last,
    b.bit_or(
      bad_last,
      both(b, [response, any(b, [vacant, b.bit_not(issued.value())])]),
    ),
    watchdog,
  )
  let portal_allowed = both(b, [job.idle, healthy])
  let write_allowed = both(b, [portal_allowed, write_shape, write_aligned])
  let read_allowed = b.bit_and(portal_allowed, read_aligned)
  let take_write = both(b, [a.write, portal_write, write_allowed, vacant])
  let take_read = both(b, [
    a.read,
    portal_read,
    read_allowed,
    vacant,
    b.bit_not(take_write),
  ])
  let take_job = both(b, [job.request_valid, vacant, healthy])
  let allocate = any(b, [take_job, take_write, take_read])
  let request_valid = both(b, [
    b.bit_not(vacant),
    b.bit_not(issued.value()),
    healthy,
    b.bit_not(eq(b, s.state.value(), 17UL)),
  ])
  let request_fire = b.bit_and(request_valid, ready)
  let request_line = job_owner
  let request_burst = b.bit_and(job_owner, job.request_burst)
  update(b, burst_owned, request_fire, request_burst)
  update(
    b,
    line_owned,
    request_fire,
    b.bit_and(request_line, b.bit_not(job.request_write)),
  )
  increment(
    b,
    beat,
    b.bit_or(allocate, terminated),
    b.bit_and(response, issued.value()),
    n(b, 5, 1UL),
  )
  let selected_owner = b.mux(
    take_job,
    n(b, 2, 3UL),
    b.mux(take_write, n(b, 2, 1UL), n(b, 2, 2UL)),
  )
  b.connect_next(
    owner,
    b.mux(
      terminated,
      n(b, 2, 0UL),
      b.mux(allocate, selected_owner, owner.value()),
    ),
  )
  b.connect_next(
    issued,
    b.mux(
      terminated,
      n(b, 1, 0UL),
      b.mux(request_fire, n(b, 1, 1UL), issued.value()),
    ),
  )
  out(b, "ddr_request_valid", request_valid)
  out(b, "ddr_request_line", request_line)
  out(b, "ddr_request_burst", request_burst)
  out(b, "ddr_request_write", b.mux(job_owner, job.request_write, write_owner))
  out(
    b,
    "ddr_request_address",
    b.mux(
      job_owner,
      job.request_address,
      b.truncate(b.mux(write_owner, a.address, a.ar_address), 28),
    ),
  )
  out(
    b,
    "ddr_request_data",
    b.mux(
      job_owner,
      job.request_data,
      b.mux(write_owner, a.data, n(b, 32, 0UL)),
    ),
  )
  out_static(b, "ddr_response_ready", 1, 1UL)
  for i, word in job.request_more {
    out(
      b,
      "ddr_request_data" + (i + 1).to_string(),
      b.mux(job_owner, word, n(b, 32, 0UL)),
    )
  }
  let portal_write_done = b.bit_and(terminated, write_owner)
  let portal_read_done = b.bit_and(terminated, read_owner)
  let write_reject = both(b, [
    a.write,
    portal_write,
    b.bit_not(write_allowed),
    b.bit_not(write_owner),
  ])
  let read_reject = both(b, [
    a.read,
    portal_read,
    b.bit_not(read_allowed),
    b.bit_not(read_owner),
  ])
  let control_write = b.bit_and(a.write, b.bit_not(portal_write))
  let control_read = b.bit_and(a.read, b.bit_not(portal_read))
  let flags = u(
    b,
    b.concat(
      b.concat(eq(b, s.state.value(), 17UL), eq(b, s.state.value(), 16UL)),
      b.concat(job.busy, healthy),
    ),
  )
  let registers : Array[(UInt64, @wire.Signal)] = [
    (0UL, n(b, 32, 0x50524433UL)),
    (4UL, n(b, 32, 0x10007UL)),
    (8UL, flags),
    (12UL, s.error.value()),
    (20UL, bases[0]),
    (24UL, bases[1]),
    (28UL, bases[2]),
    (32UL, bases[3]),
    (36UL, count.value()),
  ]
  for pair in job.registers {
    registers.push(pair)
  }
  let mut read_data = n(b, 32, 0UL)
  let mut known = n(b, 1, 0UL)
  for (address, value) in registers {
    let selected = eq(b, a.ar_address, address)
    let value = if value.signal_type().width().bits() < 32 {
      b.zero_extend(u(b, value), 32)
    } else {
      value
    }
    read_data = b.mux(selected, value, read_data)
    known = b.bit_or(known, selected)
  }
  let response_ok = both(b, [
    issued.value(),
    eq(b, response_fault, 0UL),
    b.bit_not(bad_last),
  ])
  axi_finish(
    b,
    a,
    any(b, [control_write, write_reject, portal_write_done]),
    any(b, [any(b, writable), b.bit_and(portal_write_done, response_ok)]),
    any(b, [control_read, read_reject, portal_read_done]),
    any(b, [
      b.bit_and(control_read, known),
      b.bit_and(portal_read_done, response_ok),
    ]),
    b.mux(portal_read_done, response_data, read_data),
  )
  let hw = b.finish()
  for
    (name, signal) in [
      ("state", s.state.value()),
      ("owner", owner.value()),
      ("start", start),
      ("count", count.value()),
      ("tile", s.tile.value()),
      ("fill", s.fill.value()),
      ("retired", s.retired.value()),
      ("completed", s.completed.value()),
      ("partials", s.partials.value()),
      ("reads", s.reads.value()),
      ("writes", s.writes.value()),
      ("prefetch", s.prefetch.value()),
      ("ahead", s.ahead.value()),
      ("prefetch_write", job.prefetch_write),
      ("ddr_issued", issued.value()),
      ("ddr_line", line_owned.value()),
      ("ddr_beat", beat.value()),
      ("ddr_bad_last", bad_last),
    ] {
    observations.push({ name, node: signal.id(), })
  }
  let port = hw.memories()[0].write_ports()[0]
  observations.push({ name: "stage_write", node: port.enable().unwrap(), })
  observations.push({ name: "stage_address", node: port.address(), })
  observations.push({ name: "stage_data", node: port.data(), })
  hw
}
