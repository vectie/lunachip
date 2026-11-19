///|
/// FPDDR1.3 controller. Diagnostic observe_* outputs expose the exact state
/// used by native/RTL/formal gates; the physical wrapper keeps them internal.
pub fn controller(watchdog~ : UInt64 = 50000000UL) -> @ir.Module raise {
  guard watchdog > 0UL && watchdog <= 50000000UL else {
    fail("invalid watchdog")
  }
  let b = @wire.ModuleBuilder::new("Prx100FpOverlapDdrControl")
  b.parameter("job_watchdog_cycles", Signed(watchdog.reinterpret_as_int64()))
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  b.input_timing(rs, SampledIn(d.id()))
  let reset = b.synchronous_reset(rs, 0UL)
  let a = axi_begin(b, d, reset)
  let healthy = input(b, d, "memory_healthy", 1)
  let ready = input(b, d, "ddr_request_ready", 1)
  let response = input(b, d, "ddr_response_valid", 1)
  let response_data = input(b, d, "ddr_response_data", 32)
  let response_fault = input(b, d, "ddr_response_fault", 2)
  let response_last = input(b, d, "ddr_response_last", 1)
  let c : Map[String, @wire.Signal] = Map([])
  for p in @fp.buffered_dot_product().outputs() {
    let x = b.input("c_" + p.name(), p.signal_type())
    b.input_timing(x, SampledIn(d.id()))
    c[p.name()] = x
  }
  let owner = b.register_state_in(d, @wire.uint(2), reset~)
  let issued = b.register_state_in(d, @wire.bits(1), reset~)
  let line_owned = b.register_state_in(d, @wire.bits(1), reset~)
  let burst_owned = b.register_state_in(d, @wire.bits(1), reset~)
  let beat = b.register_state_in(d, @wire.uint(5), reset~)
  let poisoned = b.register_state_in(d, @wire.bits(1), reset~)
  let vacant = eq(b, owner.value(), 0UL)
  let write_owner = eq(b, owner.value(), 1UL)
  let read_owner = eq(b, owner.value(), 2UL)
  let job_owner = eq(b, owner.value(), 3UL)
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
  let unowned = both(b, [response, any(b, [vacant, b.bit_not(issued.value())])])
  let protocol = any(b, [poisoned.value(), bad_last, unowned])
  update(b, poisoned, b.bit_or(bad_last, unowned), n(b, 1, 1UL))
  let aborted = both(b, [
    b.bit_not(healthy),
    b.bit_not(vacant),
    b.bit_not(issued.value()),
  ])
  // A malformed last marker never releases ownership early; drain the number
  // of beats captured at acceptance, or require physical-reset recovery.
  let terminated = b.bit_or(
    both(b, [response, issued.value(), expected_last]),
    aborted,
  )
  let base_regs = Array::makei(3, _ => {
    b.register_state_in(d, @wire.uint(28), reset~)
  })
  let length = b.register_state_in(d, @wire.uint(11), reset~)
  let jobs = b.register_state_in(d, @wire.uint(6), reset~)
  let vectors = b.register_state_in(d, @wire.uint(2), reset~)
  let bases = base_regs.map(r => r.value())
  // Idle is inferred from the retained public diagnostic state through an
  // explicit register proxy, avoiding a combinational dependence on START.
  let running = b.register_state_in(d, @wire.bits(1), reset~)
  let terminal_fault = b.register_state_in(d, @wire.bits(1), reset~)
  let idle = both(b, [
    b.bit_not(running.value()),
    b.bit_not(terminal_fault.value()),
    b.bit_not(c["busy"]),
    b.bit_not(protocol),
  ])
  let portal_write = eq(b, b.slice(a.address, 31, 28), 1UL)
  let portal_read = eq(b, b.slice(a.ar_address, 31, 28), 1UL)
  let shape = eq(b, a.strobe, 15UL)
  let aligned = eq(b, b.slice(a.address, 1, 0), 0UL)
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
  let valid : Array[@wire.Signal] = [
    b.greater_equal(length.value(), n(b, 11, 1UL)),
    b.less_equal(length.value(), n(b, 11, 1024UL)),
    b.greater_equal(jobs.value(), n(b, 6, 1UL)),
    b.less_equal(jobs.value(), n(b, 6, 48UL)),
    b.greater_equal(vectors.value(), n(b, 2, 1UL)),
    b.less_equal(b.zero_extend(vectors.value(), 6), jobs.value()),
  ]
  for i in 0..<3 {
    for j in (i + 1)..<3 {
      valid.push(b.not_equal(bases[i], bases[j]))
    }
  }
  let start = both(b, [
    a.write,
    shape,
    configurable,
    healthy,
    eq(b, a.address, 16UL),
    eq(b, a.data, 1UL),
    both(b, valid),
  ])
  let invalidate_command = both(b, [
    a.write,
    shape,
    configurable,
    eq(b, a.address, 16UL),
    eq(b, a.data, 2UL),
  ])
  let writable : Array[@wire.Signal] = [start, invalidate_command]
  let base_writes : Array[@wire.Signal] = []
  for i, r in base_regs {
    let enable = both(b, [
      a.write,
      shape,
      configurable,
      eq(b, a.address, 20UL + i.to_uint64() * 4UL),
      base_shape,
    ])
    update(b, r, enable, b.truncate(a.data, 28))
    base_writes.push(enable)
    writable.push(enable)
  }
  for
    (r, address, maximum, width) in [
      (length, 32UL, 1024UL, 11),
      (jobs, 36UL, 48UL, 6),
      (vectors, 40UL, 3UL, 2),
    ] {
    let enable = both(b, [
      a.write,
      shape,
      configurable,
      eq(b, a.address, address),
      b.greater_equal(a.data, n(b, 32, 1UL)),
      b.less_equal(a.data, n(b, 32, maximum)),
    ])
    update(b, r, enable, b.truncate(a.data, width))
    writable.push(enable)
  }
  let portal_allowed = both(b, [idle, healthy])
  let write_allowed = both(b, [portal_allowed, shape, aligned])
  let read_allowed = b.bit_and(portal_allowed, read_aligned)
  let take_write = both(b, [a.write, portal_write, write_allowed, vacant])
  let take_read = both(b, [
    a.read,
    portal_read,
    read_allowed,
    vacant,
    b.bit_not(take_write),
  ])
  let job = worker(
    b,
    d,
    reset,
    rs,
    c,
    bases,
    length.value(),
    jobs.value(),
    vectors.value(),
    start,
    any(b, [invalidate_command, base_writes[0], take_write]),
    healthy,
    protocol,
    both(b, [vacant, healthy]),
    both(b, [response, job_owner, issued.value()]),
    response_data,
    response_fault,
    response_last,
    watchdog,
  )
  b.connect_next(
    running,
    b.mux(
      start,
      n(b, 1, 1UL),
      b.mux(b.bit_or(job.done, job.fault), n(b, 1, 0UL), running.value()),
    ),
  )
  update(b, terminal_fault, job.fault, n(b, 1, 1UL))
  let take_job = both(b, [job.request_valid, vacant, healthy])
  let job_write = b.register_state_in(d, @wire.bits(1), reset~)
  let job_burst = b.register_state_in(d, @wire.bits(1), reset~)
  let job_address = b.register_state_in(d, @wire.uint(28), reset~)
  let job_data = Array::makei(4, _ => {
    b.register_state_in(d, @wire.uint(32), reset~)
  })
  update(b, job_write, take_job, job.request_write)
  update(b, job_burst, take_job, job.request_burst)
  update(b, job_address, take_job, job.request_address)
  for i, r in job_data {
    update(b, r, take_job, job.request_data[i])
  }
  let allocate = any(b, [take_job, take_write, take_read])
  let request_valid = both(b, [
    b.bit_not(vacant),
    b.bit_not(issued.value()),
    healthy,
    b.bit_not(job.fault),
    b.bit_not(protocol),
  ])
  let fire = b.bit_and(request_valid, ready)
  let is_line = job_owner
  let is_burst = b.bit_and(job_owner, job_burst.value())
  b.connect_next(
    owner,
    b.mux(
      terminated,
      n(b, 2, 0UL),
      b.mux(
        allocate,
        b.mux(
          take_job,
          n(b, 2, 3UL),
          b.mux(take_write, n(b, 2, 1UL), n(b, 2, 2UL)),
        ),
        owner.value(),
      ),
    ),
  )
  b.connect_next(
    issued,
    b.mux(terminated, n(b, 1, 0UL), b.mux(fire, n(b, 1, 1UL), issued.value())),
  )
  update(b, line_owned, fire, b.bit_and(is_line, b.bit_not(job_write.value())))
  update(b, burst_owned, fire, is_burst)
  b.connect_next(
    beat,
    b.mux(
      b.bit_or(allocate, terminated),
      n(b, 5, 0UL),
      b.mux(
        b.bit_and(response, issued.value()),
        b.add(beat.value(), n(b, 5, 1UL)),
        beat.value(),
      ),
    ),
  )
  out(b, "ddr_request_valid", request_valid)
  out(b, "ddr_request_line", is_line)
  out(b, "ddr_request_burst", is_burst)
  out(b, "ddr_request_write", b.mux(job_owner, job_write.value(), write_owner))
  out(
    b,
    "ddr_request_address",
    b.mux(
      job_owner,
      job_address.value(),
      b.truncate(b.mux(write_owner, a.address, a.ar_address), 28),
    ),
  )
  for i in 0..<4 {
    out(
      b,
      if i == 0 {
        "ddr_request_data"
      } else {
        "ddr_request_data" + i.to_string()
      },
      b.mux(
        job_owner,
        job_data[i].value(),
        if i == 0 {
          b.mux(write_owner, a.data, n(b, 32, 0UL))
        } else {
          n(b, 32, 0UL)
        },
      ),
    )
  }
  out_static(b, "ddr_response_ready", 1, 1UL)
  let write_done = b.bit_and(terminated, write_owner)
  let read_done = b.bit_and(terminated, read_owner)
  let response_ok = both(b, [
    issued.value(),
    eq(b, response_fault, 0UL),
    b.bit_not(protocol),
  ])
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
    b.concat(b.concat(job.fault, job.done), b.concat(job.busy, healthy)),
  )
  let registers = [
    (0UL, n(b, 32, 0x46504433UL)),
    (4UL, n(b, 32, 0x10003UL)),
    (8UL, flags),
    (12UL, job.error),
    (20UL, bases[0]),
    (24UL, bases[1]),
    (28UL, bases[2]),
    (32UL, length.value()),
    (36UL, jobs.value()),
    (40UL, vectors.value()),
  ]
  for pair in job.registers {
    registers.push(pair)
  }
  let mut data = n(b, 32, 0UL)
  let mut known = n(b, 1, 0UL)
  for (address, value) in registers {
    let selected = eq(b, a.ar_address, address)
    let value = u(b, value)
    data = b.mux(
      selected,
      if value.signal_type().width().bits() < 32 {
        b.zero_extend(value, 32)
      } else {
        value
      },
      data,
    )
    known = b.bit_or(known, selected)
  }
  axi_finish(
    b,
    a,
    any(b, [control_write, write_reject, write_done]),
    any(b, [any(b, writable), b.bit_and(write_done, response_ok)]),
    any(b, [control_read, read_reject, read_done]),
    b.bit_or(b.bit_and(control_read, known), b.bit_and(read_done, response_ok)),
    b.mux(read_done, response_data, data),
  )
  for
    (name, x) in [
      ("owner", owner.value()),
      ("issued", issued.value()),
      ("beat", beat.value()),
      ("protocol", protocol),
    ] {
    out(b, "observe_" + name, x)
  }
  b.finish()
}
