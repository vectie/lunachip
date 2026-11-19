///|
/// Passive UI-domain read-channel observer. No output controls the observed bus.
/// Scope crosses through an explicit three-stage single-bit synchronizer.
/// Counters wrap modulo 2^32; outstanding reads continue outside scope.
pub fn mig_monitor() -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("Pblaze3MigMonitor")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  b.input_timing(rs, SampledIn(d.id()))
  let reset = b.synchronous_reset(rs, 0UL)
  let source = b.input("weight_scope", @wire.bits(1))
  b.input_timing(source, Asynchronous)
  let scope = b.bit_synchronizer("weight_scope", source, d, 3, reset~)
  let a = axi_begin(b, d, reset)
  let regs = [
    (0UL, n(b, 32, 0x4d494731UL)),
    (4UL, n(b, 32, 200000000UL)),
    (8UL, b.zero_extend(u(b, scope), 32)),
    (12UL, n(b, 32, 1UL)),
    (16UL, a.address),
    (20UL, a.data),
    (24UL, b.zero_extend(a.strobe, 32)),
  ]
  for i, prefix in ["mig", "narrow", "wide"] {
    let counters = monitor_channel(b, d, reset, prefix, scope)
    for k, value in counters {
      regs.push((0x100UL * (i + 1).to_uint64() + 4UL * k.to_uint64(), value))
    }
  }
  // The peripheral occupies a 64 KiB aperture; only the documented words read.
  let address = b.zero_extend(u(b, b.slice(a.ar_address, 15, 0)), 32)
  let mut data = n(b, 32, 0UL)
  let mut valid = n(b, 1, 0UL)
  for (offset, value) in regs {
    let select = eq(b, address, offset)
    data = b.mux(select, value, data)
    valid = b.bit_or(valid, select)
  }
  axi_finish(b, a, a.write, n(b, 1, 0UL), a.read, valid, data)
  b.finish()
}

///|
fn monitor_channel(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  prefix : String,
  scope : @wire.Signal,
) -> Array[@wire.Signal] raise {
  fn pin(name : String) -> @wire.Signal raise {
    b.register_in(d, input(b, d, prefix + "_" + name, 1), reset~)
  }
  let av = pin("arvalid")
  let ar = pin("arready")
  let aid = pin("arselect")
  let rv = pin("rvalid")
  let rr = pin("rready")
  let rid = pin("rselect")
  let last = pin("rlast")
  let take_ar = both(b, [av, ar, aid])
  let offered_r = b.bit_and(rv, rid)
  let take_r = b.bit_and(offered_r, rr)
  let take_last = b.bit_and(take_r, last)
  let rstall = b.bit_and(offered_r, b.bit_not(rr))
  let astall = both(b, [av, aid, b.bit_not(ar)])
  let pending = b.register_state_in(d, @wire.uint(9), reset~)
  let delta = b.bit_xor(take_ar, take_last)
  let next = b.mux(
    take_ar,
    b.add(pending.value(), n(b, 9, 1UL)),
    b.sub(pending.value(), n(b, 9, 1UL)),
  )
  update(b, pending, delta, next)
  let peak = b.register_state_in(d, @wire.uint(9), reset~)
  update(b, peak, b.less_than(peak.value(), pending.value()), pending.value())
  let empty = eq(b, pending.value(), 0UL)
  let error = b.register_state_in(d, @wire.bits(1), reset~)
  b.connect_next(
    error,
    any(b, [
      error.value(),
      both(b, [take_last, empty, b.bit_not(take_ar)]),
      both(b, [take_ar, eq(b, pending.value(), 511UL), b.bit_not(take_last)]),
    ]),
  )
  fn count(enable : @wire.Signal) -> @wire.Signal raise {
    let r = b.register_state_in(d, @wire.uint(32), reset~)
    update(b, r, enable, b.add(r.value(), n(b, 32, 1UL)))
    r.value()
  }
  let result = [
    count(take_ar),
    count(take_last),
    count(take_r),
    count(rstall),
    count(astall),
    b.zero_extend(pending.value(), 32),
    b.zero_extend(peak.value(), 32),
    b.zero_extend(u(b, error.value()), 32),
  ]
  let absent = b.bit_not(rv)
  let conditions = [
    n(b, 1, 1UL),
    take_ar,
    take_last,
    take_r,
    rstall,
    b.bit_and(absent, b.bit_not(empty)),
    b.bit_and(absent, empty),
    b.bit_and(rv, b.bit_not(rid)),
    astall,
    both(b, [empty, b.bit_not(av)]),
    eq(b, pending.value(), 1UL),
    both(b, [
      b.less_than(n(b, 9, 1UL), pending.value()),
      b.less_than(pending.value(), n(b, 9, 5UL)),
    ]),
    both(b, [
      b.less_than(n(b, 9, 4UL), pending.value()),
      b.less_than(pending.value(), n(b, 9, 9UL)),
    ]),
    both(b, [
      b.less_than(n(b, 9, 8UL), pending.value()),
      b.less_than(pending.value(), n(b, 9, 17UL)),
    ]),
    b.less_than(n(b, 9, 16UL), pending.value()),
  ]
  for condition in conditions {
    result.push(count(b.bit_and(scope, condition)))
  }
  result
}
