///|
// Eight independent synchronous weight banks feed eight core operand banks
// together. DDR remains channel-major, with two BF16 weights per cache word.
fn pack_operands(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  rs : @wire.Signal,
  state : @wire.Signal,
  index : @wire.Signal,
  block : @wire.Signal,
  beat : @wire.Signal,
  weight_write : @wire.Signal,
  activation_write : @wire.Signal,
  data : @wire.Signal,
  safe : @wire.Signal,
) -> @wire.Signal raise {
  let read = both(b, [
    eq(b, state, 5UL),
    b.less_than(index, n(b, 11, 1024UL)),
    safe,
    b.bit_not(b.reset_asserted(rs)),
  ])
  let address = b.register_in(d, b.truncate(index, 10), reset~)
  let valid = b.register_in(d, read, reset~)
  let load = b.bit_and(valid, safe)
  let high = eq(b, b.slice(address, 0, 0), 1UL)
  let read_index = u(b, b.slice(index, 9, 1))
  let write_index = u(b, b.concat(b.slice(block, 3, 0), beat))
  for lane in 0..<8 {
    let weights = b.synchronous_memory(
      "weight_cache_" + lane.to_string(),
      @wire.uint(32),
      512,
      d,
      read_write_policy=ReadOld,
      multi_write_policy=Reject,
    )
    b.memory_write(
      weights,
      "ddr",
      write_index,
      data,
      enable=b.bit_and(
        weight_write,
        eq(b, b.slice(block, 6, 4), lane.to_uint64()),
      ),
    )
    let packed = b.memory_read(
      weights,
      "pack",
      read_index,
      enable=read,
      enable_behavior=HoldLast,
    )
    let weight = u(
      b,
      b.mux(high, b.slice(packed, 31, 16), b.slice(packed, 15, 0)),
    )
    out(
      b,
      "write_weight_" + lane.to_string(),
      b.mux(load, weight, n(b, 16, 0UL)),
    )
  }
  let activations = b.synchronous_memory(
    "activation_cache",
    @wire.uint(32),
    512,
    d,
    read_write_policy=ReadOld,
    multi_write_policy=Reject,
  )
  b.memory_write(activations, "ddr", write_index, data, enable=activation_write)
  let packed = b.memory_read(
    activations,
    "pack",
    read_index,
    enable=read,
    enable_behavior=HoldLast,
  )
  let activation = u(
    b,
    b.mux(high, b.slice(packed, 31, 16), b.slice(packed, 15, 0)),
  )
  out(b, "write_activation", b.mux(load, activation, n(b, 16, 0UL)))
  out(b, "write_address", address)
  out(b, "load", load)
  load
}
