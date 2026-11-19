///|
priv struct InterleavedUnaryPorts {
  busy : @wire.Signal
  done : @wire.Signal
  errors : Array[@wire.Signal]
  results : Array[@wire.Signal]
}

///|
// Four independent contexts fill the three-edge arithmetic pipeline. Each
// context is revisited only after its previous result commits. Metadata is
// delayed with the data; there is no reassociation within an element.
fn interleaved_unary_logic(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  start : @wire.Signal,
  mode : @wire.Signal,
  values : Array[@wire.Signal],
  bounded~ : Bool = false,
  staged_add_inputs~ : Bool = false,
  deep_add~ : Bool = false,
  compact_pack~ : Bool = false,
  staged_product~ : Bool = false,
  registered_inputs~ : Bool = false,
) -> InterleavedUnaryPorts raise {
  assert_eq(values.length(), 4)
  assert_true(!deep_add || (bounded && staged_add_inputs))
  assert_true(!staged_product || deep_add)
  let busy = b.register_state_in(d, @wire.bits(1), reset~)
  let done = b.register_state_in(d, @wire.bits(1), reset~)
  let draining = b.register_state_in(d, @wire.bits(1), reset~)
  let index = b.register_state_in(d, @wire.uint(6), reset~)
  let lane = b.register_state_in(d, @wire.uint(2), reset~)
  let selected = b.register_state_in(d, @wire.uint(2), reset~)
  let regs = Array::makei(4, _ => {
    Array::makei(4, _ => b.register_state_in(d, @wire.uint(32), reset~))
  })
  let enabled = Array::makei(4, _ => {
    b.register_state_in(d, @wire.bits(1), reset~)
  })
  let errors = Array::makei(4, _ => {
    b.register_state_in(d, @wire.bits(1), reset~)
  })
  let requested = b.bit_and(start, b.bit_not(busy.value()))
  let active = b.bit_and(busy.value(), b.bit_not(draining.value()))
  // Five arithmetic edges plus the destination commit require six edges
  // between successive uses of one context. Four issues, then two bubbles.
  let cooldown = if deep_add {
    Some(b.register_state_in(d, @wire.uint(2), reset~))
  } else {
    None
  }
  let issue = match cooldown {
    Some(c) => b.bit_and(active, b.equal(c.value(), u(b, 2, 0UL)))
    None => active
  }
  let is_exp = b.equal(mode, u(b, 2, 3UL))
  let valid : Array[@wire.Signal] = []
  let clipped : Array[@wire.Signal] = []
  let active : Array[@wire.Signal] = []
  let seeds : Array[@wire.Signal] = []
  for value in values {
    let magnitude = field(b, value, 30, 0)
    let bounded = all(b, [
      b.greater_equal(magnitude, u(b, 31, 0x1f800000UL)),
      b.less_equal(magnitude, u(b, 31, 0x5f800000UL)),
    ])
    let v = all(b, [
      b.not_equal(mode, u(b, 2, 0UL)),
      b.mux(
        is_exp,
        b.less_equal(magnitude, u(b, 31, 0x7f800000UL)),
        b.bit_and(b.bit_not(bit(b, value, 31)), bounded),
      ),
    ])
    let clip = b.bit_and(
      is_exp,
      b.greater_than(magnitude, u(b, 31, 0x42000000UL)),
    )
    valid.push(v)
    clipped.push(clip)
    active.push(b.bit_and(v, b.bit_not(clip)))
    seeds.push(
      b.mux(
        is_exp,
        u(
          b,
          32,
          Float::from_double(1.0 / 40320.0).reinterpret_as_uint().to_uint64(),
        ),
        b.mux(
          b.equal(mode, u(b, 2, 1UL)),
          b.sub(u(b, 32, 0x7ef311c3UL), value),
          b.sub(
            u(b, 32, 0x5f375a86UL),
            b.logical_shift_right(value, u(b, 1, 1UL)),
          ),
        ),
      ),
    )
  }
  let operands = Array::makei(4, r => {
    let mut value = regs[0][r].value()
    for c in 1..<4 {
      value = b.mux(
        b.equal(lane.value(), u(b, 2, c.to_uint64())),
        regs[c][r].value(),
        value,
      )
    }
    value
  })
  let zero = u(b, 32, 0UL)
  let mut lhs = zero
  let mut rhs = zero
  let mut use_add = b.constant(@wire.bits(1), 0UL)
  let mut last = use_add
  let writes = Array::makei(4, _ => b.constant(@wire.bits(1), 0UL))
  for p, program in unary_programs() {
    for i, op in program {
      let (dst, operation, a, c, constant_a, constant_b, negate_b) = op
      let hit = all(b, [
        issue,
        b.equal(selected.value(), u(b, 2, (p + 1).to_uint64())),
        b.equal(index.value(), u(b, 6, i.to_uint64())),
      ])
      let x = if a < 0 { u(b, 32, constant_a.to_uint64()) } else { operands[a] }
      let y = if c < 0 { u(b, 32, constant_b.to_uint64()) } else { operands[c] }
      let y = if negate_b { b.bit_xor(y, u(b, 32, 0x80000000UL)) } else { y }
      lhs = b.bit_or(lhs, b.mux(hit, x, zero))
      rhs = b.bit_or(rhs, b.mux(hit, y, zero))
      writes[dst] = b.bit_or(writes[dst], hit)
      if operation == 1 {
        use_add = b.bit_or(use_add, hit)
      }
      if i == program.length() - 1 {
        last = b.bit_or(last, hit)
      }
    }
  }
  fn delay(x : @wire.Signal, count : Int32) -> @wire.Signal raise {
    let mut v = x
    for _ in 0..<count {
      v = b.register_in(d, v, reset~)
    }
    v
  }
  let product = fp32_multiply_pipeline3(
    b,
    d,
    reset,
    lhs,
    rhs,
    fast=true,
    compact_pack~,
    staged_product~,
    registered_inputs~,
  )
  let latency = if deep_add { 5 } else { 3 }
  let product = if deep_add {
    delay(
      product,
      if registered_inputs {
        0
      } else if staged_product {
        1
      } else {
        2
      },
    )
  } else {
    product
  }
  // The decoded micro-op and context select can arrive late. Keep three
  // edges to retirement, isolating this selection from the FP32 aligner.
  let (add_left, add_right, after_add) = if staged_add_inputs {
    (delay(lhs, 1), delay(rhs, 1), 1)
  } else {
    (lhs, rhs, 2)
  }
  let sum = delay(
    add(
      b,
      add_left,
      add_right,
      fast=true,
      bounded~,
      stage_aligned=deep_add,
      stage_normalized=deep_add,
      pipeline=Some((d, reset)),
    ),
    after_add,
  )
  let result = b.mux(delay(use_add, latency), sum, product)
  let destination_lane = delay(lane.value(), latency)
  let commits = writes.map(x => delay(x, latency))
  let last_lane = b.equal(lane.value(), u(b, 2, 3UL))
  if cooldown is Some(c) {
    b.connect_next(
      c,
      b.mux(
        b.bit_or(requested, b.bit_not(busy.value())),
        u(b, 2, 0UL),
        b.mux(
          b.bit_and(issue, last_lane),
          u(b, 2, 2UL),
          b.mux(
            b.not_equal(c.value(), u(b, 2, 0UL)),
            b.sub(c.value(), u(b, 2, 1UL)),
            c.value(),
          ),
        ),
      ),
    )
  }
  let final_issue = b.bit_and(last, last_lane)
  let finished = b.bit_and(busy.value(), delay(final_issue, latency))
  for c in 0..<4 {
    b.connect_next(enabled[c], b.mux(requested, active[c], enabled[c].value()))
    b.connect_next(
      errors[c],
      b.mux(requested, b.bit_not(valid[c]), errors[c].value()),
    )
    for r in 0..<4 {
      let initial = if r == 0 {
        values[c]
      } else if r == 1 {
        b.mux(
          clipped[c],
          b.mux(bit(b, values[c], 31), zero, u(b, 32, 0x7f800000UL)),
          b.mux(valid[c], seeds[c], u(b, 32, 0x7fc00000UL)),
        )
      } else {
        zero
      }
      let commit = all(b, [
        busy.value(),
        commits[r],
        enabled[c].value(),
        b.equal(destination_lane, u(b, 2, c.to_uint64())),
      ])
      b.connect_next(
        regs[c][r],
        b.mux(requested, initial, b.mux(commit, result, regs[c][r].value())),
      )
    }
  }
  b.connect_next(
    busy,
    b.mux(
      requested,
      either(b, active),
      b.mux(finished, b.constant(@wire.bits(1), 0UL), busy.value()),
    ),
  )
  b.connect_next(
    done,
    b.mux(
      requested,
      b.bit_not(either(b, active)),
      b.bit_or(done.value(), finished),
    ),
  )
  b.connect_next(selected, b.mux(requested, mode, selected.value()))
  b.connect_next(
    lane,
    b.mux(
      requested,
      u(b, 2, 0UL),
      b.mux(issue, b.add(lane.value(), u(b, 2, 1UL)), lane.value()),
    ),
  )
  b.connect_next(
    index,
    b.mux(
      requested,
      u(b, 6, 0UL),
      b.mux(
        b.bit_and(issue, last_lane),
        b.add(index.value(), u(b, 6, 1UL)),
        index.value(),
      ),
    ),
  )
  b.connect_next(
    draining,
    b.mux(
      requested,
      b.constant(@wire.bits(1), 0UL),
      b.bit_or(draining.value(), final_issue),
    ),
  )
  {
    busy: busy.value(),
    done: done.value(),
    errors: errors.map(e => e.value()),
    results: regs.map(r => r[1].value()),
  }
}

