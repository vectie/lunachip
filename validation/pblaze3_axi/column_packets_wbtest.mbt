///|
// Host-side model of the two GEMV issue schedules. All 128-byte response data,
// response cycles, AR handshakes, stalls and burst boundaries come from the
// existing 1024-bit LunaWire AXI bridge running in LunaWave.
fn layout_weight(row : Int32, col : Int32) -> UInt32 {
  let key = ((row.reinterpret_as_uint() + 1U) * 2654435761U) ^
    ((col.reinterpret_as_uint() + 3U) * 2246822519U)
  ((key >> 16) & 0x807fU) | ((116U + key % 19U) << 7)
}

///|
fn as_float(half : UInt32) -> Float {
  Float::reinterpret_from_uint(half << 16)
}

///|
fn layout_beat(
  bench : Bench,
  base : UInt64,
  stride : Int32,
  can_accept : () -> Bool,
  on_packet : (Int32, Array[UInt64]) -> Unit raise,
) -> Unit raise {
  bench.begin(base, line=true, burst=true, wide=true, data=[
    0xc0000000UL | stride.to_uint64(),
    0UL,
    0UL,
    0UL,
  ])
  let start = bench.cycle
  while bench.responses.length() < 64 && bench.cycle - start < 2000 {
    set(bench.sim, "response_ready", 1, if can_accept() { 1UL } else { 0UL })
    let packet = bench.responses.length()
    bench.step()
    if bench.responses.length() != packet {
      let (words, fault, last) = bench.responses[packet]
      assert_eq(fault, 0UL)
      assert_eq(last, if packet == 63 { 1UL } else { 0UL })
      on_packet(packet, words)
    }
  }
  assert_eq(bench.responses.length(), 64)
}

///|
fn compare_layout(
  rows : Int32,
  cols : Int32,
  latency : Int32,
  column_packets : Bool,
  fifo_depth : Int32,
) -> (Int32, Int32, Int32) raise {
  let bus = bench(
    streaming=true,
    wide512=true,
    wide1024=true,
    latency~,
    read_credits=8,
  )
  let base = 0x02000000UL
  let x = Array::makei(cols, i => {
    Float::from_double((i * 29 % 113 - 56).to_double() / 73.0)
  })
  let sums = Array::make(rows, 0.0F)
  let golden = Array::make(rows, 0.0F)
  // Halfword order is the published little-endian BF16 representation.
  for row in 0..<rows {
    for col in 0..<cols {
      let bits = layout_weight(row, col)
      let index = if column_packets {
        (row / 64 * cols + col) * 64 + row % 64
      } else {
        row * cols + col
      }
      let address = base + (index / 2 * 4).to_uint64()
      bus.memory[address] = bus.memory.get(address).unwrap_or(0UL) |
        (bits.to_uint64() << (16 * (index % 2)))
      golden[row] += x[col] * as_float(bits)
    }
  }
  let start = bus.cycle
  let mut next_issue = start
  let mut first_issue = -1
  let mut packets = 0
  let tile = Array::make(64 * 256, 0U)
  // Each entry records the clock at which a buffered column enters the MAC.
  let departure = Array::make(fifo_depth, start)
  for g in 0..<(rows / 64) {
    for stripe in 0..<(cols / 256) {
      let col = stripe * 256
      for part in 0..<4 {
        let (offset, stride) = if column_packets {
          ((g * cols + col + part * 64) * 128, 512)
        } else {
          (((g * 64 + part * 16) * cols + col) * 2, cols * 2)
        }
        layout_beat(
          bus,
          base + offset.to_uint64(),
          stride,
          () => {
            fifo_depth == 0 || departure[packets % fifo_depth] <= bus.cycle + 1
          },
          (beat, words) => {
            if fifo_depth > 0 {
              let issue = bus.cycle.max(next_issue)
              departure[packets % fifo_depth] = issue
              next_issue = issue + 1
              if col + part * 64 + beat + 1 == cols {
                next_issue += 69 // drain the pipeline and publish all row sums
              }
            }
            packets += 1
            for j in 0..<64 {
              let w = ((words[j / 2] >> (16 * (j % 2))) & 65535UL).to_uint()
              if column_packets {
                sums[g * 64 + j] += x[col + part * 64 + beat] * as_float(w)
              } else {
                tile[(part * 16 + beat / 4) * 256 + beat % 4 * 64 + j] = w
              }
            }
            if column_packets && first_issue < 0 {
              first_issue = bus.cycle
            }
          },
        )
      }
      if column_packets && fifo_depth == 0 {
        // No stripe drain. Preserve ordered sums through request boundaries.
        // No cross-group buffer in this candidate: drain and publish 64 rows.
        next_issue = bus.cycle
        if col + 256 == cols {
          for _ in 0..<69 {
            bus.step()
          }
          next_issue = bus.cycle
        }
      } else if !column_packets {
        // Ping-pong allows this fill to overlap issue, drain and result writes
        // of the previous stripe. Only the first stripe has no predecessor.
        while bus.cycle < next_issue {
          bus.step()
        }
        bus.step() // hand off the full bank
        if first_issue < 0 {
          first_issue = bus.cycle
        }
        for r in 0..<64 {
          for k in 0..<256 {
            sums[g * 64 + r] += x[col + k] * as_float(tile[r * 256 + k])
          }
        }
        next_issue = bus.cycle +
          256 +
          5 +
          (if col + 256 == cols { 64 } else { 0 })
      }
    }
  }
  assert_eq(packets, rows * cols / 64)
  assert_eq(bus.reads.length(), packets / 4)
  for r in 0..<rows {
    assert_eq(sums[r].reinterpret_as_uint(), golden[r].reinterpret_as_uint())
  }
  (
    first_issue - start,
    next_issue - start - (if fifo_depth > 0 { 1 } else { 0 }),
    packets,
  )
}

///|
test "complete GEMV with 64 BF16 rows per packet uses the existing AXI bridge" {
  for latency in [4, 16, 32] {
    for (col, depth) in [(false, 0), (true, 0), (true, 16), (true, 64)] {
      let (first, cycles, packets) = compare_layout(
        384, 1024, latency, col, depth,
      )
      println(
        "GEMV rows=384 cols=1024 latency=\{latency} column_packets=\{col} fifo=\{depth} first=\{first} cycles=\{cycles} packets=\{packets} exact_rows=384",
      )
    }
  }
}
