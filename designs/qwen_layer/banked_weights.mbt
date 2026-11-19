///|
// At each stage a shared selector bit rotates an entire vector by 2^stage.
fn rotate_weight_lanes(
  b : @wire.ModuleBuilder,
  words : Array[@wire.Signal],
  selector : @wire.Signal,
  stages : Int32,
  subtract~ : Bool,
) -> Array[@wire.Signal] raise {
  let mut result = words
  for stage in 0..<stages {
    let distance = 1 << stage
    let offset = if subtract { words.length() - distance } else { distance }
    let select = bit(b, selector, stage)
    let previous = result
    result = Array::makei(words.length(), i => {
      b.mux(select, previous[(i + offset) % words.length()], previous[i])
    })
  }
  result
}

///|
// In each 64-column segment, pair p in row r lives in bank (r+p) mod 64.
// Longer stripes prepend the segment index to the pair address. One packet
// writes 16 or 32 distinct banks. An issue reads all 64 rows in parallel.
fn banked_weights(
  m : Machine,
  inputs : Map[String, @wire.Signal],
  accept : @wire.Signal,
  issue : @wire.Signal,
  select_high : @wire.Signal,
) -> Array[@wire.Signal] raise {
  let b = m.b
  // RAM reads have no externally committed side effect. During a credit
  // stall reread the current address; the independently registered issue bit
  // still controls consumption. Reset must suppress the initial read before
  // the state/address registers are known. Keep protocol, health and credit
  // off this high-fanout BRAM enable path.
  let reading = if m.eager_weight_reads {
    all(b, [b.bit_not(b.reset_asserted(m.rs)), m.is_state(20UL)])
  } else {
    issue
  }
  let row = m.v("p_lane")
  let row_in_half = if m.paired_rows { field(b, row, 5, 0) } else { row }
  let packet_words = if m.prefetch256 { 32 } else { 16 }
  let packet = Array::makei(packet_words, i => {
    inputs[if i == 0 {
      "ddr_response_data"
    } else {
      "ddr_response_data" + i.to_string()
    }]
  })
  let write_words = rotate_weight_lanes(
    b,
    packet,
    row,
    if m.prefetch256 {
      5
    } else {
      4
    },
    subtract=true,
  )
  let pair = field(b, m.v("p_index"), 5, 1)
  let read_address = cat(
    b,
    if m.ordered_array {
      cat(b, m.v("o_active"), m.v("ordered_slot"))
    } else if m.paired_rows {
      cat(b, m.v("o_active"), m.v("p_issue_gap"))
    } else {
      m.v("o_active")
    },
    if m.ordered_array {
      field(b, m.v("p_index"), if m.stripe512 { 8 } else { 7 }, 1)
    } else if m.full_rows {
      field(b, m.v("p_index"), 9, 1)
    } else if m.prefetch256 {
      field(b, m.v("p_index"), 7, 1)
    } else {
      pair
    },
  )
  let values = Array::makei(64, bank => {
    let address = b.sub(u(b, 6, bank.to_uint64()), row_in_half)
    let writing = all(b, [
      accept,
      b.bit_not(bit(b, address, 5)),
      if m.prefetch256 {
        b.constant(@wire.bits(1), 1UL)
      } else {
        b.equal(bit(b, address, 4), bit(b, m.v("fill"), 4))
      },
    ])
    let ram = b.synchronous_memory(
      "matrix_bank_" + bank.to_string(),
      @wire.uint(32),
      if m.stripe512 {
        4096
      } else if m.full_rows {
        2048
      } else if m.paired_rows {
        512
      } else if m.prefetch256 {
        256
      } else {
        64
      },
      m.d,
      read_write_policy=ReadOld,
      multi_write_policy=Reject,
    )
    b.memory_write(
      ram,
      "ddr",
      cat(
        b,
        if m.ordered_array {
          cat(b, m.v("o_bank"), field(b, row, 8, 6))
        } else if m.paired_rows {
          cat(b, m.v("o_bank"), bit(b, row, 6))
        } else {
          m.v("o_bank")
        },
        if m.ordered_array {
          cat(
            b,
            field(b, m.v("packet_in_row"), if m.stripe512 { 2 } else { 1 }, 0),
            field(b, address, 4, 0),
          )
        } else if m.prefetch256 {
          cat(b, m.v("packet_in_row"), field(b, address, 4, 0))
        } else {
          field(b, address, 4, 0)
        },
      ),
      write_words[bank % packet_words],
      enable=writing,
    )
    let data = b.memory_read(
      ram,
      "weight",
      read_address,
      enable=reading,
      enable_behavior=HoldLast,
    )
    b.mux(select_high, field(b, data, 31, 16), field(b, data, 15, 0))
  })
  let delayed_pair = b.register_in(m.d, pair, reset=m.reset)
  rotate_weight_lanes(b, values, delayed_pair, 5, subtract=false)
}
