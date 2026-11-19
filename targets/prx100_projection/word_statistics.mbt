///|
// Counts actual tagged staging handshakes, independently of DDR transfers.
// START clears each counter. UInt32 cannot overflow within the bounded job.
fn core_memory_statistics(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  start : @wire.Signal,
  accepted : @wire.Signal,
  c : Map[String, @wire.Signal],
) -> Array[(UInt64, @wire.Signal)] raise {
  let read = b.bit_and(accepted, b.bit_not(c["memory_request_write"]))
  let enables = [
    read,
    b.bit_and(accepted, c["memory_request_write"]),
    b.bit_and(read, eq(b, c["memory_request_bytes"], 1UL)),
    b.bit_and(read, eq(b, c["memory_request_bytes"], 4UL)),
  ]
  Array::makei(4, i => {
    let counter = b.register_state_in(d, @wire.uint(32), reset~)
    increment(b, counter, start, enables[i], n(b, 32, 1UL))
    (160UL + i.to_uint64() * 4UL, counter.value())
  })
}
