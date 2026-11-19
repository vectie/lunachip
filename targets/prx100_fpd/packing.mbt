///|
// Independent cache write ports and explicit one-edge ReadOld/HoldLast reads.
// Address metadata is registered with each read, yielding consecutive core
// writes from two BF16 values in each cached word.
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
  let weights = b.synchronous_memory(
    "weight_cache",
    @wire.uint(32),
    4096,
    d,
    read_write_policy=ReadOld,
    multi_write_policy=Reject,
  )
  let activations = b.synchronous_memory(
    "activation_cache",
    @wire.uint(32),
    512,
    d,
    read_write_policy=ReadOld,
    multi_write_policy=Reject,
  )
  let write_index = u(b, b.concat(block, beat))
  b.memory_write(weights, "ddr", write_index, data, enable=weight_write)
  b.memory_write(
    activations,
    "ddr",
    b.truncate(write_index, 9),
    data,
    enable=activation_write,
  )
  let read = both(b, [
    eq(b, state, 5UL),
    b.less_than(index, n(b, 14, 8192UL)),
    safe,
    b.bit_not(b.reset_asserted(rs)),
  ])
  let address = b.register_in(d, b.truncate(index, 13), reset~)
  let valid = b.register_in(d, read, reset~)
  let weight = b.memory_read(
    weights,
    "pack",
    u(b, b.slice(index, 12, 1)),
    enable=read,
    enable_behavior=HoldLast,
  )
  let activation = b.memory_read(
    activations,
    "pack",
    u(b, b.slice(index, 9, 1)),
    enable=read,
    enable_behavior=HoldLast,
  )
  let high = eq(b, b.slice(address, 0, 0), 1UL)
  let w = b.mux(high, b.slice(weight, 31, 16), b.slice(weight, 15, 0))
  let a = b.mux(high, b.slice(activation, 31, 16), b.slice(activation, 15, 0))
  let load = b.bit_and(valid, safe)
  out(b, "load", load)
  out(b, "write_lane", u(b, b.slice(address, 12, 10)))
  out(b, "write_address", u(b, b.slice(address, 9, 0)))
  out(b, "write_data", b.mux(load, u(b, b.concat(w, a)), n(b, 32, 0UL)))
  load
}
