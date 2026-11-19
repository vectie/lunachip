///|
priv struct UnaryPorts {
  busy : @wire.Signal
  done : @wire.Signal
  error : @wire.Signal
  result : @wire.Signal
}

///|
// A micro-operation names destination, operation (0 multiply,1 add), and
// operands. Nonnegative operands select registers; negative operands encode
// constants supplied in the last two tuple elements. Negation is an explicit
// sign-bit toggle, preserving floating-point magnitudes.
fn unary_logic(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  start : @wire.Signal,
  mode : @wire.Signal,
  value : @wire.Signal,
  fast~ : Bool = false,
  short~ : Bool = false,
) -> UnaryPorts raise {
  assert_true(!short || fast)
  let busy = b.register_state_in(d, @wire.bits(1), reset~)
  let done = b.register_state_in(d, @wire.bits(1), reset~)
  let error = b.register_state_in(d, @wire.bits(1), reset~)
  let index = b.register_state_in(d, @wire.uint(6), reset~)
  let selected = b.register_state_in(d, @wire.uint(2), reset~)
  let regs = Array::makei(4, _ => b.register_state_in(d, @wire.uint(32), reset~))
  let phase = if fast {
    Some(b.register_state_in(d, @wire.uint(3), reset~))
  } else {
    None
  }
  let short_add = if short {
    Some(b.register_state_in(d, @wire.bits(1), reset~))
  } else {
    None
  }
  let issue = match phase {
    Some(p) => b.bit_and(busy.value(), b.equal(p.value(), u(b, 3, 0UL)))
    None => busy.value()
  }
  let advance = match phase {
    Some(p) =>
      b.bit_and(
        busy.value(),
        b.equal(
          p.value(),
          if short_add is Some(a) {
            b.mux(a.value(), u(b, 3, 1UL), u(b, 3, 3UL))
          } else {
            u(b, 3, 4UL)
          },
        ),
      )
    None => busy.value()
  }
  let requested = b.bit_and(start, b.bit_not(busy.value()))
  let magnitude = field(b, value, 30, 0)
  let is_exp = b.equal(mode, u(b, 2, 3UL))
  let bounded = b.bit_and(
    b.greater_equal(magnitude, u(b, 31, 0x1f800000UL)),
    b.less_equal(magnitude, u(b, 31, 0x5f800000UL)),
  )
  let valid = b.bit_and(
    b.not_equal(mode, u(b, 2, 0UL)),
    b.mux(
      is_exp,
      b.less_equal(magnitude, u(b, 31, 0x7f800000UL)),
      b.bit_and(b.bit_not(bit(b, value, 31)), bounded),
    ),
  )
  let clipped = b.bit_and(
    is_exp,
    b.greater_than(magnitude, u(b, 31, 0x42000000UL)),
  )
  let begin = b.bit_and(requested, b.bit_and(valid, b.bit_not(clipped)))
  let programs = unary_programs()
  let mut lhs = u(b, 32, 0UL)
  let mut rhs = u(b, 32, 0UL)
  let zero_operand = lhs
  let mut use_add = b.constant(@wire.bits(1), 0UL)
  let mut last = use_add
  let writes : Array[@wire.Signal] = Array::makei(4, _ => {
    b.constant(@wire.bits(1), 0UL)
  })
  for p, program in programs {
    for i, op in program {
      let (dst, operation, a, c, constant_a, constant_b, negate_b) = op
      let active = b.bit_and(
        issue,
        b.bit_and(
          b.equal(selected.value(), u(b, 2, (p + 1).to_uint64())),
          b.equal(index.value(), u(b, 6, i.to_uint64())),
        ),
      )
      let x = if a < 0 {
        u(b, 32, constant_a.to_uint64())
      } else {
        regs[a].value()
      }
      let y = if c < 0 {
        u(b, 32, constant_b.to_uint64())
      } else {
        regs[c].value()
      }
      let y = if negate_b { b.bit_xor(y, u(b, 32, 0x80000000UL)) } else { y }
      lhs = if fast {
        b.bit_or(lhs, b.mux(active, x, zero_operand))
      } else {
        b.mux(active, x, lhs)
      }
      rhs = if fast {
        b.bit_or(rhs, b.mux(active, y, zero_operand))
      } else {
        b.mux(active, y, rhs)
      }
      writes[dst] = b.bit_or(writes[dst], active)
      if operation == 1 {
        use_add = b.bit_or(use_add, active)
      }
      if i == program.length() - 1 {
        last = b.bit_or(last, active)
      }
    }
  }
  if short_add is Some(a) {
    b.connect_next(a, b.mux(issue, use_add, a.value()))
  }
  let (result, writes, last) = if fast {
    unary_pipeline(
      b,
      d,
      reset,
      issue,
      advance,
      lhs,
      rhs,
      use_add,
      writes,
      last,
      short~,
    )
  } else {
    (b.mux(use_add, add(b, lhs, rhs), multiply(b, lhs, rhs)), writes, last)
  }
  if phase is Some(p) {
    b.connect_next(
      p,
      b.mux(
        b.bit_or(requested, b.bit_or(b.bit_not(busy.value()), advance)),
        u(b, 3, 0UL),
        b.add(p.value(), u(b, 3, 1UL)),
      ),
    )
  }
  let seed = b.mux(
    is_exp,
    u(
      b,
      32,
      Float::from_double(1.0 / 40320.0).reinterpret_as_uint().to_uint64(),
    ),
    b.mux(
      b.equal(mode, u(b, 2, 1UL)),
      b.sub(u(b, 32, 0x7ef311c3UL), value),
      b.sub(u(b, 32, 0x5f375a86UL), b.logical_shift_right(value, u(b, 1, 1UL))),
    ),
  )
  for i, r in regs {
    let initial = if i == 0 {
      value
    } else if i == 1 {
      seed
    } else {
      u(b, 32, 0UL)
    }
    let initial = if i == 1 {
      b.mux(
        clipped,
        b.mux(bit(b, value, 31), u(b, 32, 0UL), u(b, 32, 0x7f800000UL)),
        b.mux(valid, initial, u(b, 32, 0x7fc00000UL)),
      )
    } else {
      initial
    }
    b.connect_next(
      r,
      b.mux(requested, initial, b.mux(writes[i], result, r.value())),
    )
  }
  b.connect_next(selected, b.mux(begin, mode, selected.value()))
  b.connect_next(
    index,
    b.mux(
      begin,
      u(b, 6, 0UL),
      b.mux(advance, b.add(index.value(), u(b, 6, 1UL)), index.value()),
    ),
  )
  b.connect_next(
    busy,
    b.mux(
      requested,
      b.bit_and(valid, b.bit_not(clipped)),
      b.mux(last, b.constant(@wire.bits(1), 0UL), busy.value()),
    ),
  )
  b.connect_next(
    done,
    b.mux(
      requested,
      b.bit_or(b.bit_not(valid), clipped),
      b.bit_or(done.value(), last),
    ),
  )
  b.connect_next(error, b.mux(requested, b.bit_not(valid), error.value()))
  {
    busy: busy.value(),
    done: done.value(),
    error: error.value(),
    result: regs[1].value(),
  }
}

