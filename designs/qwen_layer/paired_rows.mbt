///|
fn Machine::accumulator_count(m : Machine) -> Int32 {
  if m.paired_rows {
    2 * m.row_lanes
  } else {
    m.row_lanes
  }
}

///|
// A lane alternates two independent rows. Its two-edge rounded addition
// retires before the next product for the same row samples the accumulator.
// Packed-16 and smaller row-major groups issue every other edge instead.
fn paired_group(m : Machine) -> @wire.Signal raise {
  let b = m.b
  all(b, [
    b.equal(m.v("flags"), u(b, 32, 0UL)),
    b.equal(field(b, m.v("n"), 6, 0), u(b, 7, 0UL)),
  ])
}

///|
fn paired_accumulate(
  m : Machine,
  lane : Int32,
  product : @wire.Signal,
  read_half : @wire.Signal,
  write_half : @wire.Signal,
  commit : @wire.Signal,
) -> Unit raise {
  let b = m.b
  let lo = "p_sum" + lane.to_string()
  let hi = "p_sum" + (lane + m.row_lanes).to_string()
  let previous = b.mux(read_half, m.v(hi), m.v(lo))
  let sum = add(
    b,
    previous,
    product,
    fast=true,
    bounded=m.bounded_add,
    pipeline=Some((m.d, m.reset)),
  )
  m.put(lo, b.bit_and(commit, b.bit_not(write_half)), sum)
  m.put(hi, b.bit_and(commit, write_half), sum)
}

///|
fn paired_write_data(m : Machine) -> @wire.Signal raise {
  let b = m.b
  let mut words = Array::makei(m.accumulator_count(), i => {
    m.v("p_sum" + i.to_string())
  })
  for stage in 0..<m.lane_width {
    let previous = words
    let select = bit(b, m.v("p_write"), stage)
    words = Array::makei(previous.length() / 2, i => {
      b.mux(select, previous[2 * i + 1], previous[2 * i])
    })
  }
  words[0]
}
