///|
priv struct Machine {
  b : @wire.ModuleBuilder
  d : @wire.ClockDomain
  reset : @wire.SynchronousReset
  rs : @wire.Signal
  regs : Map[String, @wire.RegisterHandle]
  next : Map[String, @wire.Signal]
  order : Array[String]
  row_lanes : Int32
  lane_width : Int32
  fast_arithmetic : Bool
  short_unary : Bool
  bf16_weights : Bool
  packed_weights : Bool
  feedback : Bool
  delivery : Bool
  wide512 : Bool
  banked64 : Bool
  prefetch256 : Bool
  interleaved : Bool
  stream_unary : Bool
  staged_decode : Bool
  stream_reductions : Bool
  paired_rows : Bool
  full_rows : Bool
  dual_read : Bool
  indirect_bf16 : Bool
  bounded_add : Bool
  deep_batch : Bool
  strided_rows : Bool
  group64_rows : Bool
  stripe512 : Bool
  prefetch_row_blocks : Bool
  staged_unary_inputs : Bool
  staged_reduction_term : Bool
  staged_scalar_add : Bool
  staged_scalar_alignment : Bool
  deep_fp32_add : Bool
  compact_multiply_pack : Bool
  staged_multiply_product : Bool
  incremental_row_address : Bool
  registered_multiply_inputs : Bool
  eager_weight_reads : Bool
  ordered_array : Bool
  pipelined_vectors : Bool
  memory : MemoryAperture
}

///|
fn Machine::reg(
  m : Machine,
  name : String,
  width : Int32,
) -> @wire.Signal raise {
  guard !m.regs.contains(name) else { fail("duplicate machine register") }
  let r = m.b.register_state_in(
    m.d,
    if width == 1 {
      @wire.bits(1)
    } else {
      @wire.uint(width)
    },
    reset=m.reset,
  )
  m.regs[name] = r
  m.next[name] = r.value()
  m.order.push(name)
  r.value()
}

///|
fn Machine::v(m : Machine, name : String) -> @wire.Signal {
  m.regs[name].value()
}

///|
// Explicit priority: later guarded assignments override earlier assignments.
// Every IR register receives exactly one driver in commit().
fn Machine::put(
  m : Machine,
  name : String,
  when : @wire.Signal,
  value : @wire.Signal,
) -> Unit raise {
  m.next[name] = m.b.mux(when, value, m.next[name])
}

///|
fn Machine::set(
  m : Machine,
  name : String,
  when : @wire.Signal,
  value : UInt64,
) -> Unit raise {
  m.put(name, when, m.b.constant(m.v(name).signal_type(), value))
}

///|
fn Machine::is_state(m : Machine, state : UInt64) -> @wire.Signal raise {
  m.b.equal(m.v("state"), u(m.b, 5, state))
}

///|
fn Machine::is_op(m : Machine, op : UInt64) -> @wire.Signal raise {
  if m.staged_decode && op >= 1UL && op <= 15UL {
    m.v("opcode_" + op.to_string())
  } else {
    m.b.equal(m.v("op"), u(m.b, 32, op))
  }
}

///|
fn Machine::jump(
  m : Machine,
  when : @wire.Signal,
  state : UInt64,
) -> Unit raise {
  m.set("state", when, state)
}

///|
fn Machine::commit(m : Machine) -> Unit raise {
  for name in m.order {
    m.b.connect_next(m.regs[name], m.next[name])
  }
}

///|
fn all(
  b : @wire.ModuleBuilder,
  values : ArrayView[@wire.Signal],
) -> @wire.Signal raise {
  let mut result = values[0]
  for x in values[1:] {
    result = b.bit_and(result, x)
  }
  result
}

///|
fn either(
  b : @wire.ModuleBuilder,
  values : ArrayView[@wire.Signal],
) -> @wire.Signal raise {
  let mut result = values[0]
  for x in values[1:] {
    result = b.bit_or(result, x)
  }
  result
}

///|
fn increment(
  m : Machine,
  name : String,
  when : @wire.Signal,
  amount : UInt64,
) -> Unit raise {
  m.put(
    name,
    when,
    m.b.add(m.v(name), m.b.constant(m.v(name).signal_type(), amount)),
  )
}

///|
fn fp_less(
  b : @wire.ModuleBuilder,
  a : @wire.Signal,
  c : @wire.Signal,
) -> @wire.Signal raise {
  let signs = b.bit_xor(bit(b, a, 31), bit(b, c, 31))
  let magnitude_less = b.less_than(field(b, a, 30, 0), field(b, c, 30, 0))
  let magnitude_greater = b.greater_than(field(b, a, 30, 0), field(b, c, 30, 0))
  let zeros = b.bit_and(
    b.equal(field(b, a, 30, 0), u(b, 31, 0UL)),
    b.equal(field(b, c, 30, 0), u(b, 31, 0UL)),
  )
  b.bit_and(
    b.bit_not(zeros),
    b.mux(
      signs,
      bit(b, a, 31),
      b.mux(bit(b, a, 31), magnitude_greater, magnitude_less),
    ),
  )
}