///|
/// Four independent ordered FP32 nonlinear contexts sharing one pipeline.
/// Mode 1 reciprocal, 2 rsqrt, 3 exponential; per-lane error/clipping matches
/// unary_operator. Start is ignored while busy and completion holds until start.
/// `deep_add` requires bounded/staged_add_inputs and increases same-context
/// issue spacing from four to six edges without changing arithmetic order.
/// Example: `let hardware = @qwen_layer.interleaved_unary_operator()`.
pub fn interleaved_unary_operator(
  bounded~ : Bool = false,
  staged_add_inputs~ : Bool = false,
  deep_add~ : Bool = false,
  compact_pack~ : Bool = false,
  staged_product~ : Bool = false,
  registered_inputs~ : Bool = false,
) -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("qwen_fp32_interleaved_unary")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  b.input_timing(rs, SampledIn(d.id()))
  let reset = b.synchronous_reset(rs, 0UL)
  let start = b.input("start", @wire.bits(1))
  let mode = b.input("mode", @wire.uint(2))
  let values = Array::makei(4, i => {
    b.input("value" + i.to_string(), @wire.uint(32))
  })
  for x in [start, mode, ..values] {
    b.input_timing(x, SampledIn(d.id()))
  }
  let p = interleaved_unary_logic(
    b,
    d,
    reset,
    start,
    mode,
    values,
    bounded~,
    staged_add_inputs~,
    deep_add~,
    compact_pack~,
    staged_product~,
    registered_inputs~,
  )
  let outputs = [("busy", p.busy), ("done", p.done)]
  for i in 0..<4 {
    outputs.push(("error" + i.to_string(), p.errors[i]))
    outputs.push(("result" + i.to_string(), p.results[i]))
  }
  for (name, value) in outputs {
    let out = b.output(name, value.signal_type())
    b.output_timing(out, ProducedIn(d.id()))
    b.connect(out, value)
  }
  b.finish()
}
