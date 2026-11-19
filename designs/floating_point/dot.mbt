///|
/// Experimental scalar BF16 dot product with sequential FP32 RNE accumulation.
/// Packed operand words: a in bits15:0, b in bits31:16. A start captures
/// length1..1024; writes and further starts are ignored while busy. Reset
/// cancels a job but does not initialize operand memory. Each job starts at+0.
pub fn dot_product() -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("bf16_fp32_dot")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  b.input_timing(rs, SampledIn(d.id()))
  let reset = b.synchronous_reset(rs, 0UL)
  fn input(name : String, t : @ir.SignalType) -> @wire.Signal raise {
    let x = b.input(name, t)
    b.input_timing(x, SampledIn(d.id()))
    x
  }
  let load = input("load", @wire.bits(1))
  let address = input("write_address", @wire.uint(10))
  let data = input("write_data", @wire.uint(32))
  let start = input("start", @wire.bits(1))
  let length = input("length", @wire.uint(11))
  let state = b.register_state_in(d, @wire.uint(3), reset~)
  let index = b.register_state_in(d, @wire.uint(10), reset~)
  let count = b.register_state_in(d, @wire.uint(11), reset~)
  let product = b.register_state_in(d, @wire.uint(32), reset~)
  let sum = b.register_state_in(d, @wire.uint(32), reset~)
  let cycles = b.register_state_in(d, @wire.uint(32), reset~)
  let done = b.register_state_in(d, @wire.bits(1), reset~)
  let error = b.register_state_in(d, @wire.bits(1), reset~)
  let idle = b.equal(state.value(), u(b, 3, 0UL))
  let active = b.bit_not(idle)
  let requested = b.bit_and(start, idle)
  let valid = b.bit_and(
    b.bit_and(
      b.greater_equal(length, u(b, 11, 1UL)),
      b.less_equal(length, u(b, 11, 1024UL)),
    ),
    b.bit_not(load),
  )
  let begin = b.bit_and(requested, valid)
  let read = b.equal(state.value(), u(b, 3, 1UL))
  let mult = b.equal(state.value(), u(b, 3, 2UL))
  let accumulate = b.equal(state.value(), u(b, 3, 3UL))
  let advance = b.equal(state.value(), u(b, 3, 4UL))
  let last = b.equal(
    b.add(b.zero_extend(index.value(), 11), u(b, 11, 1UL)),
    count.value(),
  )
  let finish = b.bit_and(advance, last)
  let mem = b.synchronous_memory(
    "operands",
    @wire.uint(32),
    1024,
    d,
    read_write_policy=ReadOld,
    multi_write_policy=Reject,
  )
  b.memory_write(
    mem,
    "host",
    address,
    data,
    enable=b.bit_and(b.bit_and(load, idle), b.bit_not(b.reset_asserted(rs))),
  )
  let word = b.memory_read(
    mem,
    "compute",
    index.value(),
    enable=b.bit_and(read, b.bit_not(b.reset_asserted(rs))),
    enable_behavior=HoldLast,
  )
  b.connect_next(
    product,
    b.mux(
      mult,
      multiply(b, field(b, word, 15, 0), field(b, word, 31, 16)),
      product.value(),
    ),
  )
  b.connect_next(
    sum,
    b.mux(
      begin,
      u(b, 32, 0UL),
      b.mux(accumulate, add(b, sum.value(), product.value()), sum.value()),
    ),
  )
  b.connect_next(
    index,
    b.mux(
      begin,
      u(b, 10, 0UL),
      b.mux(advance, b.add(index.value(), u(b, 10, 1UL)), index.value()),
    ),
  )
  b.connect_next(count, b.mux(begin, length, count.value()))
  b.connect_next(
    cycles,
    b.mux(
      begin,
      u(b, 32, 0UL),
      b.mux(active, b.add(cycles.value(), u(b, 32, 1UL)), cycles.value()),
    ),
  )
  b.connect_next(
    done,
    b.mux(
      requested,
      b.constant(@wire.bits(1), 0UL),
      b.bit_or(done.value(), finish),
    ),
  )
  b.connect_next(error, b.mux(requested, b.bit_not(valid), error.value()))
  b.connect_next(
    state,
    b.mux(
      begin,
      u(b, 3, 1UL),
      b.mux(
        finish,
        u(b, 3, 0UL),
        b.mux(
          advance,
          u(b, 3, 1UL),
          b.mux(active, b.add(state.value(), u(b, 3, 1UL)), state.value()),
        ),
      ),
    ),
  )
  for
    (name, x) in [
      ("busy", active),
      ("done", done.value()),
      ("error", error.value()),
      ("result", sum.value()),
      ("cycles", cycles.value()),
    ] {
    let p = b.output(name, x.signal_type())
    b.output_timing(p, ProducedIn(d.id()))
    b.connect(p, x)
  }
  b.finish()
}
