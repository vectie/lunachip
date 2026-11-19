///|
/// Eight independent BF16/FP32 dot lanes, with a three-stage multiplier and
/// four-stage accumulator. Each lane consumes one packed operand every four
/// cycles, in increasing address order. Valid length is 1..1024; latency is
/// 4*length+4 active cycles. Each load writes all eight 1024-word banks at one shared address, with independent BF16 weights and a shared BF16 activation.
/// Reset cancels the job and invalidates resident operands; reload before use.
///
/// ```mbt nocheck
/// let core = @floating_point.fast_banked_dot_product()
/// // Connect write_activation and write_weight_0..7 before each idle load edge.
/// ```
pub fn fast_banked_dot_product() -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("bf16_fp32_fast_banked_dot")
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
  let activation = input("write_activation", @wire.uint(16))
  let weights = Array::makei(8, i => {
    input("write_weight_" + i.to_string(), @wire.uint(16))
  })
  let start = input("start", @wire.bits(1))
  let length = input("length", @wire.uint(11))
  let busy = b.register_state_in(d, @wire.bits(1), reset~)
  let phase = b.register_state_in(d, @wire.uint(2), reset~)
  let read_count = b.register_state_in(d, @wire.uint(11), reset~)
  let issue_count = b.register_state_in(d, @wire.uint(11), reset~)
  let count = b.register_state_in(d, @wire.uint(11), reset~)
  let cycles = b.register_state_in(d, @wire.uint(32), reset~)
  let done = b.register_state_in(d, @wire.bits(1), reset~)
  let error = b.register_state_in(d, @wire.bits(1), reset~)
  let idle = b.bit_not(busy.value())
  let requested = b.bit_and(start, idle)
  let valid = b.bit_and(
    b.bit_and(
      b.greater_equal(length, u(b, 11, 1UL)),
      b.less_equal(length, u(b, 11, 1024UL)),
    ),
    b.bit_not(load),
  )
  let begin = b.bit_and(requested, valid)
  let phase0 = b.equal(phase.value(), u(b, 2, 0UL))
  let phase3 = b.equal(phase.value(), u(b, 2, 3UL))
  let read = b.bit_and(
    b.bit_and(busy.value(), phase0),
    b.less_than(read_count.value(), count.value()),
  )
  let issue = b.bit_and(
    b.bit_and(
      b.bit_and(busy.value(), phase0),
      b.not_equal(read_count.value(), u(b, 11, 0UL)),
    ),
    b.less_than(issue_count.value(), count.value()),
  )
  let first = b.equal(issue_count.value(), u(b, 11, 0UL))
  let last = b.equal(b.add(issue_count.value(), u(b, 11, 1UL)), count.value())
  let mut commit = issue
  let mut finish = b.bit_and(issue, last)
  for _ in 0..<3 {
    commit = b.register_in(d, commit, reset~)
    finish = b.register_in(d, finish, reset~)
  }
  // Commit pulses are canceled by reset along with every pipeline register.
  for i in 0..<8 {
    let mem = b.synchronous_memory(
      "operands_" + i.to_string(),
      @wire.uint(32),
      1024,
      d,
      read_write_policy=ReadOld,
      multi_write_policy=Reject,
    )
    let enable = b.bit_and(
      b.bit_and(load, idle),
      b.bit_not(b.reset_asserted(rs)),
    )
    let data = b.reinterpret(b.concat(weights[i], activation), @wire.uint(32))
    b.memory_write(mem, "host", address, data, enable~)
    let word = b.memory_read(
      mem,
      "compute",
      b.truncate(read_count.value(), 10),
      enable=b.bit_and(read, b.bit_not(b.reset_asserted(rs))),
      enable_behavior=HoldLast,
    )
    let product = multiply_pipeline(
      b,
      d,
      reset,
      field(b, word, 15, 0),
      field(b, word, 31, 16),
    )
    let sum = b.register_state_in(d, @wire.uint(32), reset~)
    let next = fast_add_pipeline(
      b,
      d,
      reset,
      b.mux(first, u(b, 32, 0UL), sum.value()),
      product,
    )
    b.connect_next(
      sum,
      b.mux(begin, u(b, 32, 0UL), b.mux(commit, next, sum.value())),
    )
    let p = b.output("result_" + i.to_string(), @wire.uint(32))
    b.output_timing(p, ProducedIn(d.id()))
    b.connect(p, sum.value())
  }
  b.connect_next(
    busy,
    b.mux(
      begin,
      b.constant(@wire.bits(1), 1UL),
      b.mux(finish, b.constant(@wire.bits(1), 0UL), busy.value()),
    ),
  )
  b.connect_next(
    phase,
    b.mux(
      begin,
      u(b, 2, 0UL),
      b.mux(
        busy.value(),
        b.mux(phase3, u(b, 2, 0UL), b.add(phase.value(), u(b, 2, 1UL))),
        phase.value(),
      ),
    ),
  )
  b.connect_next(
    read_count,
    b.mux(
      begin,
      u(b, 11, 0UL),
      b.mux(read, b.add(read_count.value(), u(b, 11, 1UL)), read_count.value()),
    ),
  )
  b.connect_next(
    issue_count,
    b.mux(
      begin,
      u(b, 11, 0UL),
      b.mux(
        issue,
        b.add(issue_count.value(), u(b, 11, 1UL)),
        issue_count.value(),
      ),
    ),
  )
  b.connect_next(count, b.mux(begin, length, count.value()))
  b.connect_next(
    cycles,
    b.mux(
      begin,
      u(b, 32, 0UL),
      b.mux(busy.value(), b.add(cycles.value(), u(b, 32, 1UL)), cycles.value()),
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
  for
    (name, x) in [
      ("busy", busy.value()),
      ("done", done.value()),
      ("error", error.value()),
      ("cycles", cycles.value()),
    ] {
    let p = b.output(name, x.signal_type())
    b.output_timing(p, ProducedIn(d.id()))
    b.connect(p, x)
  }
  b.finish()
}