///|
/// Bounded FP32 reciprocal(1),rsqrt(2),exp(3) iterative unit. Reciprocal/rsqrt
/// inputs are positive in [2^-64,2^64]. Exp is approximated on [-32,32], with
/// zero/+infinity outside that interval. Invalid inputs complete with error.
pub fn unary_operator(
  fast~ : Bool = false,
  short~ : Bool = false,
) -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new(
    if short {
      "qwen_fp32_short_unary"
    } else if fast {
      "qwen_fp32_fast_unary"
    } else {
      "qwen_fp32_unary"
    },
  )
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  b.input_timing(rs, SampledIn(d.id()))
  let reset = b.synchronous_reset(rs, 0UL)
  let start = b.input("start", @wire.bits(1))
  let mode = b.input("mode", @wire.uint(2))
  let value = b.input("value", @wire.uint(32))
  for x in [start, mode, value] {
    b.input_timing(x, SampledIn(d.id()))
  }
  let p = unary_logic(b, d, reset, start, mode, value, fast~, short~)
  for
    (name, x) in [
      ("busy", p.busy),
      ("done", p.done),
      ("error", p.error),
      ("result", p.result),
    ] {
    let o = b.output(name, x.signal_type())
    b.output_timing(o, ProducedIn(d.id()))
    b.connect(o, x)
  }
  b.finish()
}
