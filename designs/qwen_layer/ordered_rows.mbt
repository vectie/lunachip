///|
fn ordered_input(
  m : Machine,
  name : String,
  width : Int32,
) -> @wire.Signal raise {
  let port = m.b.input(
    name,
    if width == 1 {
      @wire.bits(1)
    } else {
      @wire.uint(width)
    },
  )
  m.b.input_timing(port, SampledIn(m.d.id()))
  port
}

///|
// The issue port follows the synchronous activation and bank RAM reads by one
// core edge. Credit reserves space for that in-flight word in the clock bridge.
fn ordered_row_interface(
  m : Machine,
  weights : Array[@wire.Signal],
  activation : @wire.Signal,
  issue : @wire.Signal,
  last_column : @wire.Signal,
  last_row : @wire.Signal,
  long_stripe : @wire.Signal,
  stripe512 : @wire.Signal?,
  live : @wire.Signal,
  bad : @wire.Signal,
  healthy : @wire.Signal,
) -> (@wire.Signal, @wire.Signal) raise {
  let b = m.b
  fn output(name : String, value : @wire.Signal) -> Unit raise {
    let port = b.output(name, value.signal_type())
    b.output_timing(port, ProducedIn(m.d.id()))
    b.connect(port, value)
  }
  let slot = m.v("ordered_slot")
  let last_slot = field(b, last_row, 8, 6)
  // Distribute 1/2/4/8 row contexts evenly around the 18-edge feedback loop.
  let index = b.mux(
    bit(b, last_slot, 2),
    slot,
    b.mux(
      bit(b, last_slot, 1),
      b.shift_left(slot, u(b, 2, 1UL)),
      b.shift_left(slot, u(b, 2, 2UL)),
    ),
  )
  let phase = b.add(
    b.shift_left(b.zero_extend(index, 5), u(b, 1, 1UL)),
    b.zero_extend(b.reinterpret(bit(b, index, 2), @wire.uint(1)), 5),
  )
  let first = b.bit_and(
    b.equal(m.v("p_chunk"), u(b, 32, 0UL)),
    b.equal(m.v("p_index"), u(b, 10, 0UL)),
  )
  output("mac_issue", b.register_in(m.d, issue, reset=m.reset))
  for
    (name, value) in [
      ("mac_slot", slot),
      ("mac_phase", phase),
      ("mac_first", first),
      ("mac_last", last_column),
    ] {
    output(name, b.register_in(m.d, value))
  }
  output("mac_activation", activation)
  for i, weight in weights {
    output("mac_weight" + i.to_string(), weight)
  }
  output("mac_flush", either(b, [bad, b.bit_not(healthy), m.is_state(15UL)]))
  let fault = ordered_input(m, "mac_fault", 1)
  m.jump(b.bit_and(live, fault), 15UL)
  m.set("error", b.bit_and(live, fault), 4UL)
  let ret = all(b, [
    ordered_input(m, "mac_retire", 1),
    live,
    healthy,
    b.bit_not(bad),
    b.bit_not(fault),
    either(b, [m.is_state(20UL), m.is_state(21UL)]),
  ])
  let row_slot = ordered_input(m, "mac_retired_slot", 3)
  let lanes = b.mux(
    b.equal(last_row, u(b, 9, 15UL)),
    u(b, 32, 16UL),
    b.mux(b.equal(last_row, u(b, 9, 31UL)), u(b, 32, 32UL), u(b, 32, 64UL)),
  )
  let count = b.shift_left(
    lanes,
    if stripe512 is Some(w) {
      b.mux(w, u(b, 4, 9UL), b.mux(long_stripe, u(b, 4, 8UL), u(b, 4, 6UL)))
    } else {
      b.mux(long_stripe, u(b, 4, 8UL), u(b, 4, 6UL))
    },
  )
  m.put("products", ret, b.add(m.v("products"), count))
  // During state 22 prime row zero. During state 23 pre-read the next row's
  // slot so the transition from lane 63 to lane 0 has no writeback bubble.
  let write = m.v("p_write")
  let next_address = b.mux(
    m.is_state(23UL),
    field(b, b.add(write, u(b, 9, 1UL)), 8, 6),
    u(b, 3, 0UL),
  )
  let mut words = Array::makei(64, i => {
    let mem = b.synchronous_memory(
      "ordered_result_" + i.to_string(),
      @wire.uint(32),
      8,
      m.d,
      read_write_policy=ReadOld,
      multi_write_policy=Reject,
    )
    b.memory_write(
      mem,
      "retire",
      row_slot,
      ordered_input(m, "mac_sum" + i.to_string(), 32),
      enable=ret,
    )
    b.memory_read(
      mem,
      "writeback",
      next_address,
      enable=all(b, [
        b.bit_not(b.reset_asserted(m.rs)),
        either(b, [m.is_state(22UL), m.is_state(23UL)]),
      ]),
      enable_behavior=HoldLast,
    )
  })
  for index in 0..<6 {
    let prev = words
    words = Array::makei(prev.length() / 2, i => {
      b.mux(bit(b, write, index), prev[2 * i + 1], prev[2 * i])
    })
  }
  (b.bit_and(ret, b.equal(row_slot, last_slot)), words[0])
}
