///|
fn worker_counters(
  b : @wire.ModuleBuilder,
  start : @wire.Signal,
  s : WorkerState,
  states : Map[Int32, @wire.Signal],
  busy : @wire.Signal,
  descriptor_write : @wire.Signal,
  prefetch_active : @wire.Signal,
  completed : @wire.Signal,
  c : Map[String, @wire.Signal],
  filled_word : @wire.Signal,
  read_request : @wire.Signal,
  request_fire : @wire.Signal,
) -> Unit raise {
  increment(b, s.cycles, start, busy, n(b, 64, 1UL))
  increment(
    b,
    s.ddr_wait,
    start,
    any(b, [
      states[4],
      states[5],
      states[11],
      states[12],
      states[14],
      states[15],
      prefetch_active,
    ]),
    n(b, 64, 1UL),
  )
  increment(
    b,
    s.core_wait,
    start,
    any(b, [states[6], states[7], states[8]]),
    n(b, 64, 1UL),
  )
  increment(
    b,
    s.staging_cycles,
    start,
    any(b, [descriptor_write, states[4], states[5], prefetch_active]),
    n(b, 64, 1UL),
  )
  increment(
    b,
    s.compute,
    start,
    both(b, [completed, eq(b, s.ordinal.value(), 2UL)]),
    c["elapsed_cycles"],
  )
  increment(b, s.staged, start, filled_word, n(b, 32, 1UL))
  increment(
    b,
    s.reads,
    start,
    b.bit_and(read_request, request_fire),
    n(b, 32, 1UL),
  )
  increment(
    b,
    s.writes,
    start,
    both(b, [request_fire, b.bit_not(read_request)]),
    n(b, 32, 1UL),
  )
}
