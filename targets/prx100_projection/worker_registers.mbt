///|
fn worker_registers(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  start : @wire.Signal,
  s : WorkerState,
  accepted : @wire.Signal,
  c : Map[String, @wire.Signal],
) -> Array[(UInt64, @wire.Signal)] raise {
  let registers : Array[(UInt64, @wire.Signal)] = [
    (40UL, s.tile.value()),
    (44UL, s.completed.value()),
    (48UL, s.retired.value()),
    (52UL, s.partials.value()),
    (96UL, s.staged.value()),
    (100UL, s.reads.value()),
    (104UL, s.writes.value()),
    (108UL, c["producer_count"]),
    (112UL, c["consumer_count"]),
    (116UL, s.state.value()),
    (120UL, n(b, 32, 50000000UL)),
    (124UL, n(b, 32, 16UL)),
  ]
  for
    (offset, r) in [
      (56UL, s.cycles),
      (64UL, s.ddr_wait),
      (72UL, s.core_wait),
      (80UL, s.staging_cycles),
      (88UL, s.compute),
    ] {
    registers.push((offset, u(b, b.slice(r.value(), 31, 0))))
    registers.push((offset + 4UL, u(b, b.slice(r.value(), 63, 32))))
  }
  for i, sum in s.sums {
    registers.push((128UL + i.to_uint64() * 4UL, sum.value()))
  }
  for pair in core_memory_statistics(b, d, reset, start, accepted, c) {
    registers.push(pair)
  }
  registers
}
