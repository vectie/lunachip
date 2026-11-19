///|
priv struct StreamRead {
  burst_length : @wire.Signal?
  arvalid : @wire.Signal
  address : @wire.Signal
  rready : @wire.Signal
  bad_axi : @wire.Signal
  valid : @wire.Signal
  fault : @wire.Signal
  last : @wire.Signal
  done : @wire.Signal
  words : Array[@wire.Signal]
}

///|
/// Issue same-ID reads with up to sixteen outstanding. At 1024 bits a
/// 512-byte burst takes four beats. A 32 KiB group issues 64 such bursts.
/// Each burst fits one 4 KiB page. An elastic register delivers ordered beats.
fn stream_read(
  b : @wire.ModuleBuilder,
  d : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  start : @wire.Signal,
  active : @wire.Signal,
  running : @wire.Signal,
  address : @wire.Signal,
  batch : @wire.Signal,
  stride : @wire.Signal,
  healthy : @wire.Signal,
  ready : @wire.Signal,
  arready : @wire.Signal,
  rvalid : @wire.Signal,
  rresp : @wire.Signal,
  rlast : @wire.Signal,
  read_words : Array[@wire.Signal],
  deep_batch~ : Bool = false,
  strided_rows~ : Bool = false,
  group64~ : @wire.Signal? = None,
  slice1k~ : @wire.Signal? = None,
  prefetch~ : @wire.Signal? = None,
) -> StreamRead raise {
  fn reg(w : Int32) -> @wire.RegisterHandle raise {
    b.register_state_in(
      d,
      if w == 1 {
        @wire.bits(1)
      } else {
        @wire.uint(w)
      },
      reset~,
    )
  }
  let beats_per_row = 32 / read_words.length()
  let last_beat = (beats_per_row - 1).to_uint64()
  let long = if read_words.length() == 32 {
    let flag = reg(1)
    update(b, flag, start, b.bit_and(batch, b.slice(stride, 30, 30)))
    Some(flag.value())
  } else {
    None
  }
  let row_bits = if prefetch is Some(_) {
    10
  } else if deep_batch {
    7
  } else {
    5
  }
  let packet_bits = if prefetch is Some(_) {
    12
  } else if deep_batch {
    8
  } else {
    6
  }
  let spaced = if strided_rows {
    Some(b.bit_or(eq(b, stride, 0xe0001000UL), eq(b, stride, 0xe0001800UL)))
  } else {
    None
  }
  let group32 = if deep_batch {
    let contiguous = eq(b, stride, 0xe0000200UL)
    Some(
      if spaced is Some(wider) {
        b.bit_or(contiguous, wider)
      } else {
        contiguous
      },
    )
  } else {
    None
  }
  let group32 = if group64 is Some(g) {
    Some(b.bit_or(g, group32.unwrap()))
  } else {
    group32
  }
  let pending = reg(1)
  let ar_address = reg(32)
  let row_stride = reg(32)
  let rows = reg(row_bits)
  let issued = reg(row_bits)
  let completed = reg(row_bits)
  let wide_row = if slice1k is Some(w) {
    let flag = reg(1)
    update(b, flag, start, w)
    Some(flag.value())
  } else {
    None
  }
  let beat_bits = if wide_row is Some(_) { 3 } else { 2 }
  let beat = reg(beat_bits)
  let stopped = reg(2)
  let held = reg(1)
  let held_fault = reg(2)
  let delivered = reg(packet_bits)
  let final_packet = reg(packet_bits)
  let valid = both(b, [active, running, held.value()])
  let consume = b.bit_and(valid, ready)
  let last = b.equal(delivered.value(), final_packet.value())
  let done = b.bit_and(consume, last)
  let room = both(b, [
    active,
    b.bit_or(b.bit_not(held.value()), ready),
    b.bit_not(done),
  ])
  let outstanding = b.not_equal(issued.value(), completed.value())
  let failed = b.bit_not(eq(b, stopped.value(), 0UL))
  // Drain already addressed reads on a fault. A previously stalled AR stays
  // valid until handshake, even if the source has consumed all fault replies.
  let rready = both(b, [running, outstanding, b.bit_or(room, failed)])
  let receive = b.bit_and(rready, rvalid)
  let bad_axi = both(b, [
    receive,
    any(b, [
      b.bit_not(eq(b, rresp, 0UL)),
      b.bit_xor(
        rlast,
        if long is Some(flag) {
          b.bit_or(
            b.bit_not(flag),
            if wide_row is Some(w) {
              b.mux(
                w,
                eq(b, beat.value(), 7UL),
                eq(b, b.slice(beat.value(), 1, 0), 3UL),
              )
            } else {
              eq(b, beat.value(), 3UL)
            },
          )
        } else {
          eq(b, beat.value(), last_beat)
        },
      ),
    ]),
  ])
  let fault_now = b.mux(
    failed,
    stopped.value(),
    b.mux(
      b.bit_not(healthy),
      n(b, 2, 2UL),
      b.mux(bad_axi, n(b, 2, 3UL), n(b, 2, 0UL)),
    ),
  )
  let stop = b.bit_not(eq(b, fault_now, 0UL))
  let arvalid = b.bit_and(running, pending.value())
  // Across a 32 KiB group keep at most sixteen AXI read transactions
  // outstanding. Credit can only increase while ARVALID is stalled.
  let arvalid = if deep_batch {
    b.bit_and(
      arvalid,
      b.less_than(
        b.sub(issued.value(), completed.value()),
        n(b, row_bits, 16UL),
      ),
    )
  } else {
    arvalid
  }
  let issue = b.bit_and(arvalid, arready)
  let new_count = b.add(issued.value(), n(b, row_bits, 1UL))
  b.connect_next(
    pending,
    b.mux(
      start,
      n(b, 1, 1UL),
      b.mux(
        issue,
        both(b, [b.less_than(new_count, rows.value()), b.bit_not(stop)]),
        pending.value(),
      ),
    ),
  )
  // After the fourth 512-byte burst advance to the next physical row.
  // Both the issue index and current address stay stable under AR stalls.
  let step = if spaced is Some(wider) {
    let striped = reg(1)
    update(b, striped, start, wider)
    b.mux(
      b.bit_and(
        striped.value(),
        b.bit_not(eq(b, b.slice(issued.value(), 1, 0), 3UL)),
      ),
      n(b, 32, 512UL),
      row_stride.value(),
    )
  } else {
    row_stride.value()
  }
  b.connect_next(
    ar_address,
    b.mux(
      start,
      address,
      b.mux(issue, b.add(ar_address.value(), step), ar_address.value()),
    ),
  )
  update(
    b,
    row_stride,
    start,
    {
      let encoded = b.zero_extend(
        u(
          b,
          b.slice(stride, if read_words.length() == 32 { 29 } else { 30 }, 0),
        ),
        32,
      )
      if group32 is Some(g) {
        let delta = if strided_rows {
          b.mux(
            eq(b, stride, 0xe0001000UL),
            n(b, 32, 2560UL),
            b.mux(
              eq(b, stride, 0xe0001800UL),
              n(b, 32, 4608UL),
              n(b, 32, 512UL),
            ),
          )
        } else {
          n(b, 32, 512UL)
        }
        let delta = if group64 is Some(tag) {
          b.mux(tag, b.zero_extend(u(b, b.slice(stride, 12, 0)), 32), delta)
        } else {
          delta
        }
        b.mux(g, delta, encoded)
      } else {
        encoded
      }
    },
  )
  update(
    b,
    rows,
    start,
    b.mux(
      batch,
      if group32 is Some(g) {
        b.mux(
          g,
          if slice1k is Some(w) {
            let count = if prefetch is Some(early) {
              b.mux(early, n(b, row_bits, 512UL), n(b, row_bits, 32UL))
            } else {
              n(b, row_bits, 32UL)
            }
            b.mux(w, count, n(b, row_bits, 64UL))
          } else {
            n(b, row_bits, 64UL)
          },
          n(b, row_bits, 16UL),
        )
      } else {
        n(b, row_bits, 16UL)
      },
      n(b, row_bits, 1UL),
    ),
  )
  b.connect_next(
    issued,
    b.mux(start, n(b, row_bits, 0UL), b.mux(issue, new_count, issued.value())),
  )
  b.connect_next(
    completed,
    b.mux(
      start,
      n(b, row_bits, 0UL),
      b.mux(
        b.bit_and(receive, rlast),
        b.add(completed.value(), n(b, row_bits, 1UL)),
        completed.value(),
      ),
    ),
  )
  b.connect_next(
    beat,
    b.mux(
      start,
      n(b, beat_bits, 0UL),
      b.mux(
        receive,
        if beats_per_row == 2 {
          b.bit_xor(beat.value(), n(b, beat_bits, 1UL))
        } else {
          b.add(beat.value(), n(b, beat_bits, 1UL))
        },
        beat.value(),
      ),
    ),
  )
  b.connect_next(
    stopped,
    b.mux(start, n(b, 2, 0UL), b.mux(active, fault_now, stopped.value())),
  )
  let publish = b.bit_and(room, b.bit_or(receive, stop))
  b.connect_next(
    held,
    b.mux(
      start,
      n(b, 1, 0UL),
      b.bit_or(publish, both(b, [held.value(), b.bit_not(consume)])),
    ),
  )
  update(b, held_fault, publish, fault_now)
  update(
    b,
    final_packet,
    start,
    b.mux(
      batch,
      if read_words.length() == 32 {
        b.mux(
          b.slice(stride, 30, 30),
          if group32 is Some(g) {
            let last_group_beat = if prefetch is Some(early) {
              b.mux(early, n(b, packet_bits, 4095UL), n(b, packet_bits, 255UL))
            } else {
              n(b, packet_bits, 255UL)
            }
            b.mux(g, last_group_beat, n(b, packet_bits, 63UL))
          } else {
            n(b, packet_bits, 63UL)
          },
          n(b, packet_bits, 15UL),
        )
      } else {
        n(b, packet_bits, (16 * beats_per_row - 1).to_uint64())
      },
      n(b, packet_bits, last_beat),
    ),
  )
  b.connect_next(
    delivered,
    b.mux(
      start,
      n(b, packet_bits, 0UL),
      b.mux(
        consume,
        b.add(delivered.value(), n(b, packet_bits, 1UL)),
        delivered.value(),
      ),
    ),
  )
  let words = read_words.map(word => {
    let slot = reg(32)
    update(b, slot, publish, word)
    b.mux(eq(b, held_fault.value(), 0UL), slot.value(), n(b, 32, 0UL))
  })
  {
    burst_length: match long {
      Some(flag) =>
        Some(
          b.mux(
            flag,
            if wide_row is Some(w) {
              b.mux(w, n(b, 8, 7UL), n(b, 8, 3UL))
            } else {
              n(b, 8, 3UL)
            },
            n(b, 8, 0UL),
          ),
        )
      None => None
    },
    arvalid,
    address: ar_address.value(),
    rready,
    bad_axi,
    valid,
    fault: held_fault.value(),
    last,
    done,
    words,
  }
}
